import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/services/esc_pos_generator.dart';
import '../../../../core/services/receipt_pdf_service.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../core/utils/money_calculator.dart';
import '../../../../domain/entities/app_entities.dart';
import '../../../../domain/repositories/repositories.dart';

enum PosViewMode {
  workspace, // Screen 1: Billing Workspace
  checkoutReview, // Screen 2: Cart & Checkout Review
  invoicePreview, // Screen 3: Invoice Preview & Printing
}

enum ProductLayoutMode {
  grid,
  list,
}

enum ReceiptPreviewType {
  thermal58mm,
  a4Pdf,
}

enum DiscountType {
  percentage,
  fixed,
}

class PosState extends Equatable {
  const PosState({
    this.loading = false,
    this.error,
    this.viewMode = PosViewMode.workspace,
    this.layoutMode = ProductLayoutMode.grid,
    this.previewType = ReceiptPreviewType.thermal58mm,
    this.products = const [],
    this.filteredProducts = const [],
    this.popularProducts = const [],
    this.cart = const [],
    this.categories = const [],
    this.customers = const [],
    this.accounts = const [],
    this.filter = const ProductFilter(),
    this.selectedCustomerId,
    this.paymentMethod = PaymentMethod.cash,
    this.selectedPaymentAccountId,
    this.paymentReference = '',
    this.splitPayments = const [],
    this.orderDiscount = 0,
    this.discountType = DiscountType.fixed,
    this.discountInput = 0,
    this.taxEnabled = false,
    this.taxRate = 0.18,
    this.paid = 0,
    this.isManualPaidOverride = false,
    this.isCheckingOut = false,
    this.lastResult,
    this.lastSaleDetail,
    this.receiptProcessing = false,
    this.infoMessage,
    this.cashierName = 'Cashier 1',
    this.notes = '',
    this.heldBills = const [],
    this.pairedPrinters = const [],
    this.isPrinterConnected = false,
    this.connectedPrinterAddress,
    this.connectedPrinterName,
    this.printerStatusMessage,
    this.productBatches = const {},
    this.printTransportMode = PrintTransportMode.clenterClient,
    this.paperWidth = ReceiptPaperWidth.mm58,
    this.autoPrintOnCheckout = false,
    this.isClenterConnected = false,
    this.clenterStatusMessage = 'Clenter not connected',
    this.safeModeEnabled = true,
  });

  final bool loading;
  final String? error;
  final PosViewMode viewMode;
  final ProductLayoutMode layoutMode;
  final ReceiptPreviewType previewType;
  final List<ProductView> products;
  final List<ProductView> filteredProducts;
  final List<ProductView> popularProducts;
  final List<CartItem> cart;
  final List<CategoryModel> categories;
  final List<CustomerModel> customers;
  final List<AccountModel> accounts;
  final ProductFilter filter;
  final int? selectedCustomerId;
  final PaymentMethod paymentMethod;
  final int? selectedPaymentAccountId;
  final String paymentReference;
  final List<SplitPaymentItem> splitPayments;
  final double orderDiscount;
  final DiscountType discountType;
  final double discountInput;
  final bool taxEnabled;
  final double taxRate;
  final double paid;
  final bool isManualPaidOverride;
  final bool isCheckingOut;
  final SaleCheckoutResult? lastResult;
  final SaleDetailView? lastSaleDetail;
  final bool receiptProcessing;
  final String? infoMessage;
  final String cashierName;
  final String notes;
  final List<HeldBillModel> heldBills;
  final List<BluetoothDeviceInfo> pairedPrinters;
  final bool isPrinterConnected;
  final String? connectedPrinterAddress;
  final String? connectedPrinterName;
  final String? printerStatusMessage;
  final Map<int, List<ProductBatchView>> productBatches;
  final PrintTransportMode printTransportMode;
  final ReceiptPaperWidth paperWidth;
  final bool autoPrintOnCheckout;
  final bool isClenterConnected;
  final String clenterStatusMessage;
  final bool safeModeEnabled;

  /// Accurate gross subtotal (Sum of Unit Price * Qty before item discounts)
  double get grossSubtotal {
    final totals = cart.map((item) => item.price * item.qty).toList();
    return MoneyCalculator.subtotal(totals);
  }

  /// Total item-level discounts
  double get itemDiscountsTotal {
    return MoneyCalculator.round2(cart.fold(0.0, (sum, item) => sum + item.discount));
  }

  /// Net Subtotal after item discounts (Taxable subtotal before order discount)
  double get subtotal {
    final totals = cart
        .map((item) => MoneyCalculator.lineTotal(
              unitPrice: item.price,
              qty: item.qty,
              itemDiscount: item.discount,
            ))
        .toList();
    return MoneyCalculator.subtotal(totals);
  }

  /// Taxable amount after order discount
  double get taxableAmount => max(0.0, subtotal - orderDiscount);

  /// Intra-state GST breakdown
  GstBreakdown get gstBreakdown => MoneyCalculator.calculateGst(
        taxableAmount: taxableAmount,
        gstRate: taxRate,
        isInterState: false,
      );

  double get cgst => taxEnabled ? gstBreakdown.cgst : 0.0;
  double get sgst => taxEnabled ? gstBreakdown.sgst : 0.0;
  double get igst => taxEnabled ? gstBreakdown.igst : 0.0;

  /// Tax calculated via MoneyCalculator
  double get tax => MoneyCalculator.tax(
        taxableAmount: taxableAmount,
        taxEnabled: taxEnabled,
        taxRate: taxRate,
      );

  /// Raw order total before round-off
  double get rawTotal => MoneyCalculator.orderTotal(
        subtotal: subtotal,
        orderDiscount: orderDiscount,
        tax: tax,
      );

  /// Round-off delta
  double get roundOff => MoneyCalculator.roundOffTotal(rawTotal).roundOff;

