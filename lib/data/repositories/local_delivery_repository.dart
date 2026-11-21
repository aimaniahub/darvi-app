import 'package:drift/drift.dart';

import '../../domain/repositories/repositories.dart';
import '../local/db/app_database.dart';

class LocalDeliveryRepository implements DeliveryRepository {
  const LocalDeliveryRepository(this.db);

  final AppDatabase db;

  @override
  Future<List<DeliveryOrder>> getDeliveries({
    int workspaceId = 1,
    String? status,
    String? query,
  }) async {
    final q = db.select(db.deliveryOrders)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      q.where((tbl) => tbl.status.equals(status.toLowerCase()));
    }

    final rows = await q.get();

    if (query != null && query.trim().isNotEmpty) {
      final clean = query.trim().toLowerCase();
      return rows.where((d) {
        final matchesNumber = d.deliveryNumber.toLowerCase().contains(clean);
        final matchesAddress = d.deliveryAddress.toLowerCase().contains(clean);
        final matchesTransporter = d.transporterName?.toLowerCase().contains(clean) ?? false;
        final matchesVehicle = d.vehicleNumber?.toLowerCase().contains(clean) ?? false;
        final matchesTracking = d.trackingNumber?.toLowerCase().contains(clean) ?? false;
        return matchesNumber || matchesAddress || matchesTransporter || matchesVehicle || matchesTracking;
      }).toList();
    }

    return rows;
  }

  @override
  Future<DeliveryOrder?> getDeliveryById(int deliveryId) async {
    final query = db.select(db.deliveryOrders)..where((tbl) => tbl.id.equals(deliveryId));
    return query.getSingleOrNull();
  }

  @override
  Future<List<DeliveryOrderItem>> getDeliveryItems(int deliveryId) async {
    final query = db.select(db.deliveryOrderItems)..where((tbl) => tbl.deliveryOrderId.equals(deliveryId));
    return query.get();
  }

  @override
  Future<int> createDelivery({
    int workspaceId = 1,
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
    return db.transaction(() async {
      final now = DateTime.now();
      final dId = await db.into(db.deliveryOrders).insert(
            DeliveryOrdersCompanion.insert(
              workspaceId: workspaceId,
              deliveryNumber: deliveryNumber,
              saleId: Value(saleId),
              customerId: customerId,
              deliveryAddress: deliveryAddress,
              transporterName: Value(transporterName),
              vehicleNumber: Value(vehicleNumber),
              trackingNumber: Value(trackingNumber),
              shippingCharges: Value(shippingCharges),
              dispatchDate: Value(dispatchDate),
              expectedDeliveryDate: Value(expectedDeliveryDate),
              status: Value(status),
              notes: Value(notes),
              createdAt: Value(now),
            ),
          );

      for (final item in items) {
        await db.into(db.deliveryOrderItems).insert(
              DeliveryOrderItemsCompanion.insert(
                deliveryOrderId: dId,
                productId: item['productId'] as int,
                quantity: (item['quantity'] as num).toInt(),
                unit: Value(item['unit'] as String? ?? 'piece'),
              ),
            );
      }

      return dId;
    });
  }

  @override
  Future<void> updateDeliveryStatus({
    required int deliveryId,
    required String status,
    DateTime? deliveredDate,
    String? proofOfDelivery,
    String? notes,
  }) async {
    await (db.update(db.deliveryOrders)..where((tbl) => tbl.id.equals(deliveryId))).write(
      DeliveryOrdersCompanion(
        status: Value(status),
        deliveredDate: deliveredDate != null ? Value(deliveredDate) : const Value.absent(),
        proofOfDelivery: proofOfDelivery != null ? Value(proofOfDelivery) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
      ),
    );
  }
}

