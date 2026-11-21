import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/data/repositories/local_repositories.dart';
import 'package:mini_pos_inventory/features/dashboard/presentation/cubit/dashboard_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DashboardCubit cubit;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await SeedData(db).ensureSeeded();

    final ledgerRepo = LocalLedgerRepository(db);
    final salesRepo = LocalSalesRepository(db, ledgerRepo);
    final productRepo = LocalProductRepository(db);
    final partyRepo = LocalPartyRepository(db);
    final purchaseRepo = LocalPurchaseRepository(db, ledgerRepo);
    final expenseRepo = LocalExpenseRepository(db, ledgerRepo);
    final plotRepo = LocalPlotRepository(db);
    final crmRepo = LocalCrmRepository(db);
    final bookingRepo = LocalBookingRepository(db, ledgerRepo);

    cubit = DashboardCubit(
      db: db,
      salesRepository: salesRepo,
      productRepository: productRepo,
      partyRepository: partyRepo,
      purchaseRepository: purchaseRepo,
      expenseRepository: expenseRepo,
      plotRepository: plotRepo,
      crmRepository: crmRepo,
      bookingRepository: bookingRepo,
    );
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  test('DashboardCubit loads successfully with seed data and computes all 12 KPIs', () async {
    await cubit.load();

    final state = cubit.state;

    // Verify loading completed without error
    expect(state.loading, isFalse);
    expect(state.error, isNull);

    // Verify 12 KPIs are calculated
    final kpis = state.kpis;
    expect(kpis.todaySales, isNotNull);
    expect(kpis.todayInvoices, isNotNull);
    expect(kpis.monthSales, isNotNull);
    expect(kpis.monthInvoices, isNotNull);
    expect(kpis.todayCollections, isNotNull);
    expect(kpis.totalReceivables, isNotNull);
    expect(kpis.totalPayables, isNotNull);
    expect(kpis.monthlyExpenses, isNotNull);
    expect(kpis.inventoryValuation, greaterThanOrEqualTo(0.0));
    expect(kpis.totalCustomers, greaterThanOrEqualTo(0));
    expect(kpis.activeLeads, greaterThanOrEqualTo(0));
    expect(kpis.totalPlots, greaterThanOrEqualTo(4));
    expect(kpis.availablePlots, greaterThanOrEqualTo(1));
    expect(kpis.bookedPlots, greaterThanOrEqualTo(0));
    expect(kpis.activeBookings, greaterThanOrEqualTo(0));

    // Verify sales trend points generated
    expect(state.salesTrend.length, equals(7));

    // Verify payment breakdown initialized
    expect(state.paymentBreakdown.containsKey('Cash'), isTrue);
    expect(state.paymentBreakdown.containsKey('Bank'), isTrue);
    expect(state.paymentBreakdown.containsKey('UPI'), isTrue);

    // Verify plot status distribution
    expect(state.plotStatusCounts.containsKey('Available'), isTrue);
  });

  test('DashboardCubit correctly switches periods (7D, 30D, MONTH)', () async {
    await cubit.load(period: '7D');
    expect(cubit.state.salesTrend.length, equals(7));

    await cubit.load(period: '30D');
    expect(cubit.state.salesTrend.length, equals(30));

    await cubit.load(period: 'MONTH');
    expect(cubit.state.salesTrend.length, equals(DateTime.now().day));
  });
}