  /// Grand Total with accurate rounding
  double get total => MoneyCalculator.roundOffTotal(rawTotal).roundedTotal;

  /// Total distinct items in cart
  int get totalItemsCount => cart.length;

  /// Total quantity of all units in cart
  int get totalQuantityCount => cart.fold(0, (sum, item) => sum + item.qty);

  /// Customer change amount if overpaid
  double get change => MoneyCalculator.round2(max(0.0, paid - total));

  /// Remaining unpaid / credit amount
  double get outstandingBalance => MoneyCalculator.round2(max(0.0, total - paid));

  /// Selected customer model
  CustomerModel? get selectedCustomer {
    if (selectedCustomerId == null) return null;
    return customers.cast<CustomerModel?>().firstWhere(
          (c) => c?.id == selectedCustomerId,
          orElse: () => null,
        );
  }

  /// Check if this sale pushes customer past their credit limit
  bool get isCustomerOverCredit {
    final cust = selectedCustomer;
    if (cust == null || cust.creditLimit <= 0) return false;
    final currentBal = cust.balance;
    final potentialTotalDue = currentBal + outstandingBalance;
    return potentialTotalDue > cust.creditLimit;
  }

  /// Sum of all split payment rows
  double get splitPaymentsTotal {
    return MoneyCalculator.round2(splitPayments.fold(0.0, (sum, sp) => sum + sp.amount));
  }

  /// Remaining balance to allocate for split payment
  double get remainingSplitBalance => MoneyCalculator.round2(max(0.0, total - splitPaymentsTotal));

  PosState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    PosViewMode? viewMode,
    ProductLayoutMode? layoutMode,
    ReceiptPreviewType? previewType,
    List<ProductView>? products,
    List<ProductView>? filteredProducts,
    List<ProductView>? popularProducts,
    List<CartItem>? cart,
    List<CategoryModel>? categories,
    List<CustomerModel>? customers,
    List<AccountModel>? accounts,
    ProductFilter? filter,
    int? selectedCustomerId,
    bool clearCustomer = false,
    PaymentMethod? paymentMethod,
    int? selectedPaymentAccountId,
    bool clearPaymentAccount = false,
    String? paymentReference,
    List<SplitPaymentItem>? splitPayments,
    double? orderDiscount,
    DiscountType? discountType,
    double? discountInput,
    bool? taxEnabled,
    double? taxRate,
    double? paid,
    bool? isManualPaidOverride,
    bool? isCheckingOut,
    SaleCheckoutResult? lastResult,
    bool clearLastResult = false,
    SaleDetailView? lastSaleDetail,
    bool clearLastSaleDetail = false,
    bool? receiptProcessing,
    String? infoMessage,
    bool clearInfoMessage = false,
    String? cashierName,
    String? notes,
    List<HeldBillModel>? heldBills,
    List<BluetoothDeviceInfo>? pairedPrinters,
    bool? isPrinterConnected,
    String? connectedPrinterAddress,
    String? connectedPrinterName,
    String? printerStatusMessage,
    Map<int, List<ProductBatchView>>? productBatches,
    PrintTransportMode? printTransportMode,
    ReceiptPaperWidth? paperWidth,
    bool? autoPrintOnCheckout,
    bool? isClenterConnected,
    String? clenterStatusMessage,
    bool? safeModeEnabled,
  }) {
    return PosState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      viewMode: viewMode ?? this.viewMode,
      layoutMode: layoutMode ?? this.layoutMode,
      previewType: previewType ?? this.previewType,
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      popularProducts: popularProducts ?? this.popularProducts,
      cart: cart ?? this.cart,
      categories: categories ?? this.categories,
      customers: customers ?? this.customers,
      accounts: accounts ?? this.accounts,
      filter: filter ?? this.filter,
      selectedCustomerId: clearCustomer ? null : selectedCustomerId ?? this.selectedCustomerId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      selectedPaymentAccountId: clearPaymentAccount ? null : selectedPaymentAccountId ?? this.selectedPaymentAccountId,
      paymentReference: paymentReference ?? this.paymentReference,
      splitPayments: splitPayments ?? this.splitPayments,
      orderDiscount: orderDiscount ?? this.orderDiscount,
      discountType: discountType ?? this.discountType,
      discountInput: discountInput ?? this.discountInput,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      paid: paid ?? this.paid,
      isManualPaidOverride: isManualPaidOverride ?? this.isManualPaidOverride,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
      lastSaleDetail: clearLastSaleDetail ? null : lastSaleDetail ?? this.lastSaleDetail,
      receiptProcessing: receiptProcessing ?? this.receiptProcessing,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
      cashierName: cashierName ?? this.cashierName,
      notes: notes ?? this.notes,
      heldBills: heldBills ?? this.heldBills,
      pairedPrinters: pairedPrinters ?? this.pairedPrinters,
      isPrinterConnected: isPrinterConnected ?? this.isPrinterConnected,
      connectedPrinterAddress: connectedPrinterAddress ?? this.connectedPrinterAddress,
      connectedPrinterName: connectedPrinterName ?? this.connectedPrinterName,
      printerStatusMessage: printerStatusMessage ?? this.printerStatusMessage,
      productBatches: productBatches ?? this.productBatches,
      printTransportMode: printTransportMode ?? this.printTransportMode,
      paperWidth: paperWidth ?? this.paperWidth,
      autoPrintOnCheckout: autoPrintOnCheckout ?? this.autoPrintOnCheckout,
      isClenterConnected: isClenterConnected ?? this.isClenterConnected,
      clenterStatusMessage: clenterStatusMessage ?? this.clenterStatusMessage,
      safeModeEnabled: safeModeEnabled ?? this.safeModeEnabled,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        viewMode,
        layoutMode,
        previewType,
        products,
        filteredProducts,
        popularProducts,
        cart,
        categories,
        customers,
        accounts,
        filter,
        selectedCustomerId,
        paymentMethod,
        selectedPaymentAccountId,
        paymentReference,
        splitPayments,
        orderDiscount,
        discountType,
        discountInput,
        taxEnabled,
        taxRate,
        paid,
        isManualPaidOverride,
        isCheckingOut,
        lastResult,
        lastSaleDetail,
        receiptProcessing,
        infoMessage,
        cashierName,
        notes,
        heldBills,
        pairedPrinters,
        isPrinterConnected,
        connectedPrinterAddress,
        connectedPrinterName,
        printerStatusMessage,
        productBatches,
        printTransportMode,
        paperWidth,
        autoPrintOnCheckout,
        isClenterConnected,
        clenterStatusMessage,
        safeModeEnabled,
      ];
}

