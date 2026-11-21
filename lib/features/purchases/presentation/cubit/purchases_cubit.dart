import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../domain/entities/app_entities.dart';
import '../../../../domain/repositories/repositories.dart';

class PurchasesState extends Equatable {
  const PurchasesState({
    this.loading = false,
    this.error,
    this.invoices = const [],
    this.suppliers = const [],
    this.products = const [],
    this.accounts = const [],
    this.returns = const [],
    this.metrics,
    this.searchQuery = '',
    this.statusFilter = 'ALL',
    this.selectedSupplierFilter,
    this.fromDate,
    this.toDate,
    this.selectedInvoiceDetail,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> invoices;
  final List<SupplierModel> suppliers;
  final List<ProductView> products;
  final List<AccountModel> accounts;
  final List<PurchaseReturnModel> returns;
  final PurchaseDashboardMetrics? metrics;
  final String searchQuery;
  final String statusFilter; // ALL, UNPAID, PAID, CANCELLED
  final int? selectedSupplierFilter;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Map<String, dynamic>? selectedInvoiceDetail;

  PurchasesState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<Map<String, dynamic>>? invoices,
    List<SupplierModel>? suppliers,
    List<ProductView>? products,
    List<AccountModel>? accounts,
    List<PurchaseReturnModel>? returns,
    PurchaseDashboardMetrics? metrics,
    String? searchQuery,
    String? statusFilter,
    int? selectedSupplierFilter,
    bool clearSupplierFilter = false,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearDates = false,
    Map<String, dynamic>? selectedInvoiceDetail,
    bool clearSelectedInvoice = false,
  }) {
    return PurchasesState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      invoices: invoices ?? this.invoices,
      suppliers: suppliers ?? this.suppliers,
      products: products ?? this.products,
      accounts: accounts ?? this.accounts,
      returns: returns ?? this.returns,
      metrics: metrics ?? this.metrics,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      selectedSupplierFilter: clearSupplierFilter ? null : selectedSupplierFilter ?? this.selectedSupplierFilter,
      fromDate: clearDates ? null : fromDate ?? this.fromDate,
      toDate: clearDates ? null : toDate ?? this.toDate,
      selectedInvoiceDetail: clearSelectedInvoice ? null : selectedInvoiceDetail ?? this.selectedInvoiceDetail,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        invoices,
        suppliers,
        products,
        accounts,
        returns,
        metrics,
        searchQuery,
        statusFilter,
        selectedSupplierFilter,
        fromDate,
        toDate,
        selectedInvoiceDetail,
      ];
}

class PurchasesCubit extends Cubit<PurchasesState> {
  PurchasesCubit({
    required PurchaseRepository purchaseRepository,
    required PartyRepository partyRepository,
    required ProductRepository productRepository,
    AccountRepository? accountRepository,
  })  : _purchaseRepository = purchaseRepository,
        _partyRepository = partyRepository,
        _productRepository = productRepository,
        _accountRepository = accountRepository,
        super(const PurchasesState());

  final PurchaseRepository _purchaseRepository;
  final PartyRepository _partyRepository;
  final ProductRepository _productRepository;
  final AccountRepository? _accountRepository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final invoices = await _purchaseRepository.getPurchaseInvoices(
        searchQuery: state.searchQuery,
        statusFilter: state.statusFilter,
        supplierId: state.selectedSupplierFilter,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      final suppliers = await _partyRepository.getSuppliers();
      final products = await _productRepository.getProducts();
      final accounts = _accountRepository != null ? await _accountRepository.getAccounts() : <AccountModel>[];
      final metrics = await _purchaseRepository.getPurchaseDashboardMetrics(
        fromDate: state.fromDate,
        toDate: state.toDate,
        supplierId: state.selectedSupplierFilter,
        paymentStatus: state.statusFilter,
      );
      final returns = await _purchaseRepository.getPurchaseReturns(
        supplierId: state.selectedSupplierFilter,
      );

      emit(state.copyWith(
        loading: false,
        invoices: invoices,
        suppliers: suppliers,
        products: products,
        accounts: accounts,
        metrics: metrics,
        returns: returns,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
    load();
  }

  void setStatusFilter(String status) {
    emit(state.copyWith(statusFilter: status));
    load();
  }

  void setSupplierFilter(int? supplierId) {
    if (supplierId == null) {
      emit(state.copyWith(clearSupplierFilter: true));
    } else {
      emit(state.copyWith(selectedSupplierFilter: supplierId));
    }
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

  Future<void> createInvoice(PurchaseInvoiceInput input) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _purchaseRepository.createPurchaseInvoice(input);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> editInvoice(int id, PurchaseInvoiceInput input) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _purchaseRepository.editPurchaseInvoice(id, input);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> cancelInvoice(int id, {String? reason}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _purchaseRepository.cancelPurchaseInvoice(id, reason: reason);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> recordPayment({
    required int purchaseInvoiceId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _purchaseRepository.recordPurchasePayment(
        purchaseInvoiceId: purchaseInvoiceId,
        accountId: accountId,
        amount: amount,
        referenceNo: referenceNo,
        narration: narration,
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

  Future<void> createReturn(PurchaseReturnInput input) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _purchaseRepository.createPurchaseReturn(input);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<SupplierModel> createSupplierInline({
    required String name,
    String? phone,
    String? gstin,
    String? address,
    String? code,
    String? contactPerson,
    String? email,
  }) async {
    final supId = await _partyRepository.upsertSupplier(
      name: name,
      phone: phone,
      gstin: gstin,
      address: address,
      code: code,
      contactPerson: contactPerson,
      email: email,
    );
    final suppliers = await _partyRepository.getSuppliers();
    emit(state.copyWith(suppliers: suppliers));
    return suppliers.firstWhere((s) => s.id == supId);
  }
}
