import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

enum UserRole { admin, manager, cashier, fieldOfficer, agronomist }

enum StockMovementType { add, remove, adjust, purchase, sale, returnSale }

enum PaymentMethod { cash, card, split, upi, bankTransfer, credit }

enum SaleStatus { completed, returned, partiallyReturned }

extension PaymentMethodX on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.split:
        return 'split';
      case PaymentMethod.upi:
        return 'upi';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.credit:
        return 'credit';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.split:
        return 'Split';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.credit:
        return 'Credit (Pay Later)';
    }
  }

  static PaymentMethod fromValue(String value) {
    if (value == 'bank_transfer' || value == 'bankTransfer') return PaymentMethod.bankTransfer;
    return PaymentMethod.values.firstWhere(
      (method) => method.value == value || method.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

extension SaleStatusX on SaleStatus {
  String get value {
    switch (this) {
      case SaleStatus.completed:
        return 'completed';
      case SaleStatus.returned:
        return 'returned';
      case SaleStatus.partiallyReturned:
        return 'partially_returned';
    }
  }

  static SaleStatus fromValue(String value) {
    if (value == 'partially_returned' || value == 'partiallyReturned') {
      return SaleStatus.partiallyReturned;
    }
    return SaleStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SaleStatus.completed,
    );
  }
}

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.manager:
        return 'manager';
      case UserRole.cashier:
        return 'cashier';
      case UserRole.fieldOfficer:
        return 'field_officer';
      case UserRole.agronomist:
        return 'agronomist';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.fieldOfficer:
        return 'Field Officer';
      case UserRole.agronomist:
        return 'Agronomist';
    }
  }

  static UserRole fromValue(String value) {
    if (value == 'field_officer' || value == 'fieldOfficer') return UserRole.fieldOfficer;
    return UserRole.values.firstWhere(
      (role) => role.value == value || role.name == value,
      orElse: () => UserRole.cashier,
    );
  }
}

extension StockMovementTypeX on StockMovementType {
  String get value {
    switch (this) {
      case StockMovementType.add:
        return 'add';
      case StockMovementType.remove:
        return 'remove';
      case StockMovementType.adjust:
        return 'adjust';
      case StockMovementType.purchase:
        return 'purchase';
      case StockMovementType.sale:
        return 'sale';
      case StockMovementType.returnSale:
        return 'return';
    }
  }

  static StockMovementType fromValue(String value) {
    return StockMovementType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => StockMovementType.adjust,
    );
  }
}

class AppSettingsModel extends Equatable {
  const AppSettingsModel({
    required this.storeName,
    required this.currency,
    required this.taxEnabled,
    required this.taxRate,
    required this.receiptHeader,
    required this.receiptFooter,
    required this.language,
    required this.allowNegativeStock,
    required this.cashierPin,
    required this.adminPassword,
  });

  final String storeName;
  final String currency;
  final bool taxEnabled;
  final double taxRate;
  final String receiptHeader;
  final String receiptFooter;
  final String language;
  final bool allowNegativeStock;
  final String cashierPin;
  final String adminPassword;

  AppSettingsModel copyWith({
    String? storeName,
    String? currency,
    bool? taxEnabled,
    double? taxRate,
    String? receiptHeader,
    String? receiptFooter,
    String? language,
    bool? allowNegativeStock,
    String? cashierPin,
    String? adminPassword,
  }) {
    return AppSettingsModel(
      storeName: storeName ?? this.storeName,
      currency: currency ?? this.currency,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      language: language ?? this.language,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      cashierPin: cashierPin ?? this.cashierPin,
      adminPassword: adminPassword ?? this.adminPassword,
    );
  }

  static const fallback = AppSettingsModel(
    storeName: 'Darvi Group Agri Tech',
    currency: 'INR',
    taxEnabled: true,
    taxRate: 0.18,
    receiptHeader: 'Darvi Group Agri Tech\n#2 Totad Building, Arjun Vihar, Gokul Road, Hubli - 580030\nGSTIN: 29BKZPA0053M1ZQ | Ph: 9986890777',
    receiptFooter: 'Improving Agriculture, Improving lives.\nGoods once sold will not be taken back or exchanged.\nNo cash payments accepted.',
    language: 'en',
    allowNegativeStock: false,
    cashierPin: '1234',
    adminPassword: 'admin123',
  );

  @override
  List<Object?> get props => [
        storeName,
        currency,
        taxEnabled,
        taxRate,
        receiptHeader,
        receiptFooter,
        language,
        allowNegativeStock,
        cashierPin,
        adminPassword,
      ];
}

class ProductUpsertInput extends Equatable {
  const ProductUpsertInput({
    this.id,
    required this.name,
    required this.sku,
    this.barcode,
    this.categoryId,
    required this.cost,
    required this.price,
    required this.stockQty,
    this.lowStockThreshold = 5,
    this.unit = 'piece',
    this.notes,
    this.imagePath,
    this.hsnCode,
    this.gstRate = 0.0,
    this.isActive = true,
    this.mrp,
    this.brand,
  });

  final int? id;
  final String name;
  final String sku;
  final String? barcode;
  final int? categoryId;
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

  @override
  List<Object?> get props => [
        id,
        name,
        sku,
        barcode,
        categoryId,
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

class StockMovementInput extends Equatable {
  const StockMovementInput({
    required this.productId,
    required this.type,
    required this.qtyChange,
    this.reason,
    this.supplierId,
    this.unitCost,
  });

  final int productId;
  final StockMovementType type;
  final int qtyChange;
  final String? reason;
  final int? supplierId;
  final double? unitCost;

  @override
  List<Object?> get props => [
        productId,
        type,
        qtyChange,
        reason,
        supplierId,
        unitCost,
      ];
}

class ProductFilter extends Equatable {
  const ProductFilter({
    this.search = '',
    this.categoryId,
    this.lowStockOnly = false,
  });

  final String search;
  final int? categoryId;
  final bool lowStockOnly;

  ProductFilter copyWith({
    String? search,
    int? categoryId,
    bool? lowStockOnly,
    bool clearCategory = false,
  }) {
    return ProductFilter(
      search: search ?? this.search,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }

  @override
  List<Object?> get props => [search, categoryId, lowStockOnly];
}

class CategoryModel extends Equatable {
  const CategoryModel({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

class CustomerModel extends Equatable {
  const CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.balance,
    this.gstin,
    this.address,
    this.creditLimit = 10000.0,
    this.workspaceId = 1,
    this.code,
    this.alternatePhone,
    this.email,
    this.state = 'Karnataka',
    this.customerType = 'individual',
    this.creditPeriodDays = 30,
    this.isActive = true,
    this.openingBalance = 0.0,
  });

  final int id;
  final String name;
  final String? phone;
  final String? notes;
  final double balance;
  final String? gstin;
  final String? address;
  final double creditLimit;
  final int workspaceId;
  final String? code;
  final String? alternatePhone;
  final String? email;
  final String state;
  final String customerType;
  final int creditPeriodDays;
  final bool isActive;
  final double openingBalance;

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        notes,
        balance,
        gstin,
        address,
        creditLimit,
        workspaceId,
        code,
        alternatePhone,
        email,
        state,
        customerType,
        creditPeriodDays,
        isActive,
        openingBalance,
      ];
}

class SupplierModel extends Equatable {
  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.gstin,
    this.address,
    this.balance = 0.0,
    this.workspaceId = 1,
    this.code,
    this.contactPerson,
    this.email,
    this.state = 'Karnataka',
    this.paymentTerms = '30 Days',
    this.isActive = true,
    this.openingBalance = 0.0,
    this.notes,
  });

  final int id;
  final String name;
  final String? phone;
  final String? gstin;
  final String? address;
  final double balance;
  final int workspaceId;
  final String? code;
  final String? contactPerson;
  final String? email;
  final String state;
  final String paymentTerms;
  final bool isActive;
  final double openingBalance;
  final String? notes;

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        gstin,
        address,
        balance,
        workspaceId,
        code,
        contactPerson,
        email,
        state,
        paymentTerms,
        isActive,
        openingBalance,
        notes,
      ];
}

