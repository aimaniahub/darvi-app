import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/repositories/repositories.dart';

class LocalExpenseRepository implements ExpenseRepository {
  LocalExpenseRepository(this._db, this._ledgerRepository);

  final AppDatabase _db;
  final LedgerRepository _ledgerRepository;

  @override
  Future<List<ExpenseModel>> getExpenses({
    int workspaceId = 1,
    DateTime? from,
    DateTime? to,
    String? category,
    String? search,
  }) async {
    final conditions = ['workspace_id = ?'];
    final variables = <Variable>[Variable.withInt(workspaceId)];

    if (category != null && category.isNotEmpty && category.toUpperCase() != 'ALL') {
      conditions.add('category = ?');
      variables.add(Variable.withString(category));
    }

    if (from != null) {
      final fromSecs = from.millisecondsSinceEpoch ~/ 1000;
      conditions.add('expense_date >= ?');
      variables.add(Variable.withInt(fromSecs));
    }

    if (to != null) {
      final toSecs = to.millisecondsSinceEpoch ~/ 1000;
      conditions.add('expense_date <= ?');
      variables.add(Variable.withInt(toSecs));
    }

    final query = '''
      SELECT id, workspace_id, account_id, category, amount, expense_date, reference_no, notes,
             vendor_payee, tax_amount, is_cancelled, attachment_url
      FROM expenses
      WHERE ${conditions.join(' AND ')}
      ORDER BY expense_date DESC, id DESC
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();

    var list = rows.map((r) {
      final rawDate = r.data['expense_date'];
      DateTime dt = DateTime.now();
      if (rawDate is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(rawDate * 1000);
      } else if (rawDate is String) {
        dt = DateTime.tryParse(rawDate) ?? DateTime.now();
      }

      return ExpenseModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        accountId: r.data['account_id'] as int? ?? 1,
        category: r.data['category'] as String? ?? 'General',
        amount: (r.data['amount'] as num? ?? 0.0).toDouble(),
        expenseDate: dt,
        referenceNo: r.data['reference_no'] as String?,
        notes: r.data['notes'] as String?,
        vendorPayee: r.data['vendor_payee'] as String?,
        taxAmount: (r.data['tax_amount'] as num? ?? 0.0).toDouble(),
        isCancelled: (r.data['is_cancelled'] as int? ?? 0) == 1,
        attachmentUrl: r.data['attachment_url'] as String?,
      );
    }).toList();

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((e) {
        final cat = e.category.toLowerCase();
        final ref = (e.referenceNo ?? '').toLowerCase();
        final n = (e.notes ?? '').toLowerCase();
        final vp = (e.vendorPayee ?? '').toLowerCase();
        return cat.contains(q) || ref.contains(q) || n.contains(q) || vp.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Future<int> addExpense({
    int workspaceId = 1,
    required int accountId,
    required String category,
    required double amount,
    DateTime? expenseDate,
    String? referenceNo,
    String? notes,
    String? vendorPayee,
    double taxAmount = 0.0,
    String? attachmentUrl,
  }) async {
    if (amount <= 0) {
      throw AppException('Expense amount must be greater than zero');
    }

    final now = expenseDate ?? DateTime.now();
    final timeSeconds = now.millisecondsSinceEpoch ~/ 1000;

    return _db.transaction(() async {
      await _db.customStatement('''
        INSERT INTO expenses (
          workspace_id, account_id, category, amount, expense_date, reference_no, notes, created_at,
          vendor_payee, tax_amount, is_cancelled, attachment_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
      ''', [
        workspaceId,
        accountId,
        category.trim(),
        amount,
        timeSeconds,
        referenceNo?.trim(),
        notes?.trim(),
        timeSeconds,
        vendorPayee?.trim(),
        taxAmount,
        attachmentUrl,
      ]);

      final lastIdRow = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      final expenseId = lastIdRow.data['id'] as int;

      // Post double-entry financial ledger transaction
      // Proper accounting classification:
      // If input tax exists and is recoverable:
      // Debit: Operating Expense = amount - taxAmount
      // Debit: Tax Input Receivable = taxAmount
      // Credit: Account Asset = amount
      final List<LedgerPostingItem> ledgerEntries = [];
      final netExpenseAmount = (amount - taxAmount) > 0 ? (amount - taxAmount) : amount;

      if (taxAmount > 0 && taxAmount < amount) {
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'expense',
            referenceType: 'expense',
            referenceId: expenseId,
            debit: netExpenseAmount,
            credit: 0.0,
            narration: 'Expense ($category): ${notes ?? "Store expense"}',
            createdAt: now,
          ),
        );
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'expense',
            referenceType: 'tax_input',
            referenceId: expenseId,
            debit: taxAmount,
            credit: 0.0,
            narration: 'Recoverable Input GST for $category',
            createdAt: now,
          ),
        );
      } else {
        ledgerEntries.add(
          LedgerPostingItem(
            transactionType: 'expense',
            referenceType: 'expense',
            referenceId: expenseId,
            debit: amount,
            credit: 0.0,
            narration: 'Expense ($category): ${notes ?? "Store expense"}',
            createdAt: now,
          ),
        );
      }

      ledgerEntries.add(
        LedgerPostingItem(
          transactionType: 'expense',
          referenceType: 'account',
          referenceId: accountId,
          accountId: accountId,
          debit: 0.0,
          credit: amount,
          narration: 'Disbursement from account #$accountId for $category',
          createdAt: now,
        ),
      );

      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: ledgerEntries,
      );

      return expenseId;
    });
  }

  @override
  Future<void> updateExpense({
    required int id,
    int workspaceId = 1,
    required int accountId,
    required String category,
    required double amount,
    DateTime? expenseDate,
    String? referenceNo,
    String? notes,
    String? vendorPayee,
    double taxAmount = 0.0,
  }) async {
    final rows = await _db.customSelect(
      'SELECT * FROM expenses WHERE id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) throw AppException('Expense #$id not found');

    final oldExpense = rows.first.data;
    if ((oldExpense['is_cancelled'] as int? ?? 0) == 1) {
      throw AppException('Cannot edit a cancelled expense');
    }

    final oldAmount = (oldExpense['amount'] as num? ?? 0.0).toDouble();
    final oldAccountId = oldExpense['account_id'] as int? ?? accountId;
    final now = expenseDate ?? DateTime.now();
    final timeSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      // 1. Post reversal for old expense
      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'expense_reverse',
            referenceType: 'account',
            referenceId: oldAccountId,
            accountId: oldAccountId,
            debit: oldAmount,
            credit: 0.0,
            narration: 'Reversal of expense #$id for update',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'expense_reverse',
            referenceType: 'expense',
            referenceId: id,
            debit: 0.0,
            credit: oldAmount,
            narration: 'Reversal credit for edited expense #$id',
            createdAt: now,
          ),
        ],
      );

      // 2. Update expense row
      await _db.customStatement('''
        UPDATE expenses
        SET account_id = ?, category = ?, amount = ?, expense_date = ?,
            reference_no = ?, notes = ?, vendor_payee = ?, tax_amount = ?
        WHERE id = ? AND workspace_id = ?
      ''', [
        accountId,
        category.trim(),
        amount,
        timeSeconds,
        referenceNo?.trim(),
        notes?.trim(),
        vendorPayee?.trim(),
        taxAmount,
        id,
        workspaceId,
      ]);

      // 3. Post new balanced ledger entries
      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'expense',
            referenceType: 'expense',
            referenceId: id,
            debit: amount,
            credit: 0.0,
            narration: 'Updated expense ($category): ${notes ?? ""}',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'expense',
            referenceType: 'account',
            referenceId: accountId,
            accountId: accountId,
            debit: 0.0,
            credit: amount,
            narration: 'Disbursement from account #$accountId for updated expense #$id',
            createdAt: now,
          ),
        ],
      );
    });
  }

  @override
  Future<void> deleteExpense(int id) async {
    await cancelExpense(id, reason: 'Deleted by user');
  }

  @override
  Future<void> cancelExpense(int id, {String? reason}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM expenses WHERE id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) throw AppException('Expense #$id not found');

    final exp = rows.first.data;
    if ((exp['is_cancelled'] as int? ?? 0) == 1) {
      throw AppException('Expense is already cancelled');
    }

    final amount = (exp['amount'] as num? ?? 0.0).toDouble();
    final accountId = exp['account_id'] as int;
    final workspaceId = exp['workspace_id'] as int? ?? 1;
    final now = DateTime.now();

    await _db.transaction(() async {
      // Reversal: Debit Account (money returns), Credit Expense
      await _ledgerRepository.postTransaction(
        workspaceId: workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'expense_cancel',
            referenceType: 'account',
            referenceId: accountId,
            accountId: accountId,
            debit: amount,
            credit: 0.0,
            narration: 'Refund to account on expense #$id cancellation',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'expense_cancel',
            referenceType: 'expense',
            referenceId: id,
            debit: 0.0,
            credit: amount,
            narration: 'Expense reduction on cancellation #$id: ${reason ?? ""}',
            createdAt: now,
          ),
        ],
      );

      await _db.customStatement('''
        UPDATE expenses
        SET is_cancelled = 1, notes = COALESCE(notes, '') || ' [Cancelled: ' || ? || ']'
        WHERE id = ?
      ''', [reason ?? 'Cancelled', id]);
    });
  }
}
