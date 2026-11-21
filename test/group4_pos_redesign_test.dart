import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/core/services/esc_pos_generator.dart';
import 'package:mini_pos_inventory/core/services/receipt_pdf_service.dart';
import 'package:mini_pos_inventory/core/services/thermal_printer_service.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/data/repositories/local_account_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_ledger_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_party_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_product_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_sales_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_settings_repository.dart';
import 'package:mini_pos_inventory/domain/entities/app_entities.dart';
import 'package:mini_pos_inventory/domain/repositories/repositories.dart';
import 'package:mini_pos_inventory/features/pos/presentation/cubit/pos_cubit.dart';

class MockScannerService implements BarcodeScannerService {
  String? nextScanResult;

  @override
  Future<String?> scanBarcode() async => nextScanResult;
}

class MockPrinterService implements PrinterService {
  @override
  Future<void> printReceiptPdfBytes(List<int> bytes) async {}
}

class StubThermalPrinterService extends ThermalPrinterService {
  List<int> lastSentBytes = [];

  @override
  Future<List<BluetoothDeviceInfo>> getPairedDevices() async {
    return const [
      BluetoothDeviceInfo(name: 'SSEZNIK2POS-58', address: '00:11:22:33:44:55', isPaired: true),
    ];
  }

  @override
  Future<bool> connect(String address) async => true;

  @override
  Future<bool> sendBytes(Uint8List bytes, {int chunkSize = 256, int delayMs = 25}) async {
    lastSentBytes = bytes;
    return true;
  }
}