class InvoiceFilter extends Equatable {
  const InvoiceFilter({
    this.from,
    this.to,
    this.paymentMethod,
  });

  final DateTime? from;
  final DateTime? to;
  final PaymentMethod? paymentMethod;

  @override
  List<Object?> get props => [from, to, paymentMethod];
}

class SaleSummary extends Equatable {
  const SaleSummary({
    required this.id,
    required this.invoiceNo,
    required this.createdAt,
    required this.total,
    required this.paymentMethod,
    required this.status,
  });

  final int id;
  final String invoiceNo;
  final DateTime createdAt;
  final double total;
  final PaymentMethod paymentMethod;
  final SaleStatus status;

  @override
  List<Object?> get props => [id, invoiceNo, createdAt, total, paymentMethod, status];
}

class ReturnItemInput extends Equatable {
  const ReturnItemInput({required this.saleItemId, required this.qty});

  final int saleItemId;
  final int qty;

  @override
  List<Object?> get props => [saleItemId, qty];
}

class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.name,
    required this.sku,
    this.barcode,
    required this.cost,
    required this.price,
    required this.qty,
    this.discount = 0,
    this.batchId,
    this.batchNumber,
    this.unit = 'Unit',
    this.gstRate = 0.0,
    this.hsnCode,
    this.lineNote,
  });

  final int productId;
  final String name;
  final String sku;
  final String? barcode;
  final double cost;
  final double price;
  final int qty;
  final double discount;
  final int? batchId;
  final String? batchNumber;
  final String unit;
  final double gstRate;
  final String? hsnCode;
  final String? lineNote;

  double get lineTotal => (price * qty) - discount;

  CartItem copyWith({
    int? qty,
    double? discount,
    double? price,
    int? batchId,
    String? batchNumber,
    String? unit,
    double? gstRate,
    String? hsnCode,
    String? lineNote,
  }) {
    return CartItem(
      productId: productId,
      name: name,
      sku: sku,
      barcode: barcode,
      cost: cost,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      discount: discount ?? this.discount,
      batchId: batchId ?? this.batchId,
      batchNumber: batchNumber ?? this.batchNumber,
      unit: unit ?? this.unit,
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode ?? this.hsnCode,
      lineNote: lineNote ?? this.lineNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'cost': cost,
        'price': price,
        'qty': qty,
        'discount': discount,
        'batchId': batchId,
        'batchNumber': batchNumber,
        'unit': unit,
        'gstRate': gstRate,
        'hsnCode': hsnCode,
        'lineNote': lineNote,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId'] as int,
        name: json['name'] as String,
        sku: json['sku'] as String,
        barcode: json['barcode'] as String?,
        cost: (json['cost'] as num).toDouble(),
        price: (json['price'] as num).toDouble(),
        qty: json['qty'] as int,
        discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
        batchId: json['batchId'] as int?,
        batchNumber: json['batchNumber'] as String?,
        unit: json['unit'] as String? ?? 'Unit',
        gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0.0,
        hsnCode: json['hsnCode'] as String?,
        lineNote: json['lineNote'] as String?,
      );

  @override
  List<Object?> get props => [
        productId,
        name,
        sku,
        barcode,
        cost,
        price,
        qty,
        discount,
        batchId,
        batchNumber,
        unit,
        gstRate,
        hsnCode,
        lineNote,
      ];
}

class DashboardMetrics extends Equatable {
  const DashboardMetrics({
    required this.todaySales,
    required this.todayInvoices,
    required this.monthSales,
    required this.monthInvoices,
    required this.todayProfit,
    required this.monthProfit,
    required this.bestSellers,
  });

  final double todaySales;
  final int todayInvoices;
  final double monthSales;
  final int monthInvoices;
  final double todayProfit;
  final double monthProfit;
  final List<BestSellerMetric> bestSellers;

  static const empty = DashboardMetrics(
    todaySales: 0,
    todayInvoices: 0,
    monthSales: 0,
    monthInvoices: 0,
    todayProfit: 0,
    monthProfit: 0,
    bestSellers: [],
  );

  @override
  List<Object?> get props => [
        todaySales,
        todayInvoices,
        monthSales,
        monthInvoices,
        todayProfit,
        monthProfit,
        bestSellers,
      ];
}

class BestSellerMetric extends Equatable {
  const BestSellerMetric({required this.productName, required this.qty});

  final String productName;
  final int qty;

  @override
  List<Object?> get props => [productName, qty];
}

class SalesByProductMetric extends Equatable {
  const SalesByProductMetric({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.total,
  });

  final int productId;
  final String productName;
  final int qty;
  final double total;

  @override
  List<Object?> get props => [productId, productName, qty, total];
}

class SplitPaymentItem extends Equatable {
  const SplitPaymentItem({
    required this.method,
    required this.amount,
    this.accountId,
    this.accountName,
    this.referenceNo,
  });

  final PaymentMethod method;
  final double amount;
  final int? accountId;
  final String? accountName;
  final String? referenceNo;

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'amount': amount,
        'accountId': accountId,
        'accountName': accountName,
        'referenceNo': referenceNo,
      };

  factory SplitPaymentItem.fromJson(Map<String, dynamic> json) => SplitPaymentItem(
        method: PaymentMethod.values.firstWhere(
          (m) => m.name == json['method'],
          orElse: () => PaymentMethod.cash,
        ),
        amount: (json['amount'] as num).toDouble(),
        accountId: json['accountId'] as int?,
        accountName: json['accountName'] as String?,
        referenceNo: json['referenceNo'] as String?,
      );

  @override
  List<Object?> get props => [method, amount, accountId, accountName, referenceNo];
}

class HeldBillModel extends Equatable {
  const HeldBillModel({
    this.id,
    this.workspaceId = 1,
    this.referenceNote,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    this.orderDiscount = 0.0,
    this.taxEnabled = false,
    this.taxRate = 0.18,
    required this.subtotal,
    required this.totalAmount,
    required this.itemCount,
    required this.createdAt,
  });

