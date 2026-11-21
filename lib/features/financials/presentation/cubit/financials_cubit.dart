import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../domain/repositories/repositories.dart';

class FinancialsState extends Equatable {
  const FinancialsState({
    this.loading = false,
    this.error,
    this.accounts = const [],
    this.expenses = const [],
    this.ledgerEntries = const [],
    this.cashbookEntries = const [],
    this.metrics,
    this.reconciliation,
    this.profitLoss,
    this.totalCash = 0.0,
    this.totalBank = 0.0,
    this.totalUpi = 0.0,
    this.totalExpenses = 0.0,
    this.selectedAccountFilter,
    this.selectedCategoryFilter,
    this.selectedTxTypeFilter,
    this.searchQuery = '',
    this.fromDate,
    this.toDate,
  });

  final bool loading;
  final String? error;
  final List<AccountModel> accounts;
  final List<ExpenseModel> expenses;
  final List<LedgerEntryModel> ledgerEntries;
  final List<CashbookEntry> cashbookEntries;
  final FinancialDashboardMetrics? metrics;
  final Map<String, dynamic>? reconciliation;
  final Map<String, dynamic>? profitLoss;
  final double totalCash;
  final double totalBank;
  final double totalUpi;
  final double totalExpenses;
  final int? selectedAccountFilter;
  final String? selectedCategoryFilter;
  final String? selectedTxTypeFilter;
  final String searchQuery;
  final DateTime? fromDate;
  final DateTime? toDate;

  double get netBalance => totalCash + totalBank + totalUpi;

  FinancialsState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<AccountModel>? accounts,
    List<ExpenseModel>? expenses,
    List<LedgerEntryModel>? ledgerEntries,
    List<CashbookEntry>? cashbookEntries,
    FinancialDashboardMetrics? metrics,
    Map<String, dynamic>? reconciliation,
    Map<String, dynamic>? profitLoss,
    double? totalCash,
    double? totalBank,
    double? totalUpi,
    double? totalExpenses,
    int? selectedAccountFilter,
    bool clearAccountFilter = false,
    String? selectedCategoryFilter,
    bool clearCategoryFilter = false,
    String? selectedTxTypeFilter,
    bool clearTxTypeFilter = false,
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearDates = false,
  }) {
    return FinancialsState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      accounts: accounts ?? this.accounts,
      expenses: expenses ?? this.expenses,
      ledgerEntries: ledgerEntries ?? this.ledgerEntries,
      cashbookEntries: cashbookEntries ?? this.cashbookEntries,
      metrics: metrics ?? this.metrics,
      reconciliation: reconciliation ?? this.reconciliation,
      profitLoss: profitLoss ?? this.profitLoss,
      totalCash: totalCash ?? this.totalCash,
      totalBank: totalBank ?? this.totalBank,
      totalUpi: totalUpi ?? this.totalUpi,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      selectedAccountFilter: clearAccountFilter ? null : selectedAccountFilter ?? this.selectedAccountFilter,
      selectedCategoryFilter: clearCategoryFilter ? null : selectedCategoryFilter ?? this.selectedCategoryFilter,
      selectedTxTypeFilter: clearTxTypeFilter ? null : selectedTxTypeFilter ?? this.selectedTxTypeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      fromDate: clearDates ? null : fromDate ?? this.fromDate,
      toDate: clearDates ? null : toDate ?? this.toDate,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        accounts,
        expenses,
        ledgerEntries,
        cashbookEntries,
        metrics,
        reconciliation,
        profitLoss,
        totalCash,
        totalBank,
        totalUpi,
        totalExpenses,
        selectedAccountFilter,
        selectedCategoryFilter,
        selectedTxTypeFilter,
        searchQuery,
        fromDate,
        toDate,
      ];
}

class FinancialsCubit extends Cubit<FinancialsState> {
  FinancialsCubit({
    required AccountRepository accountRepository,
    required ExpenseRepository expenseRepository,
    required LedgerRepository ledgerRepository,
  })  : _accountRepository = accountRepository,
        _expenseRepository = expenseRepository,
        _ledgerRepository = ledgerRepository,
        super(const FinancialsState());

