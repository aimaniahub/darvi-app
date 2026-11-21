import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

enum BookingStatusFilter { all, booked, confirmed, cancelled, completed }

class BookingState {
  const BookingState({
    this.bookings = const [],
    this.plots = const [],
    this.customers = const [],
    this.leads = const [],
    this.accounts = const [],
    this.statusFilter = BookingStatusFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<PlotBooking> bookings;
  final List<Plot> plots;
  final List<dynamic> customers;
  final List<Lead> leads;
  final List<dynamic> accounts;
  final BookingStatusFilter statusFilter;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  BookingState copyWith({
    List<PlotBooking>? bookings,
    List<Plot>? plots,
    List<dynamic>? customers,
    List<Lead>? leads,
    List<dynamic>? accounts,
    BookingStatusFilter? statusFilter,
    String? searchQuery,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return BookingState(
      bookings: bookings ?? this.bookings,
      plots: plots ?? this.plots,
      customers: customers ?? this.customers,
      leads: leads ?? this.leads,
      accounts: accounts ?? this.accounts,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class BookingCubit extends Cubit<BookingState> {
  BookingCubit({
    required this.bookingRepository,
    required this.plotRepository,
    required this.partyRepository,
    required this.crmRepository,
    required this.accountRepository,
  }) : super(const BookingState());

  final BookingRepository bookingRepository;
  final PlotRepository plotRepository;
  final PartyRepository partyRepository;
  final CrmRepository crmRepository;
  final AccountRepository accountRepository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      final statusStr = state.statusFilter == BookingStatusFilter.all ? null : state.statusFilter.name;
      final bookingsRaw = await bookingRepository.getBookings(
        status: statusStr,
        query: state.searchQuery,
      );
      final bookings = bookingsRaw.cast<PlotBooking>();

      final plotsRaw = await plotRepository.getPlots();
      final plots = plotsRaw.cast<Plot>();

      final custs = await partyRepository.getCustomers();
      final leadsRaw = await crmRepository.getLeads();
      final leads = leadsRaw.cast<Lead>();
      final accs = await accountRepository.getAccounts();

      emit(state.copyWith(
        bookings: bookings,
        plots: plots,
        customers: custs,
        leads: leads,
        accounts: accs,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  void filterStatus(BookingStatusFilter filter) {
    emit(state.copyWith(statusFilter: filter));
    load();
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    load();
  }

  Future<int> reservePlot({
    required int plotId,
    required int customerId,
    int? leadId,
    int? employeeId,
    required double totalPlotValue,
    required double reservationAmount,
    required int paymentAccountId,
    String paymentMode = 'upi',
    int expiryDays = 7,
    String? notes,
  }) async {
    final id = await bookingRepository.reservePlot(
      plotId: plotId,
      customerId: customerId,
      leadId: leadId,
      employeeId: employeeId,
      totalPlotValue: totalPlotValue,
      reservationAmount: reservationAmount,
      paymentAccountId: paymentAccountId,
      paymentMode: paymentMode,
      expiryDays: expiryDays,
      notes: notes,
    );
    await load();
    return id;
  }

  Future<void> releaseExpiredReservations() async {
    await bookingRepository.releaseExpiredReservations();
    await load();
  }

  Future<int> createBooking({
    required String bookingNumber,
    required int plotId,
    required int customerId,
    int? leadId,
    int? employeeId,
    required double totalPlotValue,
    required double bookingAmount,
    double discount = 0.0,
    required int paymentAccountId,
    String paymentMode = 'upi',
    String? referenceNo,
    String? notes,
    required List<Map<String, dynamic>> installments,
  }) async {
    final id = await bookingRepository.createBooking(
      bookingNumber: bookingNumber,
      plotId: plotId,
      customerId: customerId,
      leadId: leadId,
      employeeId: employeeId,
      totalPlotValue: totalPlotValue,
      bookingAmount: bookingAmount,
      discount: discount,
      paymentAccountId: paymentAccountId,
      paymentMode: paymentMode,
      referenceNo: referenceNo,
      notes: notes,
      installments: installments,
    );
    await load();
    return id;
  }

  Future<void> payInstallment({
    required int installmentId,
    required double amount,
    required int paymentAccountId,
    String paymentMode = 'upi',
    String? referenceNo,
  }) async {
    await bookingRepository.payInstallment(
      installmentId: installmentId,
      amount: amount,
      paymentAccountId: paymentAccountId,
      paymentMode: paymentMode,
      referenceNo: referenceNo,
    );
    await load();
  }

  Future<Map<String, dynamic>> loadBookingStatement(int bookingId) async {
    return bookingRepository.getBookingStatement(bookingId);
  }

  Future<void> updateAgreementStatus(int bookingId, String agreementStatus) async {
    await bookingRepository.updateAgreementStatus(bookingId, agreementStatus);
    await load();
  }

  Future<int> claimSalesCommission({
    required int bookingId,
    required int employeeId,
    required double commissionRate,
    String? remarks,
  }) async {
    final claimId = await bookingRepository.claimSalesCommission(
      bookingId: bookingId,
      employeeId: employeeId,
      commissionRate: commissionRate,
      remarks: remarks,
    );
    await load();
    return claimId;
  }

  Future<void> cancelBooking({
    required int bookingId,
    required String reason,
    required double refundAmount,
    required int refundAccountId,
  }) async {
    await bookingRepository.cancelBooking(
      bookingId: bookingId,
      reason: reason,
      refundAmount: refundAmount,
      refundAccountId: refundAccountId,
    );
    await load();
  }
}