  final int? id;
  final int workspaceId;
  final String? referenceNote;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final List<CartItem> items;
  final double orderDiscount;
  final bool taxEnabled;
  final double taxRate;
  final double subtotal;
  final double totalAmount;
  final int itemCount;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspaceId': workspaceId,
        'referenceNote': referenceNote,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items.map((i) => i.toJson()).toList(),
        'orderDiscount': orderDiscount,
        'taxEnabled': taxEnabled,
        'taxRate': taxRate,
        'subtotal': subtotal,
        'totalAmount': totalAmount,
        'itemCount': itemCount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HeldBillModel.fromJson(Map<String, dynamic> json) => HeldBillModel(
        id: json['id'] as int?,
        workspaceId: json['workspaceId'] as int? ?? 1,
        referenceNote: json['referenceNote'] as String?,
        customerId: json['customerId'] as int?,
        customerName: json['customerName'] as String?,
        customerPhone: json['customerPhone'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => CartItem.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        orderDiscount: (json['orderDiscount'] as num?)?.toDouble() ?? 0.0,
        taxEnabled: json['taxEnabled'] == true || json['taxEnabled'] == 1,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.18,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        itemCount: json['itemCount'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        referenceNote,
        customerId,
        customerName,
        customerPhone,
        items,
        orderDiscount,
        taxEnabled,
        taxRate,
        subtotal,
        totalAmount,
        itemCount,
        createdAt,
      ];
}

class SaleCheckoutInput extends Equatable {
  const SaleCheckoutInput({
    required this.items,
    this.orderDiscount = 0.0,
    this.taxEnabled = false,
    this.taxRate = 0.18,
    required this.paid,
    required this.paymentMethod,
    this.customerId,
    this.cashierName,
    this.employeeId,
    this.notes,
    this.splitPayments,
    this.paymentAccountId,
    this.paymentReference,
    this.isInterState = false,
    this.workspaceId,
  });

  final List<CartItem> items;
  final double orderDiscount;
  final bool taxEnabled;
  final double taxRate;
  final double paid;
  final PaymentMethod paymentMethod;
  final int? customerId;
  final String? cashierName;
  final int? employeeId;
  final String? notes;
  final List<SplitPaymentItem>? splitPayments;
  final int? paymentAccountId;
  final String? paymentReference;
  final bool isInterState;
  final int? workspaceId;

  @override
  List<Object?> get props => [
        items,
        orderDiscount,
        taxEnabled,
        taxRate,
        paid,
        paymentMethod,
        customerId,
        cashierName,
        employeeId,
        notes,
        splitPayments,
        paymentAccountId,
        paymentReference,
        isInterState,
        workspaceId,
      ];
}

class WorkspaceModel extends Equatable {
  const WorkspaceModel({
    required this.id,
    required this.name,
    this.businessType = 'retail',
    this.gstin,
    this.phone,
    this.address,
    this.stateCode = '29',
    this.isPrimary = false,
  });

  final int id;
  final String name;
  final String businessType;
  final String? gstin;
  final String? phone;
  final String? address;
  final String stateCode;
  final bool isPrimary;

  @override
  List<Object?> get props => [id, name, businessType, gstin, phone, address, stateCode, isPrimary];
}

class AccountModel extends Equatable {
  const AccountModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.type,
    this.accountNumber,
    this.balance = 0.0,
    this.isDefault = false,
    this.bankName,
    this.ifsc,
    this.upiId,
    this.isActive = true,
  });

  final int id;
  final int workspaceId;
  final String name;
  final String type;
  final String? accountNumber;
  final double balance;
  final bool isDefault;
  final String? bankName;
  final String? ifsc;
  final String? upiId;
  final bool isActive;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        type,
        accountNumber,
        balance,
        isDefault,
        bankName,
        ifsc,
        upiId,
        isActive,
      ];
}

class LedgerEntryModel extends Equatable {
  const LedgerEntryModel({
    required this.id,
    required this.workspaceId,
    required this.transactionType,
    required this.referenceType,
    this.referenceId,
    this.partyType,
    this.partyId,
    this.accountId,
    this.debit = 0.0,
    this.credit = 0.0,
    this.narration,
    required this.createdAt,
  });

  final int id;
  final int workspaceId;
  final String transactionType;
  final String referenceType;
  final int? referenceId;
  final String? partyType;
  final int? partyId;
  final int? accountId;
  final double debit;
  final double credit;
  final String? narration;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        transactionType,
        referenceType,
        referenceId,
        partyType,
        partyId,
        accountId,
        debit,
        credit,
        narration,
        createdAt,
      ];
}

class LedgerPostingItem {
  const LedgerPostingItem({
    required this.transactionType,
    required this.referenceType,
    this.referenceId,
    this.partyType,
    this.partyId,
    this.accountId,
    this.debit = 0.0,
    this.credit = 0.0,
    this.narration,
    this.createdAt,
  });

  final String transactionType;
  final String referenceType;
  final int? referenceId;
  final String? partyType;
  final int? partyId;
  final int? accountId;
  final double debit;
  final double credit;
  final String? narration;
  final DateTime? createdAt;
}

class PurchaseInvoiceItemInput extends Equatable {
  const PurchaseInvoiceItemInput({
    required this.productId,
    required this.qty,
    required this.unitCost,
    this.gstRate = 0.0,
    this.discount = 0.0,
    required this.lineTotal,
    this.nameSnapshot,
    this.batchNumber,
    this.mfgDate,
    this.expiryDate,
    this.hsnCode,
    this.purchaseUnit = 'Unit',
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
  });

  final int productId;
  final int qty;
  final double unitCost;
  final double gstRate;
  final double discount;
  final double lineTotal;
  final String? nameSnapshot;
  final String? batchNumber;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final String? hsnCode;
  final String purchaseUnit;
  final double cgst;
  final double sgst;
  final double igst;

  @override
  List<Object?> get props => [
        productId,
        qty,
        unitCost,
        gstRate,
        discount,
        lineTotal,
        nameSnapshot,
        batchNumber,
        mfgDate,
        expiryDate,
        hsnCode,
        purchaseUnit,
        cgst,
        sgst,
        igst,
      ];
}

class PurchaseInvoiceInput extends Equatable {
  const PurchaseInvoiceInput({
    this.workspaceId = 1,
    required this.supplierId,
    required this.supplierInvoiceNo,
    required this.items,
    required this.subtotal,
    this.taxTotal = 0.0,
    required this.total,
    this.paid = 0.0,
    this.accountId,
    this.notes,
    this.internalReference,
    this.supplierInvoiceDate,
    this.grossSubtotal = 0.0,
    this.itemDiscountTotal = 0.0,
    this.invoiceDiscount = 0.0,
    this.taxableValue = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.roundOff = 0.0,
    this.isGstInclusive = false,
    this.paymentMode = 'standard',
    this.paymentReference,
  });

  final int workspaceId;
  final int supplierId;
  final String supplierInvoiceNo;
  final List<PurchaseInvoiceItemInput> items;
  final double subtotal;
  final double taxTotal;
  final double total;
  final double paid;
  final int? accountId;
  final String? notes;
  final String? internalReference;
  final DateTime? supplierInvoiceDate;
  final double grossSubtotal;
  final double itemDiscountTotal;
  final double invoiceDiscount;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double roundOff;
  final bool isGstInclusive;
  final String paymentMode;
  final String? paymentReference;

