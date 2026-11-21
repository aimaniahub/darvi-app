import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/money_calculator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/local/db/app_database.dart';
import '../cubit/booking_cubit.dart';
import '../widgets/booking_detail_sheet.dart';
import '../widgets/booking_editor_dialog.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({
    super.key,
    this.preselectedPlotId,
  });

  final int? preselectedPlotId;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (context) => BookingCubit(
        bookingRepository: deps.bookingRepository,
        plotRepository: deps.plotRepository,
        partyRepository: deps.partyRepository,
        crmRepository: deps.crmRepository,
        accountRepository: deps.accountRepository,
      )..load(),
      child: _BookingsView(preselectedPlotId: preselectedPlotId),
    );
  }
}

class _BookingsView extends StatefulWidget {
  const _BookingsView({this.preselectedPlotId});

  final int? preselectedPlotId;

  @override
  State<_BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<_BookingsView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPlotId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openBookingEditor(context);
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _openBookingEditor(BuildContext context) async {
    final cubit = context.read<BookingCubit>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => BookingEditorDialog(
        plots: cubit.state.plots,
        customers: cubit.state.customers,
        accounts: cubit.state.accounts,
        preselectedPlotId: widget.preselectedPlotId,
      ),
    );

    if (result != null) {
      await cubit.createBooking(
        bookingNumber: result['bookingNumber'] as String,
        plotId: result['plotId'] as int,
        customerId: result['customerId'] as int,
        totalPlotValue: result['totalPlotValue'] as double,
        bookingAmount: result['bookingAmount'] as double,
        paymentAccountId: result['paymentAccountId'] as int,
        paymentMode: result['paymentMode'] as String,
        referenceNo: result['referenceNo'] as String?,
        notes: result['notes'] as String?,
        installments: (result['installments'] as List).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plot booking confirmed and ledger updated!')),
        );
      }
    }
  }

  void _showBookingDetails(BuildContext context, PlotBooking booking) {
    final cubit = context.read<BookingCubit>();
    final deps = AppScope.of(context);

    final plot = cubit.state.plots.where((p) => p.id == booking.plotId).firstOrNull;
    final customer = cubit.state.customers.where((c) => c.id == booking.customerId).firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => BookingDetailSheet(
        booking: booking,
        plot: plot,
        customer: customer,
        bookingRepository: deps.bookingRepository,
        accounts: cubit.state.accounts,
        onPaymentRecorded: () {
          cubit.load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Installment payment recorded and ledger updated!')),
            );
          }
        },
        onCancelled: () {
          cubit.load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Booking cancelled, plot freed, and refund ledger posted!')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Plot Bookings & Reservations',
        breadcrumbs: const ['Vikshha Farmlands'],
        subtitle: 'Token reservations, confirmed bookings & milestone schedules',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
            onPressed: () => context.read<BookingCubit>().load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(TablerIcons.bookmarkPlus),
        label: const Text('Book Plot'),
        onPressed: () => _openBookingEditor(context),
      ),
      body: BlocConsumer<BookingCubit, BookingState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.bookings.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingSkeleton(count: 6),
            );
          }

          if (state.errorMessage != null && state.bookings.isEmpty) {
            return AppEmptyState(
              icon: TablerIcons.alertCircle,
              title: 'Unable to Load Bookings',
              message: state.errorMessage!,
              action: AppButton.primary(
                label: 'Retry',
                icon: TablerIcons.refresh,
                onPressed: () => context.read<BookingCubit>().load(),
              ),
            );
          }

          final activeCount = state.bookings
              .where((b) => b.status.toLowerCase() == 'booked' || b.status.toLowerCase() == 'confirmed')
              .length;
          final completedCount = state.bookings
              .where((b) => b.status.toLowerCase() == 'completed')
              .length;
          final cancelledCount = state.bookings
              .where((b) => b.status.toLowerCase() == 'cancelled')
              .length;

          return Column(
            children: [
              // Responsive 2-Column KPI Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: AppStatGrid(
                  spacing: 8,
                  children: [
                    AppStatCard(
                      title: 'Total Bookings',
                      value: '${state.bookings.length}',
                      subtitle: 'Reservations recorded',
                      icon: TablerIcons.bookmark,
                      accentColor: AppColors.primary,
                    ),
                    AppStatCard(
                      title: 'Active Bookings',
                      value: '$activeCount',
                      subtitle: 'Token advance / active EMI',
                      icon: TablerIcons.trendingUp,
                      accentColor: AppColors.success,
                      trendBadge: 'Active',
                      trendPositive: true,
                    ),
                    AppStatCard(
                      title: 'Completed Deals',
                      value: '$completedCount',
                      subtitle: 'Sale deeds registered',
                      icon: TablerIcons.circleCheck,
                      accentColor: AppColors.leafAccent,
                    ),
                    AppStatCard(
                      title: 'Cancelled / Refunded',
                      value: '$cancelledCount',
                      subtitle: 'Deeds released',
                      icon: TablerIcons.x,
                      accentColor: AppColors.warning,
                      trendBadge: 'Cancelled',
                      trendPositive: false,
                    ),
                  ],
                ),
              ),

              // 1. Status Filter Segment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<BookingStatusFilter>(
                    segments: [
                      ButtonSegment(
                        value: BookingStatusFilter.all,
                        label: Text('All (${state.bookings.length})'),
                      ),
                      const ButtonSegment(value: BookingStatusFilter.booked, label: Text('Booked')),
                      const ButtonSegment(value: BookingStatusFilter.confirmed, label: Text('Confirmed')),
                      const ButtonSegment(value: BookingStatusFilter.completed, label: Text('Completed')),
                      const ButtonSegment(value: BookingStatusFilter.cancelled, label: Text('Cancelled')),
                    ],
                    selected: {state.statusFilter},
                    onSelectionChanged: (set) {
                      context.read<BookingCubit>().filterStatus(set.first);
                    },
                  ),
                ),
              ),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search booking ref #...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<BookingCubit>().search('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => context.read<BookingCubit>().search(val),
                ),
              ),

              // 3. Bookings List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.bookings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bookmark_border, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No bookings found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Book a Farmland Plot'),
                                  onPressed: () => _openBookingEditor(context),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: state.bookings.length,
                            itemBuilder: (context, index) {
                              final booking = state.bookings[index];
                              final statusColor = _statusColor(booking.status);
                              final plot = state.plots.where((p) => p.id == booking.plotId).firstOrNull;
                              final customer = state.customers.where((c) => c.id == booking.customerId).firstOrNull;

                              final balance = booking.totalPlotValue - booking.bookingAmount;

                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showBookingDetails(context, booking),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  booking.bookingNumber,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: statusColor),
                                                  ),
                                                  child: Text(
                                                    booking.status.toUpperCase(),
                                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Plot: ${plot?.uniquePlotId ?? "Plot #${booking.plotId}"} • ${customer?.name ?? "Customer #${booking.customerId}"}',
                                              style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Advance: ${MoneyCalculator.formatCurrency(booking.bookingAmount)} | Bal: ${MoneyCalculator.formatCurrency(balance)}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              MoneyCalculator.formatCurrency(booking.totalPlotValue),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Icon(Icons.chevron_right, color: Colors.grey),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

