import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/utils/money_calculator.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required this.db,
    required this.salesRepository,
    required this.productRepository,
    required this.partyRepository,
    required this.purchaseRepository,
    required this.expenseRepository,
    required this.plotRepository,
    required this.crmRepository,
    required this.bookingRepository,
  }) : super(const DashboardState());

  final AppDatabase db;
  final SalesRepository salesRepository;
  final ProductRepository productRepository;
  final PartyRepository partyRepository;
  final PurchaseRepository purchaseRepository;
  final ExpenseRepository expenseRepository;
  final PlotRepository plotRepository;
  final CrmRepository crmRepository;
  final BookingRepository bookingRepository;

  Future<void> load({String period = '7D'}) async {
    emit(state.copyWith(loading: true, error: () => null, selectedPeriod: period));
    try {
      final now = DateTime.now();

      // 1. Fetch sales and invoices
      final sales = await salesRepository.getInvoices();
      final todaySalesRows = sales.where((s) => _isSameDay(s.createdAt, now)).toList();
      final monthSalesRows = sales.where((s) => s.createdAt.year == now.year && s.createdAt.month == now.month).toList();

      final todaySalesTotal = MoneyCalculator.round2(todaySalesRows.fold(0.0, (sum, s) => sum + s.total));
      final monthSalesTotal = MoneyCalculator.round2(monthSalesRows.fold(0.0, (sum, s) => sum + s.total));

      // 2. Fetch payments today (collections)
      final paymentsTodayRow = await db.customSelect('''
        SELECT COALESCE(SUM(amount), 0.0) as total
        FROM payments
        WHERE payment_type = 'customer_receipt'
          AND strftime('%Y-%m-%d', datetime(created_at, 'unixepoch')) = ?;
      ''', variables: [Variable.withString(_formatDateOnly(now))]).getSingle();
      final todayCollections = (paymentsTodayRow.data['total'] as num).toDouble();

      // 3. Customers & Receivables
      final customers = await partyRepository.getCustomers();
      final totalReceivables = MoneyCalculator.round2(
        customers.fold(0.0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0.0)),
      );

      // 4. Suppliers & Payables
      final suppliers = await partyRepository.getSuppliers();
      final totalPayables = MoneyCalculator.round2(
        suppliers.fold(0.0, (sum, s) => sum + (s.balance > 0 ? s.balance : 0.0)),
      );

      // 5. Monthly expenses
      final expenses = await expenseRepository.getExpenses();
      final monthExpensesRows = expenses.where((e) => e.expenseDate.year == now.year && e.expenseDate.month == now.month).toList();
      final monthExpensesTotal = MoneyCalculator.round2(monthExpensesRows.fold(0.0, (sum, e) => sum + e.amount));

      // 6. Products & Inventory Valuation
      final products = await productRepository.getProducts();
      final inventoryValuation = MoneyCalculator.round2(
        products.fold(0.0, (sum, p) => sum + (p.stockQty > 0 ? p.stockQty * p.cost : 0.0)),
      );
      final lowStockList = products.where((p) => p.isLowStock).toList();

      // 7. Vikshha Plots
      final plotsRaw = await plotRepository.getPlots();
      final plots = plotsRaw.cast<Plot>();
      final totalPlots = plots.length;
      final availablePlots = plots.where((p) => p.status == 'available').length;
      final bookedPlots = plots.where((p) => p.status == 'booked' || p.status == 'sold').length;

      final plotStatusCounts = <String, int>{
        'Available': availablePlots,
        'Reserved': plots.where((p) => p.status == 'reserved').length,
        'Booked': plots.where((p) => p.status == 'booked').length,
        'Sold': plots.where((p) => p.status == 'sold').length,
      };

      // 8. CRM Leads & Active Bookings
      final leadsRaw = await crmRepository.getLeads();
      final leads = leadsRaw.cast<Lead>();
      final activeLeads = leads.where((l) => l.stage != 'lost' && l.stage != 'converted').length;
      final pendingFollowUps = leads
          .where((l) => l.nextFollowUpDate != null && l.nextFollowUpDate!.isAfter(now.subtract(const Duration(days: 1))))
          .toList()
        ..sort((a, b) => a.nextFollowUpDate!.compareTo(b.nextFollowUpDate!));

      final bookingsRaw = await bookingRepository.getBookings();
      final bookings = bookingsRaw.cast<PlotBooking>();
      final activeBookings = bookings.where((b) => b.status == 'active').length;

      // 9. Purchases
      final purchases = await purchaseRepository.getPurchaseInvoices();

      // 10. Trend Data for Chart based on selected period
      final trendDays = _computeTrendDays(sales, period, now);

      // 11. Payment mode distribution
      final paymentBreakdown = <String, double>{'Cash': 0.0, 'Bank': 0.0, 'UPI': 0.0};
      for (final s in monthSalesRows) {
        final mode = s.paymentMethod.name.toUpperCase();
        if (mode.contains('CASH')) {
          paymentBreakdown['Cash'] = (paymentBreakdown['Cash'] ?? 0.0) + s.total;
        } else if (mode.contains('BANK')) {
          paymentBreakdown['Bank'] = (paymentBreakdown['Bank'] ?? 0.0) + s.total;
        } else {
          paymentBreakdown['UPI'] = (paymentBreakdown['UPI'] ?? 0.0) + s.total;
        }
      }

      // 12. Top selling products
      final topProducts = await _computeTopProducts(monthSalesRows);

      final totalProductsCount = products.length;
      final lowStockCount = lowStockList.length;
      final totalTransactionsCount = sales.length;
      final averageBill = todaySalesRows.isNotEmpty
          ? MoneyCalculator.round2(todaySalesTotal / todaySalesRows.length)
          : (monthSalesRows.isNotEmpty
              ? MoneyCalculator.round2(monthSalesTotal / monthSalesRows.length)
              : 0.0);

      final kpis = DashboardKpiData(
        todaySales: todaySalesTotal,
        todayInvoices: todaySalesRows.length,
        monthSales: monthSalesTotal,
        monthInvoices: monthSalesRows.length,
        todayCollections: todayCollections,
        totalReceivables: totalReceivables,
        totalPayables: totalPayables,
        monthlyExpenses: monthExpensesTotal,
        inventoryValuation: inventoryValuation,
        totalCustomers: customers.length,
        activeLeads: activeLeads,
        totalPlots: totalPlots,
        availablePlots: availablePlots,
        bookedPlots: bookedPlots,
        activeBookings: activeBookings,
        totalProducts: totalProductsCount,
        lowStockProductsCount: lowStockCount,
        averageBillValue: averageBill,
        totalTransactions: totalTransactionsCount,
      );

      emit(state.copyWith(
        kpis: kpis,
        salesTrend: trendDays,
        selectedPeriod: period,
        paymentBreakdown: paymentBreakdown,
        topSellingProducts: topProducts,
        plotStatusCounts: plotStatusCounts,
        recentSales: sales.take(5).toList(),
        recentPurchases: purchases.take(5).toList(),
        recentBookings: bookings.take(5).toList(),
        pendingFollowUps: pendingFollowUps.take(5).toList(),
        lowStockProducts: lowStockList.take(6).toList(),
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: () => e.toString()));
    }
  }

  void changePeriod(String period) {
    if (state.selectedPeriod == period) return;
    load(period: period);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DailyTrendPoint> _computeTrendDays(List<SaleSummary> sales, String period, DateTime now) {
    final p = period.toUpperCase();
    final int dayCount = p == '30D' ? 30 : (p == 'MONTH' ? now.day : 7);
    final points = <DailyTrendPoint>[];

    for (var i = dayCount - 1; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final daySales = sales.where((s) => _isSameDay(s.createdAt, targetDate));
      final revenue = MoneyCalculator.round2(daySales.fold(0.0, (sum, s) => sum + s.total));
      final label = '${targetDate.day}/${targetDate.month}';
      points.add(DailyTrendPoint(
        date: targetDate,
        label: label,
        revenue: revenue,
        count: daySales.length,
      ));
    }
    return points;
  }

  Future<List<Map<String, dynamic>>> _computeTopProducts(List<SaleSummary> monthSales) async {
    if (monthSales.isEmpty) return [];
    final saleIds = monthSales.map((s) => s.id).toSet();
    final allItems = await db.select(db.saleItems).get();
    final monthItems = allItems.where((item) => saleIds.contains(item.saleId));

    final map = <String, Map<String, dynamic>>{};
    for (final item in monthItems) {
      final name = item.nameSnapshot;
      if (!map.containsKey(name)) {
        map[name] = {'name': name, 'qty': 0, 'revenue': 0.0};
      }
      map[name]!['qty'] = (map[name]!['qty'] as int) + item.qty;
      map[name]!['revenue'] = (map[name]!['revenue'] as double) + item.lineTotal;
    }

    final list = map.values.toList();
    list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return list.take(5).toList();
  }
}
