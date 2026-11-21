import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_inventory/core/theme/app_colors.dart';
import 'package:mini_pos_inventory/core/widgets/widgets.dart';
import 'package:mini_pos_inventory/domain/entities/app_entities.dart';
import 'package:mini_pos_inventory/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:mini_pos_inventory/features/dashboard/presentation/widgets/dashboard_kpi_grid.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

void main() {
  group('DARVI PHASE 4.1 — DASHBOARD, PRODUCTS & INVENTORY UI INTEGRATION TESTS', () {
    testWidgets('1. DashboardKpiGrid renders real-time KPI data using AppStatGrid & AppStatCard',
        (tester) async {
      const kpis = DashboardKpiData(
        todaySales: 15450.0,
        monthSales: 345000.0,
        todayCollections: 12500.0,
        todayInvoices: 18,
        monthInvoices: 412,
        totalCustomers: 85,
        totalReceivables: 42000.0,
        totalPayables: 68000.0,
        inventoryValuation: 215000.0,
        monthlyExpenses: 45000.0,
        availablePlots: 12,
        bookedPlots: 8,
        totalPlots: 20,
        activeBookings: 6,
        activeLeads: 24,
        totalProducts: 142,
        lowStockProductsCount: 3,
        averageBillValue: 858.33,
        totalTransactions: 412,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardKpiGrid(kpis: kpis),
            ),
          ),
        ),
      );

      // Verify header and summary text
      expect(find.text('Business Overview & Real-Time KPIs'), findsOneWidget);
      expect(find.text('412 Total Bills'), findsOneWidget);

      // Verify that AppStatGrid is present
      expect(find.byType(AppStatGrid), findsOneWidget);

      // Verify key stat cards
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.text('Monthly Sales'), findsOneWidget);
      expect(find.text('Average Bill Value'), findsOneWidget);
      expect(find.text('Catalog Products'), findsOneWidget);
      expect(find.text('Low Stock Alerts'), findsOneWidget);
      expect(find.text('Inventory Valuation'), findsOneWidget);
      expect(find.text('Customer Receivables'), findsOneWidget);
      expect(find.text('Supplier Payables'), findsOneWidget);

      // Verify values
      expect(find.text('142'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('2. Products screen components render AppStatGrid, AppFilterBar and AppBadge',
        (tester) async {
      final sampleProducts = [
        const ProductView(
          id: 1,
          name: 'Organic Neem Oil 1L',
          sku: 'DAR-NEEM-01',
          barcode: '8901234567890',
          categoryId: 1,
          categoryName: 'Bio Fertilizers',
          cost: 250.0,
          price: 350.0,
          stockQty: 45,
          lowStockThreshold: 10,
          unit: 'bottle',
          notes: 'Cold pressed',
          gstRate: 5.0,
          isActive: true,
        ),
        const ProductView(
          id: 2,
          name: 'DAP Fertilizer 50kg',
          sku: 'DAR-DAP-50',
          barcode: '8901234567891',
          categoryId: 2,
          categoryName: 'Chemical Fertilizers',
          cost: 1200.0,
          price: 1350.0,
          stockQty: 4,
          lowStockThreshold: 15,
          unit: 'bag',
          notes: 'High demand',
          gstRate: 12.0,
          isActive: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AppStatGrid(
                    children: [
                      const AppStatCard(
                        title: 'Total Products',
                        value: '2',
                        subtitle: 'Catalog items',
                        icon: TablerIcons.package,
                        accentColor: AppColors.primary,
                      ),
                      const AppStatCard(
                        title: 'Low Stock Items',
                        value: '1',
                        subtitle: 'Reorder required',
                        icon: TablerIcons.alertTriangle,
                        accentColor: AppColors.warning,
                      ),
                    ],
                  ),
                  AppFilterBar(
                    searchHint: 'Search products...',
                    filterOptions: const [
                      FilterOption(id: 'all', label: 'All Items', badge: '2'),
                      FilterOption(id: 'low_stock', label: 'Low Stock', badge: '1'),
                    ],
                    selectedFilterId: 'all',
                  ),
                  AppDataTable<ProductView>(
                    columns: [
                      AppDataColumn<ProductView>(
                        title: 'Product',
                        cellBuilder: (ctx, p, idx) => Text(p.name),
                      ),
                      AppDataColumn<ProductView>(
                        title: 'Status',
                        cellBuilder: (ctx, p, idx) => p.isLowStock
                            ? const AppBadge.warning(label: 'Low Stock')
                            : const AppBadge.success(label: 'In Stock'),
                      ),
                    ],
                    items: sampleProducts,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify that stat cards are rendered
      expect(find.text('Total Products'), findsOneWidget);
      expect(find.text('Low Stock Items'), findsOneWidget);

      // Verify filter bar
      expect(find.text('All Items'), findsOneWidget);

      // Verify table rows and badges
      expect(find.text('Organic Neem Oil 1L'), findsOneWidget);
      expect(find.text('DAP Fertilizer 50kg'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('Low Stock'), findsNWidgets(2));
    });

    testWidgets('3. Inventory Operations tabs and stock movements ledger table render',
        (tester) async {
      final sampleMovements = [
        StockMovementView(
          id: 1,
          productId: 1,
          productName: 'Organic Neem Oil 1L',
          productSku: 'DAR-NEEM-01',
          type: 'inward',
          qtyChange: 50,
          reason: 'Supplier purchase PO-8821',
          balanceAfter: 50,
          createdAt: DateTime(2026, 11, 8, 10, 30),
        ),
        StockMovementView(
          id: 2,
          productId: 1,
          productName: 'Organic Neem Oil 1L',
          productSku: 'DAR-NEEM-01',
          type: 'sale',
          qtyChange: -5,
          reason: 'POS Bill #INV-1002',
          balanceAfter: 45,
          createdAt: DateTime(2026, 11, 8, 11, 45),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AppDataTable<StockMovementView>(
                    columns: [
                      AppDataColumn<StockMovementView>(
                        title: 'Product',
                        cellBuilder: (ctx, m, idx) => Text(m.productName),
                      ),
                      AppDataColumn<StockMovementView>(
                        title: 'Type',
                        cellBuilder: (ctx, m, idx) => m.type == 'inward'
                            ? const AppBadge.success(label: 'INWARD (+)')
                            : const AppBadge.info(label: 'SALE (-)'),
                      ),
                      AppDataColumn<StockMovementView>(
                        title: 'Qty Change',
                        cellBuilder: (ctx, m, idx) => Text('${m.qtyChange}'),
                      ),
                    ],
                    items: sampleMovements,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify movements ledger table elements
      expect(find.text('Organic Neem Oil 1L'), findsNWidgets(2));
      expect(find.text('INWARD (+)'), findsOneWidget);
      expect(find.text('SALE (-)'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
    });
  });
}
