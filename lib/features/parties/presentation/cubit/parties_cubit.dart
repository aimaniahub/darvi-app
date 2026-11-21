import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../domain/repositories/repositories.dart';

class PartiesState extends Equatable {
  const PartiesState({
    this.loading = false,
    this.error,
    this.customers = const [],
    this.suppliers = const [],
    this.accounts = const [],
    this.selectedTab = 0, // 0 = Customers, 1 = Suppliers
    this.searchQuery = '',
    this.customerStatement = const [],
    this.supplierStatement = const [],
    this.selectedPartyId,
    this.selectedCustomerProfile,
    this.selectedSupplierProfile,
  });

  final bool loading;
  final String? error;
  final List<CustomerModel> customers;
  final List<SupplierModel> suppliers;
  final List<AccountModel> accounts;
  final int selectedTab;
  final String searchQuery;
  final List<LedgerEntryModel> customerStatement;
  final List<LedgerEntryModel> supplierStatement;
  final int? selectedPartyId;
  final Map<String, dynamic>? selectedCustomerProfile;
  final Map<String, dynamic>? selectedSupplierProfile;

  List<CustomerModel> get filteredCustomers {
    if (searchQuery.trim().isEmpty) return customers;
    final q = searchQuery.toLowerCase();
    return customers.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.code?.toLowerCase().contains(q) ?? false) ||
          (c.phone?.contains(q) ?? false) ||
          (c.gstin?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<SupplierModel> get filteredSuppliers {
    if (searchQuery.trim().isEmpty) return suppliers;
    final q = searchQuery.toLowerCase();
    return suppliers.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.code?.toLowerCase().contains(q) ?? false) ||
          (s.phone?.contains(q) ?? false) ||
          (s.gstin?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  PartiesState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<CustomerModel>? customers,
    List<SupplierModel>? suppliers,
    List<AccountModel>? accounts,
    int? selectedTab,
    String? searchQuery,
    List<LedgerEntryModel>? customerStatement,
    List<LedgerEntryModel>? supplierStatement,
    int? selectedPartyId,
    bool clearSelectedParty = false,
    Map<String, dynamic>? selectedCustomerProfile,
    bool clearCustomerProfile = false,
    Map<String, dynamic>? selectedSupplierProfile,
    bool clearSupplierProfile = false,
  }) {
    return PartiesState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      customers: customers ?? this.customers,
      suppliers: suppliers ?? this.suppliers,
      accounts: accounts ?? this.accounts,
      selectedTab: selectedTab ?? this.selectedTab,
      searchQuery: searchQuery ?? this.searchQuery,
      customerStatement: customerStatement ?? this.customerStatement,
      supplierStatement: supplierStatement ?? this.supplierStatement,
      selectedPartyId: clearSelectedParty ? null : selectedPartyId ?? this.selectedPartyId,
      selectedCustomerProfile: clearCustomerProfile ? null : selectedCustomerProfile ?? this.selectedCustomerProfile,
      selectedSupplierProfile: clearSupplierProfile ? null : selectedSupplierProfile ?? this.selectedSupplierProfile,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        customers,
        suppliers,
        accounts,
        selectedTab,
        searchQuery,
        customerStatement,
        supplierStatement,
        selectedPartyId,
        selectedCustomerProfile,
        selectedSupplierProfile,
      ];
}

class PartiesCubit extends Cubit<PartiesState> {
  PartiesCubit({
    required PartyRepository partyRepository,
    required LedgerRepository ledgerRepository,
    required AccountRepository accountRepository,
  })  : _partyRepository = partyRepository,
        _ledgerRepository = ledgerRepository,
        _accountRepository = accountRepository,
        super(const PartiesState());

  final PartyRepository _partyRepository;
  final LedgerRepository _ledgerRepository;
  final AccountRepository _accountRepository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final customers = await _partyRepository.getCustomers();
      final suppliers = await _partyRepository.getSuppliers();
      final accounts = await _accountRepository.getAccounts();
      emit(state.copyWith(
        loading: false,
        customers: customers,
        suppliers: suppliers,
        accounts: accounts,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void setTab(int index) {
    emit(state.copyWith(
      selectedTab: index,
      clearSelectedParty: true,
      clearCustomerProfile: true,
      clearSupplierProfile: true,
    ));
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  Future<void> saveCustomer({
    int? id,
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
    emit(this.state.copyWith(loading: true, clearError: true));
    try {
      await _partyRepository.upsertCustomer(
        id: id,
        name: name,
        phone: phone,
        notes: notes,
        balance: balance,
        gstin: gstin,
        address: address,
        creditLimit: creditLimit,
        code: code,
        alternatePhone: alternatePhone,
        email: email,
        state: state,
        customerType: customerType,
        creditPeriodDays: creditPeriodDays,
        isActive: isActive,
        openingBalance: openingBalance,
      );
      await load();
    } on AppException catch (e) {
      emit(this.state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(this.state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> saveSupplier({
    int? id,
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
    emit(this.state.copyWith(loading: true, clearError: true));
    try {
      await _partyRepository.upsertSupplier(
        id: id,
        name: name,
        phone: phone,
        gstin: gstin,
        address: address,
        balance: balance,
        code: code,
        contactPerson: contactPerson,
        email: email,
        state: state,
        paymentTerms: paymentTerms,
        isActive: isActive,
        openingBalance: openingBalance,
        notes: notes,
      );
      await load();
    } on AppException catch (e) {
      emit(this.state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(this.state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> deleteCustomer(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _partyRepository.deleteCustomer(id);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> deleteSupplier(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _partyRepository.deleteSupplier(id);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> loadCustomerProfile(int customerId) async {
    try {
      final profile = await _partyRepository.getCustomerProfile(customerId);
      final entries = await _ledgerRepository.getCustomerStatement(customerId);
      emit(state.copyWith(
        selectedCustomerProfile: profile,
        customerStatement: entries,
        selectedPartyId: customerId,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> loadSupplierProfile(int supplierId) async {
    try {
      final profile = await _partyRepository.getSupplierProfile(supplierId);
      final entries = await _ledgerRepository.getSupplierStatement(supplierId);
      emit(state.copyWith(
        selectedSupplierProfile: profile,
        supplierStatement: entries,
        selectedPartyId: supplierId,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> recordCustomerReceipt({
    required int customerId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? invoiceAllocations,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _partyRepository.recordCustomerCollection(
        customerId: customerId,
        accountId: accountId,
        amount: amount,
        referenceNo: referenceNo,
        narration: narration,
        paymentDate: paymentDate,
        invoiceAllocations: invoiceAllocations,
      );
      await load();
      await loadCustomerProfile(customerId);
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> recordSupplierPayment({
    required int supplierId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? invoiceAllocations,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _partyRepository.recordSupplierPayout(
        supplierId: supplierId,
        accountId: accountId,
        amount: amount,
        referenceNo: referenceNo,
        narration: narration,
        paymentDate: paymentDate,
        invoiceAllocations: invoiceAllocations,
      );
      await load();
      await loadSupplierProfile(supplierId);
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> adjustOpeningBalance({
    required String partyType,
    required int partyId,
    required double newOpeningBalance,
    required String reason,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _partyRepository.adjustPartyOpeningBalance(
        partyType: partyType,
        partyId: partyId,
        newOpeningBalance: newOpeningBalance,
        reason: reason,
      );
      await load();
      if (partyType == 'customer') {
        await loadCustomerProfile(partyId);
      } else {
        await loadSupplierProfile(partyId);
      }
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
      rethrow;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      rethrow;
    }
  }
}
