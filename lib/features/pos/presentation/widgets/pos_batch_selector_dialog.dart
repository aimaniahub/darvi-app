import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/app_entities.dart';

class PosBatchSelectorDialog extends StatelessWidget {
  const PosBatchSelectorDialog({
    super.key,
    required this.product,
    required this.batches,
    required this.onBatchSelected,
  });

  final ProductView product;
  final List<ProductBatchView> batches;
  final void Function(ProductBatchView batch) onBatchSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lg),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Color(0xFF135D44), size: 24),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Batch: ${product.name}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'SKU: ${product.sku} • Active Batches Available: ${batches.length}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            if (batches.isEmpty)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: Text(
                  'No specific batches registered. Product will be deducted from general stock.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: batches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final isExpiringSoon = batch.expiryDate != null &&
                        batch.expiryDate!.difference(DateTime.now()).inDays <= 60;
                    final isExpired = batch.expiryDate != null &&
                        batch.expiryDate!.isBefore(DateTime.now());

                    return InkWell(
                      borderRadius: AppRadii.md,
                      onTap: () {
                        onBatchSelected(batch);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? Colors.red.shade50
                              : (isExpiringSoon ? Colors.amber.shade50 : Colors.grey.shade50),
                          borderRadius: AppRadii.md,
                          border: Border.all(
                            color: isExpired
                                ? Colors.red.shade300
                                : (isExpiringSoon ? Colors.amber.shade300 : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Batch: ${batch.batchNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isExpired)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: AppRadii.sm,
                                        ),
                                        child: const Text(
                                          'EXPIRED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else if (isExpiringSoon)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade800,
                                          borderRadius: AppRadii.sm,
                                        ),
                                        child: const Text(
                                          'EXPIRING SOON',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Expiry: ${batch.expiryDate != null ? "${batch.expiryDate!.day}/${batch.expiryDate!.month}/${batch.expiryDate!.year}" : "N/A"} • Avail Qty: ${batch.quantity}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppFormatters.money(batch.sellingPrice > 0 ? batch.sellingPrice : product.price, currency: "INR"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF135D44),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Select >',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF135D44),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

