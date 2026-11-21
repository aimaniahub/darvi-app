import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/repositories/repositories.dart';

class LocalLedgerRepository implements LedgerRepository {
  LocalLedgerRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> postTransaction({
    int workspaceId = 1,
    required List<LedgerPostingItem> entries,
  }) async {
    if (entries.isEmpty) {
      throw AppException('Ledger transaction must contain at least one entry');
    }

    // Verify double-entry balance invariant: Sum(Debits) == Sum(Credits)
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (final entry in entries) {
      totalDebit += entry.debit;
      totalCredit += entry.credit;
    }

    totalDebit = (totalDebit * 100).roundToDouble() / 100;
    totalCredit = (totalCredit * 100).roundToDouble() / 100;

    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw AppException(
        'Double-entry transaction unbalanced: Total Debit ($totalDebit) != Total Credit ($totalCredit)',
      );
    }

    final now = DateTime.now();

    await _db.transaction(() async {
      for (final entry in entries) {
        final entryTime = entry.createdAt ?? now;
        final entrySeconds = entryTime.millisecondsSinceEpoch ~/ 1000;

        await _db.customStatement('''
          INSERT INTO ledger_entries (
            workspace_id, transaction_type, reference_type, reference_id,
            party_type, party_id, account_id, debit, credit, narration, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          workspaceId,
          entry.transactionType,
          entry.referenceType,
          entry.referenceId,
          entry.partyType,
          entry.partyId,
          entry.accountId,
          entry.debit,
          entry.credit,
          entry.narration,
          entrySeconds,
        ]);
      }
    });
  }

  @override
  Future<double> getCustomerBalance(int customerId, {int workspaceId = 1}) async {
    // Customer is an Asset (Receivable)
    // Balance = Sum(Debits) - Sum(Credits)
    final rows = await _db.customSelect('''
      SELECT 
        COALESCE(SUM(debit), 0.0) as total_debit,
        COALESCE(SUM(credit), 0.0) as total_credit
      FROM ledger_entries
      WHERE workspace_id = ? AND party_type = 'customer' AND party_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId), Variable.withInt(customerId)]).get();

    if (rows.isEmpty) return 0.0;
    final row = rows.first;
    final debit = row.data['total_debit'] as num? ?? 0.0;
    final credit = row.data['total_credit'] as num? ?? 0.0;
    return ((debit - credit) * 100).roundToDouble() / 100;
  }