class PosCubit extends Cubit<PosState> {
  PosCubit({
    required ProductRepository productRepository,
    required SalesRepository salesRepository,
    required SettingsRepository settingsRepository,
    required PartyRepository partyRepository,
    required BarcodeScannerService scannerService,
    required ReceiptPdfService receiptPdfService,
    AccountRepository? accountRepository,
    ThermalPrinterService? thermalPrinterService,
  })  : _productRepository = productRepository,
        _salesRepository = salesRepository,
        _settingsRepository = settingsRepository,
        _partyRepository = partyRepository,
        _scannerService = scannerService,
        _receiptPdfService = receiptPdfService,
        _accountRepository = accountRepository,
        _thermalPrinterService = thermalPrinterService ?? ThermalPrinterService(),
        super(const PosState());

  final ProductRepository _productRepository;
  final SalesRepository _salesRepository;
  final SettingsRepository _settingsRepository;
  final PartyRepository _partyRepository;
  final BarcodeScannerService _scannerService;
  final ReceiptPdfService _receiptPdfService;
  final AccountRepository? _accountRepository;
  final ThermalPrinterService _thermalPrinterService;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final settings = await _settingsRepository.getSettings();
      final categories = await _productRepository.getCategories();
      final products = await _productRepository.getProducts();
      final popular = await _productRepository.getPopularProducts();
      final customers = await _partyRepository.getCustomers();

      List<AccountModel> accounts = [];
      if (_accountRepository != null) {
        try {
          accounts = await _accountRepository.getAccounts();
        } catch (_) {}
      }

      List<HeldBillModel> heldBills = [];
      try {
        heldBills = await _salesRepository.getHeldBills();
      } catch (_) {}

      List<BluetoothDeviceInfo> printers = [];
      try {
        printers = await _thermalPrinterService.getPairedDevices();
      } catch (_) {}

      bool isClenter = state.isClenterConnected;
      try {
        isClenter = await _thermalPrinterService.checkClenterConnection();
      } catch (_) {}

      final updatedState = state.copyWith(
        loading: false,
        categories: categories,
        products: products,
        filteredProducts: products,
        popularProducts: popular,
        customers: customers,
        accounts: accounts,
        heldBills: heldBills,
        pairedPrinters: printers,
        isPrinterConnected: _thermalPrinterService.status == BluetoothPrinterStatus.connected,
        connectedPrinterAddress: _thermalPrinterService.connectedAddress,
        isClenterConnected: isClenter,
        clenterStatusMessage: isClenter ? 'Clenter App Ready' : 'Clenter not connected',
        taxEnabled: settings.taxEnabled,
        taxRate: settings.taxRate,
        selectedCustomerId: state.selectedCustomerId ?? (customers.isNotEmpty ? customers.first.id : null),
        selectedPaymentAccountId: state.selectedPaymentAccountId ?? (accounts.isNotEmpty ? accounts.first.id : 1),
      );

      final finalPaid = updatedState.isManualPaidOverride ? updatedState.paid : updatedState.total;
      emit(updatedState.copyWith(paid: finalPaid));
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void setViewMode(PosViewMode mode) {
    emit(state.copyWith(viewMode: mode, clearError: true));
  }

  void setLayoutMode(ProductLayoutMode mode) {
    emit(state.copyWith(layoutMode: mode));
  }

  void setPreviewType(ReceiptPreviewType type) {
    emit(state.copyWith(previewType: type));
  }

  void setCashierName(String name) {
    emit(state.copyWith(cashierName: name));
  }

  void setNotes(String notes) {
    emit(state.copyWith(notes: notes));
  }

  void setPaymentMethod(PaymentMethod method) {
    emit(state.copyWith(paymentMethod: method));
  }

  void setPaymentAccountId(int? id) {
    emit(state.copyWith(selectedPaymentAccountId: id));
  }

  void setPaymentReference(String ref) {
    emit(state.copyWith(paymentReference: ref));
  }

  void selectCustomer(int? id) {
    emit(state.copyWith(selectedCustomerId: id, clearCustomer: id == null));
  }

