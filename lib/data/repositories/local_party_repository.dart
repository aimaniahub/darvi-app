import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/repositories/repositories.dart';
import 'local_ledger_repository.dart';

class LocalPartyRepository implements PartyRepository {
  LocalPartyRepository(this._db, [LocalLedgerRepository? ledgerRepo])
      : _ledgerRepository = ledgerRepo ?? LocalLedgerRepository(_db);

  final AppDatabase _db;
  final LocalLedgerRepository _ledgerRepository;

  @override
  Future<void> deleteCustomer(int id) async {
    // Check if customer has transactions (sales or ledger entries)
    final sales = await _db.customSelect(
      'SELECT id FROM sales WHERE customer_id = ? LIMIT 1',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();

    final ledger = await _db.customSelect(
      'SELECT id FROM ledger_entries WHERE party_type = "customer" AND party_id = ? LIMIT 1',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();

    if (sales.isNotEmpty || ledger.isNotEmpty) {
      // Soft-delete to preserve immutable transaction history
      await _db.customStatement('UPDATE customers SET is_active = 0 WHERE id = ?', [id]);
    } else {
      await (_db.delete(_db.customers)..where((tbl) => tbl.id.equals(id))).go();
    }
  }

  @override
  Future<void> deleteSupplier(int id) async {
    // Check if supplier has transactions (purchases or ledger entries)
    final purchases = await _db.customSelect(
      'SELECT id FROM purchase_invoices WHERE supplier_id = ? LIMIT 1',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();

    final ledger = await _db.customSelect(
      'SELECT id FROM ledger_entries WHERE party_type = "supplier" AND party_id = ? LIMIT 1',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();

    if (purchases.isNotEmpty || ledger.isNotEmpty) {
      // Soft-delete to preserve historical audit trail
      await _db.customStatement('UPDATE suppliers SET is_active = 0 WHERE id = ?', [id]);
    } else {
      await (_db.delete(_db.suppliers)..where((tbl) => tbl.id.equals(id))).go();
    }
  }

  @override
  Future<List<CustomerModel>> getCustomers({int workspaceId = 1, bool activeOnly = false}) async {
    final activeClause = activeOnly ? 'AND is_active = 1' : '';
    final rows = await _db.customSelect('''
      SELECT * FROM customers
      WHERE workspace_id = ? $activeClause
      ORDER BY name ASC
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    final List<CustomerModel> list = [];
    for (final row in rows) {
      final data = row.data;
      final cid = data['id'] as int;
      final ledgerBalance = await _ledgerRepository.getCustomerBalance(cid, workspaceId: workspaceId);

      list.add(
        CustomerModel(
          id: cid,
          name: data['name'] as String? ?? '',
          phone: data['phone'] as String?,
          notes: data['notes'] as String?,
          balance: ledgerBalance,
          gstin: data['gstin'] as String?,
          address: data['address'] as String?,
          creditLimit: (data['credit_limit'] as num? ?? 10000.0).toDouble(),
          workspaceId: data['workspace_id'] as int? ?? 1,
          code: data['code'] as String?,
          alternatePhone: data['alternate_phone'] as String?,
          email: data['email'] as String?,
          state: data['state'] as String? ?? 'Karnataka',
          customerType: data['customer_type'] as String? ?? 'individual',
          creditPeriodDays: data['credit_period_days'] as int? ?? 30,
          isActive: (data['is_active'] as int? ?? 1) == 1,
          openingBalance: (data['opening_balance'] as num? ?? 0.0).toDouble(),
        ),
      );
    }
    return list;
  }

  @override
  Future<CustomerModel?> getCustomerById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM customers WHERE id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;

    final data = rows.first.data;
    final wsId = data['workspace_id'] as int? ?? 1;
    final ledgerBalance = await _ledgerRepository.getCustomerBalance(id, workspaceId: wsId);

    return CustomerModel(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String?,
      notes: data['notes'] as String?,
      balance: ledgerBalance,
      gstin: data['gstin'] as String?,
      address: data['address'] as String?,
      creditLimit: (data['credit_limit'] as num? ?? 10000.0).toDouble(),
      workspaceId: wsId,
      code: data['code'] as String?,
      alternatePhone: data['alternate_phone'] as String?,
      email: data['email'] as String?,
      state: data['state'] as String? ?? 'Karnataka',
      customerType: data['customer_type'] as String? ?? 'individual',
      creditPeriodDays: data['credit_period_days'] as int? ?? 30,
      isActive: (data['is_active'] as int? ?? 1) == 1,
      openingBalance: (data['opening_balance'] as num? ?? 0.0).toDouble(),
    );
  }

  @override
  Future<List<SupplierModel>> getSuppliers({int workspaceId = 1, bool activeOnly = false}) async {
    final activeClause = activeOnly ? 'AND is_active = 1' : '';
    final rows = await _db.customSelect('''
      SELECT * FROM suppliers
      WHERE workspace_id = ? $activeClause
      ORDER BY name ASC
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    final List<SupplierModel> list = [];
    for (final row in rows) {
      final data = row.data;
      final sid = data['id'] as int;
      final ledgerBalance = await _ledgerRepository.getSupplierBalance(sid, workspaceId: workspaceId);

      list.add(
        SupplierModel(
          id: sid,
          name: data['name'] as String? ?? '',
          phone: data['phone'] as String?,
          gstin: data['gstin'] as String?,
          address: data['address'] as String?,
          balance: ledgerBalance,
          workspaceId: data['workspace_id'] as int? ?? 1,
          code: data['code'] as String?,
          contactPerson: data['contact_person'] as String?,
          email: data['email'] as String?,
          state: data['state'] as String? ?? 'Karnataka',
          paymentTerms: data['payment_terms'] as String? ?? '30 Days',
          isActive: (data['is_active'] as int? ?? 1) == 1,
          openingBalance: (data['opening_balance'] as num? ?? 0.0).toDouble(),
          notes: data['notes'] as String?,
        ),
      );
    }
    return list;
  }

  @override
  Future<SupplierModel?> getSupplierById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM suppliers WHERE id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;

    final data = rows.first.data;
    final wsId = data['workspace_id'] as int? ?? 1;
    final ledgerBalance = await _ledgerRepository.getSupplierBalance(id, workspaceId: wsId);

    return SupplierModel(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String?,
      gstin: data['gstin'] as String?,
      address: data['address'] as String?,
      balance: ledgerBalance,
      workspaceId: wsId,
      code: data['code'] as String?,
      contactPerson: data['contact_person'] as String?,
      email: data['email'] as String?,
      state: data['state'] as String? ?? 'Karnataka',
      paymentTerms: data['payment_terms'] as String? ?? '30 Days',
      isActive: (data['is_active'] as int? ?? 1) == 1,
      openingBalance: (data['opening_balance'] as num? ?? 0.0).toDouble(),
      notes: data['notes'] as String?,
    );
  }

  @override
  Future<int> upsertCustomer({
    int? id,
    int workspaceId = 1,
    required String name,
    String? phone,
    String? notes,
    double balance = 0,
    String? gstin,
    String? address,
    double creditLimit = 10000.0,
    String? code,
    String? alternatePhone,
    String? email,
    String state = 'Karnataka',
    String customerType = 'individual',
    int creditPeriodDays = 30,
    bool isActive = true,
    double openingBalance = 0.0,
  }) async {
    if (name.trim().isEmpty) {
      throw AppException('Customer name cannot be empty');
    }

    // Duplicate code check
    if (code != null && code.trim().isNotEmpty) {
      final codeTrimmed = code.trim();
      final existingCode = await _db.customSelect(
        'SELECT id FROM customers WHERE workspace_id = ? AND code = ? AND (? IS NULL OR id != ?)',
        readsFrom: {},
        variables: [
          Variable.withInt(workspaceId),
          Variable.withString(codeTrimmed),
          Variable.withInt(id ?? -1),
          Variable.withInt(id ?? -1),
        ],
      ).get();
      if (existingCode.isNotEmpty) {
        throw AppException('Customer code "$codeTrimmed" already exists and is assigned to another customer');
      }
    }

    return _db.transaction(() async {
      int customerId;
      if (id == null) {
        final custCode = code?.trim().isNotEmpty == true
            ? code!.trim()
            : 'CUST-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

        final effectiveOpeningBalance = openingBalance != 0.0 ? openingBalance : balance;

        await _db.customStatement('''
          INSERT INTO customers (
            name, phone, notes, balance, workspace_id, gstin, address, credit_limit,
            code, alternate_phone, email, state, customer_type, credit_period_days, is_active, opening_balance
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          name.trim(),
          phone?.trim(),
          notes?.trim(),
          effectiveOpeningBalance,
          workspaceId,
          gstin?.trim().toUpperCase(),
          address?.trim(),
          creditLimit,
          custCode,
          alternatePhone?.trim(),
          email?.trim(),
          state,
          customerType,
          creditPeriodDays,
          isActive ? 1 : 0,
          effectiveOpeningBalance,
        ]);

        final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
        customerId = lastIdRow.data['id'] as int;

        // Post opening balance into double-entry ledger
        if (effectiveOpeningBalance != 0.0) {
          final now = DateTime.now();
          if (effectiveOpeningBalance > 0) {
            // Debit Customer Receivable, Credit Opening Balance Equity
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'customer',
                  referenceId: customerId,
                  partyType: 'customer',
                  partyId: customerId,
                  debit: effectiveOpeningBalance,
                  credit: 0.0,
                  narration: 'Opening balance receivable for customer $name',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: 0.0,
                  credit: effectiveOpeningBalance,
                  narration: 'Offsetting opening balance credit to Capital/Equity',
                  createdAt: now,
                ),
              ],
            );
          } else {
            // Negative opening balance: Customer credit/advance
            final absBal = effectiveOpeningBalance.abs();
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: absBal,
                  credit: 0.0,
                  narration: 'Offsetting opening balance debit to Capital/Equity',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'customer',
                  referenceId: customerId,
                  partyType: 'customer',
                  partyId: customerId,
                  debit: 0.0,
                  credit: absBal,
                  narration: 'Opening advance credit for customer $name',
                  createdAt: now,
                ),
              ],
            );
          }
        }
      } else {
        customerId = id;
        await _db.customStatement('''
          UPDATE customers
          SET name = ?, phone = ?, notes = ?, gstin = ?, address = ?, credit_limit = ?,
              code = COALESCE(?, code), alternate_phone = ?, email = ?, state = ?,
              customer_type = ?, credit_period_days = ?, is_active = ?
          WHERE id = ? AND workspace_id = ?
        ''', [
          name.trim(),
          phone?.trim(),
          notes?.trim(),
          gstin?.trim().toUpperCase(),
          address?.trim(),
          creditLimit,
          code?.trim(),
          alternatePhone?.trim(),
          email?.trim(),
          state,
          customerType,
          creditPeriodDays,
          isActive ? 1 : 0,
          id,
          workspaceId,
        ]);
      }
      return customerId;
    });
  }

  @override
  Future<int> upsertSupplier({
    int? id,
    int workspaceId = 1,
    required String name,
    String? phone,
    String? gstin,
    String? address,
    double balance = 0,
    String? code,
    String? contactPerson,
    String? email,
    String state = 'Karnataka',
    String paymentTerms = '30 Days',
    bool isActive = true,
    double openingBalance = 0.0,
    String? notes,
  }) async {
    if (name.trim().isEmpty) {
      throw AppException('Supplier name cannot be empty');
    }

    // Duplicate code check
    if (code != null && code.trim().isNotEmpty) {
      final codeTrimmed = code.trim();
      final existingCode = await _db.customSelect(
        'SELECT id FROM suppliers WHERE workspace_id = ? AND code = ? AND (? IS NULL OR id != ?)',
        readsFrom: {},
        variables: [
          Variable.withInt(workspaceId),
          Variable.withString(codeTrimmed),
          Variable.withInt(id ?? -1),
          Variable.withInt(id ?? -1),
        ],
      ).get();
      if (existingCode.isNotEmpty) {
        throw AppException('Supplier code "$codeTrimmed" already exists and is assigned to another supplier');
      }
    }

    return _db.transaction(() async {
      int supplierId;
      if (id == null) {
        final supCode = code?.trim().isNotEmpty == true
            ? code!.trim()
            : 'SUP-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

        final effectiveOpeningBalance = openingBalance != 0.0 ? openingBalance : balance;

        await _db.customStatement('''
          INSERT INTO suppliers (
            name, phone, workspace_id, gstin, address, balance,
            code, contact_person, email, state, payment_terms, is_active, opening_balance, notes
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          name.trim(),
          phone?.trim(),
          workspaceId,
          gstin?.trim().toUpperCase(),
          address?.trim(),
          effectiveOpeningBalance,
          supCode,
          contactPerson?.trim(),
          email?.trim(),
          state,
          paymentTerms,
          isActive ? 1 : 0,
          effectiveOpeningBalance,
          notes?.trim(),
        ]);

        final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
        supplierId = lastIdRow.data['id'] as int;

        // Post opening balance into double-entry ledger
        if (effectiveOpeningBalance != 0.0) {
          final now = DateTime.now();
          if (effectiveOpeningBalance > 0) {
            // Credit Supplier Payable, Debit Opening Balance Equity
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: effectiveOpeningBalance,
                  credit: 0.0,
                  narration: 'Offsetting opening balance debit to Capital/Equity',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'supplier',
                  referenceId: supplierId,
                  partyType: 'supplier',
                  partyId: supplierId,
                  debit: 0.0,
                  credit: effectiveOpeningBalance,
                  narration: 'Opening balance payable for supplier $name',
                  createdAt: now,
                ),
              ],
            );
          } else {
            // Advance paid to supplier
            final absBal = effectiveOpeningBalance.abs();
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'supplier',
                  referenceId: supplierId,
                  partyType: 'supplier',
                  partyId: supplierId,
                  debit: absBal,
                  credit: 0.0,
                  narration: 'Opening advance paid to supplier $name',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: 0.0,
                  credit: absBal,
                  narration: 'Offsetting opening balance credit to Capital/Equity',
                  createdAt: now,
                ),
              ],
            );
          }
        }
      } else {
        supplierId = id;
        await _db.customStatement('''
          UPDATE suppliers
          SET name = ?, phone = ?, gstin = ?, address = ?,
              code = COALESCE(?, code), contact_person = ?, email = ?,
              state = ?, payment_terms = ?, is_active = ?, notes = ?
          WHERE id = ? AND workspace_id = ?
        ''', [
          name.trim(),
          phone?.trim(),
          gstin?.trim().toUpperCase(),
          address?.trim(),
          code?.trim(),
          contactPerson?.trim(),
          email?.trim(),
          state,
          paymentTerms,
          isActive ? 1 : 0,
          notes?.trim(),
          id,
          workspaceId,
        ]);
      }
      return supplierId;
    });
  }

  @override
  Future<Map<String, dynamic>> getCustomerProfile(int customerId, {int workspaceId = 1}) async {
    final customer = await getCustomerById(customerId);
    if (customer == null) throw AppException('Customer #$customerId not found');

    // Sales invoices
    final salesRows = await _db.customSelect('''
      SELECT id, invoice_no, total, tax_total, discount_total, payment_method, status, created_at
      FROM sales
      WHERE customer_id = ? AND workspace_id = ?
      ORDER BY id DESC
    ''', readsFrom: {}, variables: [Variable.withInt(customerId), Variable.withInt(workspaceId)]).get();

    // Payments received
    final paymentRows = await _db.customSelect('''
      SELECT p.*, a.name as account_name
      FROM payments p
      LEFT JOIN accounts a ON a.id = p.account_id
      WHERE p.reference_type = 'customer' AND p.reference_id = ? AND p.workspace_id = ?
      ORDER BY p.id DESC
    ''', readsFrom: {}, variables: [Variable.withInt(customerId), Variable.withInt(workspaceId)]).get();

    // Ledger statement
    final statement = await _ledgerRepository.getCustomerStatement(customerId, workspaceId: workspaceId);

    double totalSales = 0.0;
    for (final s in salesRows) {
      totalSales += (s.data['total'] as num? ?? 0.0).toDouble();
    }

    double totalCollected = 0.0;
    for (final p in paymentRows) {
      totalCollected += (p.data['amount'] as num? ?? 0.0).toDouble();
    }

    final salesList = salesRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    return {
      'customer': customer,
      'total_sales': totalSales,
      'total_purchases': totalSales,
      'total_collected': totalCollected,
      'outstanding_balance': customer.balance,
      'sales': salesList,
      'recent_sales': salesList,
      'payments': paymentRows.map((r) => Map<String, dynamic>.from(r.data)).toList(),
      'statement': statement,
    };
  }

  @override
  Future<Map<String, dynamic>> getSupplierProfile(int supplierId, {int workspaceId = 1}) async {
    final supplier = await getSupplierById(supplierId);
    if (supplier == null) throw AppException('Supplier #$supplierId not found');

    // Purchases
    final purchaseRows = await _db.customSelect('''
      SELECT id, invoice_number, total_amount, paid_amount, status, invoice_date, is_cancelled
      FROM purchase_invoices
      WHERE supplier_id = ? AND workspace_id = ?
      ORDER BY id DESC
    ''', readsFrom: {}, variables: [Variable.withInt(supplierId), Variable.withInt(workspaceId)]).get();

    // Payments to supplier
    final paymentRows = await _db.customSelect('''
      SELECT p.*, a.name as account_name
      FROM payments p
      LEFT JOIN accounts a ON a.id = p.account_id
      WHERE (p.reference_type = 'supplier' AND p.reference_id = ?)
         OR (p.payment_type = 'supplier_payment' AND p.reference_id IN (
              SELECT id FROM purchase_invoices WHERE supplier_id = ?
            ))
      ORDER BY p.id DESC
    ''', readsFrom: {}, variables: [Variable.withInt(supplierId), Variable.withInt(supplierId)]).get();

    // Returns
    final returnRows = await _db.customSelect('''
      SELECT pr.* FROM purchase_returns pr
      WHERE pr.supplier_id = ? AND pr.workspace_id = ?
      ORDER BY pr.id DESC
    ''', readsFrom: {}, variables: [Variable.withInt(supplierId), Variable.withInt(workspaceId)]).get();

    // Statement
    final statement = await _ledgerRepository.getSupplierStatement(supplierId, workspaceId: workspaceId);

    double totalPurchases = 0.0;
    double totalPaid = 0.0;
    for (final p in purchaseRows) {
      if ((p.data['is_cancelled'] as int? ?? 0) == 0) {
        totalPurchases += (p.data['total_amount'] as num? ?? 0.0).toDouble();
        totalPaid += (p.data['paid_amount'] as num? ?? 0.0).toDouble();
      }
    }

    final purchaseList = purchaseRows.map((r) => Map<String, dynamic>.from(r.data)).toList();

    return {
      'supplier': supplier,
      'total_purchases': totalPurchases,
      'total_paid': totalPaid,
      'outstanding_payable': supplier.balance,
      'purchases': purchaseList,
      'invoices': purchaseList,
      'payments': paymentRows.map((r) => Map<String, dynamic>.from(r.data)).toList(),
      'returns': returnRows.map((r) => Map<String, dynamic>.from(r.data)).toList(),
      'statement': statement,
    };
  }

  @override
  Future<void> recordCustomerCollection({
    int workspaceId = 1,
    required int customerId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? invoiceAllocations,
  }) async {
    if (amount <= 0) {
      throw AppException('Collection amount must be greater than zero');
    }

    final customer = await getCustomerById(customerId);
    if (customer == null) throw AppException('Customer not found');

    final now = paymentDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      // 1. Record receipt in payments table
      await _db.customStatement('''
        INSERT INTO payments (
          workspace_id, payment_type, reference_type, reference_id,
          account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
        ) VALUES (?, 'customer_receipt', 'customer', ?, ?, ?, 'standard', ?, ?, ?, ?)
      ''', [
        workspaceId,
        customerId,
        accountId,
        amount,
        referenceNo,
        narration ?? 'Collection from customer ${customer.name}',
        nowSeconds,
        nowSeconds,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final paymentId = lastIdRow.data['id'] as int;

      // 2. Process invoice-wise allocations if specified
      if (invoiceAllocations != null && invoiceAllocations.isNotEmpty) {
        for (final alloc in invoiceAllocations) {
          final invId = (alloc['invoice_id'] ?? alloc['sale_id']) as int;
          final allocAmt = (alloc['amount'] as num).toDouble();
          if (allocAmt > 0) {
            await _db.customStatement('''
              INSERT INTO party_payment_allocations (
                workspace_id, payment_id, party_type, party_id, invoice_type, invoice_id, allocated_amount, created_at
              ) VALUES (?, ?, 'customer', ?, 'sale', ?, ?, ?)
            ''', [workspaceId, paymentId, customerId, invId, allocAmt, nowSeconds]);
          }
        }
      }

      // 3. Post double-entry ledger entries:
      // Debit: Account Asset (cash/bank increases)
      // Credit: Customer Receivable (customer balance decreases)
      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'payment_in',
            referenceType: 'payment',
            referenceId: paymentId,
            accountId: accountId,
            debit: amount,
            credit: 0.0,
            narration: narration ?? 'Collection from customer ${customer.name}',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'payment_in',
            referenceType: 'customer',
            referenceId: customerId,
            partyType: 'customer',
            partyId: customerId,
            debit: 0.0,
            credit: amount,
            narration: 'Receipt credited to customer ${customer.name}',
            createdAt: now,
          ),
        ],
      );
    });
  }

  @override
  Future<void> recordSupplierPayout({
    int workspaceId = 1,
    required int supplierId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? invoiceAllocations,
  }) async {
    if (amount <= 0) {
      throw AppException('Payout amount must be greater than zero');
    }

    final supplier = await getSupplierById(supplierId);
    if (supplier == null) throw AppException('Supplier not found');

    final now = paymentDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      // 1. Record payment in payments table
      await _db.customStatement('''
        INSERT INTO payments (
          workspace_id, payment_type, reference_type, reference_id,
          account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
        ) VALUES (?, 'supplier_payment', 'supplier', ?, ?, ?, 'standard', ?, ?, ?, ?)
      ''', [
        workspaceId,
        supplierId,
        accountId,
        amount,
        referenceNo,
        narration ?? 'Disbursement to supplier ${supplier.name}',
        nowSeconds,
        nowSeconds,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final paymentId = lastIdRow.data['id'] as int;

      // 2. Invoice-wise allocations
      if (invoiceAllocations != null && invoiceAllocations.isNotEmpty) {
        for (final alloc in invoiceAllocations) {
          final billId = (alloc['invoice_id'] ?? alloc['purchase_invoice_id']) as int;
          final allocAmt = (alloc['amount'] as num).toDouble();
          if (allocAmt > 0) {
            await _db.customStatement('''
              INSERT INTO party_payment_allocations (
                workspace_id, payment_id, party_type, party_id, invoice_type, invoice_id, allocated_amount, created_at
              ) VALUES (?, ?, 'supplier', ?, 'purchase_invoice', ?, ?, ?)
            ''', [workspaceId, paymentId, supplierId, billId, allocAmt, nowSeconds]);

            // Also update paid_amount in purchase_invoices
            await _db.customStatement('''
              UPDATE purchase_invoices
              SET paid_amount = paid_amount + ?,
                  status = CASE WHEN paid_amount + ? >= total_amount THEN 'paid' ELSE 'partial' END
              WHERE id = ?
            ''', [allocAmt, allocAmt, billId]);
          }
        }
      }

      // 3. Post double-entry ledger entries:
      // Debit: Supplier Payable (reduces liability to supplier)
      // Credit: Account Asset (cash/bank reduces)
      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'payment_out',
            referenceType: 'supplier',
            referenceId: supplierId,
            partyType: 'supplier',
            partyId: supplierId,
            debit: amount,
            credit: 0.0,
            narration: narration ?? 'Disbursement to supplier ${supplier.name}',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'payment_out',
            referenceType: 'payment',
            referenceId: paymentId,
            accountId: accountId,
            debit: 0.0,
            credit: amount,
            narration: 'Payment out from Account #$accountId to ${supplier.name}',
            createdAt: now,
          ),
        ],
      );
    });
  }

  @override
  Future<void> adjustPartyOpeningBalance({
    int workspaceId = 1,
    required String partyType,
    required int partyId,
    required double newOpeningBalance,
    required String reason,
  }) async {
    final now = DateTime.now();

    await _db.transaction(() async {
      double currentOpBal = 0.0;
      if (partyType == 'customer') {
        final cust = await getCustomerById(partyId);
        if (cust == null) throw AppException('Customer not found');
        currentOpBal = cust.openingBalance;

        final delta = newOpeningBalance - currentOpBal;
        if (delta != 0.0) {
          // Adjust ledger with auditable adjustment entry
          if (delta > 0) {
            // Additional debit to customer receivable
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'customer',
                  referenceId: partyId,
                  partyType: 'customer',
                  partyId: partyId,
                  debit: delta,
                  credit: 0.0,
                  narration: 'Opening balance correction: $reason',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: 0.0,
                  credit: delta,
                  narration: 'Offsetting opening balance equity adjustment for Customer #$partyId',
                  createdAt: now,
                ),
              ],
            );
          } else {
            final absDelta = delta.abs();
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: absDelta,
                  credit: 0.0,
                  narration: 'Offsetting opening balance equity adjustment for Customer #$partyId',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'customer',
                  referenceId: partyId,
                  partyType: 'customer',
                  partyId: partyId,
                  debit: 0.0,
                  credit: absDelta,
                  narration: 'Opening balance downward correction: $reason',
                  createdAt: now,
                ),
              ],
            );
          }
        }

        await _db.customStatement('UPDATE customers SET opening_balance = ? WHERE id = ?', [newOpeningBalance, partyId]);
      } else {
        final sup = await getSupplierById(partyId);
        if (sup == null) throw AppException('Supplier not found');
        currentOpBal = sup.openingBalance;

        final delta = newOpeningBalance - currentOpBal;
        if (delta != 0.0) {
          if (delta > 0) {
            // Additional credit to supplier payable
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: delta,
                  credit: 0.0,
                  narration: 'Offsetting opening balance equity adjustment for Supplier #$partyId',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'supplier',
                  referenceId: partyId,
                  partyType: 'supplier',
                  partyId: partyId,
                  debit: 0.0,
                  credit: delta,
                  narration: 'Opening balance correction: $reason',
                  createdAt: now,
                ),
              ],
            );
          } else {
            final absDelta = delta.abs();
            await _ledgerRepository.postTransaction(
              workspaceId: workspaceId,
              entries: [
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'supplier',
                  referenceId: partyId,
                  partyType: 'supplier',
                  partyId: partyId,
                  debit: absDelta,
                  credit: 0.0,
                  narration: 'Opening balance downward correction: $reason',
                  createdAt: now,
                ),
                LedgerPostingItem(
                  transactionType: 'opening_balance_adj',
                  referenceType: 'equity',
                  referenceId: 0,
                  debit: 0.0,
                  credit: absDelta,
                  narration: 'Offsetting opening balance equity adjustment for Supplier #$partyId',
                  createdAt: now,
                ),
              ],
            );
          }
        }

        await _db.customStatement('UPDATE suppliers SET opening_balance = ? WHERE id = ?', [newOpeningBalance, partyId]);
      }
    });
  }
}
