import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

enum DeliveryStatusFilter { all, pending, packed, dispatched, inTransit, delivered, failed }

class DeliveryState {
  const DeliveryState({
    this.deliveries = const [],
    this.sales = const [],
    this.customers = const [],
    this.products = const [],
    this.statusFilter = DeliveryStatusFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<DeliveryOrder> deliveries;
  final List<dynamic> sales;
  final List<dynamic> customers;
  final List<dynamic> products;
  final DeliveryStatusFilter statusFilter;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  DeliveryState copyWith({
    List<DeliveryOrder>? deliveries,
    List<dynamic>? sales,
    List<dynamic>? customers,
    List<dynamic>? products,
    DeliveryStatusFilter? statusFilter,
    String? searchQuery,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return DeliveryState(
      deliveries: deliveries ?? this.deliveries,
      sales: sales ?? this.sales,
      customers: customers ?? this.customers,
      products: products ?? this.products,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class DeliveryCubit extends Cubit<DeliveryState> {
  DeliveryCubit({
    required this.deliveryRepository,
    required this.salesRepository,
    required this.partyRepository,
    required this.productRepository,
  }) : super(const DeliveryState());

  final DeliveryRepository deliveryRepository;
  final SalesRepository salesRepository;
  final PartyRepository partyRepository;
  final ProductRepository productRepository;

  String? _mapFilterToDb(DeliveryStatusFilter filter) {
    switch (filter) {
      case DeliveryStatusFilter.all:
        return null;
      case DeliveryStatusFilter.pending:
        return 'pending';
      case DeliveryStatusFilter.packed:
        return 'packed';
      case DeliveryStatusFilter.dispatched:
        return 'dispatched';
      case DeliveryStatusFilter.inTransit:
        return 'in_transit';
      case DeliveryStatusFilter.delivered:
        return 'delivered';
      case DeliveryStatusFilter.failed:
        return 'failed';
    }
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      final statusStr = _mapFilterToDb(state.statusFilter);
      final deliveriesRaw = await deliveryRepository.getDeliveries(
        status: statusStr,
        query: state.searchQuery,
      );
      final deliveries = deliveriesRaw.cast<DeliveryOrder>();

      final sales = await salesRepository.getInvoices();
      final custs = await partyRepository.getCustomers();
      final prods = await productRepository.getProducts();

      emit(state.copyWith(
        deliveries: deliveries,
        sales: sales,
        customers: custs,
        products: prods,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  void filterStatus(DeliveryStatusFilter filter) {
    emit(state.copyWith(statusFilter: filter));
    load();
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    load();
  }

  Future<int> createDelivery({
    required String deliveryNumber,
    int? saleId,
    required int customerId,
    required String deliveryAddress,
    String? transporterName,
    String? vehicleNumber,
    String? trackingNumber,
    double shippingCharges = 0.0,
    DateTime? dispatchDate,
    DateTime? expectedDeliveryDate,
    String status = 'pending',
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final id = await deliveryRepository.createDelivery(
      deliveryNumber: deliveryNumber,
      saleId: saleId,
      customerId: customerId,
      deliveryAddress: deliveryAddress,
      transporterName: transporterName,
      vehicleNumber: vehicleNumber,
      trackingNumber: trackingNumber,
      shippingCharges: shippingCharges,
      dispatchDate: dispatchDate,
      expectedDeliveryDate: expectedDeliveryDate,
      status: status,
      notes: notes,
      items: items,
    );
    await load();
    return id;
  }

  Future<void> updateStatus({
    required int deliveryId,
    required String status,
    DateTime? deliveredDate,
    String? proofOfDelivery,
    String? notes,
  }) async {
    await deliveryRepository.updateDeliveryStatus(
      deliveryId: deliveryId,
      status: status,
      deliveredDate: deliveredDate,
      proofOfDelivery: proofOfDelivery,
      notes: notes,
    );
    await load();
  }
}