  @override
  List<Object?> get props => [
        workspaceId,
        supplierId,
        supplierInvoiceNo,
        items,
        subtotal,
        taxTotal,
        total,
        paid,
        accountId,
        notes,
        internalReference,
        supplierInvoiceDate,
        grossSubtotal,
        itemDiscountTotal,
        invoiceDiscount,
        taxableValue,
        cgst,
        sgst,
        igst,
        roundOff,
        isGstInclusive,
        paymentMode,
        paymentReference,
      ];
}

class PurchaseReturnItemInput extends Equatable {
  const PurchaseReturnItemInput({
    required this.productId,
    this.batchNumber,
    required this.quantity,
    required this.unitCost,
    this.gstRate = 0.0,
    this.taxAmount = 0.0,
    required this.total,
  });

  final int productId;
  final String? batchNumber;
  final int quantity;
  final double unitCost;
  final double gstRate;
  final double taxAmount;
  final double total;

  @override
  List<Object?> get props => [
        productId,
        batchNumber,
        quantity,
        unitCost,
        gstRate,
        taxAmount,
        total,
      ];
}

class PurchaseReturnInput extends Equatable {
  const PurchaseReturnInput({
    this.workspaceId = 1,
    required this.purchaseInvoiceId,
    required this.supplierId,
    required this.debitNoteNumber,
    required this.items,
    required this.subtotal,
    this.taxTotal = 0.0,
    required this.totalAmount,
    this.reason,
    this.refundAccountId,
    this.returnDate,
  });

  final int workspaceId;
  final int purchaseInvoiceId;
  final int supplierId;
  final String debitNoteNumber;
  final List<PurchaseReturnItemInput> items;
  final double subtotal;
  final double taxTotal;
  final double totalAmount;
  final String? reason;
  final int? refundAccountId;
  final DateTime? returnDate;

  @override
  List<Object?> get props => [
        workspaceId,
        purchaseInvoiceId,
        supplierId,
        debitNoteNumber,
        items,
        subtotal,
        taxTotal,
        totalAmount,
        reason,
        refundAccountId,
        returnDate,
      ];
}

class PurchaseReturnModel extends Equatable {
  const PurchaseReturnModel({
    required this.id,
    required this.workspaceId,
    required this.purchaseInvoiceId,
    required this.supplierId,
    required this.debitNoteNumber,
    required this.returnDate,
    required this.subtotal,
    required this.taxTotal,
    required this.totalAmount,
    this.reason,
    this.status = 'completed',
    required this.createdAt,
    this.supplierName,
    this.invoiceNumber,
  });

  final int id;
  final int workspaceId;
  final int purchaseInvoiceId;
  final int supplierId;
  final String debitNoteNumber;
  final DateTime returnDate;
  final double subtotal;
  final double taxTotal;
  final double totalAmount;
  final String? reason;
  final String status;
  final DateTime createdAt;
  final String? supplierName;
  final String? invoiceNumber;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        purchaseInvoiceId,
        supplierId,
        debitNoteNumber,
        returnDate,
        subtotal,
        taxTotal,
        totalAmount,
        reason,
        status,
        createdAt,
        supplierName,
        invoiceNumber,
      ];
}

class PaymentAllocationModel extends Equatable {
  const PaymentAllocationModel({
    required this.id,
    required this.workspaceId,
    required this.paymentId,
    required this.partyType,
    required this.partyId,
    required this.invoiceType,
    required this.invoiceId,
    required this.allocatedAmount,
    required this.createdAt,
  });

  final int id;
  final int workspaceId;
  final int paymentId;
  final String partyType;
  final int partyId;
  final String invoiceType;
  final int invoiceId;
  final double allocatedAmount;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        paymentId,
        partyType,
        partyId,
        invoiceType,
        invoiceId,
        allocatedAmount,
        createdAt,
      ];
}

class PurchaseDashboardMetrics extends Equatable {
  const PurchaseDashboardMetrics({
    required this.totalPurchases,
    required this.todayPurchases,
    required this.monthlyPurchases,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.pendingSupplierPayments,
    required this.invoicesCount,
    required this.returnsTotal,
    required this.recentReceivedStock,
  });

  final double totalPurchases;
  final double todayPurchases;
  final double monthlyPurchases;
  final double totalPaid;
  final double totalOutstanding;
  final int pendingSupplierPayments;
  final int invoicesCount;
  final double returnsTotal;
  final List<Map<String, dynamic>> recentReceivedStock;

  @override
  List<Object?> get props => [
        totalPurchases,
        todayPurchases,
        monthlyPurchases,
        totalPaid,
        totalOutstanding,
        pendingSupplierPayments,
        invoicesCount,
        returnsTotal,
        recentReceivedStock,
      ];
}

class FinancialDashboardMetrics extends Equatable {
  const FinancialDashboardMetrics({
    required this.totalCash,
    required this.totalBank,
    required this.totalUpi,
    required this.totalLiquidBalance,
    required this.todayCollections,
    required this.todayPayments,
    required this.monthlyExpenses,
    required this.customerReceivables,
    required this.supplierPayables,
    required this.payrollPaid,
    required this.incentivesPaid,
  });

  final double totalCash;
  final double totalBank;
  final double totalUpi;
  final double totalLiquidBalance;
  final double todayCollections;
  final double todayPayments;
  final double monthlyExpenses;
  final double customerReceivables;
  final double supplierPayables;
  final double payrollPaid;
  final double incentivesPaid;

  @override
  List<Object?> get props => [
        totalCash,
        totalBank,
        totalUpi,
        totalLiquidBalance,
        todayCollections,
        todayPayments,
        monthlyExpenses,
        customerReceivables,
        supplierPayables,
        payrollPaid,
        incentivesPaid,
      ];
}

class CashbookEntry extends Equatable {
  const CashbookEntry({
    required this.date,
    required this.description,
    this.referenceNo,
    required this.accountName,
    required this.type,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  final DateTime date;
  final String description;
  final String? referenceNo;
  final String accountName;
  final String type; // 'receipt', 'payment', 'transfer'
  final double debit;
  final double credit;
  final double runningBalance;

  @override
  List<Object?> get props => [
        date,
        description,
        referenceNo,
        accountName,
        type,
        debit,
        credit,
        runningBalance,
      ];
}

class ExpenseModel extends Equatable {
  const ExpenseModel({
    required this.id,
    required this.workspaceId,
    required this.accountId,
    required this.category,
    required this.amount,
    required this.expenseDate,
    this.referenceNo,
    this.notes,
    this.vendorPayee,
    this.taxAmount = 0.0,
    this.isCancelled = false,
    this.attachmentUrl,
  });

  final int id;
  final int workspaceId;
  final int accountId;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String? referenceNo;
  final String? notes;
  final String? vendorPayee;
  final double taxAmount;
  final bool isCancelled;
  final String? attachmentUrl;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        accountId,
        category,
        amount,
        expenseDate,
        referenceNo,
        notes,
        vendorPayee,
        taxAmount,
        isCancelled,
        attachmentUrl,
      ];
}

class EmployeeModel extends Equatable {
  const EmployeeModel({
    required this.id,
    required this.workspaceId,
    required this.employeeCode,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.designation,
    this.department = 'Sales',
    required this.loginPin,
    this.baseSalary = 0.0,
    required this.joiningDate,
    this.isActive = true,
    this.dateOfBirth,
    this.gender = 'male',
    this.address,
    this.emergencyContact,
    this.employmentType = 'full_time',
    this.workLocation = 'Hubli Store',
    this.salaryType = 'monthly',
    this.allowances = 0.0,
    this.fixedDeductions = 0.0,
    this.bankAccountName,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.shiftId,
  });