  final AccountRepository _accountRepository;
  final ExpenseRepository _expenseRepository;
  final LedgerRepository _ledgerRepository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final accounts = await _accountRepository.getAccounts();
      final expenses = await _expenseRepository.getExpenses(
        from: state.fromDate,
        to: state.toDate,
        category: state.selectedCategoryFilter,
        search: state.searchQuery,
      );
      final ledgerEntries = await _ledgerRepository.getRecentLedgerEntries(
        accountId: state.selectedAccountFilter,
        transactionType: state.selectedTxTypeFilter,
        fromDate: state.fromDate,
        toDate: state.toDate,
        search: state.searchQuery,
      );
      final cashbook = await _accountRepository.getCashbookEntries(
        accountId: state.selectedAccountFilter,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      final metrics = await _accountRepository.getFinancialDashboardMetrics(
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      final reconciliation = await _ledgerRepository.reconcileBalances();
      final pnl = await _accountRepository.getProfitAndLossReport(
        fromDate: state.fromDate,
        toDate: state.toDate,
      );

      double cash = 0.0, bank = 0.0, upi = 0.0;
      for (final a in accounts) {
        if (a.type == 'cash') cash += a.balance;
        if (a.type == 'bank') bank += a.balance;
        if (a.type == 'upi') upi += a.balance;
      }

      double totalExp = 0.0;
      for (final e in expenses) {
        if (!e.isCancelled) {
          totalExp += e.amount;
        }
      }

      emit(state.copyWith(
        loading: false,
        accounts: accounts,
        expenses: expenses,
        ledgerEntries: ledgerEntries,
        cashbookEntries: cashbook,
        metrics: metrics,
        reconciliation: reconciliation,
        profitLoss: pnl,
        totalCash: cash,
        totalBank: bank,
        totalUpi: upi,
        totalExpenses: totalExp,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void setAccountFilter(int? accountId) {
    if (accountId == null) {
      emit(state.copyWith(clearAccountFilter: true));
    } else {
      emit(state.copyWith(selectedAccountFilter: accountId));
    }
    load();
  }

  void setCategoryFilter(String? category) {
    if (category == null || category.isEmpty || category == 'ALL') {
      emit(state.copyWith(clearCategoryFilter: true));
    } else {
      emit(state.copyWith(selectedCategoryFilter: category));
    }
    load();
  }

  void setTxTypeFilter(String? txType) {
    if (txType == null || txType.isEmpty || txType == 'ALL') {
      emit(state.copyWith(clearTxTypeFilter: true));
    } else {
      emit(state.copyWith(selectedTxTypeFilter: txType));
    }
    load();
  }

  void setSearchQuery(String q) {
    emit(state.copyWith(searchQuery: q));
    load();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    if (from == null && to == null) {
      emit(state.copyWith(clearDates: true));
    } else {
      emit(state.copyWith(fromDate: from, toDate: to));
    }
    load();
  }

  Future<void> addExpense({
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
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _expenseRepository.addExpense(
        accountId: accountId,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        referenceNo: referenceNo,
        notes: notes,
        vendorPayee: vendorPayee,
        taxAmount: taxAmount,
        attachmentUrl: attachmentUrl,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> updateExpense({
    required int id,
    required int accountId,
    required String category,
    required double amount,
    DateTime? expenseDate,
    String? referenceNo,
    String? notes,
    String? vendorPayee,
    double taxAmount = 0.0,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _expenseRepository.updateExpense(
        id: id,
        accountId: accountId,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        referenceNo: referenceNo,
        notes: notes,
        vendorPayee: vendorPayee,
        taxAmount: taxAmount,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> cancelExpense(int id, {String? reason}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _expenseRepository.cancelExpense(id, reason: reason);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> deleteExpense(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _expenseRepository.deleteExpense(id);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> createAccount({
    required String name,
    required String type,
    String? accountNumber,
    double initialBalance = 0.0,
    bool isDefault = false,
    String? bankName,
    String? ifsc,
    String? upiId,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _accountRepository.createAccount(
        name: name,
        type: type,
        accountNumber: accountNumber,
        initialBalance: initialBalance,
        isDefault: isDefault,
        bankName: bankName,
        ifsc: ifsc,
        upiId: upiId,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> updateAccount({
    required int id,
    required String name,
    required String type,
    String? accountNumber,
    bool? isDefault,
    String? bankName,
    String? ifsc,
    String? upiId,
    bool? isActive,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _accountRepository.updateAccount(
        id: id,
        name: name,
        type: type,
        accountNumber: accountNumber,
        isDefault: isDefault,
        bankName: bankName,
        ifsc: ifsc,
        upiId: upiId,
        isActive: isActive,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> deactivateAccount(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _accountRepository.deactivateAccount(id);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> transferFunds({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? transferDate,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _accountRepository.transferFunds(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        referenceNo: referenceNo,
        narration: narration,
        transferDate: transferDate,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> recordMoneyReceived({
    required int accountId,
    required double amount,
    required String category,
    int? customerId,
    String? referenceNo,
    String? description,
    DateTime? receiptDate,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _accountRepository.recordMoneyReceived(
        accountId: accountId,
        amount: amount,
        category: category,
        customerId: customerId,
        referenceNo: referenceNo,
        description: description,
        receiptDate: receiptDate,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> recordMoneyPaid({
    required int accountId,
    required double amount,
    required String category,
    int? supplierId,
    int? employeeId,
    String? referenceNo,
    String? description,
    DateTime? paymentDate,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _accountRepository.recordMoneyPaid(
        accountId: accountId,
        amount: amount,
        category: category,
        supplierId: supplierId,
        employeeId: employeeId,
        referenceNo: referenceNo,
        description: description,
        paymentDate: paymentDate,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }
}