  /// Registers a new customer without losing active cart state
  Future<void> quickAddCustomer({
    required String name,
    required String phone,
    String? gstin,
    String? address,
    double creditLimit = 0.0,
  }) async {
    try {
      final newId = await _partyRepository.upsertCustomer(
        name: name.trim(),
        phone: phone.trim(),
        gstin: gstin?.trim(),
        address: address?.trim(),
        creditLimit: creditLimit,
      );
      final refreshedCustomers = await _partyRepository.getCustomers();

      emit(
        state.copyWith(
          customers: refreshedCustomers,
          selectedCustomerId: newId,
          infoMessage: 'Customer registered: $name',
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> scanAndAdd() async {
    final code = await _scannerService.scanBarcode();
    if (code == null || code.isEmpty) return;
    final product = await _productRepository.findByBarcode(code);
    if (product == null) {
      emit(state.copyWith(error: 'Product not found for barcode: $code', clearLastResult: true));
      return;
    }
    addProductToCart(product);
  }

  Future<void> loadBatchesForProduct(int productId) async {
    try {
      final batches = await _productRepository.getBatches(productId: productId);
      final map = Map<int, List<ProductBatchView>>.from(state.productBatches);
      map[productId] = batches;
      emit(state.copyWith(productBatches: map));
    } catch (_) {}
  }

  void updateFilter({String? search, int? categoryId, bool? lowStockOnly}) {
    final filter = state.filter.copyWith(
      search: search,
      categoryId: categoryId,
      lowStockOnly: lowStockOnly,
      clearCategory: categoryId == -1,
    );
    final searchLower = filter.search.trim().toLowerCase();
    final filtered = state.products.where((p) {
      final matchSearch = searchLower.isEmpty ||
          p.name.toLowerCase().contains(searchLower) ||
          p.sku.toLowerCase().contains(searchLower) ||
          (p.barcode?.contains(searchLower) ?? false);
      final matchCategory = filter.categoryId == null || p.categoryId == filter.categoryId;
      final matchLow = !filter.lowStockOnly || p.isLowStock;
      return matchSearch && matchCategory && matchLow;
    }).toList();

    emit(state.copyWith(filter: filter, filteredProducts: filtered));
  }

  void addProductToCart(
    ProductView product, {
    int? batchId,
    String? batchNumber,
    double? customPrice,
  }) {
    final existingIndex = state.cart.indexWhere((item) =>
        item.productId == product.id &&
        (batchId == null || item.batchId == batchId));

    final updated = [...state.cart];
    final priceToUse = customPrice ?? product.price;

    if (existingIndex == -1) {
      updated.add(
        CartItem(
          productId: product.id,
          name: product.name,
          sku: product.sku,
          barcode: product.barcode,
          cost: product.cost,
          price: priceToUse,
          qty: 1,
          batchId: batchId,
          batchNumber: batchNumber,
          unit: 'Unit',
          gstRate: product.gstRate,
          hsnCode: product.hsnCode,
        ),
      );
    } else {
      final item = updated[existingIndex];
      updated[existingIndex] = item.copyWith(
        qty: item.qty + 1,
        price: customPrice ?? item.price,
      );
    }

    final tempState = state.copyWith(cart: updated);
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;

    emit(
      state.copyWith(
        cart: updated,
        paid: newPaid,
        clearError: true,
        clearLastResult: true,
      ),
    );
  }

  void updateItemQty(int productId, int qty) {
    final updated = [...state.cart];
    final index = updated.indexWhere((item) => item.productId == productId);
    if (index == -1) return;

    if (qty <= 0) {
      updated.removeAt(index);
    } else {
      updated[index] = updated[index].copyWith(qty: qty);
    }

    final tempState = state.copyWith(cart: updated);
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;
    emit(state.copyWith(cart: updated, paid: newPaid));
  }

  void removeFromCart(int productId) {
    final updated = state.cart.where((item) => item.productId != productId).toList();
    final tempState = state.copyWith(cart: updated);
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;
    emit(state.copyWith(cart: updated, paid: newPaid));
  }

  void clearCart() {
    emit(
      state.copyWith(
        cart: const [],
        orderDiscount: 0,
        discountInput: 0,
        paid: 0,
        isManualPaidOverride: false,
        splitPayments: const [],
        clearError: true,
      ),
    );
  }

  void setItemDiscount(int productId, double discount) {
    final updated = [...state.cart];
    final index = updated.indexWhere((item) => item.productId == productId);
    if (index == -1) return;
    final item = updated[index];
    updated[index] = item.copyWith(discount: max(0.0, discount));

    final tempState = state.copyWith(cart: updated);
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;
    emit(state.copyWith(cart: updated, paid: newPaid));
  }

  void setItemPrice(int productId, double price) {
    final updated = [...state.cart];
    final index = updated.indexWhere((item) => item.productId == productId);
    if (index == -1) return;
    final item = updated[index];
    updated[index] = item.copyWith(price: max(0.0, price));

    final tempState = state.copyWith(cart: updated);
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;
    emit(state.copyWith(cart: updated, paid: newPaid));
  }

  void setItemBatch(int productId, int batchId, String batchNumber) {
    final updated = [...state.cart];
    final index = updated.indexWhere((item) => item.productId == productId);
    if (index == -1) return;
    updated[index] = updated[index].copyWith(batchId: batchId, batchNumber: batchNumber);
    emit(state.copyWith(cart: updated));
  }

  void setItemLineNote(int productId, String note) {
    final updated = [...state.cart];
    final index = updated.indexWhere((item) => item.productId == productId);
    if (index == -1) return;
    updated[index] = updated[index].copyWith(lineNote: note);
    emit(state.copyWith(cart: updated));
  }

  void setDiscount(DiscountType type, double value) {
    final safeValue = max(0.0, value);
    double calculatedDiscount = 0.0;
    if (type == DiscountType.percentage) {
      final pct = min(100.0, safeValue);
      calculatedDiscount = MoneyCalculator.round2((state.subtotal * pct) / 100.0);
    } else {
      calculatedDiscount = min(state.subtotal, safeValue);
    }

    final tempState = state.copyWith(
      orderDiscount: calculatedDiscount,
      discountType: type,
      discountInput: safeValue,
    );
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;
    emit(
      state.copyWith(
        orderDiscount: calculatedDiscount,
        discountType: type,
        discountInput: safeValue,
        paid: newPaid,
      ),
    );
  }

  void setOrderDiscount(double value) {
    setDiscount(DiscountType.fixed, value);
  }

  void setTaxEnabled(bool enabled) {
    final tempState = state.copyWith(taxEnabled: enabled);
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;
    emit(state.copyWith(taxEnabled: enabled, paid: newPaid));
  }

  void setTaxRate(double rate) {
    final tempState = state.copyWith(taxRate: max(0.0, rate));
    final newPaid = state.isManualPaidOverride ? state.paid : tempState.total;
    emit(state.copyWith(taxRate: max(0.0, rate), paid: newPaid));
  }

  void setPaid(double value) {
    emit(
      state.copyWith(
        paid: max(0.0, value),
        isManualPaidOverride: true,
      ),
    );
  }

  void resetPaidToTotal() {
    emit(
      state.copyWith(
        paid: state.total,
        isManualPaidOverride: false,
      ),
    );
  }

  // Split payment methods
  void addSplitPayment(
    PaymentMethod method,
    double amount, {
    int? accountId,
    String? accountName,
    String? referenceNo,
  }) {
    if (amount <= 0) return;
    final row = SplitPaymentItem(
      method: method,
      amount: MoneyCalculator.round2(amount),
      accountId: accountId,
      accountName: accountName,
      referenceNo: referenceNo,
    );
    final updated = [...state.splitPayments, row];
    final totalSplit = updated.fold(0.0, (sum, sp) => sum + sp.amount);
    emit(
      state.copyWith(
        splitPayments: updated,
        paymentMethod: PaymentMethod.split,
        paid: totalSplit,
        isManualPaidOverride: true,
      ),
    );
  }

  void removeSplitPayment(int index) {
    if (index < 0 || index >= state.splitPayments.length) return;
    final updated = [...state.splitPayments]..removeAt(index);
    final totalSplit = updated.fold(0.0, (sum, sp) => sum + sp.amount);
    emit(
      state.copyWith(
        splitPayments: updated,
        paid: totalSplit,
        isManualPaidOverride: updated.isNotEmpty,
      ),
    );
  }

  void clearSplitPayments() {
    emit(
      state.copyWith(
        splitPayments: const [],
        paid: state.total,
        isManualPaidOverride: false,
      ),
    );
  }

  // Held Bills Management
  Future<void> loadHeldBills() async {
    try {
      final bills = await _salesRepository.getHeldBills();
      emit(state.copyWith(heldBills: bills));
    } catch (_) {}
  }

  Future<void> holdCurrentBill({String? note}) async {
    if (state.cart.isEmpty) {
      emit(state.copyWith(error: 'Cannot hold an empty cart'));
      return;
    }

    try {
      final heldBill = HeldBillModel(
        referenceNote: note ?? 'Held @ ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        customerId: state.selectedCustomerId,
        customerName: state.selectedCustomer?.name,
        customerPhone: state.selectedCustomer?.phone,
        items: state.cart,
        orderDiscount: state.orderDiscount,
        taxEnabled: state.taxEnabled,
        taxRate: state.taxRate,
        subtotal: state.subtotal,
        totalAmount: state.total,
        itemCount: state.totalQuantityCount,
        createdAt: DateTime.now(),
      );

      await _salesRepository.saveHeldBill(heldBill);
      final refreshed = await _salesRepository.getHeldBills();

      emit(
        state.copyWith(
          heldBills: refreshed,
          cart: const [],
          orderDiscount: 0,
          discountInput: 0,
          paid: 0,
          isManualPaidOverride: false,
          splitPayments: const [],
          clearError: true,
          infoMessage: 'Bill parked successfully (${refreshed.length} held)',
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: 'Failed to hold bill: $e'));
    }
  }

  Future<void> resumeHeldBill(HeldBillModel bill) async {
    try {
      if (bill.id != null) {
        await _salesRepository.deleteHeldBill(bill.id!);
      }
      final refreshed = await _salesRepository.getHeldBills();

      final tempState = state.copyWith(
        heldBills: refreshed,
        cart: bill.items,
        orderDiscount: bill.orderDiscount,
        taxEnabled: bill.taxEnabled,
        taxRate: bill.taxRate,
        selectedCustomerId: bill.customerId,
        isManualPaidOverride: false,
        viewMode: PosViewMode.workspace,
        clearError: true,
        infoMessage: 'Resumed bill for ${bill.customerName ?? "Walk-in Customer"}',
      );

      emit(tempState.copyWith(paid: tempState.total));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to resume bill: $e'));
    }
  }

  Future<void> deleteHeldBill(int id) async {
    try {
      await _salesRepository.deleteHeldBill(id);
      final refreshed = await _salesRepository.getHeldBills();
      emit(state.copyWith(heldBills: refreshed, infoMessage: 'Held bill removed'));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to delete held bill: $e'));
    }
  }

  // Checkout and Invoice Preview
  Future<void> checkout() async {
    if (state.isCheckingOut || state.loading) {
      return;
    }

    if (state.cart.isEmpty) {
      emit(state.copyWith(error: 'Cart is empty'));
      return;
    }

    emit(state.copyWith(isCheckingOut: true, loading: true, clearError: true));

    try {
      final result = await _salesRepository.checkout(
        SaleCheckoutInput(
          items: state.cart,
          orderDiscount: state.orderDiscount,
          taxEnabled: state.taxEnabled,
          taxRate: state.taxRate,
          paid: state.paid,
          paymentMethod: state.paymentMethod,
          customerId: state.selectedCustomerId,
          cashierName: state.cashierName,
          notes: state.notes,
          splitPayments: state.splitPayments.isNotEmpty ? state.splitPayments : null,
          paymentAccountId: state.selectedPaymentAccountId,
          paymentReference: state.paymentReference,
        ),
      );

      SaleDetailView? saleDetail;
      try {
        saleDetail = await _salesRepository.getInvoiceDetail(result.saleId);
      } catch (_) {}

      emit(
        state.copyWith(
          isCheckingOut: false,
          loading: false,
          lastResult: result,
          lastSaleDetail: saleDetail,
          viewMode: PosViewMode.invoicePreview,
          cart: const [],
          orderDiscount: 0,
          discountInput: 0,
          paid: 0,
          isManualPaidOverride: false,
          splitPayments: const [],
          notes: '',
          infoMessage: 'Sale completed: ${result.invoiceNo}',
        ),
      );

      if (state.autoPrintOnCheckout && saleDetail != null) {
        printReceiptSmooth(saleDetail: saleDetail);
      }

      await load();
    } on AppException catch (e) {
      emit(state.copyWith(isCheckingOut: false, loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(isCheckingOut: false, loading: false, error: e.toString()));
    }
  }

  Future<void> loadInvoiceDetailForPreview(int saleId) async {
    try {
      final detail = await _salesRepository.getInvoiceDetail(saleId);
      emit(state.copyWith(lastSaleDetail: detail));
    } catch (_) {}
  }

  void newSale() {
    emit(
      state.copyWith(
        viewMode: PosViewMode.workspace,
        cart: const [],
        orderDiscount: 0,
        discountInput: 0,
        paid: 0,
        isManualPaidOverride: false,
        isCheckingOut: false,
        splitPayments: const [],
        clearLastResult: true,
        clearLastSaleDetail: true,
        clearError: true,
        clearInfoMessage: true,
      ),
    );
  }

  // Configuration setters for smooth multi-transport printing
  void setPrintTransportMode(PrintTransportMode mode) {
    emit(state.copyWith(printTransportMode: mode));
    if (mode == PrintTransportMode.clenterClient) {
      checkClenterStatus();
    }
  }

  void setPaperWidth(ReceiptPaperWidth width) {
    emit(state.copyWith(paperWidth: width));
  }

  void setAutoPrintOnCheckout(bool enabled) {
    emit(state.copyWith(autoPrintOnCheckout: enabled));
  }

  void setSafeMode(bool enabled) {
    emit(state.copyWith(safeModeEnabled: enabled));
  }

  Future<void> checkClenterStatus() async {
    final connected = await _thermalPrinterService.checkClenterConnection();
    emit(state.copyWith(
      isClenterConnected: connected,
      clenterStatusMessage: connected ? 'Clenter App Ready' : 'Clenter not connected',
    ));
  }

  Future<void> connectClenter() async {
    emit(state.copyWith(receiptProcessing: true, clenterStatusMessage: 'Checking Clenter connection...'));
    final connected = await _thermalPrinterService.checkClenterConnection();
    emit(state.copyWith(
      receiptProcessing: false,
      isClenterConnected: connected,
      clenterStatusMessage: connected ? 'Clenter App Ready' : 'Clenter not connected',
      infoMessage: connected ? 'Connected to Clenter App' : 'Clenter not connected on port 8080/9100',
    ));
  }

  /// Unified smooth receipt printing dispatcher across Clenter, System Spooler, and Bluetooth
  Future<void> printReceiptSmooth({SaleDetailView? saleDetail}) async {
    SaleDetailView? detail = saleDetail ?? state.lastSaleDetail;
    if (detail == null) {
      if (state.cart.isNotEmpty) {
        final sale = SaleView(
          id: 0,
          invoiceNo: 'EST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          createdAt: DateTime.now(),
          customerId: state.selectedCustomerId,
          subtotal: state.subtotal,
          discountTotal: state.orderDiscount,
          taxTotal: state.tax,
          total: state.total,
          paid: state.paid > 0 ? state.paid : state.total,
          changeAmount: state.change,
          paymentMethod: state.paymentMethod,
          status: SaleStatus.completed,
          cgstTotal: state.cgst,
          sgstTotal: state.sgst,
          igstTotal: state.igst,
          roundOff: state.roundOff,
        );
        final items = state.cart.map((c) => SaleItemView(
          id: 0,
          saleId: 0,
          productId: c.productId,
          nameSnapshot: c.name,
          costSnapshot: c.cost,
          priceSnapshot: c.price,
          qty: c.qty,
          discount: c.discount,
          lineTotal: c.lineTotal,
          unit: c.unit,
        )).toList();
        detail = SaleDetailView(sale: sale, items: items);
      } else {
        emit(state.copyWith(error: 'No invoice available for printing'));
        return;
      }
    }

    emit(state.copyWith(receiptProcessing: true, clearError: true));
    try {
      final settings = await _settingsRepository.getSettings();
      final storeName = settings.storeName.isNotEmpty ? settings.storeName : 'Darvi Group Agri Tech';
      final header = settings.receiptHeader.isNotEmpty ? settings.receiptHeader : '#2 Totad Building, Arjun Vihar, Gokul Road, Hubli 580030';
      final footer = settings.receiptFooter.isNotEmpty ? settings.receiptFooter : 'Goods once sold will not be taken back.';

      if (state.printTransportMode == PrintTransportMode.clenterClient) {
        // Mode 1: Cleanter companion app (HTTP JSON / Socket)
        final int cols = state.paperWidth == ReceiptPaperWidth.mm80 ? 48 : 32;
        final bytes = EscPosGenerator.buildDarviReceipt(
          sale: detail.sale,
          items: detail.items,
          customerName: state.selectedCustomer?.name,
          businessName: storeName,
          gstin: '29BKZPA0053M1ZQ',
          address: header,
          phone: '9986890777',
          receiptSlogan: 'Improving Agriculture, Improving lives.',
          receiptTerms: footer,
          cgst: detail.sale.cgstTotal,
          sgst: detail.sale.sgstTotal,
          igst: detail.sale.igstTotal,
          roundOff: detail.sale.roundOff,
          width: cols,
          feedBeforeCut: 4,
          safeMode: state.safeModeEnabled,
        );

        final cleanterJson = {
          'paperWidth': state.paperWidth == ReceiptPaperWidth.mm80 ? 80 : 58,
          'cut': true,
          'reference': detail.sale.invoiceNo,
          'content': [
            {'type': 'text', 'value': storeName, 'align': 'center', 'bold': true, 'size': 'double'},
            {'type': 'text', 'value': 'GSTIN: 29BKZPA0053M1ZQ', 'align': 'center'},
            {'type': 'text', 'value': header, 'align': 'center'},
            {'type': 'divider'},
            {'type': 'text', 'value': 'Invoice: ${detail.sale.invoiceNo}', 'bold': true},
            {'type': 'text', 'value': 'Date: ${detail.sale.createdAt.toString().substring(0, 16)}'},
            {'type': 'text', 'value': 'Cashier: ${state.cashierName}'},
            {'type': 'text', 'value': 'Customer: ${state.selectedCustomer?.name ?? "Walk-in Customer"}'},
            {'type': 'divider'},
            {'type': 'text', 'value': 'ITEM               QTY   TOTAL', 'bold': true},
            ...detail.items.map((it) {
              final name = it.name.length > 16 ? it.name.substring(0, 16) : it.name.padRight(16);
              return {
                'type': 'text',
                'value': '$name ${it.qty.toString().padLeft(4)} ${it.lineTotal.toStringAsFixed(2).padLeft(8)}',
              };
            }),
            {'type': 'divider'},
            {'type': 'text', 'value': 'TOTAL: INR ${detail.sale.total.toStringAsFixed(2)}', 'bold': true, 'align': 'right', 'size': 'large'},
            {'type': 'text', 'value': 'PAID:  INR ${detail.sale.paid.toStringAsFixed(2)}', 'align': 'right'},
            if (detail.sale.changeAmount > 0)
              {'type': 'text', 'value': 'CHANGE: INR ${detail.sale.changeAmount.toStringAsFixed(2)}', 'align': 'right'},
            {'type': 'divider'},
            {'type': 'text', 'value': 'Improving Agriculture, Improving lives.', 'align': 'center'},
            {'type': 'text', 'value': footer, 'align': 'center'},
            {'type': 'text', 'value': 'Thank You! Visit Again.', 'align': 'center'},
            {'type': 'spacer', 'lines': 3},
          ],
        };

        // Try HTTP JSON first
        bool ok = await _thermalPrinterService.sendJsonToClenter(cleanterJson);
        if (!ok) {
          // Try Raw socket / byte stream second
          ok = await _thermalPrinterService.sendBytesToClenter(bytes);
        }

        if (ok) {
          emit(state.copyWith(
            receiptProcessing: false,
            isClenterConnected: true,
            clenterStatusMessage: 'Clenter App Ready',
            infoMessage: 'Receipt printed via Clenter',
          ));
          return;
        } else {
          // If Cleanter is unreachable, smoothly fallback to System Spooler
          await _receiptPdfService.printThermalViaSystemSpooler(
            sale: detail.sale,
            items: detail.items,
            storeName: storeName,
            header: header,
            footer: footer,
            currency: settings.currency,
            paperWidth: state.paperWidth,
          );
          emit(state.copyWith(
            receiptProcessing: false,
            isClenterConnected: false,
            clenterStatusMessage: 'Clenter not connected',
            infoMessage: 'Receipt sent to System Printer',
          ));
          return;
        }
      } else if (state.printTransportMode == PrintTransportMode.systemSpooler) {
        // Mode 2: Universal OS System Spooler
        await _receiptPdfService.printThermalViaSystemSpooler(
          sale: detail.sale,
          items: detail.items,
          storeName: storeName,
          header: header,
          footer: footer,
          currency: settings.currency,
          paperWidth: state.paperWidth,
        );
        emit(state.copyWith(receiptProcessing: false, infoMessage: 'Print job dispatched to System Spooler'));
        return;
      } else {
        // Mode 3: Direct Bluetooth SPP
        if (_thermalPrinterService.status != BluetoothPrinterStatus.connected && !state.isPrinterConnected) {
          emit(state.copyWith(
            receiptProcessing: false,
            error: 'Bluetooth printer not connected. Connect device or switch to Clenter/System Print.',
          ));
          return;
        }
        await printThermalReceipt();
      }
    } catch (e) {
      emit(state.copyWith(receiptProcessing: false, error: 'Printing failed: $e'));
    }
  }

  // Thermal & PDF Printing
  Future<void> refreshPrinters() async {
    try {
      final devices = await _thermalPrinterService.getPairedDevices();
      emit(
        state.copyWith(
          pairedPrinters: devices,
          isPrinterConnected: _thermalPrinterService.status == BluetoothPrinterStatus.connected,
          connectedPrinterAddress: _thermalPrinterService.connectedAddress,
          printerStatusMessage: devices.isEmpty ? 'No paired Bluetooth devices' : '${devices.length} printer(s) found',
        ),
      );
    } catch (e) {
      emit(state.copyWith(printerStatusMessage: 'Bluetooth scan unavailable'));
    }
  }

  Future<void> connectPrinter(BluetoothDeviceInfo device) async {
    emit(state.copyWith(printerStatusMessage: 'Connecting to ${device.name}...'));
    final success = await _thermalPrinterService.connect(device.address);
    if (success) {
      emit(
        state.copyWith(
          isPrinterConnected: true,
          connectedPrinterAddress: device.address,
          connectedPrinterName: device.name,
          printerStatusMessage: 'Connected to ${device.name}',
          infoMessage: 'Printer connected',
        ),
      );
    } else {
      emit(
        state.copyWith(
          isPrinterConnected: false,
          connectedPrinterAddress: null,
          printerStatusMessage: _thermalPrinterService.errorMessage ?? 'Connection failed',
          error: _thermalPrinterService.errorMessage ?? 'Failed to connect to printer',
        ),
      );
    }
  }

  Future<void> disconnectPrinter() async {
    await _thermalPrinterService.disconnect();
    emit(
      state.copyWith(
        isPrinterConnected: false,
        connectedPrinterAddress: null,
        connectedPrinterName: null,
        printerStatusMessage: 'Printer disconnected',
      ),
    );
  }

  Future<void> printDiagnosticTicket() async {
    emit(state.copyWith(receiptProcessing: true, clearError: true));
    try {
      final int cols = state.paperWidth == ReceiptPaperWidth.mm80 ? 48 : 32;
      final bytes = EscPosGenerator.buildDiagnosticTestPrint(width: cols, feedBeforeCut: 4);

      if (state.printTransportMode == PrintTransportMode.clenterClient) {
        final ok = await _thermalPrinterService.sendBytesToClenter(bytes);
        emit(state.copyWith(
          receiptProcessing: false,
          isClenterConnected: ok,
          clenterStatusMessage: ok ? 'Clenter App Ready' : 'Clenter not connected',
          infoMessage: ok ? 'Diagnostic test ticket sent to Clenter' : 'Clenter not connected',
          error: ok ? null : 'Clenter not connected on port 8080/9100',
        ));
      } else if (state.printTransportMode == PrintTransportMode.systemSpooler) {
        await _receiptPdfService.printDiagnosticSelfTest(paperWidth: state.paperWidth);
        emit(state.copyWith(receiptProcessing: false, infoMessage: 'Diagnostic test sent to spooler'));
      } else {
        final ok = await _thermalPrinterService.sendBytes(bytes);
        emit(
          state.copyWith(
            receiptProcessing: false,
            infoMessage: ok ? 'Diagnostic test ticket printed' : 'Print failed: printer not connected',
            error: ok ? null : _thermalPrinterService.errorMessage,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(receiptProcessing: false, error: 'Diagnostic print error: $e'));
    }
  }

  Future<void> printThermalReceipt() async {
    final detail = state.lastSaleDetail;
    if (detail == null) {
      emit(state.copyWith(error: 'No invoice available for printing'));
      return;
    }

    emit(state.copyWith(receiptProcessing: true, clearError: true));
    try {
      final settings = await _settingsRepository.getSettings();
      final int cols = state.paperWidth == ReceiptPaperWidth.mm80 ? 48 : 32;
      final bytes = EscPosGenerator.buildDarviReceipt(
        sale: detail.sale,
        items: detail.items,
        customerName: state.selectedCustomer?.name,
        businessName: 'Darvi Group Agri Tech',
        gstin: '29BKZPA0053M1ZQ',
        address: '#2 Totad Building, Arjun Vihar, Gokul Road, Hubli 580030',
        phone: '9986890777',
        receiptSlogan: 'Improving Agriculture, Improving lives.',
        receiptTerms: settings.receiptFooter.isNotEmpty
            ? settings.receiptFooter
            : 'Goods once sold will not be taken back.',
        cgst: detail.sale.cgstTotal,
        sgst: detail.sale.sgstTotal,
        igst: detail.sale.igstTotal,
        roundOff: detail.sale.roundOff,
        width: cols,
        feedBeforeCut: 4,
        safeMode: state.safeModeEnabled,
      );

      final success = await _thermalPrinterService.sendBytes(bytes);
      emit(
        state.copyWith(
          receiptProcessing: false,
          infoMessage: success ? 'Thermal receipt sent to printer' : 'Thermal print failed: printer not connected',
          error: success ? null : _thermalPrinterService.errorMessage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(receiptProcessing: false, error: 'Thermal print error: $e'));
    }
  }

  Future<void> shareLastReceipt() async {
    await _handlePdfAction(share: true);
  }

  Future<void> printA4Pdf() async {
    await _handlePdfAction(share: false);
  }

  Future<void> printLastReceipt() async {
    await printReceiptSmooth();
  }

  Future<void> _handlePdfAction({required bool share}) async {
    SaleDetailView? detail = state.lastSaleDetail;
    if (detail == null) {
      if (state.cart.isNotEmpty) {
        final sale = SaleView(
          id: 0,
          invoiceNo: 'EST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          createdAt: DateTime.now(),
          customerId: state.selectedCustomerId,
          subtotal: state.subtotal,
          discountTotal: state.orderDiscount,
          taxTotal: state.tax,
          total: state.total,
          paid: state.paid > 0 ? state.paid : state.total,
          changeAmount: state.change,
          paymentMethod: state.paymentMethod,
          status: SaleStatus.completed,
          cgstTotal: state.cgst,
          sgstTotal: state.sgst,
          igstTotal: state.igst,
          roundOff: state.roundOff,
        );
        final items = state.cart.map((c) => SaleItemView(
          id: 0,
          saleId: 0,
          productId: c.productId,
          nameSnapshot: c.name,
          costSnapshot: c.cost,
          priceSnapshot: c.price,
          qty: c.qty,
          discount: c.discount,
          lineTotal: c.lineTotal,
          unit: c.unit,
        )).toList();
        detail = SaleDetailView(sale: sale, items: items);
      } else {
        emit(state.copyWith(error: 'No invoice available for PDF generation'));
        return;
      }
    }

    emit(state.copyWith(receiptProcessing: true, clearError: true));
    try {
      final settings = await _settingsRepository.getSettings();
      final file = await _receiptPdfService.generateReceipt(
        sale: detail.sale,
        items: detail.items,
        storeName: settings.storeName,
        header: settings.receiptHeader,
        footer: settings.receiptFooter,
        currency: settings.currency,
        paperWidth: state.paperWidth,
      );

      if (share) {
        await _receiptPdfService.sharePdf(file);
      } else {
        await _receiptPdfService.printPdf(file);
      }

      emit(
        state.copyWith(
          receiptProcessing: false,
          infoMessage: share ? 'Invoice shared' : 'Invoice sent to system printer',
        ),
      );
    } catch (e) {
      emit(state.copyWith(receiptProcessing: false, error: 'PDF error: $e'));
    }
  }
}
