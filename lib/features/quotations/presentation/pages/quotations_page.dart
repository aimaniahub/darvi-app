import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/money_calculator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/local/db/app_database.dart';
import '../cubit/quotation_cubit.dart';
import '../widgets/quotation_detail_sheet.dart';
import '../widgets/quotation_editor_dialog.dart';

class QuotationsPage extends StatelessWidget {
  const QuotationsPage({
    super.key,
    this.preselectedPlot,
    this.preselectedLead,
  });

  final Plot? preselectedPlot;
  final Lead? preselectedLead;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (context) => QuotationCubit(
        quotationRepository: deps.quotationRepository,
        partyRepository: deps.partyRepository,
        crmRepository: deps.crmRepository,
        productRepository: deps.productRepository,
        plotRepository: deps.plotRepository,
        accountRepository: deps.accountRepository,
      )..load(),
      child: _QuotationsView(preselectedPlot: preselectedPlot, preselectedLead: preselectedLead),
    );
  }
}

class _QuotationsView extends StatefulWidget {
  const _QuotationsView({this.preselectedPlot, this.preselectedLead});

  final Plot? preselectedPlot;
  final Lead? preselectedLead;

  @override
  State<_QuotationsView> createState() => _QuotationsViewState();
}

class _QuotationsViewState extends State<_QuotationsView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPlot != null || widget.preselectedLead != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openQuotationEditor(context);
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'converted':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _openQuotationEditor(BuildContext context) async {
    final cubit = context.read<QuotationCubit>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => QuotationEditorDialog(
        customers: cubit.state.customers,
        leads: cubit.state.leads,
        products: cubit.state.products,
        plots: cubit.state.plots,
        preselectedPlot: widget.preselectedPlot,
        preselectedLead: widget.preselectedLead,
      ),
    );

    if (result != null) {
      await cubit.createQuotation(
        quotationNumber: result['quotationNumber'] as String,
        customerId: result['customerId'] as int?,
        leadId: result['leadId'] as int?,
        customerName: result['customerName'] as String,
        customerPhone: result['customerPhone'] as String,
        validUntil: result['validUntil'] as DateTime,
        subtotal: result['subtotal'] as double,
        discountTotal: result['discountTotal'] as double,
        taxTotal: result['taxTotal'] as double,
        cgstTotal: result['cgstTotal'] as double,
        sgstTotal: result['sgstTotal'] as double,
        igstTotal: result['igstTotal'] as double,
        totalAmount: result['totalAmount'] as double,
        status: result['status'] as String,
        terms: result['terms'] as String?,
        notes: result['notes'] as String?,
        items: (result['items'] as List).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation generated successfully!')),
        );
      }
    }
  }

  void _showQuotationDetails(BuildContext context, Quotation quotation) {
    final cubit = context.read<QuotationCubit>();
    final deps = AppScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => QuotationDetailSheet(
        quotation: quotation,
        quotationRepository: deps.quotationRepository,
        accounts: cubit.state.accounts,
        onStatusChanged: (newStatus) {
          Navigator.of(ctx).pop();
          cubit.updateStatus(quotation.id, newStatus);
        },
        onConvertedToSale: (accountId, paymentMode) async {
          Navigator.of(ctx).pop();
          final saleId = await cubit.convertToSale(
            quotationId: quotation.id,
            accountId: accountId,
            paymentMode: paymentMode,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Converted to Sales Invoice #$saleId!')),
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
        title: 'Farmland Quotations',
        breadcrumbs: const ['Vikshha Farmlands'],
        subtitle: 'Price estimates, installment plans & quotation proposals',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
            onPressed: () => context.read<QuotationCubit>().load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(TablerIcons.filePlus),
        label: const Text('New Quotation'),
        onPressed: () => _openQuotationEditor(context),
      ),
      body: BlocConsumer<QuotationCubit, QuotationState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.quotations.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingSkeleton(count: 6),
            );
          }

          if (state.errorMessage != null && state.quotations.isEmpty) {
            return AppEmptyState(
              icon: TablerIcons.alertCircle,
              title: 'Unable to Load Quotations',
              message: state.errorMessage!,
              action: AppButton.primary(
                label: 'Retry',
                icon: TablerIcons.refresh,
                onPressed: () => context.read<QuotationCubit>().load(),
              ),
            );
          }

          final pendingCount = state.quotations
              .where((q) => q.status.toLowerCase() == 'sent' || q.status.toLowerCase() == 'draft')
              .length;
          final acceptedCount = state.quotations
              .where((q) => q.status.toLowerCase() == 'accepted')
              .length;
          final convertedCount = state.quotations
              .where((q) => q.status.toLowerCase() == 'converted')
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
                      title: 'Total Quotations',
                      value: '${state.quotations.length}',
                      subtitle: 'Estimates generated',
                      icon: TablerIcons.fileInvoice,
                      accentColor: AppColors.primary,
                    ),
                    AppStatCard(
                      title: 'Pending Review',
                      value: '$pendingCount',
                      subtitle: 'Draft / sent to client',
                      icon: TablerIcons.clock,
                      accentColor: AppColors.warning,
                      trendBadge: 'Pending',
                      trendPositive: true,
                    ),
                    AppStatCard(
                      title: 'Accepted Quotes',
                      value: '$acceptedCount',
                      subtitle: 'Approved by investor',
                      icon: TablerIcons.circleCheck,
                      accentColor: AppColors.leafAccent,
                    ),
                    AppStatCard(
                      title: 'Converted to Sale',
                      value: '$convertedCount',
                      subtitle: 'Tax invoices billed',
                      icon: TablerIcons.receipt,
                      accentColor: AppColors.success,
                      trendBadge: 'Billed',
                      trendPositive: true,
                    ),
                  ],
                ),
              ),

              // 1. Status Segmented Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<QuotationStatusFilter>(
                    segments: [
                      ButtonSegment(
                        value: QuotationStatusFilter.all,
                        label: Text('All (${state.quotations.length})'),
                      ),
                      const ButtonSegment(value: QuotationStatusFilter.draft, label: Text('Draft')),
                      const ButtonSegment(value: QuotationStatusFilter.sent, label: Text('Sent')),
                      const ButtonSegment(value: QuotationStatusFilter.accepted, label: Text('Accepted')),
                      const ButtonSegment(value: QuotationStatusFilter.rejected, label: Text('Rejected')),
                      const ButtonSegment(value: QuotationStatusFilter.converted, label: Text('Converted')),
                    ],
                    selected: {state.statusFilter},
                    onSelectionChanged: (set) {
                      context.read<QuotationCubit>().filterStatus(set.first);
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
                    hintText: 'Search quotation #, client name, phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<QuotationCubit>().search('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => context.read<QuotationCubit>().search(val),
                ),
              ),

              // 3. Quotations List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.quotations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.request_quote_outlined, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No quotations found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Quotation'),
                                  onPressed: () => _openQuotationEditor(context),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: state.quotations.length,
                            itemBuilder: (context, index) {
                              final quote = state.quotations[index];
                              final statusColor = _statusColor(quote.status);

                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showQuotationDetails(context, quote),
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
                                                  quote.quotationNumber,
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
                                                    quote.status.toUpperCase(),
                                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${quote.customerName} (${quote.customerPhone})',
                                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Valid until: ${quote.validUntil.toLocal().toString().substring(0, 10)}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              MoneyCalculator.formatCurrency(quote.totalAmount),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).primaryColor,
                                              ),
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

