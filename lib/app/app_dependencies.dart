import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/services/barcode_scanner_service_impl.dart';
import '../core/services/file_export_service.dart';
import '../core/services/receipt_pdf_service.dart';
import '../core/services/stub_services.dart';
import '../core/state/app_cubit.dart';
import '../data/local/db/app_database.dart';
import '../data/local/seed/seed_data.dart';
import '../data/repositories/local_repositories.dart';
import '../domain/repositories/repositories.dart';

class AppDependencies {
  AppDependencies._({
    required this.rootNavigatorKey,
    required this.database,
    required this.authRepository,
    required this.settingsRepository,
    required this.productRepository,
    required this.salesRepository,
    required this.reportsRepository,
    required this.partyRepository,
    required this.ledgerRepository,
    required this.accountRepository,
    required this.purchaseRepository,
    required this.expenseRepository,
    required this.employeeRepository,
    required this.plotRepository,
    required this.crmRepository,
    required this.quotationRepository,
    required this.bookingRepository,
    required this.deliveryRepository,
    required this.syncService,
    required this.printerService,
    required this.barcodeScannerService,
    required this.fileExportService,
    required this.receiptPdfService,
    required this.appCubit,
  });

  final GlobalKey<NavigatorState> rootNavigatorKey;
  final AppDatabase database;

  final AuthRepository authRepository;
  final SettingsRepository settingsRepository;
  final ProductRepository productRepository;
  final SalesRepository salesRepository;
  final ReportsRepository reportsRepository;
  final PartyRepository partyRepository;
  final LedgerRepository ledgerRepository;
  final AccountRepository accountRepository;
  final PurchaseRepository purchaseRepository;
  final ExpenseRepository expenseRepository;
  final EmployeeRepository employeeRepository;
  final PlotRepository plotRepository;
  final CrmRepository crmRepository;
  final QuotationRepository quotationRepository;
  final BookingRepository bookingRepository;
  final DeliveryRepository deliveryRepository;

  final SyncService syncService;
  final PrinterService printerService;
  final BarcodeScannerService barcodeScannerService;
  final FileExportService fileExportService;
  final ReceiptPdfService receiptPdfService;

  final AppCubit appCubit;

  factory AppDependencies.forTesting({
    required AppDatabase database,
    GlobalKey<NavigatorState>? rootNavigatorKey,
  }) {
    final navKey = rootNavigatorKey ?? GlobalKey<NavigatorState>();
    final ledgerRepository = LocalLedgerRepository(database);
    final accountRepository = LocalAccountRepository(database, ledgerRepository);
    final purchaseRepository = LocalPurchaseRepository(database, ledgerRepository);
    final expenseRepository = LocalExpenseRepository(database, ledgerRepository);
    final employeeRepository = LocalEmployeeRepository(database, ledgerRepository);
    final plotRepository = LocalPlotRepository(database);
    final crmRepository = LocalCrmRepository(database);
    final quotationRepository = LocalQuotationRepository(database, ledgerRepository);
    final bookingRepository = LocalBookingRepository(database, ledgerRepository);
    final deliveryRepository = LocalDeliveryRepository(database);
    final settingsRepository = LocalSettingsRepository(database);
    final productRepository = LocalProductRepository(database);
    final authRepository = LocalAuthRepository(database);
    final salesRepository = LocalSalesRepository(database, ledgerRepository);
    final partyRepository = LocalPartyRepository(database, ledgerRepository);
    final reportsRepository = LocalReportsRepository(database, productRepository);

    final barcodeScannerService = RouteBarcodeScannerService(navKey);
    final fileExportService = FileExportService();
    final printerService = StubPrinterService();
    final receiptPdfService = ReceiptPdfService(printerService: printerService);
    final syncService = FakeSyncService();

    final appCubit = AppCubit(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
    );

    return AppDependencies._(
      rootNavigatorKey: navKey,
      database: database,
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      productRepository: productRepository,
      salesRepository: salesRepository,
      reportsRepository: reportsRepository,
      partyRepository: partyRepository,
      ledgerRepository: ledgerRepository,
      accountRepository: accountRepository,
      purchaseRepository: purchaseRepository,
      expenseRepository: expenseRepository,
      employeeRepository: employeeRepository,
      plotRepository: plotRepository,
      crmRepository: crmRepository,
      quotationRepository: quotationRepository,
      bookingRepository: bookingRepository,
      deliveryRepository: deliveryRepository,
      syncService: syncService,
      printerService: printerService,
      barcodeScannerService: barcodeScannerService,
      fileExportService: fileExportService,
      receiptPdfService: receiptPdfService,
      appCubit: appCubit,
    );
  }