  final int id;
  final int workspaceId;
  final String employeeCode;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String designation;
  final String department;
  final String loginPin;
  final double baseSalary;
  final DateTime joiningDate;
  final bool isActive;
  final String? dateOfBirth;
  final String gender;
  final String? address;
  final String? emergencyContact;
  final String employmentType;
  final String workLocation;
  final String salaryType;
  final double allowances;
  final double fixedDeductions;
  final String? bankAccountName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final int? shiftId;

  EmployeeModel redacted() {
    final maskedAccount = bankAccountNumber != null && bankAccountNumber!.length >= 4
        ? '****${bankAccountNumber!.substring(bankAccountNumber!.length - 4)}'
        : (bankAccountNumber != null ? '****' : null);
    return copyWith(
      loginPin: '****',
      baseSalary: 0.0,
      allowances: 0.0,
      fixedDeductions: 0.0,
      bankAccountNumber: maskedAccount,
      bankIfsc: bankIfsc != null ? '****' : null,
    );
  }

  EmployeeModel copyWith({
    int? id,
    int? workspaceId,
    String? employeeCode,
    String? name,
    String? phone,
    String? email,
    String? role,
    String? designation,
    String? department,
    String? loginPin,
    double? baseSalary,
    DateTime? joiningDate,
    bool? isActive,
    String? dateOfBirth,
    String? gender,
    String? address,
    String? emergencyContact,
    String? employmentType,
    String? workLocation,
    String? salaryType,
    double? allowances,
    double? fixedDeductions,
    String? bankAccountName,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    int? shiftId,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      loginPin: loginPin ?? this.loginPin,
      baseSalary: baseSalary ?? this.baseSalary,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      employmentType: employmentType ?? this.employmentType,
      workLocation: workLocation ?? this.workLocation,
      salaryType: salaryType ?? this.salaryType,
      allowances: allowances ?? this.allowances,
      fixedDeductions: fixedDeductions ?? this.fixedDeductions,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      shiftId: shiftId ?? this.shiftId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        employeeCode,
        name,
        phone,
        email,
        role,
        designation,
        department,
        loginPin,
        baseSalary,
        joiningDate,
        isActive,
        dateOfBirth,
        gender,
        address,
        emergencyContact,
        employmentType,
        workLocation,
        salaryType,
        allowances,
        fixedDeductions,
        bankAccountName,
        bankName,
        bankAccountNumber,
        bankIfsc,
        shiftId,
      ];
}

class ShiftModel extends Equatable {
  const ShiftModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 30,
    this.graceMinutes = 15,
    this.isOvernight = false,
    this.isActive = true,
  });

  final int id;
  final int workspaceId;
  final String name;
  final String startTime;
  final String endTime;
  final int breakMinutes;
  final int graceMinutes;
  final bool isOvernight;
  final bool isActive;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        startTime,
        endTime,
        breakMinutes,
        graceMinutes,
        isOvernight,
        isActive,
      ];
}

class LeaveRequestModel extends Equatable {
  const LeaveRequestModel({
    required this.id,
    required this.workspaceId,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    this.totalDays = 1.0,
    required this.leaveType,
    this.reason,
    this.status = 'pending',
    this.approvedBy,
    this.approverRemarks,
    required this.createdAt,
  });

  final int id;
  final int workspaceId;
  final int employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final String leaveType; // 'casual', 'sick', 'earned', 'unpaid'
  final String? reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String? approvedBy;
  final String? approverRemarks;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        employeeId,
        startDate,
        endDate,
        totalDays,
        leaveType,
        reason,
        status,
        approvedBy,
        approverRemarks,
        createdAt,
      ];
}

class HolidayModel extends Equatable {
  const HolidayModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.date,
    this.description,
    this.isOptional = false,
  });

  final int id;
  final int workspaceId;
  final String name;
  final String date; // YYYY-MM-DD
  final String? description;
  final bool isOptional;

  @override
  List<Object?> get props => [id, workspaceId, name, date, description, isOptional];
}

class SalesTargetModel extends Equatable {
  const SalesTargetModel({
    required this.id,
    required this.workspaceId,
    required this.employeeId,
    required this.targetType,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.startDate,
    required this.endDate,
    this.status = 'in_progress',
  });

  final int id;
  final int workspaceId;
  final int employeeId;
  final String targetType; // 'revenue', 'volume', 'leads'
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'in_progress', 'achieved', 'expired'

  double get progressRatio => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get progressPercent => (progressRatio * 100).clamp(0.0, 100.0);

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        employeeId,
        targetType,
        targetAmount,
        currentAmount,
        startDate,
        endDate,
        status,
      ];
}

class AttendanceSummaryModel extends Equatable {
  const AttendanceSummaryModel({
    required this.employeeId,
    required this.employeeName,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.leaveDays,
    required this.overtimeHours,
    required this.lateDays,
  });

  final int employeeId;
  final String employeeName;
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int leaveDays;
  final double overtimeHours;
  final int lateDays;

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        totalDays,
        presentDays,
        absentDays,
        halfDays,
        leaveDays,
        overtimeHours,
        lateDays,
      ];
}

class AttendanceModel extends Equatable {
  const AttendanceModel({
    required this.id,
    required this.workspaceId,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.status = 'present',
    this.workingHours = 8.0,
    this.notes,
    this.shiftId,
    this.breakMinutes = 0,
    this.isLate = false,
    this.overtimeHours = 0.0,
    this.correctedBy,
    this.correctionReason,
  });

  final int id;
  final int workspaceId;
  final int employeeId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status;
  final double workingHours;
  final String? notes;
  final int? shiftId;
  final int breakMinutes;
  final bool isLate;
  final double overtimeHours;
  final String? correctedBy;
  final String? correctionReason;

  AttendanceModel copyWith({
    int? id,
    int? workspaceId,
    int? employeeId,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? status,
    double? workingHours,
    String? notes,
    int? shiftId,
    int? breakMinutes,
    bool? isLate,
    double? overtimeHours,
    String? correctedBy,
    String? correctionReason,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      status: status ?? this.status,
      workingHours: workingHours ?? this.workingHours,
      notes: notes ?? this.notes,
      shiftId: shiftId ?? this.shiftId,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      isLate: isLate ?? this.isLate,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      correctedBy: correctedBy ?? this.correctedBy,
      correctionReason: correctionReason ?? this.correctionReason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        employeeId,
        date,
        checkInTime,
        checkOutTime,
        status,
        workingHours,
        notes,
        shiftId,
        breakMinutes,
        isLate,
        overtimeHours,
        correctedBy,
        correctionReason,
      ];
}

class PayrollRecordModel extends Equatable {
  const PayrollRecordModel({
    required this.id,
    required this.workspaceId,
    required this.employeeId,
    required this.month,
    required this.year,
    required this.basicSalary,
    this.incentiveAmount = 0.0,
    this.allowances = 0.0,
    this.deductions = 0.0,
    required this.netSalary,
    this.status = 'draft',
    this.paidFromAccountId,
    this.paidDate,
    this.notes,
  });

