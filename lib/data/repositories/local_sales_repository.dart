import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../../core/utils/money_calculator.dart';
import '../local/db/app_database.dart';
import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/repositories.dart';
import 'local_ledger_repository.dart';

class LocalSalesRepository implements SalesRepository {
  LocalSalesRepository(this._db, [LocalLedgerRepository? ledgerRepo])
      : _ledgerRepository = ledgerRepo ?? LocalLedgerRepository(_db);

  final AppDatabase _db;
  final LocalLedgerRepository _ledgerRepository;

  @override
  Future<SaleCheckoutResult> checkout(SaleCheckoutInput input) async {
    if (input.items.isEmpty) {
      throw AppException('Cart is empty');
    }

    return _db.transaction(() async {
      final settings = await (_db.select(_db.appSettings)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
      final allowNegativeStock = settings?.allowNegativeStock ?? false;

      final now = DateTime.now();

      // Aggregate total quantity needed per productId to avoid race condition or insufficient stock
      // if same product is in cart multiple times
      final Map<int, int> requiredQtyPerProduct = {};
      for (final item in input.items) {
        requiredQtyPerProduct[item.productId] = (requiredQtyPerProduct[item.productId] ?? 0) + item.qty;
      }

      final productIds = requiredQtyPerProduct.keys.toList();
      final products = await (_db.select(_db.products)..where((tbl) => tbl.id.isIn(productIds))).get();
      final productById = {for (final product in products) product.id: product};

      for (final entry in requiredQtyPerProduct.entries) {
        final product = productById[entry.key];
        if (product == null) {
          throw AppException('Product ID ${entry.key} no longer exists');
        }
        if (!allowNegativeStock && product.stockQty < entry.value) {
          throw AppException('Insufficient stock for ${product.name} (Required: ${entry.value}, Available: ${product.stockQty})');
        }
      }

      final lineTotals = input.items
          .map(
            (item) => MoneyCalculator.lineTotal(
              unitPrice: item.price,
              qty: item.qty,
              itemDiscount: item.discount,
            ),
          )
          .toList();

      final subtotal = MoneyCalculator.subtotal(lineTotals);
      final itemDiscountTotal = MoneyCalculator.round2(input.items.fold(0, (sum, item) => sum + item.discount));
      final tax = MoneyCalculator.tax(
        taxableAmount: max(0, subtotal - input.orderDiscount),
        taxEnabled: input.taxEnabled,
        taxRate: input.taxRate,
      );
      final rawTotal = MoneyCalculator.orderTotal(
        subtotal: subtotal,
        orderDiscount: input.orderDiscount,
        tax: tax,
      );

      // Apply rounded total and delta
      final roundOffCalc = MoneyCalculator.roundOffTotal(rawTotal);
      final roundedTotal = roundOffCalc.roundedTotal;
      final roundOffDelta = roundOffCalc.roundOff;
      final total = roundedTotal;

      final discountTotal = MoneyCalculator.round2(itemDiscountTotal + input.orderDiscount);
      double paid = input.paid;
      if (input.splitPayments != null && input.splitPayments!.isNotEmpty) {
        paid = MoneyCalculator.round2(input.splitPayments!.fold(0.0, (sum, sp) => sum + sp.amount));
      }
      final change = MoneyCalculator.round2(max(0, paid - total));
      final actualPaidForOrder = MoneyCalculator.round2(min(paid, total));

      final invoiceNo = await _nextInvoiceNo(now);
      final wsId = input.workspaceId ?? 1;

      // Determine GST breakdown based on isInterState flag
      final gstBreakdown = MoneyCalculator.calculateGst(
        taxableAmount: max(0, subtotal - input.orderDiscount),
        gstRate: input.taxRate,
        isInterState: input.isInterState,
      );

      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              invoiceNo: invoiceNo,
              createdAt: Value(now),
              customerId: Value(input.customerId),
              employeeId: Value(input.employeeId),
              subtotal: subtotal,
              discountTotal: discountTotal,
              taxTotal: tax,
              total: total,
              paid: paid,
              changeAmount: change,
              paymentMethod: input.paymentMethod.value,
              status: SaleStatus.completed.value,
              workspaceId: Value(wsId),
              cgstTotal: Value(gstBreakdown.cgst),
              sgstTotal: Value(gstBreakdown.sgst),
              igstTotal: Value(gstBreakdown.igst),
              roundOff: Value(roundOffDelta),
            ),
          );

      // Update Group 4 extra attributes on sale
      final splitJson = input.splitPayments != null && input.splitPayments!.isNotEmpty
          ? jsonEncode(input.splitPayments!.map((e) => e.toJson()).toList())
          : null;
      await _db.customStatement('''
        UPDATE sales
        SET cashier_name = ?, notes = ?, payment_details = ?
        WHERE id = ?;
      ''', [input.cashierName, input.notes, splitJson, saleId]);

      // Record items and perform ATOMIC stock decrements
      for (var i = 0; i < input.items.length; i++) {
        final item = input.items[i];

        final saleItemId = await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: item.productId,
                nameSnapshot: item.name,
                costSnapshot: item.cost,
                priceSnapshot: item.price,
                qty: item.qty,
                discount: Value(item.discount),
                lineTotal: lineTotals[i],
              ),
            );

        final itemGstRate = input.taxEnabled ? item.gstRate : 0.0;
        final itemTaxable = subtotal > 0
            ? max(0.0, lineTotals[i] - (lineTotals[i] / subtotal) * input.orderDiscount)
            : 0.0;
        final itemTaxAmount = input.taxEnabled
            ? MoneyCalculator.tax(taxableAmount: itemTaxable, taxEnabled: true, taxRate: itemGstRate)
            : 0.0;
        final itemCgst = (!input.isInterState && input.taxEnabled) ? MoneyCalculator.round2(itemTaxAmount / 2.0) : 0.0;
        final itemSgst = (!input.isInterState && input.taxEnabled) ? MoneyCalculator.round2(itemTaxAmount / 2.0) : 0.0;
        final itemIgst = (input.isInterState && input.taxEnabled) ? itemTaxAmount : 0.0;

        // Update Group 4 and Phase 5.1 item details
        await _db.customStatement('''
          UPDATE sale_items
          SET batch_id = ?, batch_number = ?, unit = ?, line_note = ?, discount_amount = ?, tax_rate = ?, hsn_code = ?,
              cgst = ?, sgst = ?, igst = ?, tax_amount = ?
          WHERE id = ?;
        ''', [
          item.batchId,
          item.batchNumber,
          item.unit,
          item.lineNote,
          item.discount,
          itemGstRate,
          item.hsnCode,
          itemCgst,
          itemSgst,
          itemIgst,
          itemTaxAmount,
          saleItemId,
        ]);

        // Atomic stock decrement via SQL arithmetic to prevent overwrite
        final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
        await _db.customStatement('''
          UPDATE products
          SET stock_qty = stock_qty - ?, updated_at = ?
          WHERE id = ?
        ''', [item.qty, nowSeconds, item.productId]);

        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: item.productId,
                type: StockMovementType.sale.value,
                qtyChange: -item.qty,
                reason: Value('Sale $invoiceNo'),
                createdAt: Value(now),
              ),
            );

        // Deduct from batch: if item has a specific batch assigned, deduct from it
        if (item.batchId != null) {
          await _db.customStatement('''
            UPDATE product_batches
            SET quantity = MAX(0, quantity - ?), updated_at = ?
            WHERE id = ?;
          ''', [item.qty, nowSeconds, item.batchId]);
        } else {
          // FEFO batch stock reduction: deduct from earliest-expiring active batches
          try {
            final batches = await _db.customSelect(
              'SELECT id, quantity FROM product_batches WHERE product_id = ? AND quantity > 0 ORDER BY expiry_date ASC, id ASC;',
              variables: [Variable.withInt(item.productId)],
            ).get();

            var remainingToDeduct = item.qty;
            for (final b in batches) {
              if (remainingToDeduct <= 0) break;
              final bId = b.data['id'] as int;
              final bQty = (b.data['quantity'] as num).toInt();
              final deductFromBatch = min(remainingToDeduct, bQty);
              await _db.customStatement('''
                UPDATE product_batches
                SET quantity = quantity - ?, updated_at = ?
                WHERE id = ?;
              ''', [deductFromBatch, nowSeconds, bId]);
              remainingToDeduct -= deductFromBatch;
            }
          } catch (_) {}
        }
      }

      // 4. Double-Entry Financial Ledger Posting
      // Segregating Sales Revenue (Net Taxable) and GST Output Tax (Liability)
      final List<LedgerPostingItem> ledgerEntries = [];

      final double taxableRevenue = MoneyCalculator.round2(max(0, subtotal - input.orderDiscount) + roundOffDelta);
      final double gstOutputTax = MoneyCalculator.round2(tax);

      // Credit: Sales Revenue = taxableRevenue
      ledgerEntries.add(
        LedgerPostingItem(
          transactionType: 'sale',
          referenceType: 'revenue',
          referenceId: saleId,
          debit: 0.0,
          credit: taxableRevenue,
          narration: 'Sales revenue for invoice $invoiceNo',
          createdAt: now,
        ),
      );

      // Credit: GST Output Tax Payable (Liability) = gstOutputTax
      if (gstOutputTax > 0) {
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'sale',
            referenceType: 'tax_payable',
            referenceId: saleId,
            debit: 0.0,
            credit: gstOutputTax,
            narration: 'GST Output Tax collected for invoice $invoiceNo (CGST: ${gstBreakdown.cgst}, SGST: ${gstBreakdown.sgst}, IGST: ${gstBreakdown.igst})',
            createdAt: now,
          ),
        );
      }

      // If customer paid anything up-front
      if (actualPaidForOrder > 0) {
        if (input.splitPayments != null && input.splitPayments!.isNotEmpty) {
          for (final sp in input.splitPayments!) {
            if (sp.amount <= 0) continue;
            final int accId = sp.accountId ??
                (sp.method == PaymentMethod.cash
                    ? 1
                    : (sp.method == PaymentMethod.bankTransfer ? 2 : 3));

            ledgerEntries.add(
              LedgerPostingItem(
                transactionType: 'payment_in',
                referenceType: 'sale',
                referenceId: saleId,
                accountId: accId,
                debit: sp.amount,
                credit: 0.0,
                narration: 'Split payment for invoice $invoiceNo via ${sp.method.value}',
                createdAt: now,
              ),
            );

            await _db.customStatement('''
              INSERT INTO payments (
                workspace_id, payment_type, reference_type, reference_id,
                account_id, amount, payment_mode, reference_no, narration, created_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              wsId,
              'customer_receipt',
              'sale',
              saleId,
              accId,
              sp.amount,
              sp.method.value,
              sp.referenceNo ?? invoiceNo,
              'Sale split payment receipt',
              now.millisecondsSinceEpoch ~/ 1000,
            ]);
          }
        } else {
          // Single payment
          final int defaultAccountId = input.paymentAccountId ??
              (input.paymentMethod == PaymentMethod.cash
                  ? 1
                  : (input.paymentMethod == PaymentMethod.bankTransfer ? 2 : 3));

          ledgerEntries.add(
            LedgerPostingItem(
              transactionType: 'payment_in',
              referenceType: 'sale',
              referenceId: saleId,
              accountId: defaultAccountId,
              debit: actualPaidForOrder,
              credit: 0.0,
              narration: 'Payment received for invoice $invoiceNo via ${input.paymentMethod.value}',
              createdAt: now,
            ),
          );

          // Record in payments table
          await _db.customStatement('''
            INSERT INTO payments (
              workspace_id, payment_type, reference_type, reference_id,
              account_id, amount, payment_mode, reference_no, narration, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            wsId,
            'customer_receipt',
            'sale',
            saleId,
            defaultAccountId,
            actualPaidForOrder,
            input.paymentMethod.value,
            input.paymentReference ?? invoiceNo,
            'Sale payment receipt',
            now.millisecondsSinceEpoch ~/ 1000,
          ]);
        }
      }

      // If uncollected balance remains, debit Customer Receivable
      final double unpaidAmount = MoneyCalculator.round2(total - actualPaidForOrder);
      if (unpaidAmount > 0) {
        int custId;
        if (input.customerId != null) {
          custId = input.customerId!;
        } else {
          // Find or ensure Walk-in Customer record in this workspace
          final walkInRow = await (_db.select(_db.customers)
                ..where((tbl) => tbl.workspaceId.equals(wsId) & tbl.name.equals('Walk-in Customer')))
              .getSingleOrNull();
          if (walkInRow != null) {
            custId = walkInRow.id;
          } else {
            final firstCust = await (_db.select(_db.customers)
                  ..where((tbl) => tbl.workspaceId.equals(wsId))
                  ..limit(1))
                .getSingleOrNull();
            custId = firstCust?.id ?? 1;
          }
        }

        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'sale',
            referenceType: 'customer',
            referenceId: custId,
            partyType: 'customer',
            partyId: custId,
            debit: unpaidAmount,
            credit: 0.0,
            narration: 'Outstanding credit balance for invoice $invoiceNo',
            createdAt: now,
          ),
        );
      }

      // Post balanced transaction
      await _ledgerRepository.postTransaction(
        workspaceId: wsId,
        entries: ledgerEntries,
      );

      // Attribution & Incentive Calculation Hook
      if (input.employeeId != null) {
        try {
          final rules = await _db.customSelect(
            'SELECT * FROM incentive_rules WHERE is_active = 1 AND (workspace_id = ? OR workspace_id IS NULL)',
            variables: [Variable.withInt(wsId)],
            readsFrom: {},
          ).get();

          double computedIncentive = 0.0;
          for (final rule in rules) {
            final type = rule.data['rule_type'] as String? ?? 'percentage_revenue';
            final threshold = (rule.data['threshold_amount'] as num? ?? 0.0).toDouble();
            final rate = (rule.data['reward_rate'] as num? ?? 0.0).toDouble();
            final targetPid = rule.data['target_product_id'] as int?;

            if (type == 'percentage_revenue') {
              if (total >= threshold) {
                computedIncentive += (total * (rate / 100.0));
              }
            } else if (type == 'fixed_per_product' && targetPid != null) {
              final targetQty = input.items.where((it) => it.productId == targetPid).fold<int>(0, (acc, it) => acc + it.qty);
              if (targetQty > 0) {
                computedIncentive += (targetQty * rate);
              }
            }
          }

          if (computedIncentive > 0) {
            final roundedInc = MoneyCalculator.round2(computedIncentive);
            final nowSec = now.millisecondsSinceEpoch ~/ 1000;
            await _db.customStatement('''
              INSERT INTO incentive_claims (workspace_id, employee_id, sale_id, amount, original_amount, reversed_amount, description, status, created_at)
              VALUES (?, ?, ?, ?, ?, 0.0, ?, 'pending', ?);
            ''', [wsId, input.employeeId, saleId, roundedInc, roundedInc, 'Commission for Invoice $invoiceNo', nowSec]);
          }
        } catch (_) {}
      }

      return SaleCheckoutResult(
        saleId: saleId,
        invoiceNo: invoiceNo,
        total: total,
        paid: paid,
        change: change,
      );
    });
  }

  @override
  Future<SaleDetailView?> getInvoiceDetail(int saleId, {int? workspaceId}) async {
    final query = _db.select(_db.sales)..where((tbl) => tbl.id.equals(saleId));
    if (workspaceId != null) {
      query.where((tbl) => tbl.workspaceId.equals(workspaceId));
    }
    final sale = await query.getSingleOrNull();
    if (sale == null) {
      return null;
    }
    final items = await (_db.select(_db.saleItems)..where((tbl) => tbl.saleId.equals(saleId))).get();

    return SaleDetailView(
      sale: _toSaleView(sale),
      items: items.map(_toSaleItemView).toList(),
    );
  }

  @override
  Future<List<SaleSummary>> getInvoices({InvoiceFilter filter = const InvoiceFilter(), int workspaceId = 1}) async {
    final sales = await (_db.select(_db.sales)
          ..where((tbl) => tbl.workspaceId.equals(workspaceId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();

    return sales
        .where((sale) {
          final matchesFrom = filter.from == null || !sale.createdAt.isBefore(filter.from!);
          final matchesTo =
              filter.to == null || !sale.createdAt.isAfter(filter.to!.add(const Duration(days: 1)));
          final matchesPayment =
              filter.paymentMethod == null || sale.paymentMethod == filter.paymentMethod!.value;
          return matchesFrom && matchesTo && matchesPayment;
        })
        .map(
          (sale) => SaleSummary(
            id: sale.id,
            invoiceNo: sale.invoiceNo,
            createdAt: sale.createdAt,
            total: sale.total,
            paymentMethod: PaymentMethodX.fromValue(sale.paymentMethod),
            status: SaleStatusX.fromValue(sale.status),
          ),
        )
        .toList();
  }

  @override
  Future<ReturnResult> returnItems({
    required int saleId,
    required List<ReturnItemInput> items,
    UserRole? callerRole,
  }) {
    if (callerRole != null &&
        callerRole != UserRole.admin &&
        callerRole != UserRole.manager &&
        callerRole != UserRole.cashier) {
      throw AppException('Access denied: Returns require cashier, manager, or admin permission');
    }
    if (items.isEmpty) {
      throw AppException('Select at least one item');
    }

    return _db.transaction(() async {
      final sale = await (_db.select(_db.sales)..where((tbl) => tbl.id.equals(saleId))).getSingleOrNull();
      if (sale == null) {
        throw AppException('Sale not found');
      }
      if (sale.status == 'cancelled') {
        throw AppException('Cannot process return for cancelled invoice');
      }

      final saleItems = await (_db.select(_db.saleItems)..where((tbl) => tbl.saleId.equals(saleId))).get();
      final saleItemById = {for (final item in saleItems) item.id: item};
      final wsId = sale.workspaceId ?? 1;

      // Check previously returned quantities for each item of this sale
      final priorReturnRows = await _db.customSelect(
        '''
        SELECT si.original_sale_item_id, si.product_id, SUM(ABS(si.qty)) as returned_qty
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.original_sale_id = ?
        GROUP BY si.original_sale_item_id, si.product_id
        ''',
        variables: [Variable.withInt(saleId)],
        readsFrom: {},
      ).get();

      final Map<int, int> priorReturnedByItemId = {};
      final Map<int, int> priorReturnedByProductId = {};
      for (final r in priorReturnRows) {
        final origItemId = r.data['original_sale_item_id'] as int?;
        final pid = r.data['product_id'] as int;
        final qty = (r.data['returned_qty'] as num).toInt();
        if (origItemId != null) {
          priorReturnedByItemId[origItemId] = (priorReturnedByItemId[origItemId] ?? 0) + qty;
        }
        priorReturnedByProductId[pid] = (priorReturnedByProductId[pid] ?? 0) + qty;
      }

      for (final returnInput in items) {
        final original = saleItemById[returnInput.saleItemId];
        if (original == null) {
          throw AppException('Invalid return item');
        }
        final alreadyReturned = priorReturnedByItemId[original.id] ?? priorReturnedByProductId[original.productId] ?? 0;
        final remainingReturnable = original.qty.abs() - alreadyReturned;

        if (returnInput.qty <= 0) {
          throw AppException('Return quantity must be greater than zero for ${original.nameSnapshot}');
        }
        if (returnInput.qty > remainingReturnable) {
          throw AppException(
            'Cannot return ${returnInput.qty} units of ${original.nameSnapshot}. Only $remainingReturnable remaining unreturned.',
          );
        }
      }

      double totalReturn = 0;
      double discountReturn = 0;
      double totalReturnCgst = 0;
      double totalReturnSgst = 0;
      double totalReturnIgst = 0;
      double totalReturnTax = 0;
      final now = DateTime.now();

      final returnInvoice = await _nextReturnInvoiceNo(now);
      final returnSaleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              invoiceNo: returnInvoice,
              createdAt: Value(now),
              customerId: Value(sale.customerId),
              subtotal: 0,
              discountTotal: 0,
              taxTotal: 0,
              total: 0,
              paid: 0,
              changeAmount: 0,
              paymentMethod: sale.paymentMethod,
              status: SaleStatus.returned.value,
              workspaceId: Value(wsId),
            ),
          );

      await _db.customStatement(
        'UPDATE sales SET original_sale_id = ? WHERE id = ?;',
        [saleId, returnSaleId],
      );

      for (final returnInput in items) {
        final original = saleItemById[returnInput.saleItemId]!;
        final origQty = max(1, original.qty.abs());
        final fraction = returnInput.qty / origQty;

        final perUnitLine = original.lineTotal / origQty;
        final perUnitDiscount = original.discount / origQty;
        final returnLineTotal = MoneyCalculator.round2(-perUnitLine * returnInput.qty);
        final returnDiscount = MoneyCalculator.round2(perUnitDiscount * returnInput.qty);

        totalReturn += returnLineTotal;
        discountReturn += returnDiscount;

        // Fetch original line taxes from extra columns
        final origTaxRow = await _db.customSelect(
          'SELECT cgst, sgst, igst, tax_amount FROM sale_items WHERE id = ?',
          readsFrom: {},
          variables: [Variable.withInt(original.id)],
        ).getSingleOrNull();

        final origCgst = (origTaxRow?.data['cgst'] as num? ?? 0.0).toDouble();
        final origSgst = (origTaxRow?.data['sgst'] as num? ?? 0.0).toDouble();
        final origIgst = (origTaxRow?.data['igst'] as num? ?? 0.0).toDouble();
        final origTaxAmt = (origTaxRow?.data['tax_amount'] as num? ?? 0.0).toDouble();

        final returnCgst = MoneyCalculator.round2(origCgst * fraction);
        final returnSgst = MoneyCalculator.round2(origSgst * fraction);
        final returnIgst = MoneyCalculator.round2(origIgst * fraction);
        final returnTaxAmt = MoneyCalculator.round2(origTaxAmt * fraction);

        totalReturnCgst += returnCgst;
        totalReturnSgst += returnSgst;
        totalReturnIgst += returnIgst;
        totalReturnTax += returnTaxAmt;

        final returnItemId = await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: returnSaleId,
                productId: original.productId,
                nameSnapshot: original.nameSnapshot,
                costSnapshot: original.costSnapshot,
                priceSnapshot: original.priceSnapshot,
                qty: -returnInput.qty,
                discount: Value(returnDiscount),
                lineTotal: returnLineTotal,
              ),
            );

        await _db.customStatement('''
          UPDATE sale_items
          SET original_sale_item_id = ?, cgst = ?, sgst = ?, igst = ?, tax_amount = ?
          WHERE id = ?;
        ''', [original.id, -returnCgst, -returnSgst, -returnIgst, -returnTaxAmt, returnItemId]);

        // Atomic stock restoration
        final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
        await _db.customStatement('''
          UPDATE products
          SET stock_qty = stock_qty + ?, updated_at = ?
          WHERE id = ?
        ''', [returnInput.qty, nowSeconds, original.productId]);

        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: original.productId,
                type: StockMovementType.returnSale.value,
                qtyChange: returnInput.qty,
                reason: Value('Return ${sale.invoiceNo}'),
                createdAt: Value(now),
              ),
            );
      }

      // Calculate total original sale items quantity vs total returned items across all returns
      final totalOrigQty = saleItems.fold<int>(0, (acc, it) => acc + it.qty.abs());
      final allReturnsQuery = await _db.customSelect(
        '''
        SELECT COALESCE(SUM(ABS(si.qty)), 0) as total_returned
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.original_sale_id = ?
        ''',
        variables: [Variable.withInt(saleId)],
        readsFrom: {},
      ).getSingle();
      final totalReturnedSoFar = (allReturnsQuery.data['total_returned'] as num).toInt();
      final bool isFullReturn = totalReturnedSoFar >= totalOrigQty;

      await (_db.update(_db.sales)..where((tbl) => tbl.id.equals(returnSaleId))).write(
        SalesCompanion(
          subtotal: Value(totalReturn),
          discountTotal: Value(discountReturn),
          taxTotal: Value(-totalReturnTax),
          cgstTotal: Value(-totalReturnCgst),
          sgstTotal: Value(-totalReturnSgst),
          igstTotal: Value(-totalReturnIgst),
          total: Value(totalReturn),
          status: Value(SaleStatus.returned.value),
        ),
      );

      // Update original sale status: 'returned' if 100% returned, otherwise 'partially_returned'
      await _db.customStatement(
        'UPDATE sales SET status = ? WHERE id = ?;',
        [isFullReturn ? 'returned' : 'partially_returned', saleId],
      );

      // Post Return Ledger Entries:
      // Debit: Sales Returns (Debit) = totalReturn.abs()
      // Credit: Customer or Cash Refund (Credit) = totalReturn.abs()
      final returnVal = totalReturn.abs();
      if (returnVal > 0) {
        final custId = sale.customerId ?? 1;
        await _ledgerRepository.postTransaction(
          workspaceId: wsId,
          entries: [
            LedgerPostingItem(
              transactionType: 'sale_return',
              referenceType: 'sale',
              referenceId: returnSaleId,
              debit: returnVal,
              credit: 0.0,
              narration: 'Sales return adjustment for $returnInvoice',
              createdAt: now,
            ),
            LedgerPostingItem(
              transactionType: 'sale_return',
              referenceType: 'customer',
              referenceId: custId,
              partyType: 'customer',
              partyId: custId,
              debit: 0.0,
              credit: returnVal,
              narration: 'Customer credit note for $returnInvoice',
              createdAt: now,
            ),
          ],
        );
      }

      // Mathematical Partial & Full Incentive Reversal
      try {
        final claims = await _db.customSelect(
          'SELECT * FROM incentive_claims WHERE sale_id = ?',
          readsFrom: {},
          variables: [Variable.withInt(saleId)],
        ).get();

        if (claims.isNotEmpty) {
          final rules = await _db.customSelect(
            'SELECT * FROM incentive_rules WHERE is_active = 1 AND (workspace_id = ? OR workspace_id IS NULL)',
            variables: [Variable.withInt(wsId)],
            readsFrom: {},
          ).get();

          for (final claim in claims) {
            final cid = claim.data['id'] as int;
            final cstatus = claim.data['status'] as String? ?? 'pending';
            final cEmployeeId = claim.data['employee_id'] as int? ?? 1;
            final cAccountId = claim.data['paid_from_account_id'] as int? ?? 1;
            final origClaimAmount = (claim.data['original_amount'] as num? ?? claim.data['amount'] as num? ?? 0.0).toDouble();
            final priorReversed = (claim.data['reversed_amount'] as num? ?? 0.0).toDouble();
            final nowSec = now.millisecondsSinceEpoch ~/ 1000;

            double calculatedReversal = 0.0;
            if (isFullReturn) {
              calculatedReversal = max(0.0, origClaimAmount - priorReversed);
            } else {
              // Calculate item-specific reversal
              for (final returnInput in items) {
                final original = saleItemById[returnInput.saleItemId]!;
                for (final rule in rules) {
                  final type = rule.data['rule_type'] as String? ?? 'percentage_revenue';
                  final rate = (rule.data['reward_rate'] as num? ?? 0.0).toDouble();
                  final threshold = (rule.data['threshold_amount'] as num? ?? 0.0).toDouble();
                  final targetPid = rule.data['target_product_id'] as int?;

                  if (type == 'fixed_per_product' && targetPid == original.productId) {
                    calculatedReversal += (returnInput.qty * rate);
                  } else if (type == 'percentage_revenue') {
                    if (sale.total >= threshold) {
                      final itemLineVal = (original.lineTotal / max(1, original.qty.abs())) * returnInput.qty;
                      calculatedReversal += (itemLineVal * (rate / 100.0));
                    }
                  }
                }
              }

              // Fallback if rule not found or 0: proportional to return fraction of sale subtotal
              if (calculatedReversal <= 0.0 && sale.subtotal > 0) {
                final returnSubtotal = totalReturn.abs();
                calculatedReversal = (returnSubtotal / sale.subtotal) * origClaimAmount;
              }

              calculatedReversal = MoneyCalculator.round2(calculatedReversal);
              final maxReversible = max(0.0, origClaimAmount - priorReversed);
              calculatedReversal = min(calculatedReversal, maxReversible);
            }

            if (calculatedReversal <= 0.0) continue;

            final newReversedAmount = MoneyCalculator.round2(priorReversed + calculatedReversal);
            final newRemainingAmount = MoneyCalculator.round2(max(0.0, origClaimAmount - newReversedAmount));

            if (cstatus == 'pending' || cstatus == 'approved') {
              if (isFullReturn || newRemainingAmount <= 0.0) {
                await _db.customStatement('''
                  UPDATE incentive_claims
                  SET status = 'rejected', amount = 0.0, reversed_amount = ?, processed_at = ?
                  WHERE id = ?
                ''', [newReversedAmount, nowSec, cid]);
              } else {
                await _db.customStatement('''
                  UPDATE incentive_claims
                  SET amount = ?, reversed_amount = ?, processed_at = ?
                  WHERE id = ?
                ''', [newRemainingAmount, newReversedAmount, nowSec, cid]);
              }
            } else if (cstatus == 'paid' || cstatus == 'partially_reversed') {
              // Exact double-entry ledger reversal for the paid amount being reversed
              await _ledgerRepository.postTransaction(
                workspaceId: wsId,
                entries: [
                  LedgerPostingItem(
                    transactionType: 'incentive',
                    referenceType: 'incentive_reversal',
                    referenceId: cid,
                    partyType: 'employee',
                    partyId: cEmployeeId,
                    debit: 0.0,
                    credit: calculatedReversal,
                    narration: 'Reversal of incentive claim #$cid ($calculatedReversal) due to return $returnInvoice',
                    createdAt: now,
                  ),
                  LedgerPostingItem(
                    transactionType: 'incentive',
                    referenceType: 'incentive_reversal',
                    referenceId: cid,
                    accountId: cAccountId,
                    debit: calculatedReversal,
                    credit: 0.0,
                    narration: 'Refund to account #$cAccountId for incentive reversal #$cid',
                    createdAt: now,
                  ),
                ],
              );

              final newStatus = (isFullReturn || newRemainingAmount <= 0.0) ? 'reversed' : 'partially_reversed';
              await _db.customStatement('''
                UPDATE incentive_claims
                SET status = ?, amount = ?, reversed_amount = ?, processed_at = ?
                WHERE id = ?
              ''', [newStatus, newRemainingAmount, newReversedAmount, nowSec, cid]);
            }
          }
        }
      } catch (_) {}

      return ReturnResult(returnSaleId: returnSaleId, invoiceNo: returnInvoice);
    });
  }

  SaleItemView _toSaleItemView(SaleItem item) {
    return SaleItemView(
      id: item.id,
      saleId: item.saleId,
      productId: item.productId,
      nameSnapshot: item.nameSnapshot,
      costSnapshot: item.costSnapshot,
      priceSnapshot: item.priceSnapshot,
      qty: item.qty,
      discount: item.discount,
      lineTotal: item.lineTotal,
    );
  }

  SaleView _toSaleView(Sale sale) {
    return SaleView(
      id: sale.id,
      invoiceNo: sale.invoiceNo,
      createdAt: sale.createdAt,
      customerId: sale.customerId,
      subtotal: sale.subtotal,
      discountTotal: sale.discountTotal,
      taxTotal: sale.taxTotal,
      total: sale.total,
      paid: sale.paid,
      changeAmount: sale.changeAmount,
      paymentMethod: PaymentMethodX.fromValue(sale.paymentMethod),
      status: SaleStatusX.fromValue(sale.status),
      cgstTotal: sale.cgstTotal,
      sgstTotal: sale.sgstTotal,
      igstTotal: sale.igstTotal,
      roundOff: sale.roundOff,
    );
  }

  Future<String> _nextInvoiceNo(DateTime now) async {
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final countExp = _db.sales.id.count();
    final query = _db.selectOnly(_db.sales)
      ..addColumns([countExp])
      ..where(_db.sales.invoiceNo.like('INV-$datePart-%'));
    final count = (await query.getSingleOrNull())?.read(countExp) ?? 0;
    final sequence = (count + 1).toString().padLeft(4, '0');
    return 'INV-$datePart-$sequence';
  }

  Future<String> _nextReturnInvoiceNo(DateTime now) async {
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final countExp = _db.sales.id.count();
    final query = _db.selectOnly(_db.sales)
      ..addColumns([countExp])
      ..where(_db.sales.invoiceNo.like('RET-$datePart-%'));
    final count = (await query.getSingleOrNull())?.read(countExp) ?? 0;
    final sequence = (count + 1).toString().padLeft(4, '0');
    return 'RET-$datePart-$sequence';
  }

  @override
  Future<List<HeldBillModel>> getHeldBills({int workspaceId = 1}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM held_bills WHERE workspace_id = ? ORDER BY created_at DESC;',
      variables: [Variable.withInt(workspaceId)],
    ).get();

    return rows.map((r) {
      final data = r.data;
      final cartJsonStr = data['cart_data'] as String;
      final List<dynamic> cartList = jsonDecode(cartJsonStr) as List<dynamic>;
      final items = cartList.map((i) => CartItem.fromJson(i as Map<String, dynamic>)).toList();

      final createdAtVal = data['created_at'];
      DateTime createdAt = DateTime.now();
      if (createdAtVal is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtVal * 1000);
      } else if (createdAtVal is String) {
        createdAt = DateTime.tryParse(createdAtVal) ?? DateTime.now();
      }

      return HeldBillModel(
        id: data['id'] as int?,
        workspaceId: (data['workspace_id'] as num?)?.toInt() ?? workspaceId,
        referenceNote: data['reference_note'] as String?,
        customerId: data['customer_id'] as int?,
        customerName: data['customer_name'] as String?,
        customerPhone: data['customer_phone'] as String?,
        items: items,
        orderDiscount: (data['order_discount'] as num?)?.toDouble() ?? 0.0,
        taxEnabled: data['tax_enabled'] == 1,
        taxRate: (data['tax_rate'] as num?)?.toDouble() ?? 0.18,
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0.0,
        itemCount: (data['item_count'] as num?)?.toInt() ?? items.length,
        createdAt: createdAt,
      );
    }).toList();
  }

  @override
  Future<int> saveHeldBill(HeldBillModel bill) async {
    final cartJson = jsonEncode(bill.items.map((i) => i.toJson()).toList());
    final nowSeconds = bill.createdAt.millisecondsSinceEpoch ~/ 1000;

    await _db.customStatement('''
      INSERT INTO held_bills (
        workspace_id, reference_note, customer_id, customer_name, customer_phone,
        cart_data, order_discount, tax_enabled, tax_rate, subtotal, total_amount, item_count, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
      bill.workspaceId,
      bill.referenceNote,
      bill.customerId,
      bill.customerName,
      bill.customerPhone,
      cartJson,
      bill.orderDiscount,
      bill.taxEnabled ? 1 : 0,
      bill.taxRate,
      bill.subtotal,
      bill.totalAmount,
      bill.itemCount,
      nowSeconds,
    ]);

    final lastId = await _db.customSelect('SELECT last_insert_rowid() AS id;').getSingle();
    return (lastId.data['id'] as num).toInt();
  }

  @override
  Future<void> deleteHeldBill(int id) async {
    await _db.customStatement('DELETE FROM held_bills WHERE id = ?;', [id]);
  }
}

