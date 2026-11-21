import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../cubit/pos_cubit.dart';

class PosCustomerCard extends StatelessWidget {
  const PosCustomerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final cubit = context.read<PosCubit>();
        final customer = state.selectedCustomer;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.md,
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(TablerIcons.user, size: 20, color: Color(0xFF135D44)),
                    const SizedBox(width: 8),
                    const Text(
                      'Customer',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      icon: const Icon(TablerIcons.userPlus, size: 16),
                      label: const Text('Quick Add', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showQuickAddCustomerDialog(context, cubit),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Customer Selector Dropdown
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  value: state.selectedCustomerId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: AppRadii.sm),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Walk-in Customer (General Sale)'),
                    ),
                    ...state.customers.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(
                          '${c.name} • ${c.phone ?? "No phone"}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (id) => cubit.selectCustomer(id),
                ),

                // Customer Details & Credit Alert
                if (customer != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: customer.balance > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                      borderRadius: AppRadii.sm,
                      border: Border.all(
                        color: customer.balance > 0 ? Colors.amber.shade300 : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer.gstin != null && customer.gstin!.isNotEmpty)
                                Text(
                                  'GSTIN: ${customer.gstin}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                              Text(
                                'Current Outstanding: ${AppFormatters.money(customer.balance, currency: "INR")}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: customer.balance > 0 ? Colors.amber.shade900 : Colors.green.shade900,
                                ),
                              ),
                              if (customer.creditLimit > 0)
                                Text(
                                  'Credit Limit: ${AppFormatters.money(customer.creditLimit, currency: "INR")}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                            ],
                          ),
                        ),
                        if (state.isCustomerOverCredit)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: AppRadii.sm,
                            ),
                            child: const Text(
                              'OVER LIMIT',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickAddCustomerDialog(BuildContext context, PosCubit cubit) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final creditCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(TablerIcons.userPlus, color: Color(0xFF135D44)),
            SizedBox(width: 8),
            Text('Quick Register Customer'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: gstinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address / Village (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: creditCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit (₹) (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135D44),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Phone are required')),
                );
                return;
              }
              cubit.quickAddCustomer(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                gstin: gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                creditLimit: double.tryParse(creditCtrl.text.trim()) ?? 0.0,
              );
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save & Select'),
          ),
        ],
      ),
    );
  }
}

