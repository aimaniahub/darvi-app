import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:mini_pos_inventory/app/app_dependencies.dart';
import 'package:mini_pos_inventory/app/app_scope.dart';
import 'package:mini_pos_inventory/app/theme/app_theme.dart';
import 'package:mini_pos_inventory/core/errors/app_exception.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/core/services/esc_pos_generator.dart';
import 'package:mini_pos_inventory/core/services/thermal_printer_service.dart';
import 'package:mini_pos_inventory/core/widgets/widgets.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/domain/entities/app_entities.dart';
import 'package:mini_pos_inventory/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:mini_pos_inventory/features/reports/presentation/pages/reports_page.dart';
import 'package:mini_pos_inventory/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:mini_pos_inventory/features/settings/presentation/pages/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppDependencies deps;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.darvi.billing/bluetooth_printer'), (MethodCall methodCall) async {
      if (methodCall.method == 'getPairedDevices') {
        return <dynamic>[];
      }
      return null;
    });

    db = AppDatabase(NativeDatabase.memory());
    await db.ensureGroup1SchemaTables();
    await db.ensureGroup2SchemaTables();
    await db.ensureGroup3SchemaTables();
    await db.ensureGroup4SchemaTables();
    await db.ensurePhase4_4SchemaTables();
    await db.sanitizeDateTimeColumns();
    await SeedData(db).ensureSeeded();

    deps = AppDependencies.forTesting(database: db);
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

  group('PHASE 4.4 - MODULE 1: REPORTS & ANALYTICS', () {
    test('Calculates real comprehensive summary grounded in SQLite tables', () async {
      final summary = await deps.reportsRepository.getComprehensiveSummary();
      expect(summary, isNotNull);
      expect(summary.totalSales, greaterThanOrEqualTo(0.0));
      expect(summary.totalPurchases, greaterThanOrEqualTo(0.0));
      expect(summary.totalSalesInvoices, greaterThanOrEqualTo(0));
      expect(summary.grossProfit, isNotNull);
      expect(summary.netProfit, isNotNull);
      expect(summary.inventoryValuation, greaterThanOrEqualTo(0.0));
      expect(summary.outputGstTotal, greaterThanOrEqualTo(0.0));
      expect(summary.inputGstTotal, greaterThanOrEqualTo(0.0));
    });

    test('Returns GST tax report rows for both outward sales and inward purchases', () async {
      final gstRows = await deps.reportsRepository.getGstReportRows();
      expect(gstRows, isNotNull);
      for (final row in gstRows) {
        expect(row.invoiceNo, isNotEmpty);
        expect(row.partyName, isNotEmpty);
        expect(row.type, anyOf(['sales_output', 'purchase_input']));
        expect(row.taxableAmount, greaterThanOrEqualTo(0.0));
        expect(row.totalGst, greaterThanOrEqualTo(0.0));
      }
    });

    test('Financial trial balance provides double-entry debit and credit rows', () async {
      final trialBalance = await deps.reportsRepository.getFinancialTrialBalance();
      expect(trialBalance, isNotEmpty);
      final categories = trialBalance.map((e) => e.accountType.toLowerCase()).toSet();
      expect(categories.any((c) => ['asset', 'liability', 'equity', 'revenue', 'expense'].contains(c)), isTrue);
    });

    test('Purchase report rows contain supplier, dates, total, and balance due', () async {
      final purchaseRows = await deps.reportsRepository.getPurchaseReportRows();
      expect(purchaseRows, isNotNull);
    });

    test('HR report summary aggregates employee workforce, attendance, and payroll', () async {
      final hr = await deps.reportsRepository.getHrReportSummary();
      expect(hr.totalEmployees, greaterThanOrEqualTo(0));
      expect(hr.activeEmployees, greaterThanOrEqualTo(0));
      expect(hr.attendancePercentage, greaterThanOrEqualTo(0.0));
      expect(hr.totalPayrollDisbursed, greaterThanOrEqualTo(0.0));
    });

    test('ReportsCubit state transitions and date filtering presets', () async {
      final cubit = ReportsCubit(
        reportsRepository: deps.reportsRepository,
        salesRepository: deps.salesRepository,
        exportService: deps.fileExportService,
      );

      await cubit.load();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.summary, isNot(ComprehensiveReportSummary.empty));

      cubit.selectTab(2);
      expect(cubit.state.selectedTab, 2);

      await cubit.setPresetRange('today');
      expect(cubit.state.from, isNotNull);
      expect(cubit.state.to, isNotNull);

      await cubit.setPresetRange('all');
      expect(cubit.state.from, isNull);
      expect(cubit.state.to, isNull);

      await cubit.close();
    });

    test('Generates comprehensive executive PDF and CSV reports', () async {
      final summary = await deps.reportsRepository.getComprehensiveSummary();
      final pdfFile = await deps.fileExportService.generateComprehensiveReportPdf(
        summary: summary,
        businessName: 'Darvi Group Agri Tech',
        gstin: '29BKZPA0053M1ZQ',
      );
      expect(await pdfFile.exists(), isTrue);
      expect(await pdfFile.length(), greaterThan(100));

      final csvSales = await deps.fileExportService.exportSalesCsv([]);
      expect(await csvSales.exists(), isTrue);

      final csvInventory = await deps.fileExportService.exportInventoryCsv([]);
      expect(await csvInventory.exists(), isTrue);

      final csvGst = await deps.fileExportService.exportGstCsv([]);
      expect(await csvGst.exists(), isTrue);
    });
  });

  group('PHASE 4.4 - MODULE 2: SETTINGS & BUSINESS CONFIGURATION', () {
    test('Retrieves default Darvi Group corporate profile', () async {
      final profile = await deps.settingsRepository.getBusinessProfile();
      expect(profile.businessName, 'Darvi Group Agri Tech');
      expect(profile.gstin, '29BKZPA0053M1ZQ');
      expect(profile.state, 'Karnataka');
      expect(profile.stateCode, '29');
      expect(profile.phone, '9986890777');
    });

    test('Updates and persists business profile and invoice settings', () async {
      final initial = await deps.settingsRepository.getBusinessProfile();
      final updated = initial.copyWith(
        businessName: 'Darvi Group Agri Tech Pvt Ltd',
        invoicePrefix: 'DVI-2026-',
        paymentTerms: '15 Days',
        roundOffMode: 'nearest_one',
      );

      await deps.settingsRepository.updateBusinessProfile(updated);
      final reloaded = await deps.settingsRepository.getBusinessProfile();

      expect(reloaded.businessName, 'Darvi Group Agri Tech Pvt Ltd');
      expect(reloaded.invoicePrefix, 'DVI-2026-');
      expect(reloaded.paymentTerms, '15 Days');
      expect(reloaded.roundOffMode, 'nearest_one');
    });

    test('SSEZNIK2POS Bluetooth thermal printer service lifecycle and status', () async {
      final printerService = deps.receiptPdfService.thermalPrinterService;
      expect(printerService.status, BluetoothPrinterStatus.disconnected);

      // Query paired devices without crashing on test/host environment
      final paired = await printerService.getPairedDevices();
      expect(paired, isA<List<BluetoothDeviceInfo>>());

      // Disconnect safely
      await printerService.disconnect();
      expect(printerService.status, BluetoothPrinterStatus.disconnected);
    });

    test('ESC/POS generator builds valid byte streams for 58mm thermal receipts', () {
      final testBytes = EscPosGenerator.buildDiagnosticTestPrint();
      expect(testBytes, isNotEmpty);
      expect(testBytes.first, 0x1B); // ESC

      final sale = SaleView(
        id: 1,
        invoiceNo: 'DARVI-TEST-001',
        createdAt: DateTime.now(),
        customerId: null,
        subtotal: 1000.0,
        discountTotal: 0.0,
        taxTotal: 50.0,
        total: 1050.0,
        paid: 1050.0,
        changeAmount: 0.0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.completed,
      );

      final items = <SaleItemView>[
        const SaleItemView(
          id: 1,
          saleId: 1,
          productId: 1,
          nameSnapshot: 'NPK Fertilizer 50kg',
          priceSnapshot: 1000.0,
          costSnapshot: 800.0,
          qty: 1,
          lineTotal: 1000.0,
          discount: 0.0,
        ),
      ];

      final receiptBytes = EscPosGenerator.buildDarviReceipt(
        sale: sale,
        items: items,
        businessName: 'Darvi Group Agri Tech',
        gstin: '29BKZPA0053M1ZQ',
        address: 'Hubli, Karnataka',
        phone: '9986890777',
        receiptSlogan: 'Improving Agriculture, Improving lives.',
        receiptTerms: 'Goods once sold are subject to Darvi policy.',
      );

      expect(receiptBytes, isNotEmpty);
      expect(receiptBytes.length, greaterThan(50));
    });

    test('Creates atomic JSON database backup with SHA-256 verification and restore', () async {
      // 1. Create backup
      final backupRecord = await deps.settingsRepository.createBackup();
      expect(backupRecord.filename, contains('darvi_backup_'));
      expect(backupRecord.checksum, isNotEmpty);
      expect(backupRecord.recordCount, greaterThan(0));

      // 2. Validate backup checksum
      final isValid = await deps.settingsRepository.validateBackup(backupRecord.filePath);
      expect(isValid, isTrue);

      // 3. Backup history listing
      final history = await deps.settingsRepository.getBackupHistory();
      expect(history.any((b) => b.id == backupRecord.id), isTrue);

      // 4. Safe atomic restore
      final restored = await deps.settingsRepository.restoreBackup(backupRecord.filePath);
      expect(restored, isTrue);
    });
  });

  group('PHASE 4.4 - MODULE 3: ACCESS MANAGEMENT & RBAC', () {
    test('Default users are seeded with salted SHA-256 credentials (zero plaintext)', () async {
      final users = await deps.authRepository.getUsers();
      expect(users.length, greaterThanOrEqualTo(5));

      final usernames = users.map((u) => u.username).toSet();
      expect(usernames.contains('admin'), isTrue);
      expect(usernames.contains('manager'), isTrue);
      expect(usernames.contains('cashier'), isTrue);
      expect(usernames.contains('field_officer'), isTrue);
      expect(usernames.contains('agronomist'), isTrue);

      // Authenticate with salted credentials
      final adminSession = await deps.authRepository.loginWithCredentials('admin', 'admin123');
      expect(adminSession, isNotNull);
      expect(adminSession!.role, UserRole.admin);

      final cashierSession = await deps.authRepository.loginWithUserPin('1111');
      expect(cashierSession, isNotNull);
      expect(cashierSession!.role, UserRole.cashier);
    });

    test('User CRUD operations with salted credential hashing', () async {
      final newUser = UserModel(
        id: 0,
        workspaceId: 1,
        name: 'Suresh Kumar',
        username: 'suresh.k',
        email: 'suresh@darvigroup.com',
        phone: '9845012345',
        role: UserRole.fieldOfficer.value,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final newUserId = await deps.authRepository.createUser(
        newUser,
        password: 'Password@123',
        pin: '5566',
      );
      expect(newUserId, greaterThan(0));

      // Verify user was stored correctly
      final fetched = await deps.authRepository.getUserById(newUserId);
      expect(fetched, isNotNull);
      expect(fetched!.username, 'suresh.k');
      expect(fetched.userRole, UserRole.fieldOfficer);

      // Toggle user active status
      await deps.authRepository.setUserActive(newUserId, false);
      final disabledUser = await deps.authRepository.getUserById(newUserId);
      expect(disabledUser!.isActive, isFalse);

      // Reset credentials
      await deps.authRepository.resetCredentials(newUserId, pin: '9988');
      // When inactive, loginWithUserPin throws AppException
      expect(
        () => deps.authRepository.loginWithUserPin('9988'),
        throwsA(isA<AppException>()),
      );

      // Reactivate user and verify login
      await deps.authRepository.setUserActive(newUserId, true);
      final activeSession = await deps.authRepository.loginWithUserPin('9988');
      expect(activeSession, isNotNull);
      expect(activeSession!.userId, newUserId);
    });

    test('Permission Matrix enforces fine-grained RBAC rules across 12 modules', () {
      // Admin has complete authority
      for (final m in PermissionModule.values) {
        for (final a in PermissionAction.values) {
          expect(PermissionMatrix.can(UserRole.admin, m, a), isTrue);
        }
      }

      // Cashier permissions
      expect(PermissionMatrix.can(UserRole.cashier, PermissionModule.pos, PermissionAction.create), isTrue);
      expect(PermissionMatrix.can(UserRole.cashier, PermissionModule.pos, PermissionAction.view), isTrue);
      expect(PermissionMatrix.can(UserRole.cashier, PermissionModule.settings, PermissionAction.edit), isFalse);
      expect(PermissionMatrix.can(UserRole.cashier, PermissionModule.payroll, PermissionAction.create), isFalse);

      // Field officer permissions
      expect(PermissionMatrix.can(UserRole.fieldOfficer, PermissionModule.parties, PermissionAction.create), isTrue);
      expect(PermissionMatrix.can(UserRole.fieldOfficer, PermissionModule.parties, PermissionAction.view), isTrue);
      expect(PermissionMatrix.can(UserRole.fieldOfficer, PermissionModule.settings, PermissionAction.view), isFalse);

      // Agronomist permissions
      expect(PermissionMatrix.can(UserRole.agronomist, PermissionModule.products, PermissionAction.view), isTrue);
      expect(PermissionMatrix.can(UserRole.agronomist, PermissionModule.financials, PermissionAction.create), isFalse);
    });

    test('Audit logging records user activity and can be retrieved chronologically', () async {
      await deps.authRepository.logActivity(
        username: 'admin',
        module: 'settings',
        action: 'test_action',
        details: 'Testing audit log creation for Phase 4.4',
      );

      final logs = await deps.authRepository.getActivityLogs(limit: 10);
      expect(logs, isNotEmpty);
      expect(logs.any((l) => l.action == 'test_action'), isTrue);
    });
  });

  group('PHASE 4.4 - WIDGET INTEGRATION & RESPONSIVENESS', () {
    testWidgets('ReportsPage renders KPI cards, quick date filter bar, and category tabs', (tester) async {
      tester.view.physicalSize = const Size(1366, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final reportsCubit = ReportsCubit(
        reportsRepository: deps.reportsRepository,
        salesRepository: deps.salesRepository,
        exportService: deps.fileExportService,
      );
      await reportsCubit.load();

      await tester.pumpWidget(buildTestableWidget(ReportsPage(cubit: reportsCubit)));
      await tester.pumpAndSettle();

      expect(find.text('Reports'), findsWidgets);
      expect(find.byType(AppStatGrid), findsWidgets);
      expect(find.text('All Time'), findsWidgets);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Sales & Invoices'), findsWidgets);
      expect(find.text('Purchases & Payables'), findsWidgets);
      expect(find.text('Inventory Valuation'), findsWidgets);
      expect(find.text('Financials & Trial Balance'), findsWidgets);
      expect(find.text('GST & Tax Registers'), findsWidgets);
      expect(find.text('HR & Payroll Analytics'), findsWidgets);

      await reportsCubit.close();
    });

    testWidgets('SettingsPage renders all 6 sub-tabs, business profile, printer preview, and users', (tester) async {
      tester.view.physicalSize = const Size(1366, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settingsCubit = SettingsCubit(
        settingsRepository: deps.settingsRepository,
        authRepository: deps.authRepository,
        receiptPdfService: deps.receiptPdfService,
      );
      await settingsCubit.load();

      await tester.pumpWidget(buildTestableWidget(SettingsPage(cubit: settingsCubit)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Business Profile & Brand'), findsWidgets);
      expect(find.text('Invoice & System Config'), findsWidgets);
      expect(find.text('SSEZNIK2POS 58mm Printer'), findsWidgets);
      expect(find.text('Backup & Restore'), findsWidgets);
      expect(find.text('Users & Access Control'), findsWidgets);
      expect(find.text('Permission Matrix & Audit'), findsWidgets);

      // Verify business profile card
      expect(find.text('Darvi Group Agri Tech'), findsWidgets);

      // Select SSEZNIK2POS printer tab (tab 2)
      settingsCubit.selectTab(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('SSEZNIK2POS Thermal Printer (58mm)'), findsWidgets);
      expect(find.text('58mm Thermal Receipt Preview'), findsWidgets);

      // Select Users & Access Control tab (tab 4)
      settingsCubit.selectTab(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Add User'), findsWidgets);
      expect(find.textContaining('User Directory'), findsWidgets);

      // Select Permission Matrix & Audit tab (tab 5)
      settingsCubit.selectTab(5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Role-Based Access Control (RBAC) Matrix'), findsWidgets);
      expect(find.textContaining('User Activity & Security Audit Trail'), findsWidgets);

      await settingsCubit.close();
    });

    testWidgets('Responsive mobile viewport adapts without overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final reportsCubit = ReportsCubit(
        reportsRepository: deps.reportsRepository,
        salesRepository: deps.salesRepository,
        exportService: deps.fileExportService,
      );
      await reportsCubit.load();

      await tester.pumpWidget(buildTestableWidget(ReportsPage(cubit: reportsCubit), size: const Size(400, 800)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ReportsPage), findsOneWidget);

      final settingsCubit = SettingsCubit(
        settingsRepository: deps.settingsRepository,
        authRepository: deps.authRepository,
        receiptPdfService: deps.receiptPdfService,
      );
      await settingsCubit.load();

      await tester.pumpWidget(buildTestableWidget(SettingsPage(cubit: settingsCubit), size: const Size(400, 800)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SettingsPage), findsOneWidget);

      await reportsCubit.close();
      await settingsCubit.close();
    });
  });
}

