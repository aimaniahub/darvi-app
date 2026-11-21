import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/repositories/repositories.dart';

class LocalPurchaseRepository implements PurchaseRepository {
  LocalPurchaseRepository(this._db, this._ledgerRepository);

  final AppDatabase _db;
  final LedgerRepository _ledgerRepository;

  @override
  Future<int> createPurchaseInvoice(PurchaseInvoiceInput input) async {
    if (input.items.isEmpty) {
      throw AppException('Purchase invoice must contain at least one item');
    }

    final supplierRows = await _db.customSelect(
      'SELECT id, name FROM suppliers WHERE id = ? AND workspace_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(input.supplierId), Variable.withInt(input.workspaceId)],
    ).get();
    if (supplierRows.isEmpty) {
      throw AppException('Selected supplier does not exist in this workspace');
    }

    // Duplicate bill number prevention for the same supplier
    final existingBill = await _db.customSelect(
      'SELECT id FROM purchase_invoices WHERE workspace_id = ? AND supplier_id = ? AND invoice_number = ? AND is_cancelled = 0',
      readsFrom: {},
      variables: [
        Variable.withInt(input.workspaceId),
        Variable.withInt(input.supplierId),
        Variable.withString(input.supplierInvoiceNo.trim()),
      ],
    ).get();
    if (existingBill.isNotEmpty) {
      throw AppException(
        'Invoice "${input.supplierInvoiceNo}" has already been entered for this supplier.',
      );
    }

    // Validate quantities, costs, GST
    for (final item in input.items) {
      if (item.qty <= 0) {
        throw AppException('Item quantity must be greater than zero');
      }
      if (item.unitCost < 0) {
        throw AppException('Item unit cost cannot be negative');
      }
      if (item.gstRate < 0 || item.gstRate > 100) {
        throw AppException('GST rate must be between 0% and 100%');
      }
    }

    if (input.paid > input.total + 0.01) {
      throw AppException('Paid amount cannot exceed total purchase bill amount');
    }

    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final invDateSeconds = (input.supplierInvoiceDate ?? now).millisecondsSinceEpoch ~/ 1000;

    return _db.transaction(() async {
      // 1. Insert Purchase Invoice record
      final internalRef = input.internalReference ??
          'PUR-${now.year}-${(now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';

      await _db.customStatement('''
        INSERT INTO purchase_invoices (
          workspace_id, supplier_id, invoice_number, invoice_date,
          subtotal, tax_total, total_amount, paid_amount, status, notes, created_at,
          internal_reference, supplier_invoice_date, gross_subtotal, item_discount_total,
          invoice_discount, taxable_value, cgst, sgst, igst, round_off, is_gst_inclusive, is_cancelled, returned_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0.0)
      ''', [
        input.workspaceId,
        input.supplierId,
        input.supplierInvoiceNo.trim(),
        invDateSeconds,
        input.subtotal,
        input.taxTotal,
        input.total,
        input.paid,
        input.paid >= input.total ? 'paid' : (input.paid > 0 ? 'partial' : 'unpaid'),
        input.notes,
        nowSeconds,
        internalRef,
        invDateSeconds,
        input.grossSubtotal > 0 ? input.grossSubtotal : input.subtotal,
        input.itemDiscountTotal,
        input.invoiceDiscount,
        input.taxableValue > 0 ? input.taxableValue : input.subtotal,
        input.cgst,
        input.sgst,
        input.igst,
        input.roundOff,
        input.isGstInclusive ? 1 : 0,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final purchaseId = lastIdRow.data['id'] as int;

      // 2. Insert items, update inventory stock, batches, and movements
      for (final item in input.items) {
        final mfgSecs = item.mfgDate != null ? item.mfgDate!.millisecondsSinceEpoch ~/ 1000 : null;
        final expSecs = item.expiryDate != null ? item.expiryDate!.millisecondsSinceEpoch ~/ 1000 : null;

        await _db.customStatement('''
          INSERT INTO purchase_invoice_items (
            purchase_invoice_id, product_id, quantity, unit_cost, gst_rate, discount, total,
            batch_number, mfg_date, expiry_date, hsn_code, purchase_unit, returned_qty, cgst, sgst, igst
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
        ''', [
          purchaseId,
          item.productId,
          item.qty,
          item.unitCost,
          item.gstRate,
          item.discount,
          item.lineTotal,
          item.batchNumber,
          mfgSecs,
          expSecs,
          item.hsnCode,
          item.purchaseUnit,
          item.cgst,
          item.sgst,
          item.igst,
        ]);

        // Atomic stock increment and cost update
        await _db.customStatement('''
          UPDATE products
          SET stock_qty = stock_qty + ?, cost = ?, updated_at = ?
          WHERE id = ?
        ''', [item.qty, item.unitCost, nowSeconds, item.productId]);

        // Manage product batches if batch number provided
        if (item.batchNumber != null && item.batchNumber!.trim().isNotEmpty) {
          final batchTrimmed = item.batchNumber!.trim();
          final existingBatch = await _db.customSelect(
            'SELECT id, quantity FROM product_batches WHERE product_id = ? AND batch_number = ? AND workspace_id = ?',
            readsFrom: {},
            variables: [Variable.withInt(item.productId), Variable.withString(batchTrimmed), Variable.withInt(input.workspaceId)],
          ).get();

          if (existingBatch.isNotEmpty) {
            final batchId = existingBatch.first.data['id'] as int;
            await _db.customStatement('''
              UPDATE product_batches
              SET quantity = quantity + ?, updated_at = ?
              WHERE id = ?
            ''', [item.qty, nowSeconds, batchId]);
          } else {
            await _db.customStatement('''
              INSERT INTO product_batches (
                workspace_id, product_id, batch_number, mfg_date, expiry_date,
                cost_price, selling_price, quantity, initial_quantity, status,
                supplier_id, purchase_invoice_id, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)
            ''', [
              input.workspaceId,
              item.productId,
              batchTrimmed,
              mfgSecs,
              expSecs,
              item.unitCost,
              item.unitCost * 1.25, // default markup preview
              item.qty,
              item.qty,
              input.supplierId,
              purchaseId,
              nowSeconds,
              nowSeconds,
            ]);
          }
        }

        // Stock movement audit log
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: item.productId,
                type: StockMovementType.purchase.value,
                qtyChange: item.qty,
                unitCost: Value(item.unitCost),
                reason: Value('Purchase Inward: Bill #${input.supplierInvoiceNo} ($internalRef)'),
                supplierId: Value(input.supplierId),
                createdAt: Value(now),
              ),
            );
      }

      // 3. Post double-entry financial ledger transactions
      // Debit: Inventory / Purchase Asset = input.total
      // Credit: Supplier Payable (Liability) = input.total
      final List<LedgerPostingItem> ledgerEntries = [
        LedgerPostingItem(
          transactionType: 'purchase',
          referenceType: 'purchase_invoice',
          referenceId: purchaseId,
          debit: input.total,
          credit: 0.0,
          narration: 'Purchase inward bill #${input.supplierInvoiceNo} ($internalRef)',
          createdAt: now,
        ),
        LedgerPostingItem(
          transactionType: 'purchase',
          referenceType: 'supplier',
          referenceId: input.supplierId,
          partyType: 'supplier',
          partyId: input.supplierId,
          debit: 0.0,
          credit: input.total,
          narration: 'Payable to Supplier #${input.supplierId} for bill #${input.supplierInvoiceNo}',
          createdAt: now,
        ),
      ];

      // If payment was made at invoice creation:
      if (input.paid > 0 && input.accountId != null) {
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'payment_out',
            referenceType: 'purchase_invoice',
            referenceId: purchaseId,
            partyType: 'supplier',
            partyId: input.supplierId,
            debit: input.paid,
            credit: 0.0,
            narration: 'Payment for Purchase #${input.supplierInvoiceNo}',
            createdAt: now,
          ),
        );
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'payment_out',
            referenceType: 'account',
            referenceId: input.accountId,
            accountId: input.accountId,
            debit: 0.0,
            credit: input.paid,
            narration: 'Payment disbursement from Account #${input.accountId} for Purchase #${input.supplierInvoiceNo}',
            createdAt: now,
          ),
        );