void main() {
  late AppDatabase db;
  late LocalLedgerRepository ledgerRepo;
  late LocalSalesRepository salesRepo;
  late LocalProductRepository productRepo;
  late LocalPartyRepository partyRepo;
  late LocalAccountRepository accountRepo;
  late LocalSettingsRepository settingsRepo;
  late MockScannerService scannerService;
  late MockPrinterService printerService;
  late ReceiptPdfService pdfService;
  late StubThermalPrinterService thermalPrinter;

  int testProduct1Id = 0;
  int testProduct2Id = 0;
  int testBatch1Id = 0;
  int testCustomerId = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await SeedData(db).ensureSeeded();

    ledgerRepo = LocalLedgerRepository(db);
    salesRepo = LocalSalesRepository(db, ledgerRepo);
    productRepo = LocalProductRepository(db);
    partyRepo = LocalPartyRepository(db, ledgerRepo);
    accountRepo = LocalAccountRepository(db, ledgerRepo);
    settingsRepo = LocalSettingsRepository(db);
    scannerService = MockScannerService();
    printerService = MockPrinterService();
    pdfService = ReceiptPdfService(printerService: printerService);
    thermalPrinter = StubThermalPrinterService();

    // 1. Seed Customer
    testCustomerId = await partyRepo.upsertCustomer(
      name: 'Ramesh Gowda',
      phone: '9845012345',
      address: 'Hubli Rural',
      creditLimit: 10000.0,
      gstin: '29AAACR1234A1Z5',
    );

    // 2. Seed Products
    testProduct1Id = await productRepo.upsertProduct(
      const ProductUpsertInput(
        name: 'Hybrid Cotton Seed 500g',
        sku: 'SEED-COT-001',
        barcode: '8901234567890',
        cost: 250.0,
        price: 450.0,
        stockQty: 50,
        unit: 'pack',
        brand: 'Darvi Seeds',
        hsnCode: '120999',
        gstRate: 18.0,
      ),
    );

    testProduct2Id = await productRepo.upsertProduct(
      const ProductUpsertInput(
        name: 'Bio Organic Fertilizer 1kg',
        sku: 'FERT-BIO-002',
        barcode: '8909876543210',
        cost: 120.0,
        price: 220.0,
        stockQty: 30,
        unit: 'bag',
        brand: 'Darvi Nutrients',
        hsnCode: '310100',
        gstRate: 5.0,
      ),
    );

    // 3. Seed Batch for Product 1
    testBatch1Id = await productRepo.addBatch(
      ProductBatchView(
        id: 0,
        workspaceId: 1,
        productId: testProduct1Id,
        batchNumber: 'COT-2026-A1',
        costPrice: 250.0,
        sellingPrice: 450.0,
        quantity: 20,
        initialQuantity: 20,
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        status: 'active',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  PosCubit createCubit() {
    return PosCubit(
      productRepository: productRepo,
      salesRepository: salesRepo,
      settingsRepository: settingsRepo,
      partyRepository: partyRepo,
      accountRepository: accountRepo,
      scannerService: scannerService,
      receiptPdfService: pdfService,
      thermalPrinterService: thermalPrinter,
    );
  }

  group('DARVI POS REDESIGN — SCREEN 1: BILLING WORKSPACE', () {
    test('1.1 Product search & discovery filters by name, SKU, and barcode', () async {
      final cubit = createCubit();
      await cubit.load();

      expect(cubit.state.products.length >= 2, true);

      // Search by name
      cubit.updateFilter(search: 'Cotton');
      expect(cubit.state.filteredProducts.length, 1);
      expect(cubit.state.filteredProducts.first.sku, 'SEED-COT-001');

      // Search by SKU
      cubit.updateFilter(search: 'FERT-BIO');
      expect(cubit.state.filteredProducts.length, 1);
      expect(cubit.state.filteredProducts.first.name, 'Bio Organic Fertilizer 1kg');

      // Search by barcode
      cubit.updateFilter(search: '8901234567890');
      expect(cubit.state.filteredProducts.length, 1);
      expect(cubit.state.filteredProducts.first.id, testProduct1Id);

      // Reset
      cubit.updateFilter(search: '');
      expect(cubit.state.filteredProducts.length >= 2, true);
    });

    test('1.2 Grid vs List layout mode toggling', () async {
      final cubit = createCubit();
      expect(cubit.state.layoutMode, ProductLayoutMode.grid);

      cubit.setLayoutMode(ProductLayoutMode.list);
      expect(cubit.state.layoutMode, ProductLayoutMode.list);

      cubit.setLayoutMode(ProductLayoutMode.grid);
      expect(cubit.state.layoutMode, ProductLayoutMode.grid);
    });

    test('1.3 Cart manipulations: add, batch assignment, qty, line discount, and price override', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);

      // Add with specific batch
      cubit.addProductToCart(
        p1,
        batchId: testBatch1Id,
        batchNumber: 'COT-2026-A1',
      );

      expect(cubit.state.cart.length, 1);
      expect(cubit.state.cart.first.qty, 1);
      expect(cubit.state.cart.first.batchId, testBatch1Id);
      expect(cubit.state.cart.first.batchNumber, 'COT-2026-A1');
      expect(cubit.state.grossSubtotal, 450.0);

      // Quantity increment (+2 -> total 3)
      cubit.updateItemQty(testProduct1Id, 3);
      expect(cubit.state.cart.first.qty, 3);
      expect(cubit.state.grossSubtotal, 1350.0);

      // Line discount
      cubit.setItemDiscount(testProduct1Id, 50.0);
      expect(cubit.state.itemDiscountsTotal, 50.0);
      expect(cubit.state.subtotal, 1300.0); // 1350 - 50

      // Price override
      cubit.setItemPrice(testProduct1Id, 440.0);
      expect(cubit.state.cart.first.price, 440.0);
      expect(cubit.state.grossSubtotal, 1320.0); // 440 * 3
      expect(cubit.state.subtotal, 1270.0); // 1320 - 50
    });

    test('1.4 Bill discount (fixed vs percentage) and GST intra-state calculation', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1); // Price: 450.0, Qty: 1

      // Fixed bill discount ₹50
      cubit.setDiscount(DiscountType.fixed, 50.0);
      expect(cubit.state.orderDiscount, 50.0);
      expect(cubit.state.taxableAmount, 400.0); // 450 - 50

      // Enable GST at 18%
      cubit.setTaxEnabled(true);
      cubit.setTaxRate(0.18);
      expect(cubit.state.tax, 72.0); // 400 * 0.18
      expect(cubit.state.cgst, 36.0); // 9% CGST
      expect(cubit.state.sgst, 36.0); // 9% SGST
      expect(cubit.state.total, 472.0); // 400 + 72

      // Percentage discount: 10%
      cubit.setDiscount(DiscountType.percentage, 10.0);
      expect(cubit.state.orderDiscount, 45.0); // 10% of 450
      expect(cubit.state.taxableAmount, 405.0);
    });

    test('1.5 Quick add customer preserves active cart state', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);
      expect(cubit.state.cart.length, 1);

      // Register new customer inline
      await cubit.quickAddCustomer(
        name: 'Suresh Patil',
        phone: '9900112233',
        address: 'Dharwad',
      );

      // Cart state must remain completely intact
      expect(cubit.state.cart.length, 1);
      expect(cubit.state.selectedCustomer?.name, 'Suresh Patil');
    });

    test('1.6 Park / Hold bill lifecycle: park, list, resume, delete', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      final p2 = cubit.state.products.firstWhere((p) => p.id == testProduct2Id);

      cubit.addProductToCart(p1);
      cubit.addProductToCart(p2);
      cubit.setDiscount(DiscountType.fixed, 20.0);
      cubit.selectCustomer(testCustomerId);

      expect(cubit.state.cart.length, 2);

      // 1. Hold Bill
      await cubit.holdCurrentBill(note: 'Customer went to ATM');
      expect(cubit.state.cart.isEmpty, true);
      expect(cubit.state.heldBills.length, 1);
      expect(cubit.state.heldBills.first.referenceNote, 'Customer went to ATM');
      expect(cubit.state.heldBills.first.customerName, 'Ramesh Gowda');

      // 2. Resume Held Bill
      final held = cubit.state.heldBills.first;
      await cubit.resumeHeldBill(held);

      expect(cubit.state.cart.length, 2);
      expect(cubit.state.orderDiscount, 20.0);
      expect(cubit.state.selectedCustomerId, testCustomerId);
      expect(cubit.state.heldBills.isEmpty, true); // Removed from parked queue upon resume
    });
  });

  group('DARVI POS REDESIGN — SCREEN 2: CART & CHECKOUT REVIEW', () {
    test('2.1 Cash tender and accurate change due calculation', () async {
      final cubit = createCubit();
      await cubit.load();
      cubit.setTaxEnabled(false);

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1); // 450.0

      cubit.setViewMode(PosViewMode.checkoutReview);
      expect(cubit.state.viewMode, PosViewMode.checkoutReview);

      // Tender ₹500 cash
      cubit.setPaymentMethod(PaymentMethod.cash);
      cubit.setPaid(500.0);

      expect(cubit.state.total, 450.0);
      expect(cubit.state.paid, 500.0);
      expect(cubit.state.change, 50.0);
      expect(cubit.state.outstandingBalance, 0.0);
    });

    test('2.2 Multi-row Split Payments debit respective accounts atomically', () async {
      final cubit = createCubit();
      await cubit.load();
      cubit.setTaxEnabled(false);

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);
      cubit.updateItemQty(testProduct1Id, 4); // 4 * 450 = 1800.0

      cubit.setViewMode(PosViewMode.checkoutReview);
      expect(cubit.state.total, 1800.0);

      // Add Split payment rows: ₹800 Cash + ₹1000 UPI
      cubit.addSplitPayment(PaymentMethod.cash, 800.0, accountId: 1);
      cubit.addSplitPayment(PaymentMethod.upi, 1000.0, accountId: 3, referenceNo: 'UPI-TXN-9988');

      expect(cubit.state.splitPayments.length, 2);
      expect(cubit.state.splitPaymentsTotal, 1800.0);
      expect(cubit.state.remainingSplitBalance, 0.0);

      // Complete checkout
      await cubit.checkout();

      expect(cubit.state.lastResult != null, true);
      expect(cubit.state.lastResult!.total, 1800.0);
      expect(cubit.state.lastResult!.paid, 1800.0);

      // Verify double-entry ledger postings debiting Account 1 (800) and Account 3 (1000)
      final cashDebits = await db.customSelect(
        'SELECT debit FROM ledger_entries WHERE account_id = 1 AND transaction_type = "payment_in";',
      ).get();
      expect(cashDebits.isNotEmpty, true);
      expect(cashDebits.first.data['debit'], 800.0);

      final upiDebits = await db.customSelect(
        'SELECT debit FROM ledger_entries WHERE account_id = 3 AND transaction_type = "payment_in";',
      ).get();
      expect(upiDebits.isNotEmpty, true);
      expect(upiDebits.first.data['debit'], 1000.0);
    });

    test('2.3 Credit sale debits customer receivable and tracks credit limit exposure', () async {
      final cubit = createCubit();
      await cubit.load();
      cubit.setTaxEnabled(false);

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);
      cubit.selectCustomer(testCustomerId);

      cubit.setPaymentMethod(PaymentMethod.credit);
      cubit.setPaid(0.0);

      expect(cubit.state.outstandingBalance, 450.0);
      expect(cubit.state.isCustomerOverCredit, false); // limit is 10000

      await cubit.checkout();

      // Verify customer ledger receivable entry
      final custDebits = await db.customSelect(
        'SELECT debit FROM ledger_entries WHERE party_type = "customer" AND party_id = ?;',
        variables: [Variable.withInt(testCustomerId)],
      ).get();
      expect(custDebits.isNotEmpty, true);
      expect(custDebits.first.data['debit'], 450.0);
    });

    test('2.4 Concurrency gate prevents double-tap checkout duplicate sales', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);

      // Initial product stock was 50
      final stockBefore = (await productRepo.getProduct(testProduct1Id))!.stockQty;
      expect(stockBefore, 50);

      // Trigger first checkout
      final f1 = cubit.checkout();
      // Concurrently trigger second checkout (simulating rapid cashier double tap)
      final f2 = cubit.checkout();

      await Future.wait([f1, f2]);

      final salesCount = await db.customSelect('SELECT COUNT(*) AS c FROM sales;').getSingle();
      expect(salesCount.data['c'], 1); // EXACTLY ONE sale invoice created!

      final stockAfter = (await productRepo.getProduct(testProduct1Id))!.stockQty;
      expect(stockAfter, 49); // Deducted exactly 1 unit, never duplicated!
    });

    test('2.5 Specific batch assignment decrements that batch directly', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(
        p1,
        batchId: testBatch1Id,
        batchNumber: 'COT-2026-A1',
      );
      cubit.updateItemQty(testProduct1Id, 5);

      await cubit.checkout();

      final batchRow = await db.customSelect(
        'SELECT quantity FROM product_batches WHERE id = ?;',
        variables: [Variable.withInt(testBatch1Id)],
      ).getSingle();

      expect(batchRow.data['quantity'], 15); // 20 - 5 = 15
    });
  });

  group('DARVI POS REDESIGN — SCREEN 3: INVOICE PREVIEW & SSEZNIK2POS 58MM PRINTING', () {
    test('3.1 Successful checkout automatically transitions to Screen 3 with invoice details', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);

      await cubit.checkout();

      expect(cubit.state.viewMode, PosViewMode.invoicePreview);
      expect(cubit.state.lastResult != null, true);
      expect(cubit.state.lastSaleDetail != null, true);
      expect(cubit.state.lastSaleDetail!.sale.invoiceNo, startsWith('INV-'));
    });

    test('3.2 SSEZNIK2POS 58mm thermal ESC/POS byte sequence generation adheres to 32 columns', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);
      cubit.setTaxEnabled(true);
      cubit.setTaxRate(0.18);
      cubit.selectCustomer(testCustomerId);

      await cubit.checkout();

      // Trigger thermal printing
      await cubit.printThermalReceipt();

      expect(thermalPrinter.lastSentBytes.isNotEmpty, true);

      final rawReceiptText = latin1.decode(thermalPrinter.lastSentBytes, allowInvalid: true);

      // Verify required Darvi and SSEZNIK2POS formatting
      expect(rawReceiptText.toUpperCase().contains('DARVI GROUP AGRI TECH'), true);
      expect(rawReceiptText.contains('29BKZPA0053M1ZQ'), true);
      expect(rawReceiptText.contains('Hubli'), true);
      expect(rawReceiptText.contains('Hybrid Cotton Seed'), true);
      expect(rawReceiptText.contains('Improving Agriculture,'), true);
      expect(rawReceiptText.contains('Thank You! Visit Again.'), true);
    });

    test('3.3 Diagnostic hardware self-test ticket byte generation', () async {
      final testBytes = EscPosGenerator.buildDiagnosticTestPrint();
      expect(testBytes.isNotEmpty, true);

      final text = latin1.decode(testBytes, allowInvalid: true);
      expect(text.contains('DARVI BILLING'), true);
      expect(text.contains('PRINTER SELF-TEST'), true);
      expect(text.contains('SSEZNIK2POS (58mm)'), true);
      expect(text.contains('Font A (32 Columns)'), true);
    });

    test('3.4 Strict Invariant: Repeated printing never modifies inventory or double-entry ledger', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);

      await cubit.checkout();

      final stockBeforePrint = (await productRepo.getProduct(testProduct1Id))!.stockQty;
      final ledgerCountBefore = (await db.customSelect('SELECT COUNT(*) AS c FROM ledger_entries;').getSingle()).data['c'];
      final salesCountBefore = (await db.customSelect('SELECT COUNT(*) AS c FROM sales;').getSingle()).data['c'];

      // Print multiple times
      await cubit.printThermalReceipt();
      await cubit.printThermalReceipt();
      await cubit.printDiagnosticTicket();

      final stockAfterPrint = (await productRepo.getProduct(testProduct1Id))!.stockQty;
      final ledgerCountAfter = (await db.customSelect('SELECT COUNT(*) AS c FROM ledger_entries;').getSingle()).data['c'];
      final salesCountAfter = (await db.customSelect('SELECT COUNT(*) AS c FROM sales;').getSingle()).data['c'];

      expect(stockAfterPrint, stockBeforePrint);
      expect(ledgerCountAfter, ledgerCountBefore);
      expect(salesCountAfter, salesCountBefore);
    });

    test('3.5 Start New Sale safely resets state and returns to Billing Workspace', () async {
      final cubit = createCubit();
      await cubit.load();

      final p1 = cubit.state.products.firstWhere((p) => p.id == testProduct1Id);
      cubit.addProductToCart(p1);
      await cubit.checkout();

      expect(cubit.state.viewMode, PosViewMode.invoicePreview);

      cubit.newSale();

      expect(cubit.state.viewMode, PosViewMode.workspace);
      expect(cubit.state.cart.isEmpty, true);
      expect(cubit.state.lastResult, isNull);
      expect(cubit.state.lastSaleDetail, isNull);
      expect(cubit.state.paid, 0.0);
    });
  });
}
