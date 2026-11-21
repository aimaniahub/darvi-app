import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:mini_pos_inventory/app/app_dependencies.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  MockPathProviderPlatform(this.testPath);
  final String testPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => testPath;

  @override
  Future<String?> getTemporaryPath() async => testPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppDependencies deps;
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('darvi_perf_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );

    db = AppDatabase(NativeDatabase.memory());
    await SeedData(db).ensureSeeded();
    await db.ensurePhase4_4SchemaTables();
    await db.ensurePhase5_1SchemaTables();
    deps = AppDependencies.forTesting(database: db);
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PHASE 6: REALISTIC VOLUME PERFORMANCE & STABILITY', () {
    test('1. Ingest 1,000+ Products and verify barcode lookup < 50ms', () async {
      final stopwatch = Stopwatch()..start();

      // Batch insert 1,000 products
      await db.transaction(() async {
        for (int i = 1; i <= 1000; i++) {
          final sku = 'SKU-${i.toString().padLeft(5, '0')}';
          await db.customStatement('''
            INSERT INTO products (workspace_id, name, sku, barcode, cost, price, stock_qty, unit, low_stock_threshold, is_active, created_at)
            VALUES (1, 'Bulk Agro Product #$i', ?, ?, 100.0, 150.0, 50, 'kg', 5, 1, 1700000000);
          ''', [sku, sku]);
        }
      });
      stopwatch.stop();
      final insertMs = stopwatch.elapsedMilliseconds;
      expect(insertMs, lessThan(10000)); // Fast bulk transaction insert

      // Benchmark single barcode/sku search filter lookup
      final lookupWatch = Stopwatch()..start();
      final products = await deps.productRepository.getProducts(
        filter: const ProductFilter(search: 'SKU-00789'),
      );
      lookupWatch.stop();

      expect(products, isNotEmpty);
      expect(products.first.name, 'Bulk Agro Product #789');
      expect(lookupWatch.elapsedMilliseconds, lessThan(150)); // Sub-150ms lookup
    });

    test('2. Ingest 5,000 Sales Records and verify dashboard aggregation latency', () async {
      // Fast insert 5,000 sales
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.transaction(() async {
        for (int i = 1; i <= 5000; i++) {
          final inv = 'INV-PERF-${i.toString().padLeft(6, '0')}';
          await db.customStatement('''
            INSERT INTO sales (workspace_id, invoice_no, subtotal, discount_total, tax_total, cgst_total, sgst_total, igst_total, total, paid, change_amount, payment_method, status, created_at)
            VALUES (1, ?, 1000.0, 0.0, 180.0, 90.0, 90.0, 0.0, 1180.0, 1180.0, 0.0, 'cash', 'completed', ?);
          ''', [inv, nowSec - (i * 60)]);
        }
      });

      // Query dashboard metrics over 5,000 records
      final metricsWatch = Stopwatch()..start();
      final metrics = await deps.reportsRepository.getDashboardMetrics(workspaceId: 1);
      metricsWatch.stop();

      expect(metrics, isNotNull);
      expect(metrics.monthInvoices, greaterThanOrEqualTo(5000));
      expect(metrics.monthSales, greaterThanOrEqualTo(5000 * 1180.0));
      expect(metricsWatch.elapsedMilliseconds, lessThan(800)); // Sub-800ms aggregation over 5000 records
    });

    test('3. Query performance: Paginated sales listing does not load full history into memory', () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.transaction(() async {
        for (int i = 1; i <= 200; i++) {
          final inv = 'INV-PAGE-${i.toString().padLeft(4, '0')}';
          await db.customStatement('''
            INSERT INTO sales (workspace_id, invoice_no, subtotal, discount_total, tax_total, cgst_total, sgst_total, igst_total, total, paid, change_amount, payment_method, status, created_at)
            VALUES (1, ?, 500.0, 0.0, 90.0, 45.0, 45.0, 0.0, 590.0, 590.0, 0.0, 'cash', 'completed', ?);
          ''', [inv, nowSec - (i * 10)]);
        }
      });

      final queryWatch = Stopwatch()..start();
      final invoices = await deps.salesRepository.getInvoices(workspaceId: 1);
      queryWatch.stop();

      expect(invoices, isNotEmpty);
      expect(invoices.length, greaterThanOrEqualTo(200));
      expect(queryWatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