        // Record in payments table
        await _db.customStatement('''
          INSERT INTO payments (
            workspace_id, payment_type, reference_type, reference_id,
            account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          input.workspaceId,
          'supplier_payment',
          'purchase_invoice',
          purchaseId,
          input.accountId,
          input.paid,
          input.paymentMode,
          input.paymentReference ?? input.supplierInvoiceNo,
          'Purchase invoice advance/payment',
          nowSeconds,
          invDateSeconds,
        ]);

        final lastPayRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
        final paymentId = lastPayRow.data['id'] as int;

        // Record invoice-wise allocation
        await _db.customStatement('''
          INSERT INTO party_payment_allocations (
            workspace_id, payment_id, party_type, party_id, invoice_type, invoice_id, allocated_amount, created_at
          ) VALUES (?, ?, 'supplier', ?, 'purchase_invoice', ?, ?, ?)
        ''', [
          input.workspaceId,
          paymentId,
          input.supplierId,
          purchaseId,
          input.paid,
          nowSeconds,
        ]);
      }

      await _ledgerRepository.postTransaction(
        workspaceId: input.workspaceId,
        entries: ledgerEntries,
      );

      return purchaseId;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPurchaseInvoices({
    int workspaceId = 1,
    String? searchQuery,
    String? statusFilter,
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
  }) async {
    final conditions = ['p.workspace_id = ?'];
    final variables = <Variable>[Variable.withInt(workspaceId)];

    if (supplierId != null) {
      conditions.add('p.supplier_id = ?');
      variables.add(Variable.withInt(supplierId));
    }

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toUpperCase() != 'ALL') {
      if (statusFilter.toLowerCase() == 'cancelled') {
        conditions.add('p.is_cancelled = 1');
      } else {
        conditions.add('p.status = ? AND p.is_cancelled = 0');
        variables.add(Variable.withString(statusFilter.toLowerCase()));
      }
    }

    if (fromDate != null) {
      final fromSecs = fromDate.millisecondsSinceEpoch ~/ 1000;
      conditions.add('p.invoice_date >= ?');
      variables.add(Variable.withInt(fromSecs));
    }

    if (toDate != null) {
      final toSecs = toDate.millisecondsSinceEpoch ~/ 1000;
      conditions.add('p.invoice_date <= ?');
      variables.add(Variable.withInt(toSecs));
    }

    final query = '''
      SELECT p.id, p.workspace_id, p.supplier_id, p.invoice_number, p.invoice_date,
             p.subtotal, p.tax_total, p.total_amount, p.paid_amount, p.status, p.notes,
             p.internal_reference, p.gross_subtotal, p.item_discount_total, p.invoice_discount,
             p.taxable_value, p.cgst, p.sgst, p.igst, p.round_off, p.is_gst_inclusive,
             p.is_cancelled, p.returned_amount,
             s.name as supplier_name, s.phone as supplier_phone, s.gstin as supplier_gstin
      FROM purchase_invoices p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY p.id DESC
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();
    var list = rows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((b) {
        final invNo = (b['invoice_number'] ?? '').toString().toLowerCase();
        final intRef = (b['internal_reference'] ?? '').toString().toLowerCase();
        final sName = (b['supplier_name'] ?? '').toString().toLowerCase();
        return invNo.contains(q) || intRef.contains(q) || sName.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Future<Map<String, dynamic>?> getPurchaseInvoiceDetail(int id) async {
    final rows = await _db.customSelect('''
      SELECT p.id, p.workspace_id, p.supplier_id, p.invoice_number, p.invoice_date,
             p.subtotal, p.tax_total, p.total_amount, p.paid_amount, p.status, p.notes,
             p.internal_reference, p.gross_subtotal, p.item_discount_total, p.invoice_discount,
             p.taxable_value, p.cgst, p.sgst, p.igst, p.round_off, p.is_gst_inclusive,
             p.is_cancelled, p.returned_amount, p.created_at,
             s.name as supplier_name, s.phone as supplier_phone, s.gstin as supplier_gstin,
             s.address as supplier_address, s.state as supplier_state
      FROM purchase_invoices p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      WHERE p.id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(id)]).get();

    if (rows.isEmpty) return null;
    final header = Map<String, dynamic>.from(rows.first.data);

    final totalAmount = (header['total_amount'] as num? ?? 0.0).toDouble();
    final paidAmount = (header['paid_amount'] as num? ?? 0.0).toDouble();
    header['supplier_invoice_no'] = header['invoice_number'];
    header['total'] = totalAmount;
    header['paid'] = paidAmount;
    header['outstanding_amount'] = (totalAmount - paidAmount).clamp(0.0, double.infinity);
    header['outstanding_balance'] = header['outstanding_amount'];
    header['payment_status'] = header['status'];
    header['subtotal'] = (header['subtotal'] as num? ?? 0.0).toDouble();
    header['tax_total'] = (header['tax_total'] as num? ?? 0.0).toDouble();

    // Items
    final itemRows = await _db.customSelect('''
      SELECT pii.*, pr.name as product_name, pr.sku as product_sku, pr.unit as product_unit
      FROM purchase_invoice_items pii
      LEFT JOIN products pr ON pr.id = pii.product_id
      WHERE pii.purchase_invoice_id = ?
      ORDER BY pii.id ASC
    ''', readsFrom: {}, variables: [Variable.withInt(id)]).get();
    header['items'] = itemRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    // Payments recorded
    final paymentRows = await _db.customSelect('''
      SELECT p.*, a.name as account_name, a.type as account_type
      FROM payments p
      LEFT JOIN accounts a ON a.id = p.account_id
      WHERE p.reference_type = 'purchase_invoice' AND p.reference_id = ?
      ORDER BY p.id DESC
    ''', readsFrom: {}, variables: [Variable.withInt(id)]).get();
    header['payments'] = paymentRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    // Returns recorded
    final returnRows = await _db.customSelect('''
      SELECT pr.* FROM purchase_returns pr
      WHERE pr.purchase_invoice_id = ?
      ORDER BY pr.id DESC
    ''', readsFrom: {}, variables: [Variable.withInt(id)]).get();
    header['returns'] = returnRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    // Ledger postings for this invoice
    final ledgerRows = await _db.customSelect('''
      SELECT * FROM ledger_entries
      WHERE (reference_type = 'purchase_invoice' AND reference_id = ?)
         OR (transaction_type = 'payment_out' AND reference_type = 'purchase_invoice' AND reference_id = ?)
      ORDER BY id ASC
    ''', readsFrom: {}, variables: [Variable.withInt(id), Variable.withInt(id)]).get();
    header['ledger_entries'] = ledgerRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    return header;
  }

  @override
  Future<void> editPurchaseInvoice(int id, PurchaseInvoiceInput input) async {
    final existing = await getPurchaseInvoiceDetail(id);
    if (existing == null) {
      throw AppException('Purchase invoice #$id not found');
    }
    if ((existing['is_cancelled'] as int? ?? 0) == 1) {
      throw AppException('Cannot edit a cancelled purchase invoice');
    }

    final returns = existing['returns'] as List<dynamic>? ?? [];
    if (returns.isNotEmpty) {
      throw AppException('Cannot edit purchase invoice with existing returns. Create a debit note instead.');
    }

    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final invDateSeconds = (input.supplierInvoiceDate ?? now).millisecondsSinceEpoch ~/ 1000;
    final oldItems = (existing['items'] as List<dynamic>?) ?? [];
    final oldTotal = (existing['total_amount'] as num? ?? 0.0).toDouble();
    final oldSupplierId = existing['supplier_id'] as int;

    await _db.transaction(() async {
      // 1. Reverse stock and batches from old items
      for (final oldItem in oldItems) {
        final pid = oldItem['product_id'] as int;
        final qty = oldItem['quantity'] as int;
        final batch = oldItem['batch_number'] as String?;

        await _db.customStatement('''
          UPDATE products
          SET stock_qty = stock_qty - ?, updated_at = ?
          WHERE id = ?
        ''', [qty, nowSeconds, pid]);

        if (batch != null && batch.trim().isNotEmpty) {
          await _db.customStatement('''
            UPDATE product_batches
            SET quantity = MAX(0, quantity - ?), updated_at = ?
            WHERE product_id = ? AND batch_number = ?
          ''', [qty, nowSeconds, pid, batch.trim()]);
        }

        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: pid,
                type: StockMovementType.adjust.value,
                qtyChange: -qty,
                reason: Value('Purchase Invoice #$id reversal for edit'),
                supplierId: Value(oldSupplierId),
                createdAt: Value(now),
              ),
            );
      }

      // 2. Post reversing ledger entry for original purchase total
      // Reversal: Debit Supplier Payable, Credit Inventory
      await _ledgerRepository.postTransaction(
        workspaceId: input.workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'purchase_reverse',
            referenceType: 'supplier',
            referenceId: oldSupplierId,
            partyType: 'supplier',
            partyId: oldSupplierId,
            debit: oldTotal,
            credit: 0.0,
            narration: 'Reversal of purchase bill #${existing['invoice_number']} prior to edit',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'purchase_reverse',
            referenceType: 'purchase_invoice',
            referenceId: id,
            debit: 0.0,
            credit: oldTotal,
            narration: 'Inventory credit reversal for edited purchase bill #$id',
            createdAt: now,
          ),
        ],
      );

      // 3. Remove old items
      await _db.customStatement('DELETE FROM purchase_invoice_items WHERE purchase_invoice_id = ?', [id]);

      // 4. Update purchase invoice header
      final currentPaid = (existing['paid_amount'] as num? ?? 0.0).toDouble();
      final newStatus = currentPaid >= input.total ? 'paid' : (currentPaid > 0 ? 'partial' : 'unpaid');

      await _db.customStatement('''
        UPDATE purchase_invoices
        SET supplier_id = ?, invoice_number = ?, invoice_date = ?,
            subtotal = ?, tax_total = ?, total_amount = ?, status = ?, notes = ?,
            gross_subtotal = ?, item_discount_total = ?, invoice_discount = ?,
            taxable_value = ?, cgst = ?, sgst = ?, igst = ?, round_off = ?, is_gst_inclusive = ?
        WHERE id = ?
      ''', [
        input.supplierId,
        input.supplierInvoiceNo.trim(),
        invDateSeconds,
        input.subtotal,
        input.taxTotal,
        input.total,
        newStatus,
        input.notes,
        input.grossSubtotal > 0 ? input.grossSubtotal : input.subtotal,
        input.itemDiscountTotal,
        input.invoiceDiscount,
        input.taxableValue > 0 ? input.taxableValue : input.subtotal,
        input.cgst,
        input.sgst,
        input.igst,
        input.roundOff,
        input.isGstInclusive ? 1 : 0,
        id,
      ]);

      // 5. Insert new items and apply corrected stock
      for (final item in input.items) {
        final mfgSecs = item.mfgDate != null ? item.mfgDate!.millisecondsSinceEpoch ~/ 1000 : null;
        final expSecs = item.expiryDate != null ? item.expiryDate!.millisecondsSinceEpoch ~/ 1000 : null;

        await _db.customStatement('''
          INSERT INTO purchase_invoice_items (
            purchase_invoice_id, product_id, quantity, unit_cost, gst_rate, discount, total,
            batch_number, mfg_date, expiry_date, hsn_code, purchase_unit, returned_qty, cgst, sgst, igst
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
        ''', [
          id,
          item.productId,
          item.qty,
          item.unitCost,
          item.gstRate,
          item.discount,
          item.lineTotal,
          item.batchNumber,
          mfgSecs,
          expSecs,
          item.hsnCode,
          item.purchaseUnit,
          item.cgst,
          item.sgst,
          item.igst,
        ]);

        await _db.customStatement('''
          UPDATE products
          SET stock_qty = stock_qty + ?, cost = ?, updated_at = ?
          WHERE id = ?
        ''', [item.qty, item.unitCost, nowSeconds, item.productId]);

        if (item.batchNumber != null && item.batchNumber!.trim().isNotEmpty) {
          final batchTrimmed = item.batchNumber!.trim();
          final existingBatch = await _db.customSelect(
            'SELECT id FROM product_batches WHERE product_id = ? AND batch_number = ? AND workspace_id = ?',
            readsFrom: {},
            variables: [Variable.withInt(item.productId), Variable.withString(batchTrimmed), Variable.withInt(input.workspaceId)],
          ).get();

          if (existingBatch.isNotEmpty) {
            final batchId = existingBatch.first.data['id'] as int;
            await _db.customStatement('''
              UPDATE product_batches
              SET quantity = quantity + ?, updated_at = ?
              WHERE id = ?
            ''', [item.qty, nowSeconds, batchId]);
          } else {
            await _db.customStatement('''
              INSERT INTO product_batches (
                workspace_id, product_id, batch_number, mfg_date, expiry_date,
                cost_price, selling_price, quantity, initial_quantity, status,
                supplier_id, purchase_invoice_id, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)
            ''', [
              input.workspaceId,
              item.productId,
              batchTrimmed,
              mfgSecs,
              expSecs,
              item.unitCost,
              item.unitCost * 1.25,
              item.qty,
              item.qty,
              input.supplierId,
              id,
              nowSeconds,
              nowSeconds,
            ]);
          }
        }

        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: item.productId,
                type: StockMovementType.purchase.value,
                qtyChange: item.qty,
                unitCost: Value(item.unitCost),
                reason: Value('Edited Purchase Inward: Bill #${input.supplierInvoiceNo}'),
                supplierId: Value(input.supplierId),
                createdAt: Value(now),
              ),
            );
      }

      // 6. Post new ledger transaction for corrected total
      await _ledgerRepository.postTransaction(
        workspaceId: input.workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'purchase',
            referenceType: 'purchase_invoice',
            referenceId: id,
            debit: input.total,
            credit: 0.0,
            narration: 'Corrected purchase bill #${input.supplierInvoiceNo} inventory inward',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'purchase',
            referenceType: 'supplier',
            referenceId: input.supplierId,
            partyType: 'supplier',
            partyId: input.supplierId,
            debit: 0.0,
            credit: input.total,
            narration: 'Corrected payable to Supplier #${input.supplierId} for bill #${input.supplierInvoiceNo}',
            createdAt: now,
          ),
        ],
      );
    });
  }

  @override
  Future<void> cancelPurchaseInvoice(int id, {String? reason}) async {
    final detail = await getPurchaseInvoiceDetail(id);
    if (detail == null) throw AppException('Purchase invoice #$id not found');
    if ((detail['is_cancelled'] as int? ?? 0) == 1) {
      throw AppException('Purchase invoice #$id is already cancelled');
    }

    final total = (detail['total_amount'] as num? ?? 0.0).toDouble();
    final paid = (detail['paid_amount'] as num? ?? 0.0).toDouble();
    if (paid > 0) {
      throw AppException('Cannot cancel invoice with recorded payments (₹${paid.toStringAsFixed(2)}). Please issue a return or reverse payments first.');
    }

    final returns = detail['returns'] as List<dynamic>? ?? [];
    if (returns.isNotEmpty) {
      throw AppException('Cannot cancel purchase invoice with existing returns.');
    }

    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final items = detail['items'] as List<dynamic>? ?? [];
    final supplierId = detail['supplier_id'] as int;

    await _db.transaction(() async {
      // 1. Deduct stock and batches
      for (final item in items) {
        final pid = item['product_id'] as int;
        final qty = item['quantity'] as int;
        final batch = item['batch_number'] as String?;

        await _db.customStatement('''
          UPDATE products
          SET stock_qty = stock_qty - ?, updated_at = ?
          WHERE id = ?
        ''', [qty, nowSeconds, pid]);

        if (batch != null && batch.trim().isNotEmpty) {
          await _db.customStatement('''
            UPDATE product_batches
            SET quantity = MAX(0, quantity - ?), updated_at = ?
            WHERE product_id = ? AND batch_number = ?
          ''', [qty, nowSeconds, pid, batch.trim()]);
        }

        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: pid,
                type: StockMovementType.adjust.value,
                qtyChange: -qty,
                reason: Value('Cancellation of Purchase #${detail['invoice_number']}: ${reason ?? "Cancelled"}'),
                supplierId: Value(supplierId),
                createdAt: Value(now),
              ),
            );
      }

      // 2. Reverse ledger posting
      // Debit: Supplier Payable (reduces liability to 0)
      // Credit: Inventory (reduces inventory asset to 0)
      await _ledgerRepository.postTransaction(
        workspaceId: detail['workspace_id'] as int? ?? 1,
        entries: [
          LedgerPostingItem(
            transactionType: 'purchase_cancel',
            referenceType: 'supplier',
            referenceId: supplierId,
            partyType: 'supplier',
            partyId: supplierId,
            debit: total,
            credit: 0.0,
            narration: 'Cancellation reversal of purchase #${detail['invoice_number']}',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'purchase_cancel',
            referenceType: 'purchase_invoice',
            referenceId: id,
            debit: 0.0,
            credit: total,
            narration: 'Inventory reduction on purchase cancellation #$id',
            createdAt: now,
          ),
        ],
      );

      // 3. Mark invoice cancelled
      await _db.customStatement('''
        UPDATE purchase_invoices
        SET is_cancelled = 1, status = 'cancelled', notes = COALESCE(notes, '') || ' [Cancelled: ' || ? || ']'
        WHERE id = ?
      ''', [reason ?? 'Cancelled by user', id]);
    });
  }

  @override
  Future<void> recordPurchasePayment({
    required int purchaseInvoiceId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
  }) async {
    if (amount <= 0) {
      throw AppException('Payment amount must be greater than zero');
    }

    final detail = await getPurchaseInvoiceDetail(purchaseInvoiceId);
    if (detail == null) throw AppException('Purchase invoice not found');
    if ((detail['is_cancelled'] as int? ?? 0) == 1) {
      throw AppException('Cannot pay a cancelled purchase invoice');
    }

    final total = (detail['total_amount'] as num? ?? 0.0).toDouble();
    final paid = (detail['paid_amount'] as num? ?? 0.0).toDouble();
    final due = total - paid;

    if (amount > due + 0.01) {
      throw AppException('Payment amount (₹$amount) exceeds outstanding balance (₹$due)');
    }

    final now = paymentDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final supplierId = detail['supplier_id'] as int;
    final workspaceId = detail['workspace_id'] as int? ?? 1;
    final invoiceNumber = detail['invoice_number'] as String? ?? '';

    await _db.transaction(() async {
      // 1. Update purchase invoice paid amount
      final newPaid = paid + amount;
      final newStatus = newPaid >= total ? 'paid' : 'partial';

      await _db.customStatement('''
        UPDATE purchase_invoices
        SET paid_amount = ?, status = ?
        WHERE id = ?
      ''', [newPaid, newStatus, purchaseInvoiceId]);

      // 2. Insert into payments table
      await _db.customStatement('''
        INSERT INTO payments (
          workspace_id, payment_type, reference_type, reference_id,
          account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
        ) VALUES (?, 'supplier_payment', 'purchase_invoice', ?, ?, ?, 'standard', ?, ?, ?, ?)
      ''', [
        workspaceId,
        purchaseInvoiceId,
        accountId,
        amount,
        referenceNo,
        narration ?? 'Payment against purchase #$invoiceNumber',
        nowSeconds,
        nowSeconds,
      ]);

      final lastPayRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final paymentId = lastPayRow.data['id'] as int;

      // 3. Insert invoice-wise allocation
      await _db.customStatement('''
        INSERT INTO party_payment_allocations (
          workspace_id, payment_id, party_type, party_id, invoice_type, invoice_id, allocated_amount, created_at
        ) VALUES (?, ?, 'supplier', ?, 'purchase_invoice', ?, ?, ?)
      ''', [workspaceId, paymentId, supplierId, purchaseInvoiceId, amount, nowSeconds]);

      // 4. Post double-entry ledger entries
      // Debit: Supplier Payable (reduces liability)
      // Credit: Account Asset (reduces cash/bank)
      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'payment_out',
            referenceType: 'purchase_invoice',
            referenceId: purchaseInvoiceId,
            partyType: 'supplier',
            partyId: supplierId,
            debit: amount,
            credit: 0.0,
            narration: 'Payment for Purchase #$invoiceNumber',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'payment_out',
            referenceType: 'account',
            referenceId: accountId,
            accountId: accountId,
            debit: 0.0,
            credit: amount,
            narration: 'Disbursement from Account #$accountId for Purchase #$invoiceNumber',
            createdAt: now,
          ),
        ],
      );
    });
  }

  @override
  Future<int> createPurchaseReturn(PurchaseReturnInput input) async {
    if (input.items.isEmpty) {
      throw AppException('At least one item must be returned');
    }

    final invoice = await getPurchaseInvoiceDetail(input.purchaseInvoiceId);
    if (invoice == null) throw AppException('Purchase invoice not found');
    if ((invoice['is_cancelled'] as int? ?? 0) == 1) {
      throw AppException('Cannot return items from a cancelled purchase invoice');
    }

    final invoiceItems = (invoice['items'] as List<dynamic>?) ?? [];
    final now = input.returnDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    // Validate quantities against unreturned quantities
    for (final returnItem in input.items) {
      Map<String, dynamic>? original;
      for (final it in invoiceItems) {
        if (it is Map && it['product_id'] == returnItem.productId) {
          original = Map<String, dynamic>.from(it);
          break;
        }
      }
      if (original == null) {
        throw AppException('Product #${returnItem.productId} was not part of this purchase invoice');
      }
      final purchasedQty = original['quantity'] as int;
      final alreadyReturned = original['returned_qty'] as int? ?? 0;
      final maxAvailable = purchasedQty - alreadyReturned;

      if (returnItem.quantity <= 0) {
        throw AppException('Return quantity must be greater than zero');
      }
      if (returnItem.quantity > maxAvailable) {
        throw AppException(
          'Cannot return ${returnItem.quantity} units for product #${returnItem.productId}. Only $maxAvailable units remaining unreturned.',
        );
      }
    }

    return _db.transaction(() async {
      // 1. Insert into purchase_returns
      await _db.customStatement('''
        INSERT INTO purchase_returns (
          workspace_id, purchase_invoice_id, supplier_id, debit_note_number,
          return_date, subtotal, tax_total, total_amount, reason, status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'completed', ?)
      ''', [
        input.workspaceId,
        input.purchaseInvoiceId,
        input.supplierId,
        input.debitNoteNumber,
        nowSeconds,
        input.subtotal,
        input.taxTotal,
        input.totalAmount,
        input.reason,
        nowSeconds,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final returnId = lastIdRow.data['id'] as int;

      // 2. Insert return items and update inventory & batches
      for (final item in input.items) {
        await _db.customStatement('''
          INSERT INTO purchase_return_items (
            purchase_return_id, product_id, batch_number, quantity, unit_cost, gst_rate, tax_amount, total
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          returnId,
          item.productId,
          item.batchNumber,
          item.quantity,
          item.unitCost,
          item.gstRate,
          item.taxAmount,
          item.total,
        ]);

        // Update returned_qty in purchase_invoice_items
        await _db.customStatement('''
          UPDATE purchase_invoice_items
          SET returned_qty = returned_qty + ?
          WHERE purchase_invoice_id = ? AND product_id = ?
        ''', [item.quantity, input.purchaseInvoiceId, item.productId]);

        // Deduct from product inventory
        await _db.customStatement('''
          UPDATE products
          SET stock_qty = stock_qty - ?, updated_at = ?
          WHERE id = ?
        ''', [item.quantity, nowSeconds, item.productId]);

        // Deduct from batch
        if (item.batchNumber != null && item.batchNumber!.trim().isNotEmpty) {
          await _db.customStatement('''
            UPDATE product_batches
            SET quantity = MAX(0, quantity - ?), updated_at = ?
            WHERE product_id = ? AND batch_number = ?
          ''', [item.quantity, nowSeconds, item.productId, item.batchNumber!.trim()]);
        }

        // Audit stock movement
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: item.productId,
                type: StockMovementType.adjust.value,
                qtyChange: -item.quantity,
                unitCost: Value(item.unitCost),
                reason: Value('Purchase Return Debit Note #${input.debitNoteNumber}: ${input.reason ?? "Return to supplier"}'),
                supplierId: Value(input.supplierId),
                createdAt: Value(now),
              ),
            );
      }

      // 3. Update returned_amount on purchase invoice
      await _db.customStatement('''
        UPDATE purchase_invoices
        SET returned_amount = returned_amount + ?
        WHERE id = ?
      ''', [input.totalAmount, input.purchaseInvoiceId]);

      // 4. Double-entry ledger posting:
      // Debit: Supplier Payable (reduces liability to supplier)
      // Credit: Purchase Returns / Inventory Asset (reduces inventory asset)
      final List<LedgerPostingItem> ledgerEntries = [
        LedgerPostingItem(
          transactionType: 'purchase_return',
          referenceType: 'supplier',
          referenceId: input.supplierId,
          partyType: 'supplier',
          partyId: input.supplierId,
          debit: input.totalAmount,
          credit: 0.0,
          narration: 'Debit Note #${input.debitNoteNumber} issued to Supplier #${input.supplierId}',
          createdAt: now,
        ),
        LedgerPostingItem(
          transactionType: 'purchase_return',
          referenceType: 'purchase_return',
          referenceId: returnId,
          debit: 0.0,
          credit: input.totalAmount,
          narration: 'Inventory stock reduction for purchase return #${input.debitNoteNumber}',
          createdAt: now,
        ),
      ];

      // If supplier provided an immediate cash/bank refund:
      if (input.refundAccountId != null) {
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'payment_in',
            referenceType: 'account',
            referenceId: input.refundAccountId,
            accountId: input.refundAccountId,
            debit: input.totalAmount,
            credit: 0.0,
            narration: 'Refund received into Account #${input.refundAccountId} for Debit Note #${input.debitNoteNumber}',
            createdAt: now,
          ),
        );
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'payment_in',
            referenceType: 'supplier',
            referenceId: input.supplierId,
            partyType: 'supplier',
            partyId: input.supplierId,
            debit: 0.0,
            credit: input.totalAmount,
            narration: 'Offset supplier payable for cash refund on Debit Note #${input.debitNoteNumber}',
            createdAt: now,
          ),
        );

        // Record in payments table
        await _db.customStatement('''
          INSERT INTO payments (
            workspace_id, payment_type, reference_type, reference_id,
            account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
          ) VALUES (?, 'supplier_refund', 'purchase_return', ?, ?, ?, 'standard', ?, ?, ?, ?)
        ''', [
          input.workspaceId,
          returnId,
          input.refundAccountId,
          input.totalAmount,
          input.debitNoteNumber,
          'Supplier refund for Debit Note #${input.debitNoteNumber}',
          nowSeconds,
          nowSeconds,
        ]);
      }

      await _ledgerRepository.postTransaction(
        workspaceId: input.workspaceId,
        entries: ledgerEntries,
      );

      return returnId;
    });
  }

  @override
  Future<List<PurchaseReturnModel>> getPurchaseReturns({
    int workspaceId = 1,
    int? purchaseInvoiceId,
    int? supplierId,
  }) async {
    final conditions = ['pr.workspace_id = ?'];
    final variables = <Variable>[Variable.withInt(workspaceId)];

    if (purchaseInvoiceId != null) {
      conditions.add('pr.purchase_invoice_id = ?');
      variables.add(Variable.withInt(purchaseInvoiceId));
    }
    if (supplierId != null) {
      conditions.add('pr.supplier_id = ?');
      variables.add(Variable.withInt(supplierId));
    }

    final query = '''
      SELECT pr.*, s.name as supplier_name, pi.invoice_number
      FROM purchase_returns pr
      LEFT JOIN suppliers s ON s.id = pr.supplier_id
      LEFT JOIN purchase_invoices pi ON pi.id = pr.purchase_invoice_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY pr.id DESC
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();
    return rows.map((r) {
      final retSecs = r.data['return_date'] as int? ?? 0;
      final createSecs = r.data['created_at'] as int? ?? 0;
      return PurchaseReturnModel(
        id: r.data['id'] as int,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        purchaseInvoiceId: r.data['purchase_invoice_id'] as int,
        supplierId: r.data['supplier_id'] as int,
        debitNoteNumber: r.data['debit_note_number'] as String? ?? '',
        returnDate: DateTime.fromMillisecondsSinceEpoch(retSecs * 1000),
        subtotal: (r.data['subtotal'] as num? ?? 0.0).toDouble(),
        taxTotal: (r.data['tax_total'] as num? ?? 0.0).toDouble(),
        totalAmount: (r.data['total_amount'] as num? ?? 0.0).toDouble(),
        reason: r.data['reason'] as String?,
        status: r.data['status'] as String? ?? 'completed',
        createdAt: DateTime.fromMillisecondsSinceEpoch(createSecs * 1000),
        supplierName: r.data['supplier_name'] as String?,
        invoiceNumber: r.data['invoice_number'] as String?,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getPurchaseReturnDetail(int returnId) async {
    final rows = await _db.customSelect('''
      SELECT pr.*, s.name as supplier_name, s.phone as supplier_phone, s.gstin as supplier_gstin,
             pi.invoice_number, pi.invoice_date as original_invoice_date
      FROM purchase_returns pr
      LEFT JOIN suppliers s ON s.id = pr.supplier_id
      LEFT JOIN purchase_invoices pi ON pi.id = pr.purchase_invoice_id
      WHERE pr.id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(returnId)]).get();

    if (rows.isEmpty) return null;
    final header = Map<String, dynamic>.from(rows.first.data);

    final itemRows = await _db.customSelect('''
      SELECT pri.*, pr.name as product_name, pr.sku as product_sku
      FROM purchase_return_items pri
      LEFT JOIN products pr ON pr.id = pri.product_id
      WHERE pri.purchase_return_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(returnId)]).get();
    header['items'] = itemRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    return header;
  }

  @override
  Future<PurchaseDashboardMetrics> getPurchaseDashboardMetrics({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? paymentStatus,
  }) async {
    final bills = await getPurchaseInvoices(
      workspaceId: workspaceId,
      fromDate: fromDate,
      toDate: toDate,
      supplierId: supplierId,
      statusFilter: paymentStatus,
    );

    double totalPurchases = 0.0;
    double totalPaid = 0.0;
    double todayPurchases = 0.0;
    double monthlyPurchases = 0.0;
    int pendingSupplierPayments = 0;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    for (final b in bills) {
      if ((b['is_cancelled'] as int? ?? 0) == 1) continue;

      final tot = (b['total_amount'] as num? ?? 0.0).toDouble();
      final pd = (b['paid_amount'] as num? ?? 0.0).toDouble();
      totalPurchases += tot;
      totalPaid += pd;

      if (tot > pd) {
        pendingSupplierPayments++;
      }

      final invDateSecs = b['invoice_date'] as int? ?? 0;
      final invDate = DateTime.fromMillisecondsSinceEpoch(invDateSecs * 1000);

      if (invDate.isAfter(todayStart) || invDate.isAtSameMomentAs(todayStart)) {
        todayPurchases += tot;
      }
      if (invDate.isAfter(monthStart) || invDate.isAtSameMomentAs(monthStart)) {
        monthlyPurchases += tot;
      }
    }

    // Purchase returns total
    final returnRows = await _db.customSelect('''
      SELECT COALESCE(SUM(total_amount), 0.0) as returns_total
      FROM purchase_returns
      WHERE workspace_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final returnsTotal = returnRows.isNotEmpty ? (returnRows.first.data['returns_total'] as num? ?? 0.0).toDouble() : 0.0;

    // Recently received stock
    final recentInwardRows = await _db.customSelect('''
      SELECT pii.product_id, pii.quantity, pii.unit_cost, pii.batch_number,
             pr.name as product_name, pr.sku as product_sku, pi.invoice_number, pi.invoice_date,
             s.name as supplier_name
      FROM purchase_invoice_items pii
      JOIN purchase_invoices pi ON pi.id = pii.purchase_invoice_id
      LEFT JOIN products pr ON pr.id = pii.product_id
      LEFT JOIN suppliers s ON s.id = pi.supplier_id
      WHERE pi.workspace_id = ? AND pi.is_cancelled = 0
      ORDER BY pi.id DESC, pii.id DESC
      LIMIT 10
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    final recentReceivedStock = recentInwardRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    return PurchaseDashboardMetrics(
      totalPurchases: totalPurchases,
      todayPurchases: todayPurchases,
      monthlyPurchases: monthlyPurchases,
      totalPaid: totalPaid,
      totalOutstanding: (totalPurchases - totalPaid) > 0 ? (totalPurchases - totalPaid) : 0.0,
      pendingSupplierPayments: pendingSupplierPayments,
      invoicesCount: bills.where((b) => (b['is_cancelled'] as int? ?? 0) == 0).length,
      returnsTotal: returnsTotal,
      recentReceivedStock: recentReceivedStock,
    );
  }

  @override
  Future<Map<String, dynamic>> getPurchaseReport({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    // 1. Supplier-wise summary
    final supplierSummaryRows = await _db.customSelect('''
      SELECT s.id as supplier_id, s.name as supplier_name,
             COUNT(pi.id) as invoice_count,
             COALESCE(SUM(pi.total_amount), 0.0) as total_amount,
             COALESCE(SUM(pi.paid_amount), 0.0) as paid_amount,
             COALESCE(SUM(pi.total_amount - pi.paid_amount), 0.0) as due_amount
      FROM purchase_invoices pi
      JOIN suppliers s ON s.id = pi.supplier_id
      WHERE pi.workspace_id = ? AND pi.is_cancelled = 0
      GROUP BY s.id, s.name
      ORDER BY total_amount DESC
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    // 2. Product-wise inward summary
    final productSummaryRows = await _db.customSelect('''
      SELECT pr.id as product_id, pr.name as product_name, pr.sku as product_sku,
             COALESCE(SUM(pii.quantity), 0) as total_quantity,
             COALESCE(SUM(pii.total), 0.0) as total_cost
      FROM purchase_invoice_items pii
      JOIN purchase_invoices pi ON pi.id = pii.purchase_invoice_id
      JOIN products pr ON pr.id = pii.product_id
      WHERE pi.workspace_id = ? AND pi.is_cancelled = 0
      GROUP BY pr.id, pr.name, pr.sku
      ORDER BY total_cost DESC
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    // 3. Purchase GST summary
    final gstSummaryRows = await _db.customSelect('''
      SELECT COALESCE(SUM(taxable_value), 0.0) as taxable_total,
             COALESCE(SUM(cgst), 0.0) as cgst_total,
             COALESCE(SUM(sgst), 0.0) as sgst_total,
             COALESCE(SUM(igst), 0.0) as igst_total,
             COALESCE(SUM(tax_total), 0.0) as tax_total,
             COALESCE(SUM(total_amount), 0.0) as grand_total
      FROM purchase_invoices
      WHERE workspace_id = ? AND is_cancelled = 0
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    final supplierSummary = supplierSummaryRows.map((r) => Map<String, dynamic>.from(r.data)).toList();
    final productSummary = productSummaryRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    return {
      'supplier_summary': supplierSummary,
      'supplier_wise': supplierSummary,
      'product_summary': productSummary,
      'product_wise': productSummary,
      'gst_summary': gstSummaryRows.isNotEmpty ? Map<String, dynamic>.from(gstSummaryRows.first.data) : {},
      'monthly_trends': <Map<String, dynamic>>[],
    };
  }
}
