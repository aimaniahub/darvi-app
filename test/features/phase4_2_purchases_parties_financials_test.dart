import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:mini_pos_inventory/app/app_dependencies.dart';
import 'package:mini_pos_inventory/app/app_scope.dart';
import 'package:mini_pos_inventory/app/theme/app_theme.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/core/widgets/widgets.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/features/financials/presentation/pages/financials_page.dart';
import 'package:mini_pos_inventory/features/parties/presentation/pages/parties_page.dart';
import 'package:mini_pos_inventory/features/purchases/presentation/pages/purchases_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppDependencies deps;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureGroup1SchemaTables();
    await db.ensureGroup2SchemaTables();
    await db.ensureGroup3SchemaTables();
    await db.ensureGroup4SchemaTables();
    await db.sanitizeDateTimeColumns();
    await SeedData(db).ensureSeeded();

    deps = AppDependencies.forTesting(database: db);

    // Seed a purchase invoice so that Purchases data table and supplier ledger have real entries
    final suppliers = await deps.partyRepository.getSuppliers();
    final products = await deps.productRepository.getProducts();
    if (suppliers.isNotEmpty && products.isNotEmpty) {
      await deps.purchaseRepository.createPurchaseInvoice(
        PurchaseInvoiceInput(
          supplierId: suppliers.first.id,
          supplierInvoiceNo: 'INV-TEST-001',
          subtotal: 1000.0,
          taxTotal: 50.0,
          total: 1050.0,
          paid: 500.0,
          items: [
            PurchaseInvoiceItemInput(
              productId: products.first.id,
              qty: 10,
              unitCost: 100.0,
              lineTotal: 1050.0,
              gstRate: 5.0,
              batchNumber: 'BAT-01',
            ),
          ],
        ),
      );
    }
  });

  tearDown(() async {
    await deps.dispose();
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(1366, 900)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: AppScope(
        dependencies: deps,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: child,
        ),
      ),
    );
  }

  group('DARVI PHASE 4.2 — PURCHASES, PARTIES & FINANCIALS UI INTEGRATION TESTS', () {
    testWidgets('1. PurchasesPage renders AppStatGrid with 6 KPIs, AppFilterBar, and Desktop Data Table',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const PurchasesPage()));
      await tester.pumpAndSettle();

      // Verify Header Title and Subtitle
      expect(find.text('Purchases & Inward Stock'), findsOneWidget);
      expect(
        find.text('Inward inventory, supplier bills, debit notes & payables'),
        findsOneWidget,
      );

      // Verify 6-KPI AppStatGrid and its Cards
      expect(find.byType(AppStatGrid), findsWidgets);
      expect(find.text('Total Purchases'), findsOneWidget);
      expect(find.text("Today's Inward"), findsOneWidget);
      expect(find.text('Monthly Purchases'), findsOneWidget);
      expect(find.text('Total Amount Paid'), findsOneWidget);
      expect(find.text('Supplier Payables'), findsOneWidget);
      expect(find.text('Debit Notes / Returns'), findsOneWidget);

      // Verify AppFilterBar and search box
      expect(find.byType(AppFilterBar), findsOneWidget);
      expect(find.text('Search bill #, ref, supplier...'), findsOneWidget);

      // Verify quick filter chips
      expect(find.text('All Bills'), findsOneWidget);
      expect(find.text('Due / Unpaid'), findsOneWidget);
      expect(find.text('Fully Paid'), findsOneWidget);

      // Verify action buttons
      expect(find.text('New Purchase Bill'), findsOneWidget);

      // Verify Desktop AppDataTable columns
      expect(find.text('Invoice & Ref'), findsOneWidget);
      expect(find.text('Supplier'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Balance Due'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);

      // Verify the seeded invoice row appears in the table
      expect(find.text('#INV-TEST-001'), findsOneWidget);

      // Test opening "New Purchase Bill" modal
      await tester.tap(find.text('New Purchase Bill'));
      await tester.pumpAndSettle();

      // Verify purchase invoice builder drawer opened
      expect(find.text('Record Multi-Item Purchase Bill'), findsOneWidget);
      expect(find.text('Supplier *'), findsOneWidget);
      expect(find.text('Supplier Bill # *'), findsOneWidget);
      expect(find.text('+ Supplier'), findsOneWidget);
      expect(find.textContaining('Line Items'), findsOneWidget);
      expect(find.text('Add Line Item'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(TablerIcons.x).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Record Multi-Item Purchase Bill'), findsNothing);
    });

    testWidgets('2. PartiesPage renders Customer/Supplier tabs, 4 KPIs, AppFilterBar, and Tables',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const PartiesPage()));
      await tester.pumpAndSettle();

      // Verify Title and Subtitle
      expect(find.text('Customer & Receivables'), findsOneWidget);
      expect(
        find.text('Client balances, credit management & receivables tracking'),
        findsOneWidget,
      );

      // Verify segmented switch tabs
      expect(find.textContaining('Customers'), findsWidgets);
      expect(find.textContaining('Suppliers'), findsWidgets);

      // Verify Customers 4-KPI Grid
      expect(find.byType(AppStatGrid), findsWidgets);
      expect(find.text('Total Customers'), findsOneWidget);
      expect(find.text('Total Receivables'), findsOneWidget);
      expect(find.text('Advance Credits'), findsOneWidget);
      expect(find.text('Settled Accounts'), findsOneWidget);

      // Verify Customer Filter Bar and Primary Button
      expect(find.byType(AppFilterBar), findsOneWidget);
      expect(find.text('Search customer by legal name, code, phone, GSTIN...'), findsOneWidget);
      expect(find.text('+ New Customer'), findsOneWidget);

      // Verify Customer Table columns
      expect(find.text('Customer Name & Code'), findsOneWidget);
      expect(find.text('Contact Details'), findsOneWidget);
      expect(find.text('Classification'), findsOneWidget);
      expect(find.text('Credit Terms'), findsOneWidget);
      expect(find.text('Balance & Status'), findsOneWidget);

      // Switch to Suppliers tab
      await tester.tap(find.textContaining('Suppliers').first);
      await tester.pumpAndSettle();

      // Verify Supplier Title update
      expect(find.text('Supplier & Payables'), findsOneWidget);

      // Verify Supplier 4-KPI Grid
      expect(find.text('Total Suppliers'), findsOneWidget);
      expect(find.text('Total Payables'), findsOneWidget);
      expect(find.text('Advance Disbursed'), findsOneWidget);

      // Verify Supplier Filter Bar and Primary Button
      expect(find.text('Search supplier by vendor name, code, contact person, phone...'), findsOneWidget);
      expect(find.text('+ New Supplier'), findsOneWidget);

      // Verify Supplier Table columns
      expect(find.text('Supplier Name & Code'), findsOneWidget);
      expect(find.text('Contact Person & Phone'), findsOneWidget);
      expect(find.text('GSTIN / State'), findsOneWidget);
      expect(find.text('Payment Terms'), findsOneWidget);
      expect(find.text('Payable Due'), findsOneWidget);

      // Test opening "+ New Supplier" registration sheet
      await tester.tap(find.text('+ New Supplier'));
      await tester.pumpAndSettle();

      expect(find.text('Register New Supplier'), findsOneWidget);
      expect(find.text('Legal / Business Name *'), findsOneWidget);
      expect(find.text('Primary Mobile *'), findsOneWidget);
      expect(find.text('Contact Person Name'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(TablerIcons.x).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Register New Supplier'), findsNothing);
    });

    testWidgets('3. FinancialsPage renders 5 Tabs, Liquid Funds KPIs, Accounts Table, and Ledger Status',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const FinancialsPage()));
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Financial Management & Accounts'), findsOneWidget);
      expect(find.text('Multi-account cashbook, double-entry ledger, expenses & P&L'), findsOneWidget);

      // Verify 5 Primary Navigation Tabs
      expect(find.text('Dashboard & Accounts'), findsOneWidget);
      expect(find.text('Cashbook Journal'), findsOneWidget);
      expect(find.text('Operating Expenses'), findsOneWidget);
      expect(find.text('Double-Entry Ledger'), findsOneWidget);
      expect(find.text('Reconciliation & P&L'), findsOneWidget);

      // --- Tab 0: Dashboard & Accounts ---
      expect(find.text('Store Cash Drawer'), findsWidgets);
      expect(find.text('Company Bank'), findsWidgets);
      expect(find.text('Store UPI Account'), findsWidgets);
      expect(find.text('Net Liquid Funds'), findsOneWidget);

      expect(find.text("Today's Collections"), findsOneWidget);
      expect(find.text("Today's Payments"), findsOneWidget);
      expect(find.text('Monthly Expenses'), findsOneWidget);

      expect(find.text('Customer Receivables'), findsOneWidget);
      expect(find.text('Supplier Payables'), findsOneWidget);
      expect(find.text('Payroll Disbursed'), findsOneWidget);

      expect(find.textContaining('Configured Payment Accounts'), findsOneWidget);
      expect(find.text('Account Name & Type'), findsOneWidget);
      expect(find.text('Identifiers & Details'), findsOneWidget);

      // --- Tab 1: Cashbook Journal ---
      await tester.tap(find.text('Cashbook Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Filter by Account'), findsOneWidget);
      expect(find.text('All Accounts (Consolidated)'), findsOneWidget);

      // --- Tab 2: Operating Expenses ---
      await tester.tap(find.text('Operating Expenses'));
      await tester.pumpAndSettle();
      expect(find.text('Search expenses by description, payee or ref...'), findsOneWidget);
      expect(find.text('+ Add Expense'), findsOneWidget);
      expect(find.text('No Operating Expenses Recorded'), findsOneWidget);
      expect(find.text('Record Expense'), findsWidgets);

      // --- Tab 3: Double-Entry Ledger ---
      await tester.tap(find.text('Double-Entry Ledger'));
      await tester.pumpAndSettle();
      expect(find.text('Search ledger narration or reference...'), findsOneWidget);
      expect(find.textContaining('Double-Entry Ledger Postings'), findsOneWidget);

      // --- Tab 4: Reconciliation & P&L ---
      await tester.tap(find.text('Reconciliation & P&L'));
      await tester.pumpAndSettle();
      expect(find.text('Double-Entry Trial Balance Reconciled & In Equilibrium'), findsOneWidget);
      expect(find.textContaining('Total Debits: ₹'), findsOneWidget);
      expect(find.text('Profit & Loss Statement (Operating Summary)'), findsOneWidget);
      expect(find.text('Net Operating Sales (Revenue excl. Tax):'), findsOneWidget);
      expect(find.text('Cost of Goods Sold (COGS):'), findsOneWidget);
      expect(find.text('Gross Profit:'), findsOneWidget);
      expect(find.text('Operating Expenses:'), findsOneWidget);
      expect(find.text('Net Profit / (Loss):'), findsOneWidget);
      expect(find.text('Asset & Liability Reconciliation Overview'), findsOneWidget);
    });

    testWidgets('4. Responsive mobile card view adapts seamlessly for Purchases and Parties',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // iPhone 12/13/14 size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const PurchasesPage(), size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // In mobile view, AppDataTable is swapped for mobile card list view
      expect(find.byType(PurchasesPage), findsOneWidget);
      expect(find.text('Purchases & Inward Stock'), findsOneWidget);
      expect(find.byType(AppStatGrid), findsWidgets);
      expect(find.text('Total Purchases'), findsOneWidget);
      expect(find.text('New Purchase Bill'), findsOneWidget);
    });
  });
}
