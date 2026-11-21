import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

enum QuotationStatusFilter { all, draft, sent, accepted, rejected, converted }

class QuotationState {
  const QuotationState({
    this.quotations = const [],
    this.customers = const [],
    this.leads = const [],
    this.products = const [],
    this.plots = const [],
    this.accounts = const [],
    this.statusFilter = QuotationStatusFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Quotation> quotations;
  final List<dynamic> customers;
  final List<Lead> leads;
  final List<dynamic> products;
  final List<Plot> plots;
  final List<dynamic> accounts;
  final QuotationStatusFilter statusFilter;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  QuotationState copyWith({
    List<Quotation>? quotations,
    List<dynamic>? customers,
    List<Lead>? leads,
    List<dynamic>? products,
    List<Plot>? plots,
    List<dynamic>? accounts,
    QuotationStatusFilter? statusFilter,
    String? searchQuery,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return QuotationState(
      quotations: quotations ?? this.quotations,
      customers: customers ?? this.customers,
      leads: leads ?? this.leads,
      products: products ?? this.products,
      plots: plots ?? this.plots,
      accounts: accounts ?? this.accounts,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class QuotationCubit extends Cubit<QuotationState> {
  QuotationCubit({
    required this.quotationRepository,
    required this.partyRepository,
    required this.crmRepository,
    required this.productRepository,
    required this.plotRepository,
    required this.accountRepository,
  }) : super(const QuotationState());

  final QuotationRepository quotationRepository;
  final PartyRepository partyRepository;
  final CrmRepository crmRepository;
  final ProductRepository productRepository;
  final PlotRepository plotRepository;
  final AccountRepository accountRepository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      final statusStr = state.statusFilter == QuotationStatusFilter.all ? null : state.statusFilter.name;
      final quotesRaw = await quotationRepository.getQuotations(
        status: statusStr,
        query: state.searchQuery,
      );
      final quotes = quotesRaw.cast<Quotation>();

      final custs = await partyRepository.getCustomers();
      final leadsRaw = await crmRepository.getLeads();
      final leads = leadsRaw.cast<Lead>();
      final prods = await productRepository.getProducts();
      final plotsRaw = await plotRepository.getPlots();
      final plots = plotsRaw.cast<Plot>();
      final accs = await accountRepository.getAccounts();

      emit(state.copyWith(
        quotations: quotes,
        customers: custs,
        leads: leads,
        products: prods,
        plots: plots,
        accounts: accs,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  void filterStatus(QuotationStatusFilter filter) {
    emit(state.copyWith(statusFilter: filter));
    load();
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    load();
  }

  Future<int> createQuotation({
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
    final id = await quotationRepository.createQuotation(
      quotationNumber: quotationNumber,
      customerId: customerId,
      leadId: leadId,
      customerName: customerName,
      customerPhone: customerPhone,
      validUntil: validUntil,
      subtotal: subtotal,
      discountTotal: discountTotal,
      taxTotal: taxTotal,
      cgstTotal: cgstTotal,
      sgstTotal: sgstTotal,
      igstTotal: igstTotal,
      totalAmount: totalAmount,
      status: status,
      terms: terms,
      notes: notes,
      items: items,
    );
    await load();
    return id;
  }

  Future<void> updateStatus(int quotationId, String status) async {
    await quotationRepository.updateQuotationStatus(quotationId, status);
    await load();
  }

  Future<int> convertToSale({
    required int quotationId,
    required int accountId,
    required String paymentMode,
  }) async {
    final saleId = await quotationRepository.convertQuotationToSale(
      quotationId: quotationId,
      accountId: accountId,
      paymentMode: paymentMode,
    );
    await load();
    return saleId;
  }
}

