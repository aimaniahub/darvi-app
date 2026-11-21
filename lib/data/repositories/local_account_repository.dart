import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/repositories/repositories.dart';

class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(this._db, this._ledgerRepository);

  final AppDatabase _db;
  final LedgerRepository _ledgerRepository;

  @override
  Future<List<AccountModel>> getAccounts({int workspaceId = 1, bool activeOnly = true}) async {
    final activeClause = activeOnly ? 'AND is_active = 1' : '';
    final rows = await _db.customSelect('''
      SELECT id, workspace_id, name, type, account_number, is_default, is_active,
             bank_name, ifsc, upi_id
      FROM accounts
      WHERE workspace_id = ? $activeClause
      ORDER BY is_default DESC, id ASC
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    final List<AccountModel> accounts = [];
    for (final row in rows) {
      final accountId = row.data['id'] as int;
      final balance = await _ledgerRepository.getAccountBalance(accountId, workspaceId: workspaceId);
      accounts.add(
        AccountModel(
          id: accountId,
          workspaceId: row.data['workspace_id'] as int? ?? 1,
          name: row.data['name'] as String? ?? '',
          type: row.data['type'] as String? ?? 'cash',
          accountNumber: row.data['account_number'] as String?,
          balance: balance,
          isDefault: (row.data['is_default'] as int? ?? 0) == 1,
          bankName: row.data['bank_name'] as String?,
          ifsc: row.data['ifsc'] as String?,
          upiId: row.data['upi_id'] as String?,
          isActive: (row.data['is_active'] as int? ?? 1) == 1,
        ),
      );
    }
    return accounts;
  }

  @override
  Future<AccountModel?> getDefaultAccount({int workspaceId = 1}) async {
    final accounts = await getAccounts(workspaceId: workspaceId);
    if (accounts.isEmpty) return null;
    return accounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => accounts.first,
    );
  }

  @override
  Future<int> createAccount({
    int workspaceId = 1,
    required String name,
    required String type,
    String? accountNumber,
    double initialBalance = 0,
    bool isDefault = false,
    String? bankName,
    String? ifsc,
    String? upiId,
  }) async {
    if (name.trim().isEmpty) throw AppException('Account name cannot be empty');

    return _db.transaction(() async {
      if (isDefault) {
        await _db.customStatement('''
          UPDATE accounts SET is_default = 0 WHERE workspace_id = ?
        ''', [workspaceId]);
      }

      await _db.customStatement('''
        INSERT INTO accounts (
          workspace_id, name, type, account_number, is_default, is_active,
          bank_name, ifsc, upi_id
        ) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)
      ''', [
        workspaceId,
        name.trim(),
        type.toLowerCase().trim(),
        accountNumber?.trim(),
        isDefault ? 1 : 0,
        bankName?.trim(),
        ifsc?.trim().toUpperCase(),
        upiId?.trim(),
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final accountId = lastIdRow.data['id'] as int;

      if (initialBalance != 0.0) {
        final now = DateTime.now();
        if (initialBalance > 0) {
          // Debit Asset Account, Credit Capital/Equity opening balance
          await _ledgerRepository.postTransaction(
            workspaceId: workspaceId,
            entries: [
              LedgerPostingItem(
                transactionType: 'opening_balance',
                referenceType: 'account',
                referenceId: accountId,
                accountId: accountId,
                debit: initialBalance,
                credit: 0.0,
                narration: 'Account opening balance for $name',
                createdAt: now,
              ),
              LedgerPostingItem(
                transactionType: 'opening_balance',
                referenceType: 'equity',
                referenceId: 0,
                debit: 0.0,
                credit: initialBalance,
                narration: 'Offsetting opening balance credit to Capital/Equity',
                createdAt: now,
              ),
            ],
          );
        } else {
          final absBal = initialBalance.abs();
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
                referenceType: 'account',
                referenceId: accountId,
                accountId: accountId,
                debit: 0.0,
                credit: absBal,
                narration: 'Negative initial balance for $name',
                createdAt: now,
              ),
            ],
          );
        }
      }

      return accountId;
    });
  }

  @override
  Future<void> updateAccount({
    required int id,
    int workspaceId = 1,
    required String name,
    required String type,
    String? accountNumber,
    bool? isDefault,
    String? bankName,
    String? ifsc,
    String? upiId,
    bool? isActive,
  }) async {
    await _db.transaction(() async {
      if (isDefault == true) {
        await _db.customStatement('UPDATE accounts SET is_default = 0 WHERE workspace_id = ?', [workspaceId]);
      }

      await _db.customStatement('''
        UPDATE accounts
        SET name = ?, type = ?, account_number = ?,
            is_default = COALESCE(?, is_default),
            bank_name = ?, ifsc = ?, upi_id = ?,
            is_active = COALESCE(?, is_active)
        WHERE id = ? AND workspace_id = ?
      ''', [
        name.trim(),
        type.toLowerCase().trim(),
        accountNumber?.trim(),
        isDefault != null ? (isDefault ? 1 : 0) : null,
        bankName?.trim(),
        ifsc?.trim().toUpperCase(),
        upiId?.trim(),
        isActive != null ? (isActive ? 1 : 0) : null,
        id,
        workspaceId,
      ]);
    });
  }

  @override
  Future<void> deactivateAccount(int id) async {
    final balance = await _ledgerRepository.getAccountBalance(id);
    if (balance.abs() > 0.01) {
      throw AppException(
        'Cannot deactivate account with non-zero balance (Current: ₹${balance.toStringAsFixed(2)}). Please transfer remaining funds first.',
      );
    }
    await _db.customStatement('UPDATE accounts SET is_active = 0, is_default = 0 WHERE id = ?', [id]);
  }

  @override
  Future<void> transferFunds({
    int workspaceId = 1,
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? transferDate,
  }) async {
    if (fromAccountId == toAccountId) {
      throw AppException('Source and destination accounts must be different');
    }
    if (amount <= 0) {
      throw AppException('Transfer amount must be greater than zero');
    }

    final fromBalance = await _ledgerRepository.getAccountBalance(fromAccountId, workspaceId: workspaceId);
    if (amount > fromBalance + 0.01) {
      throw AppException('Insufficient balance in source account (Available: ₹${fromBalance.toStringAsFixed(2)})');
    }

    final now = transferDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      // 1. Record transfer transaction in payments
      final transferRef = referenceNo ?? 'TRF-${now.millisecondsSinceEpoch % 100000}';

      await _db.customStatement('''
        INSERT INTO payments (
          workspace_id, payment_type, reference_type, reference_id,
          account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
        ) VALUES (?, 'transfer', 'account', ?, ?, ?, 'transfer', ?, ?, ?, ?)
      ''', [
        workspaceId,
        toAccountId,
        fromAccountId,
        amount,
        transferRef,
        narration ?? 'Inter-account transfer from #$fromAccountId to #$toAccountId',
        nowSeconds,
        nowSeconds,
      ]);

      // 2. Post balanced double-entry ledger entries:
      // Debit: Destination Account (Asset +)
      // Credit: Source Account (Asset -)
      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'transfer',
            referenceType: 'account',
            referenceId: toAccountId,
            accountId: toAccountId,
            debit: amount,
            credit: 0.0,
            narration: narration ?? 'Transfer in from account #$fromAccountId (Ref: $transferRef)',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'transfer',
            referenceType: 'account',
            referenceId: fromAccountId,
            accountId: fromAccountId,
            debit: 0.0,
            credit: amount,
            narration: narration ?? 'Transfer out to account #$toAccountId (Ref: $transferRef)',
            createdAt: now,
          ),
        ],
      );
    });
  }

  @override
  Future<void> recordPayment({
    int workspaceId = 1,
    required String paymentType, // 'customer_receipt' or 'supplier_payment'
    int? customerId,
    int? supplierId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
  }) async {
    if (amount <= 0) {
      throw AppException('Payment amount must be greater than zero');
    }

    final now = paymentDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      // 1. Record in payments table
      await _db.customStatement('''
        INSERT INTO payments (
          workspace_id, payment_type, reference_type, reference_id,
          account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        workspaceId,
        paymentType,
        customerId != null ? 'customer' : (supplierId != null ? 'supplier' : 'other'),
        customerId ?? supplierId ?? 0,
        accountId,
        amount,
        'standard',
        referenceNo,
        narration,
        nowSeconds,
        nowSeconds,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final paymentId = lastIdRow.data['id'] as int;

      // 2. Post balanced double-entry ledger entries
      if (paymentType == 'customer_receipt' && customerId != null) {
        // Debit Asset (Account), Credit Asset Receivable (Customer)
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
              narration: narration ?? 'Received payment from Customer #$customerId',
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
              narration: narration ?? 'Payment receipt applied to Customer #$customerId',
              createdAt: now,
            ),
          ],
        );
      } else if (paymentType == 'supplier_payment' && supplierId != null) {
        // Debit Liability Payable (Supplier), Credit Asset (Account)
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
              narration: narration ?? 'Paid supplier #$supplierId',
              createdAt: now,
            ),
            LedgerPostingItem(
              transactionType: 'payment_out',
              referenceType: 'payment',
              referenceId: paymentId,
              accountId: accountId,
              debit: 0.0,
              credit: amount,
              narration: narration ?? 'Payment disbursement to Supplier #$supplierId',
              createdAt: now,
            ),
          ],
        );
      } else {
        throw AppException('Invalid payment parameters: party must be specified');
      }
    });
  }

  @override
  Future<void> recordMoneyReceived({
    int workspaceId = 1,
    required int accountId,
    required double amount,
    required String category, // 'customer_receipt', 'advance', 'other_income', etc.
    int? customerId,
    String? referenceNo,
    String? description,
    DateTime? receiptDate,
  }) async {
    if (amount <= 0) throw AppException('Receipt amount must be greater than zero');

    final now = receiptDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      await _db.customStatement('''
        INSERT INTO payments (
          workspace_id, payment_type, reference_type, reference_id,
          account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
        ) VALUES (?, 'receipt', ?, ?, ?, ?, 'standard', ?, ?, ?, ?)
      ''', [
        workspaceId,
        customerId != null ? 'customer' : 'other_income',
        customerId ?? 0,
        accountId,
        amount,
        referenceNo,
        description ?? 'Direct receipt: $category',
        nowSeconds,
        nowSeconds,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final paymentId = lastIdRow.data['id'] as int;

      if (customerId != null) {
        // Customer receipt: Debit Account, Credit Customer
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
              narration: description ?? 'Customer receipt (Ref: $referenceNo)',
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
              narration: description ?? 'Receipt payment applied',
              createdAt: now,
            ),
          ],
        );
      } else {
        // Other business income: Debit Account, Credit Revenue
        await _ledgerRepository.postTransaction(
          workspaceId: workspaceId,
          entries: [
            LedgerPostingItem(
              transactionType: 'other_receipt',
              referenceType: 'account',
              referenceId: accountId,
              accountId: accountId,
              debit: amount,
              credit: 0.0,
              narration: description ?? 'Other receipt: $category',
              createdAt: now,
            ),
            LedgerPostingItem(
              transactionType: 'other_receipt',
              referenceType: 'revenue',
              referenceId: 0,
              debit: 0.0,
              credit: amount,
              narration: description ?? 'Other business income: $category',
              createdAt: now,
            ),
          ],
        );
      }
    });
  }

  @override
  Future<void> recordMoneyPaid({
    int workspaceId = 1,
    required int accountId,
    required double amount,
    required String category, // 'supplier_payment', 'salary', 'incentive', 'expense', 'other'
    int? supplierId,
    int? employeeId,
    String? referenceNo,
    String? description,
    DateTime? paymentDate,
  }) async {
    if (amount <= 0) throw AppException('Payment amount must be greater than zero');

    final now = paymentDate ?? DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      await _db.customStatement('''
        INSERT INTO payments (
          workspace_id, payment_type, reference_type, reference_id,
          account_id, amount, payment_mode, reference_no, narration, created_at, payment_date
        ) VALUES (?, 'payout', ?, ?, ?, ?, 'standard', ?, ?, ?, ?)
      ''', [
        workspaceId,
        supplierId != null ? 'supplier' : (employeeId != null ? 'employee' : 'other_expense'),
        supplierId ?? employeeId ?? 0,
        accountId,
        amount,
        referenceNo,
        description ?? 'Direct payout: $category',
        nowSeconds,
        nowSeconds,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final paymentId = lastIdRow.data['id'] as int;

      if (supplierId != null) {
        // Supplier payout: Debit Supplier, Credit Account
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
              narration: description ?? 'Supplier payout (Ref: $referenceNo)',
              createdAt: now,
            ),
            LedgerPostingItem(
              transactionType: 'payment_out',
              referenceType: 'payment',
              referenceId: paymentId,
              accountId: accountId,
              debit: 0.0,
              credit: amount,
              narration: description ?? 'Disbursement from account #$accountId',
              createdAt: now,
            ),
          ],
        );
      } else if (employeeId != null) {
        // Payroll / Incentive payout: Debit Salary Liability, Credit Account
        await _ledgerRepository.postTransaction(
          workspaceId: workspaceId,
          entries: [
            LedgerPostingItem(
              transactionType: 'salary_payout',
              referenceType: 'salary',
              referenceId: employeeId,
              partyType: 'employee',
              partyId: employeeId,
              debit: amount,
              credit: 0.0,
              narration: description ?? 'Salary payout for Employee #$employeeId',
              createdAt: now,
            ),
            LedgerPostingItem(
              transactionType: 'salary_payout',
              referenceType: 'account',
              referenceId: accountId,
              accountId: accountId,
              debit: 0.0,
              credit: amount,
              narration: description ?? 'Salary disbursement from account #$accountId',
              createdAt: now,
            ),
          ],
        );
      } else {
        // General business disbursement: Debit Expense, Credit Account
        await _ledgerRepository.postTransaction(
          workspaceId: workspaceId,
          entries: [
            LedgerPostingItem(
              transactionType: 'other_expense',
              referenceType: 'expense',
              referenceId: 0,
              debit: amount,
              credit: 0.0,
              narration: description ?? 'Disbursement: $category',
              createdAt: now,
            ),
            LedgerPostingItem(
              transactionType: 'other_expense',
              referenceType: 'account',
              referenceId: accountId,
              accountId: accountId,
              debit: 0.0,
              credit: amount,
              narration: description ?? 'Payment out from Account #$accountId',
              createdAt: now,
            ),
          ],
        );
      }
    });
  }

  @override
  Future<List<CashbookEntry>> getCashbookEntries({
    int workspaceId = 1,
    int? accountId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final conditions = [
      'le.workspace_id = ?',
      'le.account_id IS NOT NULL',
    ];
    final variables = <Variable>[Variable.withInt(workspaceId)];

    if (accountId != null) {
      conditions.add('le.account_id = ?');
      variables.add(Variable.withInt(accountId));
    }
    if (fromDate != null) {
      conditions.add('le.created_at >= ?');
      variables.add(Variable.withInt(fromDate.millisecondsSinceEpoch ~/ 1000));
    }
    if (toDate != null) {
      conditions.add('le.created_at <= ?');
      variables.add(Variable.withInt(toDate.millisecondsSinceEpoch ~/ 1000));
    }

    final query = '''
      SELECT le.*, a.name as account_name
      FROM ledger_entries le
      LEFT JOIN accounts a ON a.id = le.account_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY le.created_at ASC, le.id ASC
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();

    double runningBalance = 0.0;
    final List<CashbookEntry> entries = [];

    for (final r in rows) {
      final debit = (r.data['debit'] as num? ?? 0.0).toDouble();
      final credit = (r.data['credit'] as num? ?? 0.0).toDouble();
      runningBalance += (debit - credit);

      final createSecs = r.data['created_at'] as int? ?? 0;
      final txType = r.data['transaction_type'] as String? ?? '';
      String entryType = 'receipt';
      if (txType == 'transfer') {
        entryType = 'transfer';
      } else if (credit > 0) {
        entryType = 'payment';
      }

      entries.add(
        CashbookEntry(
          date: DateTime.fromMillisecondsSinceEpoch(createSecs * 1000),
          description: r.data['narration'] as String? ?? 'Account transaction',
          referenceNo: '${r.data['reference_type'] ?? ""} #${r.data['reference_id'] ?? ""}',
          accountName: r.data['account_name'] as String? ?? 'Account',
          type: entryType,
          debit: debit,
          credit: credit,
          runningBalance: (runningBalance * 100).roundToDouble() / 100,
        ),
      );
    }

    return entries;
  }

  @override
  Future<FinancialDashboardMetrics> getFinancialDashboardMetrics({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final accounts = await getAccounts(workspaceId: workspaceId);

    double cash = 0.0, bank = 0.0, upi = 0.0;
    for (final a in accounts) {
      if (a.type == 'cash') cash += a.balance;
      if (a.type == 'bank') bank += a.balance;
      if (a.type == 'upi') upi += a.balance;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayStartSecs = todayStart.millisecondsSinceEpoch ~/ 1000;
    final monthStart = DateTime(now.year, now.month, 1);
    final monthStartSecs = monthStart.millisecondsSinceEpoch ~/ 1000;

    // Today's collections
    final todayCollRows = await _db.customSelect('''
      SELECT COALESCE(SUM(amount), 0.0) as total_coll
      FROM payments
      WHERE workspace_id = ? AND payment_type IN ('customer_receipt', 'receipt')
        AND created_at >= ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId), Variable.withInt(todayStartSecs)]).get();
    final todayColl = todayCollRows.isNotEmpty ? (todayCollRows.first.data['total_coll'] as num? ?? 0.0).toDouble() : 0.0;

    // Today's payments
    final todayPayRows = await _db.customSelect('''
      SELECT COALESCE(SUM(amount), 0.0) as total_pay
      FROM payments
      WHERE workspace_id = ? AND payment_type IN ('supplier_payment', 'payout', 'expense')
        AND created_at >= ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId), Variable.withInt(todayStartSecs)]).get();
    final todayPay = todayPayRows.isNotEmpty ? (todayPayRows.first.data['total_pay'] as num? ?? 0.0).toDouble() : 0.0;

    // Monthly expenses
    final expRows = await _db.customSelect('''
      SELECT COALESCE(SUM(amount), 0.0) as total_exp
      FROM expenses
      WHERE workspace_id = ? AND is_cancelled = 0 AND expense_date >= ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId), Variable.withInt(monthStartSecs)]).get();
    final monthlyExpenses = expRows.isNotEmpty ? (expRows.first.data['total_exp'] as num? ?? 0.0).toDouble() : 0.0;

    // Total Customer Receivables
    final custRecRows = await _db.customSelect('''
      SELECT COALESCE(SUM(debit - credit), 0.0) as receivables
      FROM ledger_entries
      WHERE workspace_id = ? AND party_type = 'customer'
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final custReceivables = custRecRows.isNotEmpty ? (custRecRows.first.data['receivables'] as num? ?? 0.0).toDouble() : 0.0;

    // Total Supplier Payables
    final supPayRows = await _db.customSelect('''
      SELECT COALESCE(SUM(credit - debit), 0.0) as payables
      FROM ledger_entries
      WHERE workspace_id = ? AND party_type = 'supplier'
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final supPayables = supPayRows.isNotEmpty ? (supPayRows.first.data['payables'] as num? ?? 0.0).toDouble() : 0.0;

    // Payroll paid (from payroll records or ledger)
    final payrollRows = await _db.customSelect('''
      SELECT COALESCE(SUM(net_salary), 0.0) as payroll_paid
      FROM payroll_records
      WHERE workspace_id = ? AND status = 'paid'
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final payrollPaid = payrollRows.isNotEmpty ? (payrollRows.first.data['payroll_paid'] as num? ?? 0.0).toDouble() : 0.0;

    // Incentives paid
    final incentiveRows = await _db.customSelect('''
      SELECT COALESCE(SUM(amount), 0.0) as incentives_paid
      FROM incentive_claims
      WHERE workspace_id = ? AND status = 'paid'
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final incentivesPaid = incentiveRows.isNotEmpty ? (incentiveRows.first.data['incentives_paid'] as num? ?? 0.0).toDouble() : 0.0;

    return FinancialDashboardMetrics(
      totalCash: cash,
      totalBank: bank,
      totalUpi: upi,
      totalLiquidBalance: cash + bank + upi,
      todayCollections: todayColl,
      todayPayments: todayPay,
      monthlyExpenses: monthlyExpenses,
      customerReceivables: custReceivables > 0 ? custReceivables : 0.0,
      supplierPayables: supPayables > 0 ? supPayables : 0.0,
      payrollPaid: payrollPaid,
      incentivesPaid: incentivesPaid,
    );
  }

  @override
  Future<Map<String, dynamic>> getProfitAndLossReport({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    // 1. Total Net Sales (Revenue excluding tax)
    final salesRows = await _db.customSelect('''
      SELECT COALESCE(SUM(subtotal - discount_total), 0.0) as net_sales,
             COALESCE(SUM(tax_total), 0.0) as sales_tax,
             COALESCE(SUM(total), 0.0) as gross_sales
      FROM sales
      WHERE workspace_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final netSales = salesRows.isNotEmpty ? (salesRows.first.data['net_sales'] as num? ?? 0.0).toDouble() : 0.0;

    // 2. Cost of Goods Sold (from sale items cost snapshot)
    final cogsRows = await _db.customSelect('''
      SELECT COALESCE(SUM(si.qty * si.cost_snapshot), 0.0) as cogs
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.workspace_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final cogs = cogsRows.isNotEmpty ? (cogsRows.first.data['cogs'] as num? ?? 0.0).toDouble() : 0.0;

    final grossProfit = netSales - cogs;

    // 3. Operating Expenses grouped by category
    final expRows = await _db.customSelect('''
      SELECT category, COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE workspace_id = ? AND is_cancelled = 0
      GROUP BY category
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    double totalOperatingExpenses = 0.0;
    final List<Map<String, dynamic>> expenseBreakdown = [];
    for (final e in expRows) {
      final amt = (e.data['total'] as num? ?? 0.0).toDouble();
      totalOperatingExpenses += amt;
      expenseBreakdown.add({
        'category': e.data['category'] as String? ?? 'General',
        'amount': amt,
      });
    }

    final netProfit = grossProfit - totalOperatingExpenses;

    return {
      'revenue': netSales,
      'net_sales': netSales,
      'cogs': cogs,
      'cost_of_goods_sold': cogs,
      'gross_profit': grossProfit,
      'expenses': totalOperatingExpenses,
      'operating_expenses': totalOperatingExpenses,
      'expense_breakdown': expenseBreakdown,
      'net_profit': netProfit,
    };
  }
}
