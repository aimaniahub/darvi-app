import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/core/errors/app_exception.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/data/repositories/local_account_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_expense_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_ledger_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_party_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_product_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_purchase_repository.dart';

void main() {
  late AppDatabase db;
  late LocalLedgerRepository ledgerRepo;
  late LocalProductRepository productRepo;
  late LocalPartyRepository partyRepo;
  late LocalPurchaseRepository purchaseRepo;
  late LocalAccountRepository accountRepo;
  late LocalExpenseRepository expenseRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledgerRepo = LocalLedgerRepository(db);
    productRepo = LocalProductRepository(db);
    partyRepo = LocalPartyRepository(db, ledgerRepo);
    purchaseRepo = LocalPurchaseRepository(db, ledgerRepo);
    accountRepo = LocalAccountRepository(db, ledgerRepo);
    expenseRepo = LocalExpenseRepository(db, ledgerRepo);

    await SeedData(db).ensureSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  group('DARVI BILLING GROUP 3: MODULE 1 — PURCHASE MANAGEMENT TESTS', () {
    test('1.1 Multi-item purchase invoice creation, stock inward, batch tracking, and ledger posting', () async {
      // 1. Create a test product
      final productId = await productRepo.upsertProduct(
        const ProductUpsertInput(
          name: 'Darvi Bio-Urea 50kg',
          sku: 'AGRI-BIO-UREA',
          cost: 800.0,
          price: 1100.0,
          stockQty: 10,
          unit: 'bag',
          brand: 'Darvi Nutrients',
          hsnCode: '3102',
          gstRate: 5.0,
        ),
      );

      // 2. Create a supplier
      final supplierId = await partyRepo.upsertSupplier(
        name: 'Southern Bio Fertilizers Ltd',
        code: 'SUP-AGRI-001',
        contactPerson: 'Kalyan Sundaram',
        phone: '9845012345',
        email: 'contact@southbio.com',
        gstin: '29AABCS1429B1Z1',
        state: 'Karnataka',
        openingBalance: 0.0,
        paymentTerms: 'Net 30',
        isActive: true,
      );

      // 3. Create a multi-item purchase invoice: 50 bags @ 800 = 40,000 + 5% GST (2,000) = 42,000 Total.
      // Partial payment of 10,000 paid from Cash Account (id: 1)
      final invoiceInput = PurchaseInvoiceInput(
        workspaceId: 1,
        supplierId: supplierId,
        supplierInvoiceNo: 'SBF/2026/001',
        supplierInvoiceDate: DateTime(2026, 6, 15),
        isGstInclusive: false,
        subtotal: 40000.0,
        taxTotal: 2000.0,
        total: 42000.0,
        paid: 10000.0,
        accountId: 1,
        paymentMode: 'cash',
        paymentReference: 'CASH-ADV-01',
        notes: 'Monsoon bulk inventory inward',
        items: [
          PurchaseInvoiceItemInput(
            productId: productId,
            qty: 50,
            unitCost: 800.0,
            gstRate: 5.0,
            lineTotal: 42000.0,
            batchNumber: 'BATCH-2026-X1',
            mfgDate: DateTime(2026, 5, 1),
            expiryDate: DateTime(2028, 5, 1),
            hsnCode: '3102',
            purchaseUnit: 'bag',
            cgst: 1000.0,
            sgst: 1000.0,
          ),
        ],
      );

      final invoiceId = await purchaseRepo.createPurchaseInvoice(invoiceInput);
      expect(invoiceId, isPositive);

      // 4. Verify invoice details
      final invoice = await purchaseRepo.getPurchaseInvoiceDetail(invoiceId);
      expect(invoice, isNotNull);
      expect(invoice!['supplier_invoice_no'], 'SBF/2026/001');
      expect(invoice['subtotal'], 40000.0);
      expect(invoice['tax_total'], 2000.0);
      expect(invoice['total'], 42000.0);
      expect(invoice['paid'], 10000.0);
      expect(invoice['outstanding_balance'], 32000.0);
      expect(invoice['payment_status'], 'partial');

      // 5. Verify stock increment: 10 initial + 50 received = 60
      final updatedProduct = await productRepo.getProduct(productId);
      expect(updatedProduct!.stockQty, 60);

      // 6. Verify stock movement entry created
      final movements = await db.customSelect(
        'SELECT * FROM stock_movements WHERE product_id = ? AND type = ?',
        readsFrom: {},
        variables: [Variable.withInt(productId), Variable.withString('purchase')],
      ).get();
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.data['qty_change'], 50);

      // 7. Verify batch inward record created
      final batches = await db.customSelect(
        'SELECT * FROM product_batches WHERE product_id = ? AND batch_number = ?',
        readsFrom: {},
        variables: [Variable.withInt(productId), Variable.withString('BATCH-2026-X1')],
      ).get();
      expect(batches.isNotEmpty, isTrue);
      expect(batches.first.data['quantity'], 50);

      // 8. Verify Supplier Payable ledger balance: 42,000 credit - 10,000 paid = 32,000 payable
      final supplierBalance = await ledgerRepo.getSupplierBalance(supplierId);
      expect(supplierBalance, 32000.0);

      // 9. Verify Double-Entry Balance Invariant: Total Debit == Total Credit
      final reconciliation = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(reconciliation['is_trial_balanced'], isTrue);
    });

    test('1.2 Duplicate purchase invoice number prevention for same supplier', () async {
      final supplierId = await partyRepo.upsertSupplier(
        name: 'Kisan Bio Agri Ltd',
        code: 'SUP-KISAN-001',
        contactPerson: 'Suresh Patil',
        phone: '9845099999',
        openingBalance: 0.0,
        isActive: true,
      );

      final pId = await productRepo.upsertProduct(
        const ProductUpsertInput(
          name: 'Neem Cake 25kg',
          sku: 'NEEM-CAKE-25',
          cost: 300.0,
          price: 450.0,
          stockQty: 5,
        ),
      );

      final invoiceInput = PurchaseInvoiceInput(
        workspaceId: 1,
        supplierId: supplierId,
        supplierInvoiceNo: 'INV-DUP-TEST-01',
        supplierInvoiceDate: DateTime.now(),
        subtotal: 3000.0,
        total: 3000.0,
        items: [
          PurchaseInvoiceItemInput(
            productId: pId,
            qty: 10,
            unitCost: 300.0,
            lineTotal: 3000.0,
          ),
        ],
      );

      await purchaseRepo.createPurchaseInvoice(invoiceInput);

      // Attempting to insert another invoice with same supplier and invoice number should throw exception
      expect(
        () => purchaseRepo.createPurchaseInvoice(invoiceInput),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('already been entered for this supplier'),
        )),
      );
    });

    test('1.3 Safe purchase editing: reversals of previous stock and ledger', () async {
      final pId = await productRepo.upsertProduct(
        const ProductUpsertInput(
          name: 'Zinc Sulphate 10kg',
          sku: 'ZINC-SULPH-10',
          cost: 250.0,
          price: 400.0,
          stockQty: 0,
        ),
      );

      final sId = await partyRepo.upsertSupplier(
        name: 'Micro Minerals Co',
        code: 'SUP-MINERAL-01',
        contactPerson: 'Venkatesh',
        phone: '9877777777',
        openingBalance: 0.0,
        isActive: true,
      );

      // Create invoice: 20 units @ 250 = 5000
      final invoiceId = await purchaseRepo.createPurchaseInvoice(
        PurchaseInvoiceInput(
          workspaceId: 1,
          supplierId: sId,
          supplierInvoiceNo: 'BILL-EDIT-01',
          supplierInvoiceDate: DateTime.now(),
          subtotal: 5000.0,
          total: 5000.0,
          items: [
            PurchaseInvoiceItemInput(
              productId: pId,
              qty: 20,
              unitCost: 250.0,
              lineTotal: 5000.0,
              batchNumber: 'ZINC-B1',
            ),
          ],
        ),
      );

      var product = await productRepo.getProduct(pId);
      expect(product!.stockQty, 20);
      expect(await ledgerRepo.getSupplierBalance(sId), 5000.0);

      // Edit the invoice to 30 units @ 260 = 7800
      await purchaseRepo.editPurchaseInvoice(
        invoiceId,
        PurchaseInvoiceInput(
          workspaceId: 1,
          supplierId: sId,
          supplierInvoiceNo: 'BILL-EDIT-01',
          supplierInvoiceDate: DateTime.now(),
          subtotal: 7800.0,
          total: 7800.0,
          items: [
            PurchaseInvoiceItemInput(
              productId: pId,
              qty: 30,
              unitCost: 260.0,
              lineTotal: 7800.0,
              batchNumber: 'ZINC-B1',
            ),
          ],
        ),
      );

      // Verify stock was reversed from 20 back to 0 then increased to 30
      product = await productRepo.getProduct(pId);
      expect(product!.stockQty, 30);

      // Verify supplier balance updated to 7800
      expect(await ledgerRepo.getSupplierBalance(sId), 7800.0);

      // Verify double-entry ledger balance maintained
      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);
    });

    test('1.4 Purchase return / debit note: reduces stock, reverses batch & GST, credits supplier', () async {
      final pId = await productRepo.upsertProduct(
        const ProductUpsertInput(
          name: 'Organic Fungicide 1L',
          sku: 'FUNGI-ORG-01',
          cost: 500.0,
          price: 750.0,
          stockQty: 0,
        ),
      );

      final sId = await partyRepo.upsertSupplier(
        name: 'Green Crop Protection',
        code: 'SUP-GREEN-01',
        phone: '9844433322',
        openingBalance: 0.0,
        isActive: true,
      );

      final invoiceId = await purchaseRepo.createPurchaseInvoice(
        PurchaseInvoiceInput(
          workspaceId: 1,
          supplierId: sId,
          supplierInvoiceNo: 'GCP/2026/89',
          supplierInvoiceDate: DateTime.now(),
          subtotal: 10000.0,
          taxTotal: 1800.0,
          total: 11800.0,
          items: [
            PurchaseInvoiceItemInput(
              productId: pId,
              qty: 20,
              unitCost: 500.0,
              gstRate: 18.0,
              lineTotal: 11800.0,
              batchNumber: 'BATCH-FUNGI-01',
              cgst: 900.0,
              sgst: 900.0,
            ),
          ],
        ),
      );

      // 20 * 500 = 10,000 + 18% GST (1,800) = 11,800 total payable
      expect(await ledgerRepo.getSupplierBalance(sId), 11800.0);
      expect((await productRepo.getProduct(pId))!.stockQty, 20);

      // Return 5 units due to packaging defect: 5 * 500 = 2,500 + 18% GST (450) = 2,950 debit note
      final returnId = await purchaseRepo.createPurchaseReturn(
        PurchaseReturnInput(
          workspaceId: 1,
          purchaseInvoiceId: invoiceId,
          supplierId: sId,
          debitNoteNumber: 'DN-2026-001',
          returnDate: DateTime.now(),
          reason: 'Defective seal on 5 bottles',
          subtotal: 2500.0,
          taxTotal: 450.0,
          totalAmount: 2950.0,
          items: [
            PurchaseReturnItemInput(
              productId: pId,
              quantity: 5,
              unitCost: 500.0,
              gstRate: 18.0,
              taxAmount: 450.0,
              total: 2950.0,
              batchNumber: 'BATCH-FUNGI-01',
            ),
          ],
        ),
      );

      expect(returnId, isPositive);

      // Stock should decrease by 5: 20 - 5 = 15
      expect((await productRepo.getProduct(pId))!.stockQty, 15);

      // Supplier payable should decrease: 11,800 - 2,950 = 8,850
      expect(await ledgerRepo.getSupplierBalance(sId), 8850.0);

      // Verify trial balance remains balanced
      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);
    });

    test('1.5 Cannot return more items than purchased', () async {
      final pId = await productRepo.upsertProduct(
        const ProductUpsertInput(name: 'Seed Pack', sku: 'SEED-001', cost: 100, price: 150, stockQty: 0),
      );
      final sId = await partyRepo.upsertSupplier(
        name: 'Seeds Co',
        code: 'SUP-SEED-01',
        isActive: true,
      );
      final invoiceId = await purchaseRepo.createPurchaseInvoice(
        PurchaseInvoiceInput(
          workspaceId: 1,
          supplierId: sId,
          supplierInvoiceNo: 'SEED-01',
          supplierInvoiceDate: DateTime.now(),
          subtotal: 500.0,
          total: 500.0,
          items: [
            PurchaseInvoiceItemInput(productId: pId, qty: 5, unitCost: 100, lineTotal: 500),
          ],
        ),
      );

      // Attempting to return 10 when only 5 were bought
      expect(
        () => purchaseRepo.createPurchaseReturn(
          PurchaseReturnInput(
            workspaceId: 1,
            purchaseInvoiceId: invoiceId,
            supplierId: sId,
            debitNoteNumber: 'DN-EXCESS-01',
            returnDate: DateTime.now(),
            reason: 'Excess return test',
            subtotal: 1000.0,
            totalAmount: 1000.0,
            items: [
              PurchaseReturnItemInput(productId: pId, quantity: 10, unitCost: 100, total: 1000),
            ],
          ),
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('1.6 Purchase dashboard metrics and purchase reports', () async {
      final metrics = await purchaseRepo.getPurchaseDashboardMetrics(workspaceId: 1);
      expect(metrics.totalPurchases, isNotNull);
      expect(metrics.totalPaid, isNotNull);
      expect(metrics.totalOutstanding, isNotNull);
      expect(metrics.invoicesCount, isNotNull);

      final report = await purchaseRepo.getPurchaseReport(workspaceId: 1);
      expect(report.containsKey('supplier_wise'), isTrue);
      expect(report.containsKey('monthly_trends'), isTrue);
      expect(report.containsKey('gst_summary'), isTrue);
    });
  });

  group('DARVI BILLING GROUP 3: MODULE 2 — CUSTOMER AND SUPPLIER MANAGEMENT TESTS', () {
    test('2.1 Customer registration with 14 fields and duplicate code validation', () async {
      final custId = await partyRepo.upsertCustomer(
        name: 'Mahadev Agricultural Farm',
        code: 'CUST-AGRI-001',
        phone: '9845112233',
        alternatePhone: '9845112244',
        email: 'mahadev.farm@gmail.com',
        address: 'Plot 45, NH4 Bypass, Dharwad',
        state: 'Karnataka',
        gstin: '29ABCDE1234F1Z5',
        customerType: 'business',
        creditLimit: 50000.0,
        creditPeriodDays: 45,
        openingBalance: 12000.0,
        notes: 'Premium regular client with seed dealership',
        isActive: true,
      );

      expect(custId, isPositive);

      final fetched = await partyRepo.getCustomerById(custId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Mahadev Agricultural Farm');
      expect(fetched.code, 'CUST-AGRI-001');
      expect(fetched.customerType, 'business');
      expect(fetched.creditLimit, 50000.0);
      expect(fetched.creditPeriodDays, 45);
      expect(fetched.openingBalance, 12000.0);
      expect(fetched.gstin, '29ABCDE1234F1Z5');

      // Duplicate customer code validation
      expect(
        () => partyRepo.upsertCustomer(
          name: 'Another Farm',
          code: 'CUST-AGRI-001',
        ),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        )),
      );
    });

    test('2.2 Supplier registration with 12 fields and duplicate code validation', () async {
      final supId = await partyRepo.upsertSupplier(
        name: 'Karnataka Agro Chemicals',
        code: 'SUP-KAC-001',
        contactPerson: 'Raghavendra Joshi',
        phone: '9888800011',
        email: 'sales@kacagri.com',
        address: 'Industrial Area, Rayapur, Hubli',
        gstin: '29AAACK1234F1Z9',
        state: 'Karnataka',
        openingBalance: 25000.0,
        paymentTerms: 'Net 45',
        notes: 'Exclusive distributor for micronutrients',
        isActive: true,
      );

      expect(supId, isPositive);

      final fetched = await partyRepo.getSupplierById(supId);
      expect(fetched, isNotNull);
      expect(fetched!.code, 'SUP-KAC-001');
      expect(fetched.contactPerson, 'Raghavendra Joshi');
      expect(fetched.paymentTerms, 'Net 45');
      expect(fetched.openingBalance, 25000.0);

      // Duplicate code check
      expect(
        () => partyRepo.upsertSupplier(
          name: 'Different Name',
          code: 'SUP-KAC-001',
        ),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        )),
      );
    });

    test('2.3 Customer collection workflow with invoice allocation and balanced ledger posting', () async {
      // 1. Create customer
      final custId = await partyRepo.upsertCustomer(
        name: 'Shankar Farmers Cooperative',
        code: 'CUST-SHK-001',
        phone: '9900011122',
        creditLimit: 100000.0,
        isActive: true,
      );

      // 2. Insert mock sales invoice in DB to allocate against
      final saleId = await db.customInsert(
        'INSERT INTO sales (workspace_id, invoice_no, customer_id, subtotal, discount_total, tax_total, total, paid, change_amount, payment_method, status, created_at) '
        'VALUES (1, "INV-2026-001", ?, 20000.0, 0.0, 1000.0, 21000.0, 0.0, 0.0, "credit", "unpaid", 1770000000)',
        variables: [Variable.withInt(custId)],
      );

      // Post initial receivable ledger entry for sale
      await ledgerRepo.postTransaction(
        workspaceId: 1,
        entries: [
          LedgerPostingItem(
            transactionType: 'sale',
            referenceType: 'sale',
            referenceId: saleId,
            partyType: 'customer',
            partyId: custId,
            debit: 21000.0, // Customer owes 21,000
            narration: 'Sale invoice INV-2026-001',
          ),
          const LedgerPostingItem(
            transactionType: 'sale',
            referenceType: 'sale',
            credit: 21000.0, // Sales revenue
            narration: 'Sales revenue',
          ),
        ],
      );

      expect(await ledgerRepo.getCustomerBalance(custId), 21000.0);

      // 3. Receive collection: Customer pays 15,000 into Bank Account (id: 2)
      await partyRepo.recordCustomerCollection(
        customerId: custId,
        amount: 15000.0,
        accountId: 2,
        referenceNo: 'NEFT-COLLECT-887',
        paymentDate: DateTime.now(),
        narration: 'Partial payment against invoice INV-2026-001',
        invoiceAllocations: [
          {'invoice_id': saleId, 'amount': 15000.0},
        ],
      );

      // Customer outstanding should now be 21,000 - 15,000 = 6,000
      final updatedCustBalance = await ledgerRepo.getCustomerBalance(custId);
      expect(updatedCustBalance, 6000.0);

      // Bank account balance should have increased by 15,000
      final bankBalance = await ledgerRepo.getAccountBalance(2);
      expect(bankBalance, greaterThanOrEqualTo(15000.0));

      // Trial balance must remain balanced
      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);
    });

    test('2.4 Supplier payout workflow with invoice allocation and balanced ledger posting', () async {
      final supId = await partyRepo.upsertSupplier(
        name: 'Shree Balaji Seeds',
        code: 'SUP-BALAJI-01',
        phone: '9845199999',
        openingBalance: 0.0,
        isActive: true,
      );

      final pId = await productRepo.upsertProduct(
        const ProductUpsertInput(name: 'Sunflower Seeds', sku: 'SEED-SUN-01', cost: 400, price: 600, stockQty: 0),
      );

      final invId = await purchaseRepo.createPurchaseInvoice(
        PurchaseInvoiceInput(
          workspaceId: 1,
          supplierId: supId,
          supplierInvoiceNo: 'BALAJI-101',
          supplierInvoiceDate: DateTime.now(),
          subtotal: 10000.0,
          total: 10000.0,
          items: [
            PurchaseInvoiceItemInput(productId: pId, qty: 25, unitCost: 400, lineTotal: 10000),
          ],
        ),
      );
      // Total payable = 25 * 400 = 10,000
      expect(await ledgerRepo.getSupplierBalance(supId), 10000.0);

      // Supplier Payout of 6,000 via UPI (account 3)
      await partyRepo.recordSupplierPayout(
        supplierId: supId,
        amount: 6000.0,
        accountId: 3,
        referenceNo: 'UPI-REF-992211',
        paymentDate: DateTime.now(),
        narration: 'Payment towards BALAJI-101',
        invoiceAllocations: [
          {'purchase_invoice_id': invId, 'amount': 6000.0},
        ],
      );

      // Remaining payable: 10,000 - 6,000 = 4,000
      expect(await ledgerRepo.getSupplierBalance(supId), 4000.0);

      // Invoice status in purchase table should be updated to partial
      final invoice = await purchaseRepo.getPurchaseInvoiceDetail(invId);
      expect(invoice!['paid'], 6000.0);
      expect(invoice['outstanding_balance'], 4000.0);
      expect(invoice['payment_status'], 'partial');

      // Trial balance verified
      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);
    });

    test('2.5 Auditable opening balance adjustments create balanced ledger entries', () async {
      final custId = await partyRepo.upsertCustomer(
        name: 'Gowda Agro Services',
        code: 'CUST-GOWDA-01',
        phone: '9845000001',
        isActive: true,
      );

      // Adjust customer opening balance to 5,000
      await partyRepo.adjustPartyOpeningBalance(
        partyType: 'customer',
        partyId: custId,
        newOpeningBalance: 5000.0,
        reason: 'Historical ledger audit adjustment',
      );

      expect(await ledgerRepo.getCustomerBalance(custId), 5000.0);

      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);
    });

    test('2.6 Party profile queries for customer and supplier', () async {
      final custId = await partyRepo.upsertCustomer(
        name: 'Profile Test Customer',
        phone: '9988776655',
      );
      final custProfile = await partyRepo.getCustomerProfile(custId);
      expect(custProfile.containsKey('customer'), isTrue);
      expect(custProfile.containsKey('total_purchases'), isTrue);
      expect(custProfile.containsKey('recent_sales'), isTrue);

      final supId = await partyRepo.upsertSupplier(
        name: 'Profile Test Supplier',
        phone: '9988776644',
      );
      final supProfile = await partyRepo.getSupplierProfile(supId);
      expect(supProfile.containsKey('supplier'), isTrue);
      expect(supProfile.containsKey('total_purchases'), isTrue);
      expect(supProfile.containsKey('invoices'), isTrue);
    });
  });

  group('DARVI BILLING GROUP 3: MODULE 3 — FINANCIAL MANAGEMENT & ACCOUNTS TESTS', () {
    test('3.1 Account management and deactivation balance protection', () async {
      // Create new bank account
      final accId = await accountRepo.createAccount(
        name: 'HDFC Current Agri Account',
        type: 'bank',
        accountNumber: '50200012345678',
        bankName: 'HDFC Bank',
        ifsc: 'HDFC0001234',
        initialBalance: 100000.0,
      );

      expect(accId, isPositive);
      final accounts = await accountRepo.getAccounts(activeOnly: false);
      final acc = accounts.firstWhere((a) => a.id == accId);
      expect(acc.name, 'HDFC Current Agri Account');
      expect(acc.type, 'bank');
      expect(acc.bankName, 'HDFC Bank');
      expect(acc.ifsc, 'HDFC0001234');

      // Attempting to deactivate an account with a non-zero balance must fail
      expect(
        () => accountRepo.deactivateAccount(accId),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('non-zero balance'),
        )),
      );
    });

    test('3.2 Inter-account fund transfer between Cash, Bank, and UPI accounts', () async {
      // 1. Initial Cash float deposit
      await accountRepo.recordMoneyReceived(
        accountId: 1,
        amount: 10000.0,
        category: 'Opening Float',
        description: 'Daily opening cash drawer float',
      );
      final initialCash = await ledgerRepo.getAccountBalance(1);
      final initialBank = await ledgerRepo.getAccountBalance(2);

      // 2. Transfer 5,000 from Cash to Bank
      await accountRepo.transferFunds(
        fromAccountId: 1,
        toAccountId: 2,
        amount: 5000.0,
        transferDate: DateTime.now(),
        referenceNo: 'BANK-DEP-001',
        narration: 'Daily counter cash deposit',
      );

      // Verify source deducted and destination credited
      final updatedCash = await ledgerRepo.getAccountBalance(1);
      final updatedBank = await ledgerRepo.getAccountBalance(2);

      expect(updatedCash, initialCash - 5000.0);
      expect(updatedBank, initialBank + 5000.0);

      // Verify trial balance invariant
      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);
    });

    test('3.3 Expense recording with recoverable input GST and safe cancellation reversal', () async {
      final initialBank = await ledgerRepo.getAccountBalance(2);

      // Record warehouse electricity expense: Net 4000 + 18% GST (720) = 4720 from Bank Account (id: 2)
      final expenseId = await expenseRepo.addExpense(
        accountId: 2,
        category: 'Utilities',
        amount: 4720.0,
        taxAmount: 720.0,
        expenseDate: DateTime.now(),
        vendorPayee: 'HESCOM Power Utility',
        referenceNo: 'HESC-BILL-MAY',
        notes: 'Warehouse 3-phase commercial electricity',
      );

      expect(expenseId, isPositive);

      // Bank account deducted by total 4720
      final afterExpenseBank = await ledgerRepo.getAccountBalance(2);
      expect(afterExpenseBank, initialBank - 4720.0);

      // Check trial balance invariant
      var recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);

      // Safe cancellation of expense reverses funds back to Bank
      await expenseRepo.cancelExpense(expenseId, reason: 'Duplicate billing by utility');

      final afterCancelBank = await ledgerRepo.getAccountBalance(2);
      expect(afterCancelBank, initialBank);

      recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      expect(recon['is_trial_balanced'], isTrue);
    });

    test('3.4 Cashbook generation and chronological transaction tracking', () async {
      await accountRepo.recordMoneyReceived(
        accountId: 1,
        amount: 8000.0,
        category: 'Counter Collection',
        description: 'Morning collection',
      );
      await accountRepo.recordMoneyPaid(
        accountId: 1,
        amount: 1500.0,
        category: 'Transport',
        description: 'Fertilizer diesel conveyance',
      );

      final cashbook = await accountRepo.getCashbookEntries(
        workspaceId: 1,
        fromDate: DateTime(2026, 1, 1),
        toDate: DateTime(2026, 12, 31),
      );

      expect(cashbook, isNotEmpty);
      expect(cashbook.length, greaterThanOrEqualTo(2));
      for (final entry in cashbook) {
        expect(entry.runningBalance, isNotNull);
        expect(entry.accountName, isNotEmpty);
      }
    });

    test('3.5 Financial dashboard metrics and P&L statement generation', () async {
      final metrics = await accountRepo.getFinancialDashboardMetrics(workspaceId: 1);

      expect(metrics.totalCash, isNotNull);
      expect(metrics.totalBank, isNotNull);
      expect(metrics.totalUpi, isNotNull);
      expect(metrics.totalLiquidBalance, isNotNull);

      // Test P&L generation
      final pnl = await accountRepo.getProfitAndLossReport(
        workspaceId: 1,
        fromDate: DateTime(2026, 1, 1),
        toDate: DateTime(2026, 12, 31),
      );

      expect(pnl.containsKey('revenue'), isTrue);
      expect(pnl.containsKey('cogs'), isTrue);
      expect(pnl.containsKey('gross_profit'), isTrue);
      expect(pnl.containsKey('expenses'), isTrue);
      expect(pnl.containsKey('net_profit'), isTrue);
    });

    test('3.6 System-Wide Double-Entry Ledger Trial Balance Verification', () async {
      // Reconcile system-wide trial balance
      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);

      expect(recon['is_trial_balanced'], isTrue);
      expect(recon['trial_balance_diff'].abs(), lessThan(0.01));
      expect(recon['total_debit'], equals(recon['total_credit']));
    });
  });
}