  final int id;
  final int workspaceId;
  final int employeeId;
  final int month;
  final int year;
  final double basicSalary;
  final double incentiveAmount;
  final double allowances;
  final double deductions;
  final double netSalary;
  final String status;
  final int? paidFromAccountId;
  final DateTime? paidDate;
  final String? notes;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        employeeId,
        month,
        year,
        basicSalary,
        incentiveAmount,
        allowances,
        deductions,
        netSalary,
        status,
        paidFromAccountId,
        paidDate,
        notes,
      ];
}

class IncentiveRuleModel extends Equatable {
  const IncentiveRuleModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.ruleType,
    this.thresholdAmount = 0.0,
    required this.rewardRate,
    this.targetProductId,
    this.targetCategoryId,
    this.isActive = true,
  });

  final int id;
  final int workspaceId;
  final String name;
  final String ruleType;
  final double thresholdAmount;
  final double rewardRate;
  final int? targetProductId;
  final int? targetCategoryId;
  final bool isActive;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        ruleType,
        thresholdAmount,
        rewardRate,
        targetProductId,
        targetCategoryId,
        isActive,
      ];
}

class IncentiveClaimModel extends Equatable {
  const IncentiveClaimModel({
    required this.id,
    required this.workspaceId,
    required this.employeeId,
    this.saleId,
    required this.amount,
    required this.description,
    this.status = 'pending',
    required this.createdAt,
    this.processedAt,
    this.paidFromAccountId,
    this.paidDate,
  });

  final int id;
  final int workspaceId;
  final int employeeId;
  final int? saleId;
  final double amount;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final int? paidFromAccountId;
  final DateTime? paidDate;

  IncentiveClaimModel copyWith({
    int? id,
    int? workspaceId,
    int? employeeId,
    int? saleId,
    double? amount,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? processedAt,
    int? paidFromAccountId,
    DateTime? paidDate,
  }) {
    return IncentiveClaimModel(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      employeeId: employeeId ?? this.employeeId,
      saleId: saleId ?? this.saleId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      paidFromAccountId: paidFromAccountId ?? this.paidFromAccountId,
      paidDate: paidDate ?? this.paidDate,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        employeeId,
        saleId,
        amount,
        description,
        status,
        createdAt,
        processedAt,
        paidFromAccountId,
        paidDate,
      ];
}

// ============================================================================
// PHASE 4.4: USERS, ACCESS CONTROL & AUDIT LOG MODELS
// ============================================================================

class HashVerificationResult {
  const HashVerificationResult({
    required this.isValid,
    this.needsRehash = false,
  });

  final bool isValid;
  final bool needsRehash;

  bool get matches => isValid;
}

class HashHelper {
  static const int defaultPasswordIterations = 100000;
  static const int defaultPinIterations = 25000;
  static const int derivedKeyLength = 32;

  /// Generates a cryptographically secure random salt encoded in URL-safe base64
  static String generateSalt([int length = 16]) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// PBKDF2-HMAC-SHA256 (RFC 2898 / PKCS #5 v2.0)
  static Uint8List pbkdf2HmacSha256({
    required Uint8List password,
    required Uint8List salt,
    required int iterations,
    int keyLength = derivedKeyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final blocksNeeded = (keyLength + 31) ~/ 32;
    final result = Uint8List(keyLength);
    int offset = 0;

    for (int block = 1; block <= blocksNeeded; block++) {
      final blockBytes = Uint8List(salt.length + 4);
      blockBytes.setRange(0, salt.length, salt);
      blockBytes[salt.length] = (block >> 24) & 0xff;
      blockBytes[salt.length + 1] = (block >> 16) & 0xff;
      blockBytes[salt.length + 2] = (block >> 8) & 0xff;
      blockBytes[salt.length + 3] = block & 0xff;

      Uint8List u = Uint8List.fromList(hmac.convert(blockBytes).bytes);
      final blockResult = Uint8List.fromList(u);

      for (int iter = 1; iter < iterations; iter++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < blockResult.length; k++) {
          blockResult[k] ^= u[k];
        }
      }

      final toCopy = min(blockResult.length, keyLength - offset);
      result.setRange(offset, offset + toCopy, blockResult);
      offset += toCopy;
    }

    return result;
  }

  /// Hash password with PBKDF2-HMAC-SHA256 and 100,000 iterations
  static String hashPassword(String password, {String? salt, int iterations = defaultPasswordIterations}) {
    final saltStr = salt ?? generateSalt();
    final saltBytes = Uint8List.fromList(utf8.encode(saltStr));
    final pwdBytes = Uint8List.fromList(utf8.encode(password));
    final derived = pbkdf2HmacSha256(password: pwdBytes, salt: saltBytes, iterations: iterations);
    final hashB64 = base64.encode(derived);
    return '\$pbkdf2-sha256\$i=$iterations\$$saltStr\$$hashB64';
  }

  /// Hash PIN with PBKDF2-HMAC-SHA256 and 25,000 iterations
  static String hashPin(String pin, {String? salt, int iterations = defaultPinIterations}) {
    final saltStr = salt ?? generateSalt();
    final saltBytes = Uint8List.fromList(utf8.encode(saltStr));
    final pinBytes = Uint8List.fromList(utf8.encode(pin));
    final derived = pbkdf2HmacSha256(password: pinBytes, salt: saltBytes, iterations: iterations);
    final hashB64 = base64.encode(derived);
    return '\$pbkdf2-sha256\$i=$iterations\$$saltStr\$$hashB64';
  }

  /// Constant-time string equality check to prevent timing side-channel attacks
  static bool constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    int diff = 0;
    for (int i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }

  /// Verify credential against stored hash with automatic migration detection
  static HashVerificationResult verify(String input, String storedHash, {String? legacySalt}) {
    if (storedHash.startsWith(r'$pbkdf2-sha256$')) {
      final parts = storedHash.split(r'$');
      if (parts.length == 5) {
        // parts[0] is empty, parts[1] is 'pbkdf2-sha256', parts[2] is 'i=xxx', parts[3] is salt, parts[4] is hash
        final iterStr = parts[2].replaceFirst('i=', '');
        final iterations = int.tryParse(iterStr) ?? defaultPasswordIterations;
        final saltStr = parts[3];
        final expectedHashB64 = parts[4];

        final saltBytes = Uint8List.fromList(utf8.encode(saltStr));
        final inputBytes = Uint8List.fromList(utf8.encode(input));
        final derived = pbkdf2HmacSha256(password: inputBytes, salt: saltBytes, iterations: iterations);
        final computedB64 = base64.encode(derived);

        final isMatch = constantTimeEquals(computedB64, expectedHashB64);
        return HashVerificationResult(isValid: isMatch, needsRehash: false);
      }
    }

    // Legacy salted SHA-256 fallback
    if (legacySalt != null && legacySalt.isNotEmpty) {
      final legacyHash = hashCredential(input, legacySalt);
      if (constantTimeEquals(legacyHash, storedHash)) {
        return const HashVerificationResult(isValid: true, needsRehash: true);
      }
    }

    // Legacy un-salted SHA-256 or plaintext fallback
    final rawSha256 = sha256.convert(utf8.encode(input)).toString();
    if (constantTimeEquals(rawSha256, storedHash) || constantTimeEquals(input, storedHash)) {
      return const HashVerificationResult(isValid: true, needsRehash: true);
    }

    return const HashVerificationResult(isValid: false, needsRehash: false);
  }

