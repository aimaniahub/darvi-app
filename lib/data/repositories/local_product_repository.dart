import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/repositories.dart';

class LocalProductRepository implements ProductRepository {
  LocalProductRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> addCategory(String name) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(name: name.trim()),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<void> addStockMovement(StockMovementInput input) {
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(input.productId)))
          .getSingleOrNull();
      if (product == null) {
        throw AppException('Product not found');
      }

      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final newQty = product.stockQty + input.qtyChange;

      // Atomic stock quantity update
      await _db.customStatement('''
        UPDATE products
        SET stock_qty = ?, cost = COALESCE(?, cost), updated_at = ?
        WHERE id = ?
      ''', [
        newQty,
        input.unitCost,
        nowSeconds,
        input.productId,
      ]);

      await _db.customStatement('''
        INSERT INTO stock_movements (
          product_id, type, qty_change, reason, supplier_id, unit_cost, balance_after, workspace_id, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''', [
        input.productId,
        input.type.value,
        input.qtyChange,
        input.reason,
        input.supplierId,
        input.unitCost,
        newQty,
        product.workspaceId ?? 1,
        nowSeconds,
      ]);
    });
  }

  @override
  Future<void> deleteCategory(int id) async {
    final count = await (_db.select(_db.products)..where((tbl) => tbl.categoryId.equals(id))).get();
    if (count.isNotEmpty) {
      throw AppException('Cannot delete category with assigned products');
    }
    await (_db.delete(_db.categories)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<bool> canDeleteProduct(int id) async {
    try {
      final saleCount = await _db.customSelect(
        'SELECT COUNT(*) as c FROM sale_items WHERE product_id = ?;',
        variables: [Variable.withInt(id)],
      ).getSingle();
      if ((saleCount.data['c'] as num).toInt() > 0) return false;

      final piCount = await _db.customSelect(
        'SELECT COUNT(*) as c FROM purchase_invoice_items WHERE product_id = ?;',
        variables: [Variable.withInt(id)],
      ).getSingle();
      if ((piCount.data['c'] as num).toInt() > 0) return false;
    } catch (_) {}
    return true;
  }

  @override
  Future<void> deleteProduct(int id, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin) {
      throw AppException('Access denied: Deleting products requires admin permission');
    }
    final allowed = await canDeleteProduct(id);
    if (!allowed) {
      throw AppException(
        'Product has historical sales or purchase records and cannot be deleted. Deactivate or archive it instead to preserve audit logs.',
      );
    }
    await (_db.delete(_db.products)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<void> archiveProduct(int id, bool isActive, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Archiving products requires admin or manager permission');
    }
    await _db.customStatement(
      'UPDATE products SET is_active = ? WHERE id = ?;',
      [isActive ? 1 : 0, id],
    );
  }

  @override
  Future<ProductView?> findByBarcode(String barcode) async {
    final row = await (_db.select(_db.products)..where((tbl) => tbl.barcode.equals(barcode.trim())))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    final category = row.categoryId == null
        ? null
        : await (_db.select(_db.categories)..where((tbl) => tbl.id.equals(row.categoryId!)))
            .getSingleOrNull();

    final extra = await _getProductExtras(row.id);
    return _toProductView(
      row,
      category?.name,
      isActive: extra['is_active'] as bool?,
      mrp: extra['mrp'] as double?,
      brand: extra['brand'] as String?,
    );
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final rows = await (_db.select(_db.categories)..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])).get();
    return rows.map((e) => CategoryModel(id: e.id, name: e.name)).toList();
  }

  @override
  Future<List<ProductView>> getLowStockProducts({int workspaceId = 1}) async {
    final products = await (_db.select(_db.products)
          ..where((tbl) => tbl.workspaceId.equals(workspaceId) & tbl.stockQty.isSmallerOrEqual(tbl.lowStockThreshold))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.stockQty)]))
        .get();

    final categories = await _db.select(_db.categories).get();
    final catById = {for (final c in categories) c.id: c.name};
    final extras = await _getAllProductExtras();

    return products.map((p) {
      final extra = extras[p.id];
      return _toProductView(
        p,
        catById[p.categoryId],
        isActive: extra?['is_active'] as bool?,
        mrp: extra?['mrp'] as double?,
        brand: extra?['brand'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<ProductView>> getPopularProducts({int limit = 10, int workspaceId = 1}) async {
    final products = await (_db.select(_db.products)
          ..where((tbl) => tbl.workspaceId.equals(workspaceId))
          ..limit(limit))
        .get();
    final categories = await _db.select(_db.categories).get();
    final catById = {for (final c in categories) c.id: c.name};
    final extras = await _getAllProductExtras();

    return products.map((p) {
      final extra = extras[p.id];
      return _toProductView(
        p,
        catById[p.categoryId],
        isActive: extra?['is_active'] as bool?,
        mrp: extra?['mrp'] as double?,
        brand: extra?['brand'] as String?,
      );
    }).toList();
  }

  @override
  Future<ProductView?> getProduct(int id, {int? workspaceId}) async {
    final query = _db.select(_db.products)..where((tbl) => tbl.id.equals(id));
    if (workspaceId != null) {
      query.where((tbl) => tbl.workspaceId.equals(workspaceId));
    }
    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }
    final category = row.categoryId == null
        ? null
        : await (_db.select(_db.categories)..where((tbl) => tbl.id.equals(row.categoryId!)))
            .getSingleOrNull();

    final extra = await _getProductExtras(row.id);
    return _toProductView(
      row,
      category?.name,
      isActive: extra['is_active'] as bool?,
      mrp: extra['mrp'] as double?,
      brand: extra['brand'] as String?,
    );
  }

  @override
  Future<List<ProductView>> getProducts({ProductFilter filter = const ProductFilter(), int workspaceId = 1}) async {
    final query = _db.select(_db.products)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId));

    if (filter.categoryId != null) {
      query.where((tbl) => tbl.categoryId.equals(filter.categoryId!));
    }
    if (filter.lowStockOnly) {
      query.where((tbl) => tbl.stockQty.isSmallerOrEqual(tbl.lowStockThreshold));
    }

    final search = filter.search.trim().toLowerCase();
    final rows = await query.get();
    final categories = await _db.select(_db.categories).get();
    final catById = {for (final c in categories) c.id: c.name};
    final extras = await _getAllProductExtras();

    final filtered = rows.where((row) {
      if (search.isEmpty) {
        return true;
      }
      final name = row.name.toLowerCase();
      final sku = row.sku.toLowerCase();
      final barcode = (row.barcode ?? '').toLowerCase();
      return name.contains(search) || sku.contains(search) || barcode.contains(search);
    }).toList();

    return filtered.map((p) {
      final extra = extras[p.id];
      return _toProductView(
        p,
        catById[p.categoryId],
        isActive: extra?['is_active'] as bool?,
        mrp: extra?['mrp'] as double?,
        brand: extra?['brand'] as String?,
      );
    }).toList();
  }

  @override
  Future<int> upsertProduct(ProductUpsertInput input, {int workspaceId = 1, UserRole? callerRole}) {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Modifying products requires admin or manager permission');
    }
    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    return _db.transaction(() async {
      int prodId;
      if (input.id == null) {
        prodId = await _db.into(_db.products).insert(
              ProductsCompanion.insert(
                name: input.name.trim(),
                sku: input.sku.trim(),
                barcode: Value(input.barcode?.trim()),
                categoryId: Value(input.categoryId),
                cost: input.cost,
                price: input.price,
                stockQty: input.stockQty,
                lowStockThreshold: Value(input.lowStockThreshold),
                unit: Value(input.unit),
                notes: Value(input.notes),
                imagePath: Value(input.imagePath),
                createdAt: Value(now),
                updatedAt: Value(now),
                workspaceId: Value(workspaceId),
                hsnCode: Value(input.hsnCode?.trim()),
                gstRate: Value(input.gstRate),
              ),
            );

        if (input.stockQty != 0) {
          await _db.customStatement('''
            INSERT INTO stock_movements (
              product_id, type, qty_change, reason, balance_after, workspace_id, created_at
            ) VALUES (?, 'adjust', ?, 'Opening Stock Entry', ?, ?, ?);
          ''', [prodId, input.stockQty, input.stockQty, workspaceId, nowSeconds]);
        }
      } else {
        prodId = input.id!;
        await (_db.update(_db.products)..where((tbl) => tbl.id.equals(prodId))).write(
          ProductsCompanion(
            name: Value(input.name.trim()),
            sku: Value(input.sku.trim()),
            barcode: Value(input.barcode?.trim()),
            categoryId: Value(input.categoryId),
            cost: Value(input.cost),
            price: Value(input.price),
            stockQty: Value(input.stockQty),
            lowStockThreshold: Value(input.lowStockThreshold),
            unit: Value(input.unit),
            notes: Value(input.notes),
            imagePath: Value(input.imagePath),
            updatedAt: Value(now),
            workspaceId: Value(workspaceId),
            hsnCode: Value(input.hsnCode?.trim()),
            gstRate: Value(input.gstRate),
          ),
        );
      }

      // Persist extended fields (is_active, mrp, brand)
      try {
        await _db.customStatement('''
          UPDATE products
          SET is_active = ?, mrp = ?, brand = ?
          WHERE id = ?;
        ''', [
          input.isActive ? 1 : 0,
          input.mrp ?? input.price,
          input.brand,
          prodId,
        ]);
      } catch (_) {}

      return prodId;
    });
  }

  @override
  Future<void> updateCategory(CategoryModel category) {
    return (_db.update(_db.categories)..where((tbl) => tbl.id.equals(category.id))).write(
      CategoriesCompanion(name: Value(category.name.trim())),
    );
  }

  @override
  Future<List<StockMovementView>> getStockMovements({int? productId, int limit = 100, int workspaceId = 1}) async {
    final rows = await _db.customSelect('''
      SELECT sm.id, sm.product_id, p.name as product_name, p.sku as product_sku,
             sm.type, sm.qty_change, sm.reason, sm.unit_cost,
             sm.batch_number, sm.balance_after, sm.created_at
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      WHERE (sm.workspace_id = ? OR sm.workspace_id IS NULL)
      ${productId != null ? 'AND sm.product_id = ?' : ''}
      ORDER BY sm.id DESC
      LIMIT ?;
    ''', variables: [
      Variable.withInt(workspaceId),
      if (productId != null) Variable.withInt(productId),
      Variable.withInt(limit),
    ]).get();

    return rows.map((r) {
      final rawCreatedAt = r.data['created_at'];
      DateTime createdAt;
      if (rawCreatedAt is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt * 1000);
      } else if (rawCreatedAt is String) {
        createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }

      return StockMovementView(
        id: r.data['id'] as int,
        productId: r.data['product_id'] as int,
        productName: r.data['product_name'] as String? ?? 'Product #${r.data['product_id']}',
        productSku: r.data['product_sku'] as String? ?? 'SKU-${r.data['product_id']}',
        type: r.data['type'] as String? ?? 'adjust',
        qtyChange: (r.data['qty_change'] as num?)?.toInt() ?? 0,
        reason: r.data['reason'] as String?,
        batchNumber: r.data['batch_number'] as String?,
        balanceAfter: (r.data['balance_after'] as num?)?.toInt(),
        unitCost: (r.data['unit_cost'] as num?)?.toDouble(),
        createdAt: createdAt,
      );
    }).toList();
  }

  @override
  Future<List<ProductBatchView>> getBatches({int? productId, String? status, int workspaceId = 1}) async {
    final rows = await _db.customSelect('''
      SELECT pb.*, s.name as supplier_name
      FROM product_batches pb
      LEFT JOIN suppliers s ON pb.supplier_id = s.id
      WHERE (pb.workspace_id = ? OR pb.workspace_id IS NULL)
      ${productId != null ? 'AND pb.product_id = ?' : ''}
      ${status != null ? 'AND pb.status = ?' : ''}
      ORDER BY pb.expiry_date ASC, pb.id ASC;
    ''', variables: [
      Variable.withInt(workspaceId),
      if (productId != null) Variable.withInt(productId),
      if (status != null) Variable.withString(status),
    ]).get();

    return rows.map((r) {
      DateTime? parseDate(dynamic val) {
        if (val == null) return null;
        if (val is int) return DateTime.fromMillisecondsSinceEpoch(val * 1000);
        if (val is String) return DateTime.tryParse(val);
        return null;
      }

      return ProductBatchView(
        id: r.data['id'] as int,
        workspaceId: (r.data['workspace_id'] as num?)?.toInt() ?? 1,
        productId: r.data['product_id'] as int,
        batchNumber: r.data['batch_number'] as String,
        mfgDate: parseDate(r.data['mfg_date']),
        expiryDate: parseDate(r.data['expiry_date']),
        costPrice: (r.data['cost_price'] as num?)?.toDouble() ?? 0.0,
        sellingPrice: (r.data['selling_price'] as num?)?.toDouble() ?? 0.0,
        quantity: (r.data['quantity'] as num?)?.toInt() ?? 0,
        initialQuantity: (r.data['initial_quantity'] as num?)?.toInt() ?? 0,
        status: r.data['status'] as String? ?? 'active',
        supplierId: (r.data['supplier_id'] as num?)?.toInt(),
        supplierName: r.data['supplier_name'] as String?,
        notes: r.data['notes'] as String?,
      );
    }).toList();
  }

  @override
  Future<int> addBatch(ProductBatchView batch) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final mfgSec = batch.mfgDate != null ? batch.mfgDate!.millisecondsSinceEpoch ~/ 1000 : null;
    final expSec = batch.expiryDate != null ? batch.expiryDate!.millisecondsSinceEpoch ~/ 1000 : null;

    await _db.customStatement('''
      INSERT INTO product_batches (
        workspace_id, product_id, batch_number, mfg_date, expiry_date,
        cost_price, selling_price, quantity, initial_quantity, status,
        supplier_id, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
      batch.workspaceId,
      batch.productId,
      batch.batchNumber.trim(),
      mfgSec,
      expSec,
      batch.costPrice,
      batch.sellingPrice,
      batch.quantity,
      batch.initialQuantity,
      batch.status,
      batch.supplierId,
      batch.notes,
      nowSeconds,
      nowSeconds,
    ]);

    final lastId = await _db.customSelect('SELECT last_insert_rowid() as id;').getSingle();
    return lastId.data['id'] as int;
  }

  @override
  Future<void> adjustStock({
    required int productId,
    required int newQuantity,
    required String reason,
    int? batchId,
    UserRole? callerRole,
  }) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Adjusting stock requires admin or manager permission');
    }
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingleOrNull();
      if (product == null) throw AppException('Product not found');

      final diff = newQuantity - product.stockQty;
      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

      await _db.customStatement('''
        UPDATE products SET stock_qty = ?, updated_at = ? WHERE id = ?;
      ''', [newQuantity, nowSeconds, productId]);

      await _db.customStatement('''
        INSERT INTO stock_movements (
          product_id, type, qty_change, reason, balance_after, workspace_id, created_at
        ) VALUES (?, 'adjust', ?, ?, ?, ?, ?);
      ''', [productId, diff, reason, newQuantity, product.workspaceId ?? 1, nowSeconds]);

      if (batchId != null) {
        await _db.customStatement('''
          UPDATE product_batches
          SET quantity = quantity + ?, updated_at = ?
          WHERE id = ?;
        ''', [diff, nowSeconds, batchId]);
      }
    });
  }

  @override
  Future<void> writeOffStock({
    required int productId,
    required int quantity,
    required String reason,
    int? batchId,
    UserRole? callerRole,
  }) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Writing off stock requires admin or manager permission');
    }
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingleOrNull();
      if (product == null) throw AppException('Product not found');
      if (product.stockQty < quantity) {
        throw AppException('Cannot write off $quantity units. Available stock is only ${product.stockQty}.');
      }

      final newQty = product.stockQty - quantity;
      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

      await _db.customStatement('''
        UPDATE products SET stock_qty = ?, updated_at = ? WHERE id = ?;
      ''', [newQty, nowSeconds, productId]);

      await _db.customStatement('''
        INSERT INTO stock_movements (
          product_id, type, qty_change, reason, balance_after, workspace_id, created_at
        ) VALUES (?, 'damage', ?, ?, ?, ?, ?);
      ''', [productId, -quantity, reason, newQty, product.workspaceId ?? 1, nowSeconds]);

      if (batchId != null) {
        await _db.customStatement('''
          UPDATE product_batches
          SET quantity = CASE WHEN quantity >= ? THEN quantity - ? ELSE 0 END, updated_at = ?
          WHERE id = ?;
        ''', [quantity, quantity, nowSeconds, batchId]);
      }
    });
  }

  @override
  Future<void> inwardStock({
    required int productId,
    required int quantity,
    required double costPrice,
    String? batchNumber,
    DateTime? expiryDate,
    int? supplierId,
    String? notes,
  }) async {
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingleOrNull();
      if (product == null) throw AppException('Product not found');

      final newQty = product.stockQty + quantity;
      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

      await _db.customStatement('''
        UPDATE products
        SET stock_qty = ?, cost = CASE WHEN ? > 0 THEN ? ELSE cost END, updated_at = ?
        WHERE id = ?;
      ''', [newQty, costPrice, costPrice, nowSeconds, productId]);

      await _db.customStatement('''
        INSERT INTO stock_movements (
          product_id, type, qty_change, reason, balance_after, unit_cost, batch_number, supplier_id, workspace_id, created_at
        ) VALUES (?, 'inward', ?, ?, ?, ?, ?, ?, ?, ?);
      ''', [
        productId,
        quantity,
        notes ?? 'Manual Stock Inward',
        newQty,
        costPrice,
        batchNumber,
        supplierId,
        product.workspaceId ?? 1,
        nowSeconds,
      ]);

      if (batchNumber != null && batchNumber.trim().isNotEmpty) {
        final expSeconds = expiryDate != null ? expiryDate.millisecondsSinceEpoch ~/ 1000 : null;
        await _db.customStatement('''
          INSERT INTO product_batches (
            workspace_id, product_id, batch_number, mfg_date, expiry_date,
            cost_price, selling_price, quantity, initial_quantity, status,
            supplier_id, notes, created_at, updated_at
          ) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?);
        ''', [
          productId,
          batchNumber.trim(),
          nowSeconds,
          expSeconds,
          costPrice,
          product.price,
          quantity,
          quantity,
          supplierId,
          notes,
          nowSeconds,
          nowSeconds,
        ]);
      }
    });
  }

  Future<Map<String, dynamic>> _getProductExtras(int id) async {
    try {
      final rows = await _db.customSelect(
        'SELECT is_active, mrp, brand FROM products WHERE id = ?;',
        variables: [Variable.withInt(id)],
      ).get();
      if (rows.isNotEmpty) {
        final r = rows.first;
        return {
          'is_active': (r.data['is_active'] as num?)?.toInt() == 1,
          'mrp': (r.data['mrp'] as num?)?.toDouble(),
          'brand': r.data['brand'] as String?,
        };
      }
    } catch (_) {}
    return {'is_active': true, 'mrp': null, 'brand': null};
  }

  Future<Map<int, Map<String, dynamic>>> _getAllProductExtras() async {
    final map = <int, Map<String, dynamic>>{};
    try {
      final rows = await _db.customSelect('SELECT id, is_active, mrp, brand FROM products;').get();
      for (final r in rows) {
        final id = r.data['id'] as int;
        map[id] = {
          'is_active': (r.data['is_active'] as num?)?.toInt() == 1,
          'mrp': (r.data['mrp'] as num?)?.toDouble(),
          'brand': r.data['brand'] as String?,
        };
      }
    } catch (_) {}
    return map;
  }

  ProductView _toProductView(
    Product row,
    String? categoryName, {
    bool? isActive,
    double? mrp,
    String? brand,
  }) {
    return ProductView(
      id: row.id,
      name: row.name,
      sku: row.sku,
      barcode: row.barcode,
      categoryId: row.categoryId,
      categoryName: categoryName,
      cost: row.cost,
      price: row.price,
      stockQty: row.stockQty,
      lowStockThreshold: row.lowStockThreshold,
      unit: row.unit,
      notes: row.notes,
      imagePath: row.imagePath,
      hsnCode: row.hsnCode,
      gstRate: row.gstRate,
      isActive: isActive ?? true,
      mrp: mrp ?? row.price,
      brand: brand,
    );
  }
}
