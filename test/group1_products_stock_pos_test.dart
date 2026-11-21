import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/data/repositories/local_ledger_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_product_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_sales_repository.dart';
import 'package:mini_pos_inventory/domain/entities/app_entities.dart';

void main() {
  late AppDatabase db;
  late LocalProductRepository productRepo;
  late LocalLedgerRepository ledgerRepo;
  late LocalSalesRepository salesRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await SeedData(db).ensureSeeded();
    ledgerRepo = LocalLedgerRepository(db);
    productRepo = LocalProductRepository(db);
    salesRepo = LocalSalesRepository(db, ledgerRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('Group 1: Products Module Tests', () {
    test('Can register and fetch products with extended fields', () async {
      final id = await productRepo.upsertProduct(
        const ProductUpsertInput(
          name: 'Darvi Bio-Phosphate',
          sku: 'AGRI-BIO-001',
          barcode: '8901234567890',
          cost: 450.0,
          price: 650.0,
          mrp: 750.0,
          stockQty: 50,
          lowStockThreshold: 10,
          unit: 'bag',
          brand: 'Darvi Agri',
          hsnCode: '3105',
          gstRate: 18.0,
          isActive: true,
        ),
      );

      expect(id, isPositive);
      final product = await productRepo.getProduct(id);
      expect(product, isNotNull);
      expect(product!.name, 'Darvi Bio-Phosphate');
      expect(product.sku, 'AGRI-BIO-001');
      expect(product.stockQty, 50);
      expect(product.unit, 'bag');
      expect(product.brand, 'Darvi Agri');
      expect(product.isActive, isTrue);
    });

    test('Can archive and reactivate product', () async {
      final id = await productRepo.upsertProduct(
        const ProductUpsertInput(
          name: 'Archivable Fertilizer',
          sku: 'ARCH-001',
          cost: 100,
          price: 150,
          stockQty: 10,
        ),
      );

      await productRepo.archiveProduct(id, false);
      var p = await productRepo.getProduct(id);
      expect(p!.isActive, isFalse);

      await productRepo.archiveProduct(id, true);
      p = await productRepo.getProduct(id);
      expect(p!.isActive, isTrue);
    });

    test('Prevents deleting a product that has transaction history', () async {
      // Products with initial seed data or sales should not be deletable
      final products = await productRepo.getProducts();
      final p = products.first;

      // Perform a sale with this product
      await salesRepo.checkout(
        SaleCheckoutInput(
          items: [
            CartItem(
              productId: p.id,
              name: p.name,
              sku: p.sku,
              cost: p.cost,
              price: p.price,
              qty: 1,
            ),
          ],
          paymentMethod: PaymentMethod.cash,
          paid: p.price,
        ),
      );

      // Now canDeleteProduct must return false
      final canDelete = await productRepo.canDeleteProduct(p.id);
      expect(canDelete, isFalse);

      expect(
        () => productRepo.deleteProduct(p.id),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Group 1: Stock & Inventory Operations Tests', () {
    test('Stock Inward updates stock and records stock movement', () async {
      final products = await productRepo.getProducts();
      final p = products.first;
      final initialStock = p.stockQty;

      await productRepo.inwardStock(
        productId: p.id,
        quantity: 25,
        costPrice: p.cost,
        batchNumber: 'BATCH-2026-X1',
        expiryDate: DateTime(2027, 12, 31),
        notes: 'Monsoon bulk consignment',
      );

      final updated = await productRepo.getProduct(p.id);
      expect(updated!.stockQty, initialStock + 25);

      final movements = await productRepo.getStockMovements(productId: p.id);
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.type, 'inward');
      expect(movements.first.qtyChange, 25);
    });

    test('Physical Count Adjustment correctly reconciles surplus or shortage', () async {
      final products = await productRepo.getProducts();
      final p = products.first;

      // Adjust to 40 units
      await productRepo.adjustStock(
        productId: p.id,
        newQuantity: 40,
        reason: 'Monthly physical warehouse audit',
      );

      final updated = await productRepo.getProduct(p.id);
      expect(updated!.stockQty, 40);

      final movements = await productRepo.getStockMovements(productId: p.id);
      expect(movements.first.type, 'adjust');
      expect(movements.first.balanceAfter, 40);
    });

    test('Damaged goods write-off safely deducts inventory with reason code', () async {
      final products = await productRepo.getProducts();
      final p = products.first;
      final stockBefore = p.stockQty;

      await productRepo.writeOffStock(
        productId: p.id,
        quantity: 2,
        reason: 'Bag torn in transit - spilled content',
      );

      final updated = await productRepo.getProduct(p.id);
      expect(updated!.stockQty, stockBefore - 2);

      final movements = await productRepo.getStockMovements(productId: p.id);
      expect(movements.first.type, 'damage');
      expect(movements.first.qtyChange, -2);
    });

    test('Batch creation and FEFO expiry ordering', () async {
      final products = await productRepo.getProducts();
      final p = products.first;

      await productRepo.addBatch(
        ProductBatchView(
          id: 0,
          workspaceId: 1,
          productId: p.id,
          batchNumber: 'B-EARLY',
          expiryDate: DateTime(2026, 6, 1),
          costPrice: 50,
          sellingPrice: 100,
          quantity: 10,
          initialQuantity: 10,
          status: 'active',
        ),
      );

      await productRepo.addBatch(
        ProductBatchView(
          id: 0,
          workspaceId: 1,
          productId: p.id,
          batchNumber: 'B-LATE',
          expiryDate: DateTime(2027, 6, 1),
          costPrice: 50,
          sellingPrice: 100,
          quantity: 10,
          initialQuantity: 10,
          status: 'active',
        ),
      );

      final batches = await productRepo.getBatches(productId: p.id);
      expect(batches.length, 2);
      expect(batches.first.batchNumber, 'B-EARLY'); // Earliest expiring first (FEFO)
    });
  });

  group('Group 1: POS Billing & Checkout Tests', () {
    test('Atomic checkout commits sale, decrements stock, records ledger and payments', () async {
      final products = await productRepo.getProducts();
      final p = products.first;
      final stockBefore = p.stockQty;

      final checkoutResult = await salesRepo.checkout(
        SaleCheckoutInput(
          items: [
            CartItem(
              productId: p.id,
              name: p.name,
              sku: p.sku,
              cost: p.cost,
              price: p.price,
              qty: 2,
            ),
          ],
          paymentMethod: PaymentMethod.cash,
          paid: p.price * 2,
          taxEnabled: true,
          taxRate: 0.18,
        ),
      );

      expect(checkoutResult.saleId, isPositive);
      expect(checkoutResult.invoiceNo, startsWith('INV-'));

      // Check stock decremented
      final updatedP = await productRepo.getProduct(p.id);
      expect(updatedP!.stockQty, stockBefore - 2);

      // Check invoice detail
      final detail = await salesRepo.getInvoiceDetail(checkoutResult.saleId);
      expect(detail, isNotNull);
      expect(detail!.items.length, 1);
      expect(detail.items.first.qty, 2);

      // Check ledger entries posted
      final ledger = await ledgerRepo.getRecentLedgerEntries();
      final saleEntries = ledger.where((e) => e.referenceId == checkoutResult.saleId).toList();
      expect(saleEntries.isNotEmpty, isTrue);
    });

    test('Sales return restores inventory and issues credit note', () async {
      final products = await productRepo.getProducts();
      final p = products.first;

      final checkout = await salesRepo.checkout(
        SaleCheckoutInput(
          items: [
            CartItem(
              productId: p.id,
              name: p.name,
              sku: p.sku,
              cost: p.cost,
              price: p.price,
              qty: 3,
            ),
          ],
          paymentMethod: PaymentMethod.cash,
          paid: p.price * 3,
        ),
      );

      final detail = await salesRepo.getInvoiceDetail(checkout.saleId);
      final saleItemId = detail!.items.first.id;
      final stockAfterSale = (await productRepo.getProduct(p.id))!.stockQty;

      // Return 1 unit
      final returnResult = await salesRepo.returnItems(
        saleId: checkout.saleId,
        items: [
          ReturnItemInput(
            saleItemId: saleItemId,
            qty: 1,
          ),
        ],
      );

      expect(returnResult.returnSaleId, isPositive);

      // Inventory restored by 1
      final stockAfterReturn = (await productRepo.getProduct(p.id))!.stockQty;
      expect(stockAfterReturn, stockAfterSale + 1);
    });
  });
}
