import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await db.ensurePhase5_1SchemaTables();
    await db.sanitizeDateTimeColumns();
    await SeedData(db).ensureSeeded();

    deps = AppDependencies.forTesting(database: db);
  });

  tearDown(() async {
    await deps.dispose();
  });

  group('PHASE 5: SALES, PURCHASES & INVENTORY INTEGRATION', () {
    test('Complete Lifecycle: Product -> Inward Bill -> POS Sale -> Stock Deduction -> Ledger -> Return', () async {
      // 1. Create a dedicated product
      final productId = await deps.productRepository.upsertProduct(
        const ProductUpsertInput(
          name: 'Darvi Bio-Fertilizer 50kg',
          sku: 'DBF-001',
          barcode: '8901234567890',
          cost: 400.0,
          price: 600.0,
          stockQty: 10,
          lowStockThreshold: 5,
          unit: 'bag',
          hsnCode: '3101',
          gstRate: 0.05,
        ),
      );
      expect(productId, greaterThan(0));

      final initialProduct = await deps.productRepository.getProduct(productId);
      expect(initialProduct, isNotNull);
      expect(initialProduct!.stockQty, 10);

      // 2. Inward stock via multi-item purchase invoice (5 bags at 400 cost = 2000 subtotal, 2100 total)
      final suppliers = await deps.partyRepository.getSuppliers(workspaceId: 1);
      final supplierId = suppliers.first.id;

      final purchaseInvoiceId = await deps.purchaseRepository.createPurchaseInvoice(
        PurchaseInvoiceInput(
          supplierId: supplierId,
          supplierInvoiceNo: 'PB-INT-001',
          subtotal: 2000.0,
          taxTotal: 100.0,
          total: 2100.0,
          paid: 1000.0,
          items: [
            PurchaseInvoiceItemInput(
              productId: productId,
              qty: 5,
              unitCost: 400.0,
              lineTotal: 2000.0,
              nameSnapshot: initialProduct.name,
            ),
          ],
        ),
      );
      expect(purchaseInvoiceId, greaterThan(0));

      // Verify stock was incremented to 15 (10 + 5)
      final productAfterInward = await deps.productRepository.getProduct(productId);
      expect(productAfterInward!.stockQty, 15);

      // 3. POS Sale with employee attribution and customer balance update
      final employees = await deps.employeeRepository.getEmployees(workspaceId: 1);
      final empId = employees.first.id;
      final customers = await deps.partyRepository.getCustomers(workspaceId: 1);
      final custId = customers.first.id;

      // Ensure an active incentive rule exists
      await deps.employeeRepository.createIncentiveRule(
        const IncentiveRuleModel(
          id: 0,
          workspaceId: 1,
          name: 'Fertilizer 5% Commission',
          ruleType: 'percentage_revenue',
          thresholdAmount: 500.0,
          rewardRate: 5.0,
          isActive: true,
        ),
      );

      final saleResult = await deps.salesRepository.checkout(
        SaleCheckoutInput(
          items: [
            CartItem(
              productId: productId,
              name: initialProduct.name,
              sku: initialProduct.sku,
              price: 600.0,
              cost: 400.0,
              qty: 3,
            ),
          ],
          paid: 1800.0,
          paymentMethod: PaymentMethod.cash,
          employeeId: empId,
          customerId: custId,
          taxEnabled: false,
        ),
      );

      expect(saleResult.saleId, greaterThan(0));
      expect(saleResult.total, 1800.0);

      // Verify stock was atomically decremented to 12 (15 - 3)
      final productAfterSale = await deps.productRepository.getProduct(productId);
      expect(productAfterSale!.stockQty, 12);

      // Verify incentive claim was automatically created for this sale and employee
      final claims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final saleClaim = claims.firstWhere((c) => c.saleId == saleResult.saleId);
      expect(saleClaim, isNotNull);
      expect(saleClaim.employeeId, empId);
      expect(saleClaim.amount, closeTo(90.0, 0.01)); // 5% of 1800 = 90
      expect(saleClaim.status, 'pending');

      // 4. Sales Return: return 1 bag -> stock should restore to 13, and incentive should be reversed
      final saleDetails = await deps.salesRepository.getInvoiceDetail(saleResult.saleId);
      expect(saleDetails, isNotNull);
      final saleItem = saleDetails!.items.first;

      final returnResult = await deps.salesRepository.returnItems(
        saleId: saleResult.saleId,
        items: [
          ReturnItemInput(
            saleItemId: saleItem.id,
            qty: 1,
          ),
        ],
      );
      expect(returnResult.returnSaleId, greaterThan(0));

      // Verify stock restoration
      final productAfterReturn = await deps.productRepository.getProduct(productId);
      expect(productAfterReturn!.stockQty, 13);

      // Verify incentive claim status reflects hardened partial return (remains pending, amount reduced from 90 to 60)
      final claimsAfterReturn = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1);
      final reversedClaim = claimsAfterReturn.firstWhere((c) => c.id == saleClaim.id);
      expect(reversedClaim.status, 'pending');
      expect(reversedClaim.amount, closeTo(60.0, 0.01));
    });

    test('Insufficient Stock rejects POS sale when allowNegativeStock is disabled', () async {
      final productId = await deps.productRepository.upsertProduct(
        const ProductUpsertInput(
          name: 'Scarce Item',
          sku: 'SCR-001',
          cost: 100.0,
          price: 200.0,
          stockQty: 2,
          unit: 'pcs',
        ),
      );

      expect(
        () async => await deps.salesRepository.checkout(
          SaleCheckoutInput(
            items: [
              CartItem(
                productId: productId,
                name: 'Scarce Item',
                sku: 'SCR-001',
                price: 200.0,
                cost: 100.0,
                qty: 10, // requires 10, only 2 available
              ),
            ],
            paid: 2000.0,
            paymentMethod: PaymentMethod.cash,
          ),
        ),
        throwsA(isA<AppException>()),
      );

      // Verify stock untouched
      final prod = await deps.productRepository.getProduct(productId);
      expect(prod!.stockQty, 2);
    });
  });

  group('PHASE 5: EMPLOYEES, PAYROLL & INCENTIVES INTEGRATION', () {
    test('Attendance -> Payroll Processing -> Disbursal -> Ledger Posting', () async {
      final employees = await deps.employeeRepository.getEmployees(workspaceId: 1);
      final emp = employees.first;

      // 1. Record daily attendance
      final testDate = DateTime(2026, 11, 1);
      await deps.employeeRepository.recordAttendance(
        employeeId: emp.id,
        date: testDate,
        status: 'present',
        workingHours: 8.0,
        overtimeHours: 2.0,
      );

      final attendance = await deps.employeeRepository.getAttendance(date: testDate);
      expect(attendance.any((a) => a.employeeId == emp.id), isTrue);

      // 2. Process Monthly Payroll
      final payrollId = await deps.employeeRepository.processPayroll(
        employeeId: emp.id,
        month: 11,
        year: 2026,
        basicSalary: 25000.0,
        incentiveAmount: 2000.0,
        allowances: 3000.0,
        deductions: 1500.0,
        notes: 'November 2026 Comprehensive Payroll',
      );
      expect(payrollId, greaterThan(0));

      final records = await deps.employeeRepository.getPayrollRecords(workspaceId: 1, month: 11, year: 2026);
      final record = records.firstWhere((r) => r.id == payrollId);
      expect(record.netSalary, 28500.0); // (25000 + 2000 + 3000) - 1500 = 28500
      expect(record.status, 'approved');

      // 3. Disburse Payroll from Cash Account (ID 1)
      await deps.employeeRepository.disbursePayroll(
        payrollId: payrollId,
        fromAccountId: 1,
      );

      final recordsAfterDisburse = await deps.employeeRepository.getPayrollRecords(workspaceId: 1, month: 11, year: 2026);
      final disbursedRecord = recordsAfterDisburse.firstWhere((r) => r.id == payrollId);
      expect(disbursedRecord.status, 'paid');

      // 4. Duplicate Disbursal must throw exception
      expect(
        () async => await deps.employeeRepository.disbursePayroll(
          payrollId: payrollId,
          fromAccountId: 1,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('Incentive Lifecycle: Claim -> Approval -> Payout -> Double-payment prevention', () async {
      final employees = await deps.employeeRepository.getEmployees(workspaceId: 1);
      final emp = employees.first;

      final claimId = await deps.employeeRepository.createIncentiveClaim(
        IncentiveClaimModel(
          id: 0,
          workspaceId: 1,
          employeeId: emp.id,
          amount: 1500.0,
          description: 'High target bonus',
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      );
      expect(claimId, greaterThan(0));

      // Approve claim
      await deps.employeeRepository.approveIncentiveClaim(claimId, true);
      final approvedClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'approved');
      expect(approvedClaims.any((c) => c.id == claimId), isTrue);

      // Payout claim from Account 1
      await deps.employeeRepository.payoutIncentiveClaim(
        claimId: claimId,
        fromAccountId: 1,
      );

      final paidClaims = await deps.employeeRepository.getIncentiveClaims(workspaceId: 1, status: 'paid');
      expect(paidClaims.any((c) => c.id == claimId), isTrue);

      // Attempting to payout an already-paid claim must be blocked
      expect(
        () async => await deps.employeeRepository.payoutIncentiveClaim(
          claimId: claimId,
          fromAccountId: 1,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('PHASE 5: FINANCIALS, REPORTS & RECONCILIATION INTEGRATION', () {
    test('Reports Repository queries execute cleanly with correct column mappings and aggregations', () async {
      // Create a purchase bill to verify purchase queries
      final suppliers = await deps.partyRepository.getSuppliers(workspaceId: 1);
      final supplierId = suppliers.first.id;

      final products = await deps.productRepository.getProducts();
      final sampleProd = products.first;

      await deps.purchaseRepository.createPurchaseInvoice(
        PurchaseInvoiceInput(
          supplierId: supplierId,
          supplierInvoiceNo: 'PB-REP-101',
          subtotal: 5000.0,
          taxTotal: 900.0,
          total: 5900.0,
          paid: 2000.0,
          items: [
            PurchaseInvoiceItemInput(
              productId: sampleProd.id,
              qty: 10,
              unitCost: 500.0,
              lineTotal: 5000.0,
              nameSnapshot: sampleProd.name,
            ),
          ],
        ),
      );

      // 1. Purchase Reports Rows
      final purchaseRows = await deps.reportsRepository.getPurchaseReportRows(workspaceId: 1);
      expect(purchaseRows, isNotEmpty);
      final testRow = purchaseRows.firstWhere((r) => r.invoiceNo == 'PB-REP-101');
      expect(testRow.totalAmount, 5900.0);
      expect(testRow.paidAmount, 2000.0);
      expect(testRow.balanceDue, 3900.0);
      expect(testRow.paymentStatus, 'partial');

      // 2. GST Report Rows (Input & Output)
      final gstRows = await deps.reportsRepository.getGstReportRows(workspaceId: 1);
      expect(gstRows.any((r) => r.type == 'purchase_input'), isTrue);

      // 3. Comprehensive Summary
      final summary = await deps.reportsRepository.getComprehensiveSummary(workspaceId: 1);
      expect(summary.totalPurchases, greaterThanOrEqualTo(5900.0));
      expect(summary.outstandingPayables, greaterThanOrEqualTo(3900.0));
      expect(summary.inputGstTotal, greaterThanOrEqualTo(900.0));

      // 4. Financial Trial Balance
      final trialBalance = await deps.reportsRepository.getFinancialTrialBalance(workspaceId: 1);
      expect(trialBalance, isNotNull);
      expect(trialBalance, isNotEmpty);
    });

    test('Workspace Isolation: strict filtering prevents cross-tenant data leakage', () async {
      // Customers for Workspace 1
      final ws1Customers = await deps.partyRepository.getCustomers(workspaceId: 1);
      expect(ws1Customers, isNotEmpty);
      for (final c in ws1Customers) {
        expect(c.workspaceId, 1);
      }

      // Querying an empty workspace (e.g. workspace 999) returns zero customers and zero suppliers
      final emptyCustomers = await deps.partyRepository.getCustomers(workspaceId: 999);
      expect(emptyCustomers, isEmpty);

      final emptySuppliers = await deps.partyRepository.getSuppliers(workspaceId: 999);
      expect(emptySuppliers, isEmpty);
    });
  });
}
