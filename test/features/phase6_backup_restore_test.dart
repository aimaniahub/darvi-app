import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:mini_pos_inventory/app/app_dependencies.dart';
import 'package:mini_pos_inventory/core/errors/app_exception.dart';
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
    tempDir = Directory.systemTemp.createTempSync('darvi_backup_test_');
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

  group('PHASE 6: DATABASE BACKUP & RESTORE RIGOROUS VALIDATION', () {
    test('1. Full Lifecycle: Transactions -> Backup -> Mutations -> Restore -> Exact State Match', () async {
      // 1. Setup initial state with custom product and sale
      final productId = await deps.productRepository.upsertProduct(
        const ProductUpsertInput(
          name: 'Organic Plant Booster 1L',
          sku: 'OPB-1L',
          cost: 200.0,
          price: 350.0,
          stockQty: 50,
          unit: 'bottle',
        ),
      );

      final checkoutResult = await deps.salesRepository.checkout(
        SaleCheckoutInput(
          items: [
            CartItem(
              productId: productId,
              sku: 'OPB-1L',
              name: 'Organic Plant Booster 1L',
              price: 350.0,
              qty: 5,
              cost: 200.0,
            ),
          ],
          paid: 1750.0,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final initialSales = await deps.salesRepository.getInvoices();
      final initialProduct = await deps.productRepository.getProduct(productId);
      expect(initialProduct!.stockQty, 45); // 50 - 5
      expect(initialSales.any((s) => s.id == checkoutResult.saleId), isTrue);

      // 2. Generate backup
      final backupRecord = await deps.settingsRepository.createBackup();
      expect(backupRecord.status, 'valid');
      expect(backupRecord.recordCount, greaterThan(0));
      expect(File(backupRecord.filePath).existsSync(), isTrue);

      // 3. Mutate database state (add another product, deplete stock, create another checkout)
      await deps.productRepository.upsertProduct(
        const ProductUpsertInput(
          name: 'Temporary Item that should vanish after restore',
          sku: 'TMP-001',
          cost: 50.0,
          price: 100.0,
          stockQty: 10,
          unit: 'pcs',
        ),
      );

      await deps.salesRepository.checkout(
        SaleCheckoutInput(
          items: [
            CartItem(
              productId: productId,
              sku: 'OPB-1L',
              name: 'Organic Plant Booster 1L',
              price: 350.0,
              qty: 20,
              cost: 200.0,
            ),
          ],
          paid: 7000.0,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final productMutated = await deps.productRepository.getProduct(productId);
      expect(productMutated!.stockQty, 25); // 45 - 20
      final salesMutated = await deps.salesRepository.getInvoices();
      expect(salesMutated.length, initialSales.length + 1);

      // 4. Restore the earlier backup
      final restoreSuccess = await deps.settingsRepository.restoreBackup(backupRecord.filePath);
      expect(restoreSuccess, isTrue);

      // 5. Verify restored state matches the backup snapshot exactly
      final productRestored = await deps.productRepository.getProduct(productId);
      expect(productRestored!.stockQty, 45); // Restored back to 45!

      final salesRestored = await deps.salesRepository.getInvoices();
      expect(salesRestored.length, initialSales.length); // Back to initial count!
      expect(salesRestored.any((s) => s.id == checkoutResult.saleId), isTrue);

      // Mutated temporary item must NOT exist anymore
      final productsRestored = await deps.productRepository.getProducts();
      expect(productsRestored.any((p) => p.sku == 'TMP-001'), isFalse);
    });

    test('2. Foreign Key & Integrity Check validation post-restore', () async {
      final backupRecord = await deps.settingsRepository.createBackup();
      final restoreSuccess = await deps.settingsRepository.restoreBackup(backupRecord.filePath);
      expect(restoreSuccess, isTrue);

      // Verify PRAGMA integrity_check directly
      final integrityCheck = await db.customSelect('PRAGMA integrity_check;').get();
      expect(integrityCheck.first.data.values.first, 'ok');

      // Verify PRAGMA foreign_key_check directly
      final fkCheck = await db.customSelect('PRAGMA foreign_key_check;').get();
      expect(fkCheck, isEmpty);
    });

    test('3. Rejection of corrupted or invalid backup files without database corruption', () async {
      // Create a corrupted backup file
      final corruptFile = File('${tempDir.path}/corrupt_backup.json');
      await corruptFile.writeAsString('{"app": "WrongApp", "tables": {}}');

      final isValid = await deps.settingsRepository.validateBackup(corruptFile.path);
      expect(isValid, isFalse);

      expect(
        () async => await deps.settingsRepository.restoreBackup(corruptFile.path),
        throwsA(isA<AppException>()),
      );

      // Non-existent file
      final missingFile = '${tempDir.path}/does_not_exist.json';
      final isMissingValid = await deps.settingsRepository.validateBackup(missingFile);
      expect(isMissingValid, isFalse);
    });

    test('4. Atomic rollback protects database if backup data contains invalid SQL', () async {
      final initialProductCount = (await deps.productRepository.getProducts()).length;

      // Malformed JSON file with invalid column structure inside a real table
      final badDataFile = File('${tempDir.path}/bad_data.json');
      await badDataFile.writeAsString(jsonEncode({
        'app': 'Darvi Billing',
        'version': '1.0.0',
        'tables': {
          'products': [
            {'invalid_corrupt_column_name': 'dangerous_payload'}
          ]
        }
      }));

      // Validation passes syntax check, but restoration throws on SQL column execution and cleanly rolls back
      expect(
        () async => await deps.settingsRepository.restoreBackup(badDataFile.path),
        throwsA(isA<Exception>()),
      );

      // Verify existing data was untouched
      final currentProductCount = (await deps.productRepository.getProducts()).length;
      expect(currentProductCount, initialProductCount);
    });
  });
}

