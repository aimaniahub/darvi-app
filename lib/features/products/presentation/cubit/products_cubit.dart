import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../domain/entities/app_entities.dart';
import '../../../../domain/repositories/repositories.dart';

class ProductsState extends Equatable {
  const ProductsState({
    this.loading = false,
    this.error,
    this.products = const [],
    this.filteredProducts = const [],
    this.categories = const [],
    this.batches = const [],
    this.stockMovements = const [],
    this.filter = const ProductFilter(),
    this.isGridView = false,
    this.selectedCategoryFilter,
  });

  final bool loading;
  final String? error;
  final List<ProductView> products;
  final List<ProductView> filteredProducts;
  final List<CategoryModel> categories;
  final List<ProductBatchView> batches;
  final List<StockMovementView> stockMovements;
  final ProductFilter filter;
  final bool isGridView;
  final String? selectedCategoryFilter;

  // KPI Computations
  int get totalProductsCount => products.length;
  int get activeProductsCount => products.where((p) => p.isActive).length;
  int get lowStockCount => products.where((p) => p.isLowStock).length;
  int get outOfStockCount => products.where((p) => p.isOutOfStock).length;
  double get totalStockValuation => products.fold<double>(0.0, (acc, p) => acc + p.stockValuation);

  ProductsState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<ProductView>? products,
    List<ProductView>? filteredProducts,
    List<CategoryModel>? categories,
    List<ProductBatchView>? batches,
    List<StockMovementView>? stockMovements,
    ProductFilter? filter,
    bool? isGridView,
    String? selectedCategoryFilter,
    bool clearCategoryFilter = false,
  }) {
    return ProductsState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      batches: batches ?? this.batches,
      stockMovements: stockMovements ?? this.stockMovements,
      filter: filter ?? this.filter,
      isGridView: isGridView ?? this.isGridView,
      selectedCategoryFilter: clearCategoryFilter
          ? null
          : (selectedCategoryFilter ?? this.selectedCategoryFilter),
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        products,
        filteredProducts,
        categories,
        batches,
        stockMovements,
        filter,
        isGridView,
        selectedCategoryFilter,
      ];
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit(this._productRepository) : super(const ProductsState());

  final ProductRepository _productRepository;

  void toggleViewMode() {
    emit(state.copyWith(isGridView: !state.isGridView));
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final categories = await _productRepository.getCategories();
      final products = await _productRepository.getProducts(filter: state.filter);
      final batches = await _productRepository.getBatches();
      final movements = await _productRepository.getStockMovements(limit: 50);

      emit(
        state.copyWith(
          loading: false,
          categories: categories,
          products: products,
          filteredProducts: products,
          batches: batches,
          stockMovements: movements,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> applyFilter({
    String? search,
    int? categoryId,
    bool? lowStockOnly,
    String? categoryName,
  }) async {
    final filter = state.filter.copyWith(
      search: search,
      categoryId: categoryId,
      lowStockOnly: lowStockOnly,
      clearCategory: categoryId == -1,
    );
    emit(
      state.copyWith(
        filter: filter,
        selectedCategoryFilter: categoryName,
        clearCategoryFilter: categoryId == -1,
      ),
    );
    await load();
  }

  Future<void> saveProduct(ProductUpsertInput input) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.upsertProduct(input);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> archiveProduct(int id, bool isActive) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.archiveProduct(id, isActive);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> deleteProduct(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.deleteProduct(id);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> saveCategory(String name) async {
    if (name.trim().isEmpty) return;
    await _productRepository.addCategory(name.trim());
    await load();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _productRepository.updateCategory(category);
    await load();
  }

  Future<void> deleteCategory(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.deleteCategory(id);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> adjustStock({
    required int productId,
    required int newQuantity,
    required String reason,
    int? batchId,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.adjustStock(
        productId: productId,
        newQuantity: newQuantity,
        reason: reason,
        batchId: batchId,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> writeOffStock({
    required int productId,
    required int quantity,
    required String reason,
    int? batchId,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.writeOffStock(
        productId: productId,
        quantity: quantity,
        reason: reason,
        batchId: batchId,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> inwardStock({
    required int productId,
    required int quantity,
    required double costPrice,
    String? batchNumber,
    DateTime? expiryDate,
    int? supplierId,
    String? notes,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.inwardStock(
        productId: productId,
        quantity: quantity,
        costPrice: costPrice,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        supplierId: supplierId,
        notes: notes,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> applyStockMovement(StockMovementInput input) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _productRepository.addStockMovement(input);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