  /// Legacy helper for backwards compatibility
  static String hashCredential(String raw, String salt) {
    final bytes = utf8.encode('$salt:$raw');
    return sha256.convert(bytes).toString();
  }

  /// Raw SHA-256 for testing legacy migration
  static String sha256Hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    this.workspaceId = 1,
    required this.name,
    required this.username,
    this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.lastLoginAt,
    required this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int workspaceId;
  final String name;
  final String username;
  final String? email;
  final String phone;
  final String role; // 'admin', 'manager', 'cashier', 'field_officer', 'agronomist'
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserRole get userRole => UserRoleX.fromValue(role);

  UserModel copyWith({
    int? id,
    int? workspaceId,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        username,
        email,
        phone,
        role,
        isActive,
        lastLoginAt,
        createdAt,
        updatedAt,
      ];
}

class UserActivityLog extends Equatable {
  const UserActivityLog({
    required this.id,
    this.workspaceId = 1,
    this.userId,
    required this.username,
    required this.module,
    required this.action,
    required this.details,
    this.ipAddress,
    required this.createdAt,
  });

  final int id;
  final int workspaceId;
  final int? userId;
  final String username;
  final String module;
  final String action;
  final String details;
  final String? ipAddress;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        userId,
        username,
        module,
        action,
        details,
        ipAddress,
        createdAt,
      ];
}

class BackupRecord extends Equatable {
  const BackupRecord({
    required this.id,
    this.workspaceId = 1,
    required this.filename,
    required this.filePath,
    required this.fileSize,
    required this.recordCount,
    required this.checksum,
    this.status = 'valid',
    required this.createdAt,
  });

  final int id;
  final int workspaceId;
  final String filename;
  final String filePath;
  final int fileSize;
  final int recordCount;
  final String checksum;
  final String status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        filename,
        filePath,
        fileSize,
        recordCount,
        checksum,
        status,
        createdAt,
      ];
}

// ----------------------------------------------------------------------------
// PERMISSION MATRIX & ACCESS RULES
// ----------------------------------------------------------------------------

enum PermissionModule {
  dashboard,
  pos,
  products,
  inventory,
  purchases,
  parties,
  financials,
  employees,
  attendance,
  payroll,
  reports,
  settings,
}

extension PermissionModuleX on PermissionModule {
  String get displayName {
    switch (this) {
      case PermissionModule.dashboard:
        return 'Dashboard';
      case PermissionModule.pos:
        return 'Billing / POS';
      case PermissionModule.products:
        return 'Products Catalog';
      case PermissionModule.inventory:
        return 'Stock & Inventory';
      case PermissionModule.purchases:
        return 'Purchase Management';
      case PermissionModule.parties:
        return 'Parties & Suppliers';
      case PermissionModule.financials:
        return 'Financials & Accounts';
      case PermissionModule.employees:
        return 'Employee Management';
      case PermissionModule.attendance:
        return 'Attendance & Leave';
      case PermissionModule.payroll:
        return 'Payroll & Incentives';
      case PermissionModule.reports:
        return 'Reports & Analytics';
      case PermissionModule.settings:
        return 'Settings & Security';
    }
  }
}

enum PermissionAction {
  view,
  create,
  edit,
  delete,
  approve,
  export,
  manageSettings,
}

class PermissionMatrix {
  static bool can(UserRole role, PermissionModule module, PermissionAction action) {
    // Admin has superuser access to all modules and actions
    if (role == UserRole.admin) return true;

    switch (role) {
      case UserRole.manager:
        if (action == PermissionAction.manageSettings) return false;
        if (action == PermissionAction.delete && (module == PermissionModule.employees || module == PermissionModule.financials)) {
          return false;
        }
        if (module == PermissionModule.settings && action != PermissionAction.view) return false;
        return true;

      case UserRole.cashier:
        switch (module) {
          case PermissionModule.pos:
            return action == PermissionAction.view || action == PermissionAction.create || action == PermissionAction.export;
          case PermissionModule.products:
          case PermissionModule.inventory:
          case PermissionModule.parties:
            return action == PermissionAction.view || action == PermissionAction.create;
          case PermissionModule.attendance:
            return action == PermissionAction.view || action == PermissionAction.create;
          case PermissionModule.dashboard:
          case PermissionModule.reports:
            return action == PermissionAction.view;
          default:
            return false;
        }

      case UserRole.fieldOfficer:
        switch (module) {
          case PermissionModule.dashboard:
          case PermissionModule.products:
            return action == PermissionAction.view;
          case PermissionModule.parties:
            return action == PermissionAction.view || action == PermissionAction.create || action == PermissionAction.edit;
          case PermissionModule.attendance:
            return action == PermissionAction.view || action == PermissionAction.create;
          default:
            return false;
        }

      case UserRole.agronomist:
        switch (module) {
          case PermissionModule.dashboard:
          case PermissionModule.products:
          case PermissionModule.parties:
            return action == PermissionAction.view;
          case PermissionModule.attendance:
            return action == PermissionAction.view || action == PermissionAction.create;
          default:
            return false;
        }

      default:
        return false;
    }
  }
}

// ============================================================================
// PHASE 4.4: BUSINESS PROFILE & INVOICE SETTINGS MODELS
// ============================================================================

class BusinessProfileModel extends Equatable {
  const BusinessProfileModel({
    this.workspaceId = 1,
    required this.businessName,
    required this.logoPath,
    required this.address,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.state,
    required this.stateCode,
    required this.invoiceFooter,
    required this.businessSlogan,
    required this.currency,
    this.invoicePrefix = 'DARVI-',
    this.invoiceSuffix = '',
    this.nextInvoiceNumber = 1001,
    this.paymentTerms = 'Immediate',
    this.roundOffMode = 'nearest',
    this.printerName = 'SSEZNIK2POS',
    this.printerMac,
    this.paperWidthMm = 58,
    this.reprintCount = 1,
  });

  final int workspaceId;
  final String businessName;
  final String logoPath;
  final String address;
  final String phone;
  final String email;
  final String gstin;
  final String state;
  final String stateCode;
  final String invoiceFooter;
  final String businessSlogan;
  final String currency;
  final String invoicePrefix;
  final String invoiceSuffix;
  final int nextInvoiceNumber;
  final String paymentTerms;
  final String roundOffMode;
  final String printerName;
  final String? printerMac;
  final int paperWidthMm;
  final int reprintCount;

