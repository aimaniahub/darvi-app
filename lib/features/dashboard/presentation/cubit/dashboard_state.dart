import 'package:equatable/equatable.dart';

import '../../../../core/models/app_models.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../domain/entities/app_entities.dart';

class DashboardKpiData extends Equatable {
  const DashboardKpiData({
    this.todaySales = 0.0,
    this.todayInvoices = 0,
    this.monthSales = 0.0,
    this.monthInvoices = 0,
    this.todayCollections = 0.0,
    this.totalReceivables = 0.0,
    this.totalPayables = 0.0,
    this.monthlyExpenses = 0.0,
    this.inventoryValuation = 0.0,
    this.totalCustomers = 0,
    this.activeLeads = 0,
    this.totalPlots = 0,
    this.availablePlots = 0,
    this.bookedPlots = 0,
    this.activeBookings = 0,
    this.totalProducts = 0,
    this.lowStockProductsCount = 0,
    this.averageBillValue = 0.0,
    this.totalTransactions = 0,
  });

  final double todaySales;
  final int todayInvoices;
  final double monthSales;
  final int monthInvoices;
  final double todayCollections;
  final double totalReceivables;
  final double totalPayables;
  final double monthlyExpenses;
  final double inventoryValuation;
  final int totalCustomers;
  final int activeLeads;
  final int totalPlots;
  final int availablePlots;
  final int bookedPlots;
  final int activeBookings;
  final int totalProducts;
  final int lowStockProductsCount;
  final double averageBillValue;
  final int totalTransactions;

  @override
  List<Object?> get props => [
        todaySales,
        todayInvoices,
        monthSales,
        monthInvoices,
        todayCollections,
        totalReceivables,
        totalPayables,
        monthlyExpenses,
        inventoryValuation,
        totalCustomers,
        activeLeads,
        totalPlots,
        availablePlots,
        bookedPlots,
        activeBookings,
        totalProducts,
        lowStockProductsCount,
        averageBillValue,
        totalTransactions,
      ];
}

class DailyTrendPoint extends Equatable {
  const DailyTrendPoint({
    required this.date,
    required this.label,
    required this.revenue,
    required this.count,
  });

  final DateTime date;
  final String label;
  final double revenue;
  final int count;

  @override
  List<Object?> get props => [date, label, revenue, count];
}

class DashboardState extends Equatable {
  const DashboardState({
    this.kpis = const DashboardKpiData(),
    this.salesTrend = const [],
    this.selectedPeriod = '7D',
    this.paymentBreakdown = const {},
    this.topSellingProducts = const [],
    this.plotStatusCounts = const {},
    this.recentSales = const [],
    this.recentPurchases = const [],
    this.recentBookings = const [],
    this.pendingFollowUps = const [],
    this.lowStockProducts = const [],
    this.loading = false,
    this.error,
  });

  final DashboardKpiData kpis;
  final List<DailyTrendPoint> salesTrend;
  final String selectedPeriod;
  final Map<String, double> paymentBreakdown;
  final List<Map<String, dynamic>> topSellingProducts;
  final Map<String, int> plotStatusCounts;
  final List<SaleSummary> recentSales;
  final List<Map<String, dynamic>> recentPurchases;
  final List<PlotBooking> recentBookings;
  final List<Lead> pendingFollowUps;
  final List<ProductView> lowStockProducts;
  final bool loading;
  final String? error;

  DashboardState copyWith({
    DashboardKpiData? kpis,
    List<DailyTrendPoint>? salesTrend,
    String? selectedPeriod,
    Map<String, double>? paymentBreakdown,
    List<Map<String, dynamic>>? topSellingProducts,
    Map<String, int>? plotStatusCounts,
    List<SaleSummary>? recentSales,
    List<Map<String, dynamic>>? recentPurchases,
    List<PlotBooking>? recentBookings,
    List<Lead>? pendingFollowUps,
    List<ProductView>? lowStockProducts,
    bool? loading,
    String? Function()? error,
  }) {
    return DashboardState(
      kpis: kpis ?? this.kpis,
      salesTrend: salesTrend ?? this.salesTrend,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
      topSellingProducts: topSellingProducts ?? this.topSellingProducts,
      plotStatusCounts: plotStatusCounts ?? this.plotStatusCounts,
      recentSales: recentSales ?? this.recentSales,
      recentPurchases: recentPurchases ?? this.recentPurchases,
      recentBookings: recentBookings ?? this.recentBookings,
      pendingFollowUps: pendingFollowUps ?? this.pendingFollowUps,
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
    );
  }

  @override
  List<Object?> get props => [
        kpis,
        salesTrend,
        selectedPeriod,
        paymentBreakdown,
        topSellingProducts,
        plotStatusCounts,
        recentSales,
        recentPurchases,
        recentBookings,
        pendingFollowUps,
        lowStockProducts,
        loading,
        error,
      ];
}
