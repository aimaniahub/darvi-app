import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/local/db/app_database.dart';
import '../cubit/delivery_cubit.dart';
import '../widgets/delivery_detail_sheet.dart';
import '../widgets/delivery_editor_dialog.dart';

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({super.key, this.preselectedSaleId});

  final int? preselectedSaleId;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (context) => DeliveryCubit(
        deliveryRepository: deps.deliveryRepository,
        salesRepository: deps.salesRepository,
        partyRepository: deps.partyRepository,
        productRepository: deps.productRepository,
      )..load(),
      child: _DeliveriesView(preselectedSaleId: preselectedSaleId),
    );
  }
}

class _DeliveriesView extends StatefulWidget {
  const _DeliveriesView({this.preselectedSaleId});

  final int? preselectedSaleId;

  @override
  State<_DeliveriesView> createState() => _DeliveriesViewState();
}

class _DeliveriesViewState extends State<_DeliveriesView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedSaleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDeliveryEditor(context);
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.grey;
      case 'packed':
        return Colors.indigo;
      case 'dispatched':
        return Colors.blue;
      case 'in_transit':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _openDeliveryEditor(BuildContext context) async {
    final cubit = context.read<DeliveryCubit>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => DeliveryEditorDialog(
        customers: cubit.state.customers,
        sales: cubit.state.sales,
        products: cubit.state.products,
        preselectedSaleId: widget.preselectedSaleId,
      ),
    );

    if (result != null) {
      await cubit.createDelivery(
        deliveryNumber: result['deliveryNumber'] as String,
        saleId: result['saleId'] as int?,
        customerId: result['customerId'] as int,
        deliveryAddress: result['deliveryAddress'] as String,
        transporterName: result['transporterName'] as String?,
        vehicleNumber: result['vehicleNumber'] as String?,
        trackingNumber: result['trackingNumber'] as String?,
        shippingCharges: result['shippingCharges'] as double,
        dispatchDate: result['dispatchDate'] as DateTime?,
        expectedDeliveryDate: result['expectedDeliveryDate'] as DateTime?,
        status: result['status'] as String,
        notes: result['notes'] as String?,
        items: (result['items'] as List).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery dispatch order created successfully!')),
        );
      }
    }
  }

  void _showDeliveryDetails(BuildContext context, DeliveryOrder delivery) {
    final cubit = context.read<DeliveryCubit>();
    final deps = AppScope.of(context);

    final customer = cubit.state.customers.where((c) => c.id == delivery.customerId).firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DeliveryDetailSheet(
        delivery: delivery,
        customer: customer,
        deliveryRepository: deps.deliveryRepository,
        onStatusChanged: (newStatus, proof) async {
          Navigator.of(ctx).pop();
          await cubit.updateStatus(
            deliveryId: delivery.id,
            status: newStatus,
            deliveredDate: newStatus == 'delivered' ? DateTime.now() : null,
            proofOfDelivery: proof,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delivery status updated to ${newStatus.replaceAll('_', ' ')}!')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Shipping & Deliveries',
        breadcrumbs: const ['Logistics'],
        subtitle: 'Order dispatches, shipping status & logistics tracking',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
            onPressed: () => context.read<DeliveryCubit>().load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(TablerIcons.send),
        label: const Text('Dispatch Order'),
        onPressed: () => _openDeliveryEditor(context),
      ),
      body: BlocConsumer<DeliveryCubit, DeliveryState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.deliveries.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingSkeleton(count: 6),
            );
          }

          if (state.errorMessage != null && state.deliveries.isEmpty) {
            return AppEmptyState(
              icon: TablerIcons.alertCircle,
              title: 'Unable to Load Deliveries',
              message: state.errorMessage!,
              action: AppButton.primary(
                label: 'Retry',
                icon: TablerIcons.refresh,
                onPressed: () => context.read<DeliveryCubit>().load(),
              ),
            );
          }

          final pendingPackingCount = state.deliveries
              .where((d) => d.status == 'pending' || d.status == 'packed')
              .length;
          final inTransitCount = state.deliveries
              .where((d) => d.status == 'dispatched' || d.status == 'in_transit')
              .length;
          final deliveredCount = state.deliveries
              .where((d) => d.status == 'delivered')
              .length;

          return Column(
            children: [
              // Responsive 2-Column KPI Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: AppStatGrid(
                  spacing: 8,
                  children: [
                    AppStatCard(
                      title: 'Total Shipments',
                      value: '${state.deliveries.length}',
                      subtitle: 'Recorded consignments',
                      icon: TablerIcons.truckDelivery,
                      accentColor: AppColors.primary,
                    ),
                    AppStatCard(
                      title: 'In Transit',
                      value: '$inTransitCount',
                      subtitle: 'Dispatched on road',
                      icon: TablerIcons.truck,
                      accentColor: AppColors.warning,
                      trendBadge: 'On Road',
                      trendPositive: true,
                    ),
                    AppStatCard(
                      title: 'Pending Packing',
                      value: '$pendingPackingCount',
                      subtitle: 'Warehouse dispatch due',
                      icon: TablerIcons.package,
                      accentColor: AppColors.error,
                      trendBadge: 'Packing',
                      trendPositive: false,
                    ),
                    AppStatCard(
                      title: 'Delivered',
                      value: '$deliveredCount',
                      subtitle: 'Completed fulfillment',
                      icon: TablerIcons.circleCheck,
                      accentColor: AppColors.leafAccent,
                    ),
                  ],
                ),
              ),

              // 1. Status Filter Segment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<DeliveryStatusFilter>(
                    segments: [
                      ButtonSegment(
                        value: DeliveryStatusFilter.all,
                        label: Text('All (${state.deliveries.length})'),
                      ),
                      const ButtonSegment(value: DeliveryStatusFilter.pending, label: Text('Pending')),
                      const ButtonSegment(value: DeliveryStatusFilter.packed, label: Text('Packed')),
                      const ButtonSegment(value: DeliveryStatusFilter.dispatched, label: Text('Dispatched')),
                      const ButtonSegment(value: DeliveryStatusFilter.inTransit, label: Text('In Transit')),
                      const ButtonSegment(value: DeliveryStatusFilter.delivered, label: Text('Delivered')),
                    ],
                    selected: {state.statusFilter},
                    onSelectionChanged: (set) {
                      context.read<DeliveryCubit>().filterStatus(set.first);
                    },
                  ),
                ),
              ),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search delivery #, address, transporter, tracking #...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<DeliveryCubit>().search('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => context.read<DeliveryCubit>().search(val),
                ),
              ),

              // 3. Deliveries List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.deliveries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No deliveries found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Dispatch Order'),
                                  onPressed: () => _openDeliveryEditor(context),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: state.deliveries.length,
                            itemBuilder: (context, index) {
                              final delivery = state.deliveries[index];
                              final statusColor = _statusColor(delivery.status);
                              final customer = state.customers.where((c) => c.id == delivery.customerId).firstOrNull;

                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showDeliveryDetails(context, delivery),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  delivery.deliveryNumber,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: statusColor),
                                                  ),
                                                  child: Text(
                                                    delivery.status.replaceAll('_', ' ').toUpperCase(),
                                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'To: ${customer?.name ?? "Customer #${delivery.customerId}"}',
                                              style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${delivery.transporterName ?? "Direct"} • ${delivery.trackingNumber ?? "No tracking"}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              delivery.expectedDeliveryDate != null
                                                  ? 'Exp: ${delivery.expectedDeliveryDate!.toLocal().toString().substring(5, 10)}'
                                                  : 'Active',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            const Icon(Icons.chevron_right, color: Colors.grey),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

