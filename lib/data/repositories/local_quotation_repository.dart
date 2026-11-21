import 'package:drift/drift.dart';

import '../../core/models/app_models.dart';
import '../../domain/repositories/repositories.dart';
import '../local/db/app_database.dart';

class LocalQuotationRepository implements QuotationRepository {
  const LocalQuotationRepository(this.db, this.ledgerRepository);

  final AppDatabase db;
  final LedgerRepository ledgerRepository;

  @override
  Future<List<Quotation>> getQuotations({
    int workspaceId = 1,
    String? status,
    String? query,
  }) async {
    final q = db.select(db.quotations)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.quotationDate)]);

    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      q.where((tbl) => tbl.status.equals(status.toLowerCase()));
    }

    final rows = await q.get();

    if (query != null && query.trim().isNotEmpty) {
      final clean = query.trim().toLowerCase();
      return rows.where((r) {
        final matchesNumber = r.quotationNumber.toLowerCase().contains(clean);
        final matchesName = r.customerName.toLowerCase().contains(clean);
        final matchesPhone = r.customerPhone.toLowerCase().contains(clean);
        return matchesNumber || matchesName || matchesPhone;
      }).toList();
    }

    return rows;
  }

  @override
  Future<Quotation?> getQuotationById(int quotationId) async {
    final query = db.select(db.quotations)..where((tbl) => tbl.id.equals(quotationId));
    return query.getSingleOrNull();
  }

  @override
  Future<List<QuotationItem>> getQuotationItems(int quotationId) async {
    final query = db.select(db.quotationItems)..where((tbl) => tbl.quotationId.equals(quotationId));
    return query.get();
  }

  @override
  Future<int> createQuotation({
    int workspaceId = 1,
    required String quotationNumber,
    int? customerId,
    int? leadId,
    required String customerName,
    required String customerPhone,
    required DateTime validUntil,
    required double subtotal,
    double discountTotal = 0.0,
    double taxTotal = 0.0,
    double cgstTotal = 0.0,
    double sgstTotal = 0.0,
    double igstTotal = 0.0,
    required double totalAmount,
    String status = 'draft',
    String? terms,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    return db.transaction(() async {
      final now = DateTime.now();
      final qId = await db.into(db.quotations).insert(
            QuotationsCompanion.insert(
              workspaceId: workspaceId,
              quotationNumber: quotationNumber,
              customerId: Value(customerId),
              leadId: Value(leadId),
              customerName: customerName,
              customerPhone: customerPhone,
              quotationDate: Value(now),
              validUntil: validUntil,
              subtotal: subtotal,
              discountTotal: Value(discountTotal),
              taxTotal: Value(taxTotal),
              cgstTotal: Value(cgstTotal),
              sgstTotal: Value(sgstTotal),
              igstTotal: Value(igstTotal),
              totalAmount: totalAmount,
              status: Value(status),
              terms: Value(terms),
              notes: Value(notes),
              createdAt: Value(now),
            ),
          );

      for (final item in items) {
        await db.into(db.quotationItems).insert(
              QuotationItemsCompanion.insert(
                quotationId: qId,
                itemType: Value(item['itemType'] as String? ?? 'product'),
                referenceId: Value(item['referenceId'] as int?),
                description: item['description'] as String? ?? 'Item',
                quantity: Value((item['quantity'] as num?)?.toDouble() ?? 1.0),
                unitPrice: (item['unitPrice'] as num).toDouble(),
                discount: Value((item['discount'] as num?)?.toDouble() ?? 0.0),
                gstRate: Value((item['gstRate'] as num?)?.toDouble() ?? 0.0),
                total: (item['total'] as num).toDouble(),
              ),
            );
      }

      return qId;
    });
  }

  @override
  Future<void> updateQuotationStatus(int quotationId, String status) async {
    await (db.update(db.quotations)..where((tbl) => tbl.id.equals(quotationId))).write(
      QuotationsCompanion(status: Value(status)),
    );
  }

  @override
  Future<int> convertQuotationToSale({
    required int quotationId,
    required int accountId,
    required String paymentMode,
  }) async {
    return db.transaction(() async {
      final quotation = await getQuotationById(quotationId);
      if (quotation == null) {
        throw StateError('Quotation not found.');
      }
      if (quotation.status == 'converted') {
        throw StateError('Quotation has already been converted.');
      }

      final items = await getQuotationItems(quotationId);
      final now = DateTime.now();
      final invoiceNo = 'INV-${now.millisecondsSinceEpoch.toString().substring(5)}';

      // 1. Create Sale record
      final saleId = await db.into(db.sales).insert(
            SalesCompanion.insert(
              workspaceId: const Value(1),
              invoiceNo: invoiceNo,
              customerId: Value(quotation.customerId),
              subtotal: quotation.subtotal,
              discountTotal: quotation.discountTotal,
              taxTotal: quotation.taxTotal,
              total: quotation.totalAmount,
              paid: quotation.totalAmount,
              changeAmount: 0.0,
              paymentMethod: paymentMode,
              status: 'completed',
              cgstTotal: Value(quotation.cgstTotal),
              sgstTotal: Value(quotation.sgstTotal),
              igstTotal: Value(quotation.igstTotal),
              createdAt: Value(now),
            ),
          );

      // 2. Insert Sale Items
      for (final item in items) {
        final prodId = item.referenceId ?? 1;
        await db.into(db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: prodId,
                nameSnapshot: item.description,
                priceSnapshot: item.unitPrice,
                costSnapshot: item.unitPrice * 0.7, // estimated standard margin
                qty: item.quantity.toInt(),
                discount: Value(item.discount),
                lineTotal: item.total,
              ),
            );

        // Deduct inventory if product exists
        if (item.itemType == 'product' && item.referenceId != null) {
          final prod = await (db.select(db.products)..where((tbl) => tbl.id.equals(prodId))).getSingleOrNull();
          if (prod != null) {
            final newQty = prod.stockQty - item.quantity.toInt();
            await (db.update(db.products)..where((tbl) => tbl.id.equals(prodId))).write(
              ProductsCompanion(stockQty: Value(newQty)),
            );
          }
        }
      }

      // 3. Post balanced double-entry ledger entries
      final ledgerItems = <LedgerPostingItem>[
        // DR Account (asset increases)
        LedgerPostingItem(
          transactionType: 'sale',
          referenceType: 'account',
          referenceId: accountId,
          accountId: accountId,
          partyType: 'customer',
          partyId: quotation.customerId,
          debit: quotation.totalAmount,
          credit: 0.0,
          narration: 'Receipt from Quotation ${quotation.quotationNumber} conversion ($invoiceNo)',
        ),
        // CR Revenue (income increases)
        LedgerPostingItem(
          transactionType: 'sale',
          referenceType: 'revenue',
          referenceId: saleId,
          partyType: 'customer',
          partyId: quotation.customerId,
          debit: 0.0,
          credit: quotation.subtotal - quotation.discountTotal,
          narration: 'Sales Revenue for $invoiceNo',
        ),
      ];

      // CR Tax Payable if applicable
      if (quotation.taxTotal > 0) {
        ledgerItems.add(
          LedgerPostingItem(
            transactionType: 'sale',
            referenceType: 'tax_payable',
            referenceId: saleId,
            partyType: 'customer',
            partyId: quotation.customerId,
            debit: 0.0,
            credit: quotation.taxTotal,
            narration: 'GST Payable for $invoiceNo',
          ),
        );
      }

      await ledgerRepository.postTransaction(
        workspaceId: 1,
        entries: ledgerItems,
      );

      // 4. Record Payment transaction
      await db.into(db.payments).insert(
            PaymentsCompanion.insert(
              workspaceId: 1,
              accountId: accountId,
              paymentType: 'customer_receipt',
              referenceType: 'sale',
              referenceId: Value(saleId),
              amount: quotation.totalAmount,
              paymentMode: paymentMode,
              referenceNo: Value(quotation.quotationNumber),
              narration: Value('Quotation conversion payment for $invoiceNo'),
              createdAt: Value(now),
            ),
          );

      // 5. Update quotation status
      await (db.update(db.quotations)..where((tbl) => tbl.id.equals(quotationId))).write(
        QuotationsCompanion(
          status: const Value('converted'),
          convertedReferenceType: const Value('sale'),
          convertedReferenceId: Value(saleId),
        ),
      );

      return saleId;
    });
  }
}