  static Future<AppDependencies> create() async {
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    AppDatabase db = AppDatabase();
    try {
      await db.ensureGroup1SchemaTables();
      await db.ensureGroup2SchemaTables();
      await db.ensureGroup3SchemaTables();
      await db.ensureGroup4SchemaTables();
      await db.sanitizeDateTimeColumns();
      await SeedData(db).ensureSeeded();
    } catch (e, stack) {
      debugPrint('Initial SeedData failed: $e\n$stack. Auto-healing DateTime columns and retrying...');
      try {
        await db.ensureGroup1SchemaTables();
        await db.ensureGroup2SchemaTables();
        await db.ensureGroup3SchemaTables();
        await db.ensureGroup4SchemaTables();
        await db.sanitizeDateTimeColumns();
        await SeedData(db).ensureSeeded();
      } catch (inner) {
        debugPrint('Auto-heal seed retry failed: $inner. Resetting corrupted database...');
        try {
          await db.close();
          final dbFolder = await getApplicationDocumentsDirectory();
          final file = File(p.join(dbFolder.path, 'mini_pos_inventory.sqlite'));
          if (await file.exists()) {
            final backup = File(p.join(dbFolder.path, 'corrupted_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite'));
            try {
              await file.rename(backup.path);
            } catch (_) {
              await file.delete();
            }
          }
          db = AppDatabase();
          await db.ensureGroup1SchemaTables();
          await db.ensureGroup2SchemaTables();
          await db.ensureGroup3SchemaTables();
          await db.ensureGroup4SchemaTables();
          await db.sanitizeDateTimeColumns();
          await SeedData(db).ensureSeeded();
        } catch (fatal) {
          debugPrint('Fatal database recovery error: $fatal');
          rethrow;
        }
      }
    }

    final ledgerRepository = LocalLedgerRepository(db);
    final accountRepository = LocalAccountRepository(db, ledgerRepository);
    final purchaseRepository = LocalPurchaseRepository(db, ledgerRepository);
    final expenseRepository = LocalExpenseRepository(db, ledgerRepository);
    final employeeRepository = LocalEmployeeRepository(db, ledgerRepository);
    final plotRepository = LocalPlotRepository(db);
    final crmRepository = LocalCrmRepository(db);
    final quotationRepository = LocalQuotationRepository(db, ledgerRepository);
    final bookingRepository = LocalBookingRepository(db, ledgerRepository);
    final deliveryRepository = LocalDeliveryRepository(db);
    final settingsRepository = LocalSettingsRepository(db);
    final productRepository = LocalProductRepository(db);
    final authRepository = LocalAuthRepository(db);
    final salesRepository = LocalSalesRepository(db, ledgerRepository);
    final partyRepository = LocalPartyRepository(db, ledgerRepository);
    final reportsRepository = LocalReportsRepository(db, productRepository);

    final barcodeScannerService = RouteBarcodeScannerService(rootNavigatorKey);
    final fileExportService = FileExportService();
    final printerService = StubPrinterService();
    final receiptPdfService = ReceiptPdfService(printerService: printerService);
    final syncService = FakeSyncService();

    final appCubit = AppCubit(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
    )..initialize();

    return AppDependencies._(
      rootNavigatorKey: rootNavigatorKey,
      database: db,
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      productRepository: productRepository,
      salesRepository: salesRepository,
      reportsRepository: reportsRepository,
      partyRepository: partyRepository,
      ledgerRepository: ledgerRepository,
      accountRepository: accountRepository,
      purchaseRepository: purchaseRepository,
      expenseRepository: expenseRepository,
      employeeRepository: employeeRepository,
      plotRepository: plotRepository,
      crmRepository: crmRepository,
      quotationRepository: quotationRepository,
      bookingRepository: bookingRepository,
      deliveryRepository: deliveryRepository,
      syncService: syncService,
      printerService: printerService,
      barcodeScannerService: barcodeScannerService,
      fileExportService: fileExportService,
      receiptPdfService: receiptPdfService,
      appCubit: appCubit,
    );
  }

  Future<void> dispose() async {
    await appCubit.close();
    await database.close();
  }
}
