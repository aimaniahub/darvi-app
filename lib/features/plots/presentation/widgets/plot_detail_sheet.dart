import 'package:flutter/material.dart';

import '../../../../core/utils/money_calculator.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

class PlotDetailSheet extends StatelessWidget {
  const PlotDetailSheet({
    super.key,
    required this.plot,
    required this.project,
    required this.plotRepository,
    required this.onEdit,
    required this.onStatusChanged,
    this.onBookPlot,
    this.onCreateQuotation,
    this.onDelete,
  });

  final Plot plot;
  final Project? project;
  final PlotRepository plotRepository;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback? onBookPlot;
  final VoidCallback? onCreateQuotation;
  final VoidCallback? onDelete;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'reserved':
        return Colors.orange;
      case 'booked':
        return Colors.blue;
      case 'sold':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(plot.status);

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
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.landscape, color: statusColor, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plot.uniquePlotId,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${project?.name ?? "Vikshha Agro Farmland"} • Plot ${plot.plotNumber}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      plot.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Metrics Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Metric(label: 'Total Valuation', value: MoneyCalculator.formatCurrency(plot.totalPrice), isHighlight: true),
                          _Metric(label: 'Rate / Sq.Ft.', value: MoneyCalculator.formatCurrency(plot.basePrice)),
                          _Metric(label: 'Plot Area', value: '${plot.areaSqFt.toStringAsFixed(0)} Sq.Ft.'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Metric(label: 'Dimensions', value: plot.dimensions),
                          _Metric(label: 'Survey No.', value: plot.surveyNumber ?? 'N/A'),
                          _Metric(label: 'Location', value: project?.location ?? 'Hubli, KA'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Crop & Plantation Details
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.park, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Agro-Forestry & Plantation Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Crop Type: ${plot.cropType ?? "Sandalwood, Teak & Fruit Orchards"}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plot.plantationDetails ?? 'Equipped with centralized Netafim automated drip irrigation system.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      if (plot.notes != null && plot.notes!.isNotEmpty) ...[
                        const Divider(height: 20),
                        Text('Notes: ${plot.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Quick Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (plot.status == 'available' || plot.status == 'reserved') ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text('Book Plot'),
                      onPressed: onBookPlot,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Create Quotation'),
                      onPressed: onCreateQuotation,
                    ),
                  ],
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Details'),
                    onPressed: onEdit,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Change Status',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Status'),
                      onPressed: null,
                    ),
                    onSelected: onStatusChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'available', child: Text('Mark Available')),
                      PopupMenuItem(value: 'reserved', child: Text('Mark Reserved')),
                      PopupMenuItem(value: 'booked', child: Text('Mark Booked')),
                      PopupMenuItem(value: 'sold', child: Text('Mark Sold')),
                    ],
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete Plot',
                      onPressed: onDelete,
                    ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'Plot Activity & Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: plotRepository.getPlotHistory(plot.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  }
                  final history = snapshot.data ?? [];
                  if (history.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text('No previous booking or site-visit events logged for this plot.', style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  return Column(
                    children: history.map((h) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: h['type'] == 'booking' ? Colors.blue.shade100 : Colors.green.shade100,
                          child: Icon(
                            h['type'] == 'booking' ? Icons.book : Icons.directions_walk,
                            color: h['type'] == 'booking' ? Colors.blue : Colors.green,
                            size: 18,
                          ),
                        ),
                        title: Text(h['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(h['details'] as String),
                        trailing: Text(
                          (h['date'] as DateTime).toLocal().toString().substring(0, 10),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.isHighlight = false});

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 16 : 14,
            color: isHighlight ? Theme.of(context).primaryColor : null,
          ),
        ),
      ],
    );
  }
}