  @override
  Future<double> getSupplierBalance(int supplierId, {int workspaceId = 1}) async {
    // Supplier is a Liability (Payable)
    // Balance = Sum(Credits) - Sum(Debits)
    final rows = await _db.customSelect('''
      SELECT 
        COALESCE(SUM(debit), 0.0) as total_debit,
        COALESCE(SUM(credit), 0.0) as total_credit
      FROM ledger_entries
      WHERE workspace_id = ? AND party_type = 'supplier' AND party_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId), Variable.withInt(supplierId)]).get();

    if (rows.isEmpty) return 0.0;
    final row = rows.first;
    final debit = row.data['total_debit'] as num? ?? 0.0;
    final credit = row.data['total_credit'] as num? ?? 0.0;
    return ((credit - debit) * 100).roundToDouble() / 100;
  }

  @override
  Future<double> getAccountBalance(int accountId, {int workspaceId = 1}) async {
    // Cash / Bank / UPI Account is an Asset
    // Balance = Sum(Debits) - Sum(Credits)
    final rows = await _db.customSelect('''
      SELECT 
        COALESCE(SUM(debit), 0.0) as total_debit,
        COALESCE(SUM(credit), 0.0) as total_credit
      FROM ledger_entries
      WHERE workspace_id = ? AND account_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId), Variable.withInt(accountId)]).get();

    if (rows.isEmpty) return 0.0;
    final row = rows.first;
    final debit = row.data['total_debit'] as num? ?? 0.0;
    final credit = row.data['total_credit'] as num? ?? 0.0;
    return ((debit - credit) * 100).roundToDouble() / 100;
  }

  @override
  Future<List<LedgerEntryModel>> getCustomerStatement(
    int customerId, {
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final conditions = ['workspace_id = ?', "party_type = 'customer'", 'party_id = ?'];
    final variables = <Variable>[Variable.withInt(workspaceId), Variable.withInt(customerId)];

    if (fromDate != null) {
      conditions.add('created_at >= ?');
      variables.add(Variable.withInt(fromDate.millisecondsSinceEpoch ~/ 1000));
    }
    if (toDate != null) {
      conditions.add('created_at <= ?');
      variables.add(Variable.withInt(toDate.millisecondsSinceEpoch ~/ 1000));
    }

    final query = '''
      SELECT id, workspace_id, transaction_type, reference_type, reference_id,
             party_type, party_id, account_id, debit, credit, narration, created_at
      FROM ledger_entries
      WHERE ${conditions.join(' AND ')}
      ORDER BY created_at ASC, id ASC
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();
    return rows.map(_rowToModel).toList();
  }

  @override
  Future<List<LedgerEntryModel>> getSupplierStatement(
    int supplierId, {
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final conditions = ['workspace_id = ?', "party_type = 'supplier'", 'party_id = ?'];
    final variables = <Variable>[Variable.withInt(workspaceId), Variable.withInt(supplierId)];

    if (fromDate != null) {
      conditions.add('created_at >= ?');
      variables.add(Variable.withInt(fromDate.millisecondsSinceEpoch ~/ 1000));
    }
    if (toDate != null) {
      conditions.add('created_at <= ?');
      variables.add(Variable.withInt(toDate.millisecondsSinceEpoch ~/ 1000));
    }

    final query = '''
      SELECT id, workspace_id, transaction_type, reference_type, reference_id,
             party_type, party_id, account_id, debit, credit, narration, created_at
      FROM ledger_entries
      WHERE ${conditions.join(' AND ')}
      ORDER BY created_at ASC, id ASC
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();
    return rows.map(_rowToModel).toList();
  }

  @override
  Future<List<LedgerEntryModel>> getAccountStatement(
    int accountId, {
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final conditions = ['workspace_id = ?', 'account_id = ?'];
    final variables = <Variable>[Variable.withInt(workspaceId), Variable.withInt(accountId)];

    if (fromDate != null) {
      conditions.add('created_at >= ?');
      variables.add(Variable.withInt(fromDate.millisecondsSinceEpoch ~/ 1000));
    }
    if (toDate != null) {
      conditions.add('created_at <= ?');
      variables.add(Variable.withInt(toDate.millisecondsSinceEpoch ~/ 1000));
    }

    final query = '''
      SELECT id, workspace_id, transaction_type, reference_type, reference_id,
             party_type, party_id, account_id, debit, credit, narration, created_at
      FROM ledger_entries
      WHERE ${conditions.join(' AND ')}
      ORDER BY created_at ASC, id ASC
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();
    return rows.map(_rowToModel).toList();
  }

  @override
  Future<List<LedgerEntryModel>> getRecentLedgerEntries({
    int workspaceId = 1,
    int limit = 100,
    int? accountId,
    String? transactionType,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
  }) async {
    final conditions = ['workspace_id = ?'];
    final variables = <Variable>[Variable.withInt(workspaceId)];

    if (accountId != null) {
      conditions.add('account_id = ?');
      variables.add(Variable.withInt(accountId));
    }
    if (transactionType != null && transactionType.isNotEmpty && transactionType.toUpperCase() != 'ALL') {
      conditions.add('transaction_type = ?');
      variables.add(Variable.withString(transactionType));
    }
    if (fromDate != null) {
      conditions.add('created_at >= ?');
      variables.add(Variable.withInt(fromDate.millisecondsSinceEpoch ~/ 1000));
    }
    if (toDate != null) {
      conditions.add('created_at <= ?');
      variables.add(Variable.withInt(toDate.millisecondsSinceEpoch ~/ 1000));
    }

    variables.add(Variable.withInt(limit));

    final query = '''
      SELECT id, workspace_id, transaction_type, reference_type, reference_id,
             party_type, party_id, account_id, debit, credit, narration, created_at
      FROM ledger_entries
      WHERE ${conditions.join(' AND ')}
      ORDER BY id DESC
      LIMIT ?
    ''';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: variables).get();
    var list = rows.map(_rowToModel).toList();

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((e) {
        final narr = (e.narration ?? '').toLowerCase();
        final ref = '${e.referenceType} #${e.referenceId ?? ""}'.toLowerCase();
        return narr.contains(q) || ref.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Future<Map<String, dynamic>> reconcileBalances({int workspaceId = 1}) async {
    // 1. Trial balance invariant check: Total Debits == Total Credits across entire ledger
    final trialBalanceRow = await _db.customSelect('''
      SELECT COALESCE(SUM(debit), 0.0) as total_debit,
             COALESCE(SUM(credit), 0.0) as total_credit
      FROM ledger_entries
      WHERE workspace_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).getSingle();

    final totalDebit = (trialBalanceRow.data['total_debit'] as num? ?? 0.0).toDouble();
    final totalCredit = (trialBalanceRow.data['total_credit'] as num? ?? 0.0).toDouble();
    final trialBalanceDiff = ((totalDebit - totalCredit) * 100).roundToDouble() / 100;

    // 2. Accounts reconciliation (Ledger vs Accounts)
    final accountRows = await _db.customSelect(
      'SELECT id, name, type FROM accounts WHERE workspace_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(workspaceId)],
    ).get();

    final List<Map<String, dynamic>> accountReconciliations = [];
    for (final a in accountRows) {
      final accId = a.data['id'] as int;
      final accName = a.data['name'] as String? ?? 'Account';
      final accType = a.data['type'] as String? ?? 'cash';
      final bal = await getAccountBalance(accId, workspaceId: workspaceId);

      accountReconciliations.add({
        'account_id': accId,
        'account_name': accName,
        'account_type': accType,
        'ledger_balance': bal,
        'is_reconciled': true,
      });
    }

    // 3. Customer receivables reconciliation
    final custRows = await _db.customSelect(
      'SELECT id, name FROM customers WHERE workspace_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(workspaceId)],
    ).get();
    double totalCustomerReceivables = 0.0;
    for (final c in custRows) {
      final cid = c.data['id'] as int;
      final bal = await getCustomerBalance(cid, workspaceId: workspaceId);
      if (bal > 0) totalCustomerReceivables += bal;
    }

    // 4. Supplier payables reconciliation
    final supRows = await _db.customSelect(
      'SELECT id, name FROM suppliers WHERE workspace_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(workspaceId)],
    ).get();
    double totalSupplierPayables = 0.0;
    for (final s in supRows) {
      final sid = s.data['id'] as int;
      final bal = await getSupplierBalance(sid, workspaceId: workspaceId);
      if (bal > 0) totalSupplierPayables += bal;
    }

    return {
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'trial_balance_diff': trialBalanceDiff,
      'is_trial_balanced': trialBalanceDiff.abs() < 0.01,
      'accounts': accountReconciliations,
      'total_customer_receivables': totalCustomerReceivables,
      'total_supplier_payables': totalSupplierPayables,
    };
  }

  LedgerEntryModel _rowToModel(QueryRow row) {
    final rawDate = row.data['created_at'];
    DateTime date;
    if (rawDate is int) {
      date = DateTime.fromMillisecondsSinceEpoch(rawDate * 1000);
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    return LedgerEntryModel(
      id: row.data['id'] as int? ?? 0,
      workspaceId: row.data['workspace_id'] as int? ?? 1,
      transactionType: row.data['transaction_type'] as String? ?? '',
      referenceType: row.data['reference_type'] as String? ?? '',
      referenceId: row.data['reference_id'] as int?,
      partyType: row.data['party_type'] as String?,
      partyId: row.data['party_id'] as int?,
      accountId: row.data['account_id'] as int?,
      debit: (row.data['debit'] as num? ?? 0.0).toDouble(),
      credit: (row.data['credit'] as num? ?? 0.0).toDouble(),
      narration: row.data['narration'] as String?,
      createdAt: date,
    );
  }
}
