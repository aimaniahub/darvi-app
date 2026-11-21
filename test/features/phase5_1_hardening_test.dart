import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';

import 'package:mini_pos_inventory/app/app_dependencies.dart';
import 'package:mini_pos_inventory/core/errors/app_exception.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';

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
      return null;
    });

    db = AppDatabase(NativeDatabase.memory());
    await db.ensureGroup1SchemaTables();
    await db.ensureGroup2SchemaTables();
    await db.ensureGroup3SchemaTables();
    await db.ensureGroup4SchemaTables();
    await db.ensurePhase4_4SchemaTables();
    await db.ensurePhase5_1SchemaTables();
    await db.sanitizeDateTimeColumns();
    await SeedData(db).ensureSeeded();

    // Standard test commission rule (10% on sales >= 0.0)
    await db.customStatement('''
      INSERT OR REPLACE INTO incentive_rules (id, workspace_id, name, rule_type, threshold_amount, reward_rate, is_active, created_at)
      VALUES (99, 1, 'Standard Commission 10%', 'percentage_revenue', 0.0, 10.0, 1, ?);
    ''', [DateTime.now().millisecondsSinceEpoch ~/ 1000]);

    deps = AppDependencies.forTesting(database: db);
  });

  tearDown(() async {
    await deps.dispose();
  });

  group('PHASE 5.1: 1. CRITICAL — PARTIAL SALES RETURN & INCENTIVE REVERSAL', () {
    test('Scenario 1: Full return before incentive approval', () async {
      // 1. Create a sale attributed to employee 1 (Vikram - Field Officer)
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard Organic Pesticide 1L', price: 450.0, qty: 10, cost: 320.0),
          ],
          paid: 4500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      // Verify pending claim created
      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'pending');
      final claim = claims.firstWhere((c) => c.saleId == checkoutResult.saleId);
      expect(claim.amount, greaterThan(0.0));
      expect(claim.status, 'pending');

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // 2. Full return
      final returnResult = await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 10)],
      );
      expect(returnResult.returnSaleId, greaterThan(0));

      // 3. Verify original sale is marked returned
      final updatedSale = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      expect(updatedSale!.sale.status.value, 'returned');

      // 4. Verify incentive claim is rejected
      final updatedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final updatedClaim = updatedClaims.firstWhere((c) => c.id == claim.id);
      expect(updatedClaim.status, 'rejected');
      expect(updatedClaim.amount, 0.0);
    });

    test('Scenario 2: Partial return before incentive approval', () async {
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard Organic Pesticide 1L', price: 450.0, qty: 10, cost: 320.0),
          ],
          paid: 4500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'pending');
      final claim = claims.firstWhere((c) => c.saleId == checkoutResult.saleId);
      final originalClaimAmount = claim.amount;

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // Partial return: 4 out of 10 items
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 4)],
      );

      // Original sale must be partially_returned (NOT completely returned)
      final updatedSale = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      expect(updatedSale!.sale.status.value, 'partially_returned');

      // Incentive claim must remain pending, but amount reduced proportionally (60% remaining)
      final updatedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final updatedClaim = updatedClaims.firstWhere((c) => c.id == claim.id);
      expect(updatedClaim.status, 'pending');
      expect(updatedClaim.amount, lessThan(originalClaimAmount));
      expect(updatedClaim.amount, closeTo(originalClaimAmount * 0.6, 1.0));
    });

    test('Scenario 3: Full return after incentive approval but before payout', () async {
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard Organic Pesticide 1L', price: 450.0, qty: 10, cost: 320.0),
          ],
          paid: 4500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'pending');
      final claim = claims.firstWhere((c) => c.saleId == checkoutResult.saleId);

      // Approve claim
      await deps.employeeRepository.approveIncentiveClaim(claim.id, true);
      var approvedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'approved');
      expect(approvedClaims.any((c) => c.id == claim.id), isTrue);

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // Full return
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 10)],
      );

      // Claim should become rejected
      final updatedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final updatedClaim = updatedClaims.firstWhere((c) => c.id == claim.id);
      expect(updatedClaim.status, 'rejected');
      expect(updatedClaim.amount, 0.0);
    });

    test('Scenario 4: Partial return after incentive approval but before payout', () async {
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard Organic Pesticide 1L', price: 450.0, qty: 10, cost: 320.0),
          ],
          paid: 4500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'pending');
      final claim = claims.firstWhere((c) => c.saleId == checkoutResult.saleId);
      final origAmount = claim.amount;

      // Approve claim
      await deps.employeeRepository.approveIncentiveClaim(claim.id, true);

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // Return 3 out of 10 items
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 3)],
      );

      // Claim status remains approved with remaining 70%
      final updatedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final updatedClaim = updatedClaims.firstWhere((c) => c.id == claim.id);
      expect(updatedClaim.status, 'approved');
      expect(updatedClaim.amount, closeTo(origAmount * 0.7, 1.0));
    });

    test('Scenario 5: Full return after incentive payout', () async {
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard Organic Pesticide 1L', price: 450.0, qty: 10, cost: 320.0),
          ],
          paid: 4500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'pending');
      final claim = claims.firstWhere((c) => c.saleId == checkoutResult.saleId);

      // Approve & Payout
      await deps.employeeRepository.approveIncentiveClaim(claim.id, true);
      await deps.employeeRepository.payoutIncentiveClaim(claimId: claim.id, fromAccountId: 1);

      final paidClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'paid');
      expect(paidClaims.any((c) => c.id == claim.id), isTrue);

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // Full return after payout
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 10)],
      );

      // Claim is now marked reversed
      final updatedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final updatedClaim = updatedClaims.firstWhere((c) => c.id == claim.id);
      expect(updatedClaim.status, 'reversed');

      // Verify offsetting double-entry ledger entry was posted
      final ledgerRows = await db.customSelect(
        "SELECT * FROM ledger_entries WHERE reference_type = 'incentive_reversal' AND reference_id = ?",
        variables: [Variable.withInt(claim.id)],
      ).get();
      expect(ledgerRows.length, 2);
    });

    test('Scenario 6: Partial return after incentive payout', () async {
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard Organic Pesticide 1L', price: 450.0, qty: 10, cost: 320.0),
          ],
          paid: 4500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'pending');
      final claim = claims.firstWhere((c) => c.saleId == checkoutResult.saleId);
      final origAmount = claim.amount;

      // Approve & Payout
      await deps.employeeRepository.approveIncentiveClaim(claim.id, true);
      await deps.employeeRepository.payoutIncentiveClaim(claimId: claim.id, fromAccountId: 1);

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // Partial return: 5 out of 10 items
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 5)],
      );

      // Claim status must be partially_reversed (NOT reversed)
      final updatedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final updatedClaim = updatedClaims.firstWhere((c) => c.id == claim.id);
      expect(updatedClaim.status, 'partially_reversed');
      expect(updatedClaim.amount, closeTo(origAmount * 0.5, 1.0));

      // Offsetting ledger entries posted for exactly 50% reversal
      final ledgerRows = await db.customSelect(
        "SELECT * FROM ledger_entries WHERE reference_type = 'incentive_reversal' AND reference_id = ?",
        variables: [Variable.withInt(claim.id)],
      ).get();
      expect(ledgerRows.length, 2);
      final reversedEntry = ledgerRows.firstWhere((r) => (r.data['credit'] as num).toDouble() > 0);
      expect((reversedEntry.data['credit'] as num).toDouble(), closeTo(origAmount * 0.5, 1.0));
    });

    test('Scenario 7: Multiple partial returns against one invoice', () async {
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard Organic Pesticide 1L', price: 450.0, qty: 10, cost: 320.0),
          ],
          paid: 4500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // 1st partial return: 3 units
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 3)],
      );
      var saleCheck1 = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      expect(saleCheck1!.sale.status.value, 'partially_returned');

      // 2nd partial return: 4 units (total 7 units returned)
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 4)],
      );
      var saleCheck2 = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      expect(saleCheck2!.sale.status.value, 'partially_returned');

      // 3rd return: remaining 3 units (total 10 units returned) -> now fully returned!
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 3)],
      );
      var saleCheck3 = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      expect(saleCheck3!.sale.status.value, 'returned');
    });

    test('Scenario 8: Return of products that have different incentive rates', () async {
      await db.customStatement('UPDATE incentive_rules SET is_active = 0 WHERE id = 99;');
      // Create product-specific incentive rule: 100 Rs fixed per unit for Product 2
      await deps.employeeRepository.createIncentiveRule(
        const IncentiveRuleModel(
          id: 0,
          workspaceId: 1,
          name: 'Special Nitro Fertilizer Incentive',
          ruleType: 'fixed_per_product',
          rewardRate: 100.0,
          targetProductId: 2,
        ),
      );

      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard', price: 450.0, qty: 2, cost: 300.0),
            CartItem(productId: 2, sku: 'BIO-NPK', name: 'Bio-NPK', price: 800.0, qty: 2, cost: 500.0),
          ],
          paid: 2500.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: 1,
        ),
      );

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final p2SaleItemId = detail!.items.firstWhere((it) => it.productId == 2).id;

      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final claim = claims.firstWhere((c) => c.saleId == checkoutResult.saleId);
      final initialClaimAmount = claim.amount;

      // Return 1 unit of Product 2 (should reverse exactly 100 Rs from rule)
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: p2SaleItemId, qty: 1)],
      );

      final updatedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final updatedClaim = updatedClaims.firstWhere((c) => c.id == claim.id);
      expect(updatedClaim.amount, closeTo(initialClaimAmount - 100.0, 5.0));
    });

    test('Scenario 9: Cancelled invoice and repeated return submissions', () async {
      final checkoutResult = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard', price: 450.0, qty: 5, cost: 300.0),
          ],
          paid: 2250.0,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final detail = await deps.salesRepository.getInvoiceDetail(checkoutResult.saleId);
      final saleItemId = detail!.items.first.id;

      // 1. Over-return prevention: trying to return 6 units when only 5 were bought
      expect(
        () => deps.salesRepository.returnItems(
          saleId: checkoutResult.saleId,
          items: [ReturnItemInput(saleItemId: saleItemId, qty: 6)],
        ),
        throwsA(isA<AppException>()),
      );

      // Return 4 units legitimately
      await deps.salesRepository.returnItems(
        saleId: checkoutResult.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 4)],
      );

      // Now only 1 unit is returnable; trying to return 2 units must fail
      expect(
        () => deps.salesRepository.returnItems(
          saleId: checkoutResult.saleId,
          items: [ReturnItemInput(saleItemId: saleItemId, qty: 2)],
        ),
        throwsA(isA<AppException>()),
      );

      // 2. Cancelled invoice return prevention
      await db.customStatement("UPDATE sales SET status = 'cancelled' WHERE id = ?", [checkoutResult.saleId]);
      expect(
        () => deps.salesRepository.returnItems(
          saleId: checkoutResult.saleId,
          items: [ReturnItemInput(saleItemId: saleItemId, qty: 1)],
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('PHASE 5.1: 2. HIGH — PASSWORD & PIN HASHING HARDENING', () {
    test('PBKDF2-HMAC-SHA256 hash generation, format and verification', () {
      const password = 'AdminSecurePassword2026!';
      final hash = HashHelper.hashPassword(password);

      expect(hash.startsWith(r'$pbkdf2-sha256$i=100000$'), isTrue);

      final verifyCorrect = HashHelper.verify(password, hash);
      expect(verifyCorrect.matches, isTrue);
      expect(verifyCorrect.needsRehash, isFalse);

      final verifyWrong = HashHelper.verify('WrongPassword', hash);
      expect(verifyWrong.matches, isFalse);
    });

    test('Constant-time comparison protects against timing attacks', () {
      expect(HashHelper.constantTimeEquals('secret_token_123', 'secret_token_123'), isTrue);
      expect(HashHelper.constantTimeEquals('secret_token_123', 'secret_token_124'), isFalse);
      expect(HashHelper.constantTimeEquals('short', 'longer_string'), isFalse);
    });

    test('Seamless legacy migration: SHA-256 automatically upgrades to PBKDF2 on login', () async {
      // Create user with legacy SHA-256 hash
      const testUser = 'migrating_manager';
      const testPass = 'LegacyPass999';
      final legacySha256 = HashHelper.sha256Hash(testPass);

      await db.customStatement('''
        INSERT INTO users (workspace_id, name, username, email, phone, role, is_active, password_hash, pin_hash, salt, created_at)
        VALUES (1, 'Legacy User', ?, 'legacy@darvi.com', '9876543210', 'manager', 1, ?, NULL, '', 1700000000);
      ''', [testUser, legacySha256]);

      // Login with credentials
      final user = await deps.authRepository.loginWithCredentials(testUser, testPass);
      expect(user, isNotNull);
      expect(user!.username, testUser);

      // Verify database record has been upgraded to PBKDF2
      final row = await db.customSelect(
        'SELECT password_hash FROM users WHERE username = ?',
        variables: [Variable.withString(testUser)],
      ).getSingle();
      final upgradedHash = row.data['password_hash'] as String;
      expect(upgradedHash.startsWith(r'$pbkdf2-sha256$'), isTrue);
    });

    test('Employee PIN verification with PBKDF2 and auto-upgrade', () async {
      // Create employee with plaintext PIN '8888'
      final empId = await deps.employeeRepository.upsertEmployee(
        EmployeeModel(
          id: 0,
          workspaceId: 1,
          employeeCode: 'TEST-EMP-01',
          name: 'PIN Test Employee',
          phone: '9988776655',
          role: 'cashier',
          designation: 'Cashier Staff',
          loginPin: '8888',
          joiningDate: DateTime(2026, 1, 1),
        ),
      );

      // Login using PIN '8888'
      final emp = await deps.employeeRepository.getEmployeeByPin('8888');
      expect(emp, isNotNull);
      expect(emp!.id, empId);

      // Verify that stored PIN is now securely hashed with PBKDF2
      final row = await db.customSelect('SELECT login_pin FROM employees WHERE id = ?', variables: [Variable.withInt(empId)]).getSingle();
      final storedPin = row.data['login_pin'] as String;
      expect(storedPin.startsWith(r'$pbkdf2-sha256$'), isTrue);
    });
  });

  group('PHASE 5.1: 3. HIGH — GST CALCULATION & REPORTING ACCURACY', () {
    test('Intrastate vs Interstate GST distinction', () async {
      // 1. Intrastate Sale (CGST + SGST split, IGST = 0)
      final intraSale = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard', price: 1000.0, qty: 1, cost: 600.0, gstRate: 0.18),
          ],
          taxEnabled: true,
          taxRate: 0.18,
          isInterState: false,
          paid: 1180.0,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final intraDetail = await deps.salesRepository.getInvoiceDetail(intraSale.saleId);
      expect(intraDetail!.sale.cgstTotal, 90.0);
      expect(intraDetail.sale.sgstTotal, 90.0);
      expect(intraDetail.sale.igstTotal, 0.0);

      // 2. Interstate Sale (IGST total, CGST = 0, SGST = 0)
      final interSale = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard', price: 1000.0, qty: 1, cost: 600.0, gstRate: 0.18),
          ],
          taxEnabled: true,
          taxRate: 0.18,
          isInterState: true,
          paid: 1180.0,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final interDetail = await deps.salesRepository.getInvoiceDetail(interSale.saleId);
      expect(interDetail!.sale.cgstTotal, 0.0);
      expect(interDetail.sale.sgstTotal, 0.0);
      expect(interDetail.sale.igstTotal, 180.0);
    });

    test('GST Report contains correct Credit Notes and excludes cancelled invoices', () async {
      // Create sale with GST
      final sale = await deps.salesRepository.checkout(
        const SaleCheckoutInput(
          items: [
            CartItem(productId: 1, sku: 'NEEM-1L', name: 'Neem Guard', price: 1000.0, qty: 2, cost: 600.0, gstRate: 0.18),
          ],
          taxEnabled: true,
          taxRate: 0.18,
          paid: 2360.0,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final detail = await deps.salesRepository.getInvoiceDetail(sale.saleId);
      final saleItemId = detail!.items.first.id;

      // Return 1 unit
      await deps.salesRepository.returnItems(
        saleId: sale.saleId,
        items: [ReturnItemInput(saleItemId: saleItemId, qty: 1)],
      );

      // Fetch GST Report
      final gstRows = await deps.reportsRepository.getGstReportRows(workspaceId: 1);
      final returnGstRow = gstRows.firstWhere((r) => r.type == 'credit_note');
      expect(returnGstRow, isNotNull);
      expect(returnGstRow.totalInvoiceValue, lessThan(0.0));
      expect(returnGstRow.totalGst, lessThan(0.0));
    });
  });

  group('PHASE 5.1: 4. HIGH — COMPLETE WORKSPACE ISOLATION AUDIT', () {
    test('Two workspaces have zero cross-tenant leakage across products, stock, sales & reports', () async {
      // Create Product in Workspace 2
      final w2ProdId = await deps.productRepository.upsertProduct(
        const ProductUpsertInput(
          name: 'Workspace 2 Exclusive Seeds',
          sku: 'W2-SEED-01',
          price: 500.0,
          cost: 300.0,
          stockQty: 50,
        ),
        workspaceId: 2,
      );

      // Verify Product does not appear in Workspace 1 queries
      final w1Products = await deps.productRepository.getProducts(workspaceId: 1);
      expect(w1Products.any((p) => p.id == w2ProdId), isFalse);

      final w2Products = await deps.productRepository.getProducts(workspaceId: 2);
      expect(w2Products.any((p) => p.id == w2ProdId), isTrue);

      // Verify Stock Movements isolation
      final w1Movements = await deps.productRepository.getStockMovements(workspaceId: 1);
      expect(w1Movements.any((m) => m.productId == w2ProdId), isFalse);

      final w2Movements = await deps.productRepository.getStockMovements(workspaceId: 2);
      expect(w2Movements.any((m) => m.productId == w2ProdId), isTrue);

      // Sale in Workspace 2
      final w2Sale = await deps.salesRepository.checkout(
        SaleCheckoutInput(
          items: [
            CartItem(productId: w2ProdId, sku: 'W2-SEED-01', name: 'Workspace 2 Exclusive Seeds', price: 500.0, qty: 2, cost: 300.0),
          ],
          paid: 1000.0,
          paymentMethod: PaymentMethod.cash,
          workspaceId: 2,
        ),
      );

      // Verify Sale does NOT appear in Workspace 1 Invoices or Reports
      final w1Invoices = await deps.salesRepository.getInvoices(workspaceId: 1);
      expect(w1Invoices.any((s) => s.id == w2Sale.saleId), isFalse);

      final w2Invoices = await deps.salesRepository.getInvoices(workspaceId: 2);
      expect(w2Invoices.any((s) => s.id == w2Sale.saleId), isTrue);

      // Verify GST Report isolation
      final w1Gst = await deps.reportsRepository.getGstReportRows(workspaceId: 1);
      expect(w1Gst.any((r) => r.invoiceNo == w2Sale.invoiceNo), isFalse);

      final w2Gst = await deps.reportsRepository.getGstReportRows(workspaceId: 2);
      expect(w2Gst.any((r) => r.invoiceNo == w2Sale.invoiceNo), isTrue);
    });
  });

  group('PHASE 5.1: 5. HIGH — REPOSITORY-LEVEL RBAC VERIFICATION', () {
    test('Cashier is blocked from payroll and sensitive HR operations', () async {
      // Cashier role direct method calls must throw AppException
      expect(
        () => deps.employeeRepository.getPayrollRecords(callerRole: UserRole.cashier),
        throwsA(isA<AppException>()),
      );

      expect(
        () => deps.employeeRepository.processPayroll(
          employeeId: 1,
          month: 5,
          year: 2026,
          basicSalary: 25000.0,
          callerRole: UserRole.cashier,
        ),
        throwsA(isA<AppException>()),
      );

      expect(
        () => deps.employeeRepository.disbursePayroll(payrollId: 1, fromAccountId: 1, callerRole: UserRole.cashier),
        throwsA(isA<AppException>()),
      );
    });

    test('Unauthorized caller is blocked from modifying products or stock', () async {
      expect(
        () => deps.productRepository.upsertProduct(
          const ProductUpsertInput(name: 'Unauthorized Edit', sku: 'BAD-01', price: 100.0, cost: 50.0, stockQty: 10),
          callerRole: UserRole.cashier,
        ),
        throwsA(isA<AppException>()),
      );

      expect(
        () => deps.productRepository.adjustStock(
          productId: 1,
          newQuantity: 999,
          reason: 'Unauthorized Audit Modification',
          callerRole: UserRole.cashier,
        ),
        throwsA(isA<AppException>()),
      );

      expect(
        () => deps.productRepository.deleteProduct(1, callerRole: UserRole.manager),
        throwsA(isA<AppException>()), // Delete requires admin
      );
    });

    test('Non-management roles receive redacted employee details (masked PIN and bank details)', () async {
      // Admin sees unredacted details
      final adminEmployees = await deps.employeeRepository.getEmployees(callerRole: UserRole.admin);
      final firstAdminEmp = adminEmployees.first;
      expect(firstAdminEmp.loginPin, isNot('****'));

      // Cashier sees redacted details
      final cashierEmployees = await deps.employeeRepository.getEmployees(callerRole: UserRole.cashier);
      final firstCashierEmp = cashierEmployees.first;
      expect(firstCashierEmp.loginPin, '****');
      expect(firstCashierEmp.baseSalary, 0.0);
      if (firstCashierEmp.bankAccountNumber != null) {
        expect(firstCashierEmp.bankAccountNumber!.startsWith('****'), isTrue);
      }
    });
  });
}
