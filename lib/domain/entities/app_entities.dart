import 'package:equatable/equatable.dart';

import '../../core/models/app_models.dart';

class ProductView extends Equatable {
  const ProductView({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.categoryId,
    required this.categoryName,
    required this.cost,
    required this.price,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.unit,
    required this.notes,
    this.imagePath,
    this.hsnCode,
    this.gstRate = 0.0,
    this.isActive = true,
    this.mrp,
    this.brand,
  });

  final int id;
  final String name;
  final String sku;
  final String? barcode;
  final int? categoryId;
  final String? categoryName;
  final double cost;
  final double price;
  final int stockQty;
  final int lowStockThreshold;
  final String unit;
  final String? notes;
  final String? imagePath;
  final String? hsnCode;
  final double gstRate;
  final bool isActive;
  final double? mrp;
  final String? brand;

  bool get isLowStock => stockQty <= lowStockThreshold && stockQty > 0;
  bool get isOutOfStock => stockQty <= 0;
  double get stockValuation => stockQty > 0 ? stockQty * cost : 0.0;

  @override
  List<Object?> get props => [
        id,
        name,
        sku,
        barcode,
        categoryId,
        categoryName,
        cost,
        price,
        stockQty,
        lowStockThreshold,
        unit,
        notes,
        imagePath,
        hsnCode,
        gstRate,
        isActive,
        mrp,
        brand,
      ];
}

class ProductBatchView extends Equatable {
  const ProductBatchView({
    required this.id,
    required this.workspaceId,
    required this.productId,
    required this.batchNumber,
    this.mfgDate,
    this.expiryDate,
    required this.costPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.initialQuantity,
    required this.status,
    this.supplierId,
    this.supplierName,
    this.notes,
  });

  final int id;
  final int workspaceId;
  final int productId;
  final String batchNumber;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final double costPrice;
  final double sellingPrice;
  final int quantity;
  final int initialQuantity;
  final String status;
  final int? supplierId;
  final String? supplierName;
  final String? notes;

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 60)));

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        productId,
        batchNumber,
        mfgDate,
        expiryDate,
        costPrice,
        sellingPrice,
        quantity,
        initialQuantity,
        status,
        supplierId,
        supplierName,
        notes,
      ];
}

class StockMovementView extends Equatable {
  const StockMovementView({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.type,
    required this.qtyChange,
    this.reason,
    this.batchNumber,
    this.balanceAfter,
    this.unitCost,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final String productName;
  final String productSku;
  final String type;
  final int qtyChange;
  final String? reason;
  final String? batchNumber;
  final int? balanceAfter;
  final double? unitCost;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        productSku,
        type,
        qtyChange,
        reason,
        batchNumber,
        balanceAfter,
        unitCost,
        createdAt,
      ];
}

class SaleItemView extends Equatable {
  const SaleItemView({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.nameSnapshot,
    required this.costSnapshot,
    required this.priceSnapshot,
    required this.qty,
    required this.discount,
    required this.lineTotal,
    this.batchNumber,
    this.unit = 'Unit',
  });

  final int id;
  final int saleId;
  final int productId;
  final String nameSnapshot;
  final double costSnapshot;
  final double priceSnapshot;
  final int qty;
  final double discount;
  final double lineTotal;
  final String? batchNumber;
  final String unit;

  String get name => nameSnapshot;
  double get price => priceSnapshot;
  double get cost => costSnapshot;

  @override
  List<Object?> get props => [
        id,
        saleId,
        productId,
        nameSnapshot,
        costSnapshot,
        priceSnapshot,
        qty,
        discount,
        lineTotal,
        batchNumber,
        unit,
      ];
}

class SaleView extends Equatable {
  const SaleView({
    required this.id,
    required this.invoiceNo,
    required this.createdAt,
    required this.customerId,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.total,
    required this.paid,
    required this.changeAmount,
    required this.paymentMethod,
    required this.status,
    this.cgstTotal = 0.0,
    this.sgstTotal = 0.0,
    this.igstTotal = 0.0,
    this.roundOff = 0.0,
  });

  final int id;
  final String invoiceNo;
  final DateTime createdAt;
  final int? customerId;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double total;
  final double paid;
  final double changeAmount;
  final PaymentMethod paymentMethod;
  final SaleStatus status;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;
  final double roundOff;

  @override
  List<Object?> get props => [
        id,
        invoiceNo,
        createdAt,
        customerId,
        subtotal,
        discountTotal,
        taxTotal,
        total,
        paid,
        changeAmount,
        paymentMethod,
        status,
        cgstTotal,
        sgstTotal,
        igstTotal,
        roundOff,
      ];
}

class SaleDetailView extends Equatable {
  const SaleDetailView({required this.sale, required this.items});

  final SaleView sale;
  final List<SaleItemView> items;

  @override
  List<Object?> get props => [sale, items];
}

class AuthSession extends Equatable {
  const AuthSession({
    required this.role,
    required this.loginTime,
    this.userId,
    this.username,
    this.displayName,
  });

  final UserRole role;
  final DateTime loginTime;
  final int? userId;
  final String? username;
  final String? displayName;

  @override
  List<Object?> get props => [role, loginTime, userId, username, displayName];
}