  static const defaultDarvi = BusinessProfileModel(
    workspaceId: 1,
    businessName: 'Darvi Group Agri Tech',
    logoPath: 'assets/darvi_logo.png',
    address: '#2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030',
    phone: '9986890777',
    email: 'darvigroups@gmail.com',
    gstin: '29BKZPA0053M1ZQ',
    state: 'Karnataka',
    stateCode: '29',
    invoiceFooter: 'Improving Agriculture, Improving lives.\nGoods once sold will not be taken back or exchanged.\nNo cash payments accepted.',
    businessSlogan: 'Improving Agriculture, Improving lives.',
    currency: 'INR',
    invoicePrefix: 'DARVI-',
    invoiceSuffix: '',
    nextInvoiceNumber: 1001,
    paymentTerms: 'Immediate',
    roundOffMode: 'nearest',
    printerName: 'SSEZNIK2POS',
    printerMac: null,
    paperWidthMm: 58,
    reprintCount: 1,
  );

  BusinessProfileModel copyWith({
    int? workspaceId,
    String? businessName,
    String? logoPath,
    String? address,
    String? phone,
    String? email,
    String? gstin,
    String? state,
    String? stateCode,
    String? invoiceFooter,
    String? businessSlogan,
    String? currency,
    String? invoicePrefix,
    String? invoiceSuffix,
    int? nextInvoiceNumber,
    String? paymentTerms,
    String? roundOffMode,
    String? printerName,
    String? printerMac,
    int? paperWidthMm,
    int? reprintCount,
  }) {
    return BusinessProfileModel(
      workspaceId: workspaceId ?? this.workspaceId,
      businessName: businessName ?? this.businessName,
      logoPath: logoPath ?? this.logoPath,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      businessSlogan: businessSlogan ?? this.businessSlogan,
      currency: currency ?? this.currency,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceSuffix: invoiceSuffix ?? this.invoiceSuffix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      roundOffMode: roundOffMode ?? this.roundOffMode,
      printerName: printerName ?? this.printerName,
      printerMac: printerMac ?? this.printerMac,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      reprintCount: reprintCount ?? this.reprintCount,
    );
  }

  @override
  List<Object?> get props => [
        workspaceId,
        businessName,
        logoPath,
        address,
        phone,
        email,
        gstin,
        state,
        stateCode,
        invoiceFooter,
        businessSlogan,
        currency,
        invoicePrefix,
        invoiceSuffix,
        nextInvoiceNumber,
        paymentTerms,
        roundOffMode,
        printerName,
        printerMac,
        paperWidthMm,
        reprintCount,
      ];
}

// ============================================================================
// PHASE 4.4: COMPREHENSIVE REPORTS & ANALYTICS MODELS
// ============================================================================

class ComprehensiveReportSummary extends Equatable {
  const ComprehensiveReportSummary({
    required this.totalSales,
    required this.totalSalesInvoices,
    required this.totalPurchases,
    required this.totalPurchaseInvoices,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.cashInflow,
    required this.cashOutflow,
    required this.netCashFlow,
    required this.outstandingReceivables,
    required this.outstandingPayables,
    required this.inventoryValuation,
    required this.lowStockCount,
    required this.outputGstTotal,
    required this.inputGstTotal,
    required this.netGstLiability,
  });

  final double totalSales;
  final int totalSalesInvoices;
  final double totalPurchases;
  final int totalPurchaseInvoices;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final double cashInflow;
  final double cashOutflow;
  final double netCashFlow;
  final double outstandingReceivables;
  final double outstandingPayables;
  final double inventoryValuation;
  final int lowStockCount;
  final double outputGstTotal;
  final double inputGstTotal;
  final double netGstLiability;

  static const empty = ComprehensiveReportSummary(
    totalSales: 0.0,
    totalSalesInvoices: 0,
    totalPurchases: 0.0,
    totalPurchaseInvoices: 0,
    grossProfit: 0.0,
    totalExpenses: 0.0,
    netProfit: 0.0,
    cashInflow: 0.0,
    cashOutflow: 0.0,
    netCashFlow: 0.0,
    outstandingReceivables: 0.0,
    outstandingPayables: 0.0,
    inventoryValuation: 0.0,
    lowStockCount: 0,
    outputGstTotal: 0.0,
    inputGstTotal: 0.0,
    netGstLiability: 0.0,
  );

  @override
  List<Object?> get props => [
        totalSales,
        totalSalesInvoices,
        totalPurchases,
        totalPurchaseInvoices,
        grossProfit,
        totalExpenses,
        netProfit,
        cashInflow,
        cashOutflow,
        netCashFlow,
        outstandingReceivables,
        outstandingPayables,
        inventoryValuation,
        lowStockCount,
        outputGstTotal,
        inputGstTotal,
        netGstLiability,
      ];
}

class GstReportRow extends Equatable {
  const GstReportRow({
    required this.invoiceNo,
    required this.invoiceDate,
    required this.partyName,
    required this.partyGstin,
    required this.type, // 'sales_output' or 'purchase_input'
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.totalGst,
    required this.totalInvoiceValue,
  });

  final String invoiceNo;
  final DateTime invoiceDate;
  final String partyName;
  final String partyGstin;
  final String type;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalGst;
  final double totalInvoiceValue;

  @override
  List<Object?> get props => [
        invoiceNo,
        invoiceDate,
        partyName,
        partyGstin,
        type,
        taxableAmount,
        cgst,
        sgst,
        igst,
        totalGst,
        totalInvoiceValue,
      ];
}

class FinancialTrialBalanceRow extends Equatable {
  const FinancialTrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debit,
    required this.credit,
  });

  final String accountCode;
  final String accountName;
  final String accountType; // 'asset', 'liability', 'equity', 'revenue', 'expense'
  final double debit;
  final double credit;

  @override
  List<Object?> get props => [accountCode, accountName, accountType, debit, credit];
}

class PurchaseReportRow extends Equatable {
  const PurchaseReportRow({
    required this.invoiceNo,
    required this.date,
    required this.supplierName,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceDue,
    required this.paymentStatus,
  });

  final String invoiceNo;
  final DateTime date;
  final String supplierName;
  final double totalAmount;
  final double paidAmount;
  final double balanceDue;
  final String paymentStatus;

  @override
  List<Object?> get props => [
        invoiceNo,
        date,
        supplierName,
        totalAmount,
        paidAmount,
        balanceDue,
        paymentStatus,
      ];
}

class HrReportSummary extends Equatable {
  const HrReportSummary({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.attendancePercentage,
    required this.totalWorkingDays,
    required this.approvedLeaves,
    required this.totalPayrollDisbursed,
    required this.pendingPayrollAmount,
    required this.totalIncentivesPaid,
  });

  final int totalEmployees;
  final int activeEmployees;
  final double attendancePercentage;
  final int totalWorkingDays;
  final int approvedLeaves;
  final double totalPayrollDisbursed;
  final double pendingPayrollAmount;
  final double totalIncentivesPaid;

  static const empty = HrReportSummary(
    totalEmployees: 0,
    activeEmployees: 0,
    attendancePercentage: 0.0,
    totalWorkingDays: 0,
    approvedLeaves: 0,
    totalPayrollDisbursed: 0.0,
    pendingPayrollAmount: 0.0,
    totalIncentivesPaid: 0.0,
  );

  @override
  List<Object?> get props => [
        totalEmployees,
        activeEmployees,
        attendancePercentage,
        totalWorkingDays,
        approvedLeaves,
        totalPayrollDisbursed,
        pendingPayrollAmount,
        totalIncentivesPaid,
      ];
}
