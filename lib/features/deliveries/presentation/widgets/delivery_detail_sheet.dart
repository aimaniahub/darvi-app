import 'package:flutter/material.dart';

import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

class DeliveryDetailSheet extends StatelessWidget {
  const DeliveryDetailSheet({
    super.key,
    required this.delivery,
    required this.customer,
    required this.deliveryRepository,
    required this.onStatusChanged,
  });

  final DeliveryOrder delivery;
  final dynamic customer;
  final DeliveryRepository deliveryRepository;
  final void Function(String status, String? proof) onStatusChanged;

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

  void _showMarkDeliveredDialog(BuildContext context) {
    final proofCtrl = TextEditingController(text: 'Received in good condition');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delivery & Proof of Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: proofCtrl,
              decoration: const InputDecoration(
                labelText: 'Proof of Delivery / Receiver Name & Phone',
                hintText: 'e.g. Received by Suresh Patil (9845012345)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onStatusChanged('delivered', proofCtrl.text.trim());
            },
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(delivery.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: statusColor.withOpacity(0.12),
                    child: Icon(Icons.local_shipping, color: statusColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(delivery.deliveryNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Recipient: ${customer?.name ?? "Customer #${delivery.customerId}"}', style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Address: ${delivery.deliveryAddress}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      delivery.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Transporter Card
              Card(
                elevation: 0,
                color: Theme.of(context).primaryColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Col(label: 'Transporter', value: delivery.transporterName ?? 'Standard Delivery'),
                          _Col(label: 'Vehicle #', value: delivery.vehicleNumber ?? 'N/A'),
                          _Col(label: 'Tracking / Docket #', value: delivery.trackingNumber ?? 'N/A'),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Col(label: 'Dispatched', value: delivery.dispatchDate != null ? delivery.dispatchDate!.toLocal().toString().substring(0, 10) : 'Pending'),
                          _Col(label: 'Expected Delivery', value: delivery.expectedDeliveryDate != null ? delivery.expectedDeliveryDate!.toLocal().toString().substring(0, 10) : 'TBD'),
                          _Col(label: 'Shipping Charges', value: '₹${delivery.shippingCharges.toStringAsFixed(0)}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (delivery.status != 'delivered')
                    FilledButton.icon(
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark as Delivered'),
                      onPressed: () => _showMarkDeliveredDialog(context),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Change Status',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Change Status'),
                      onPressed: null,
                    ),
                    onSelected: (val) => onStatusChanged(val, null),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'pending', child: Text('Pending')),
                      PopupMenuItem(value: 'packed', child: Text('Packed')),
                      PopupMenuItem(value: 'dispatched', child: Text('Dispatched')),
                      PopupMenuItem(value: 'in_transit', child: Text('In Transit')),
                      PopupMenuItem(value: 'delivered', child: Text('Delivered')),
                      PopupMenuItem(value: 'failed', child: Text('Failed')),
                    ],
                  ),
                ],
              ),

              if (delivery.proofOfDelivery != null && delivery.proofOfDelivery!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Proof of Delivery (Delivered)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 4),
                      Text(delivery.proofOfDelivery!, style: const TextStyle(fontSize: 12)),
                      if (delivery.deliveredDate != null)
                        Text('Delivered on: ${delivery.deliveredDate!.toLocal().toString().substring(0, 16)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text('Dispatched Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              FutureBuilder<List<dynamic>>(
                future: deliveryRepository.getDeliveryItems(delivery.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  }
                  final items = (snapshot.data ?? []).cast<DeliveryOrderItem>();
                  if (items.isEmpty) {
                    return const Text('No items logged in this delivery.', style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: items.map((itm) {
                      return ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.inventory_2, size: 14),
                        ),
                        title: Text('Product #${itm.productId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Text('${itm.quantity} ${itm.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Col extends StatelessWidget {
  const _Col({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
