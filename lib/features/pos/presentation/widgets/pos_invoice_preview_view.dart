import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/pos_cubit.dart';
import 'pos_thermal_receipt_preview.dart';

class PosInvoicePreviewView extends StatelessWidget {
  const PosInvoicePreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PosCubit>();

    return BlocConsumer<PosCubit, PosState>(
      listener: (context, state) {
        if (state.infoMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.infoMessage!), backgroundColor: const Color(0xFF135D44)),
          );
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        final lastResult = state.lastResult;
        final saleDetail = state.lastSaleDetail;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: lastResult?.invoiceNo != null
                ? 'Sale Completed: ${lastResult!.invoiceNo}'
                : 'Invoice Preview',
            breadcrumbs: const ['POS Billing'],
            subtitle: 'Ready for SSEZNIK2POS 58mm Thermal Printing & A4 Export',
            showBackButton: true,
            onBackPressed: () => cubit.setViewMode(PosViewMode.workspace),
            actions: [
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(TablerIcons.shoppingCartPlus, size: 18),
                label: const Text('New Sale'),
                onPressed: () => cubit.newSale(),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 850;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT: Thermal Receipt Simulator
                          Expanded(
                            flex: 5,
                            child: _buildReceiptPreviewPanel(context, cubit, state, saleDetail),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          // RIGHT: Printer Controls & Actions
                          Expanded(
                            flex: 4,
                            child: _buildPrintOperationsPanel(context, cubit, state),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildPrintOperationsPanel(context, cubit, state),
                          const SizedBox(height: AppSpacing.md),
                          _buildReceiptPreviewPanel(context, cubit, state, saleDetail),
                        ],
                      ),
              );
            },
          ),
          bottomNavigationBar: _buildBottomActions(context, cubit, state),
        );
      },
    );
  }

  Widget _buildReceiptPreviewPanel(
    BuildContext context,
    PosCubit cubit,
    PosState state,
    dynamic saleDetail,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.md,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Preview format toggle tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('58mm Thermal Receipt (SSEZNIK2POS)'),
                  selected: state.previewType == ReceiptPreviewType.thermal58mm,
                  onSelected: (_) => cubit.setPreviewType(ReceiptPreviewType.thermal58mm),
                ),
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('A4 Tax Invoice (PDF)'),
                  selected: state.previewType == ReceiptPreviewType.a4Pdf,
                  onSelected: (_) => cubit.setPreviewType(ReceiptPreviewType.a4Pdf),
                ),
              ],
            ),
            const Divider(height: 24),
            if (saleDetail != null)
              PosThermalReceiptPreview(
                saleDetail: saleDetail,
                cashierName: state.cashierName,
                customerName: state.selectedCustomer?.name,
              )
            else
              Container(
                height: 250,
                alignment: Alignment.center,
                child: const Text('Invoice details loaded'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOperationsPanel(BuildContext context, PosCubit cubit, PosState state) {
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
                const Icon(TablerIcons.printer, color: Color(0xFF135D44), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Printer & Dispatch Operations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Print Mode Selection
            const Text(
              'Connection & Print Transport:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  avatar: const Icon(TablerIcons.deviceLaptop, size: 16),
                  label: const Text('Clenter App'),
                  selected: state.printTransportMode == PrintTransportMode.clenterClient,
                  onSelected: (_) => cubit.setPrintTransportMode(PrintTransportMode.clenterClient),
                ),
                ChoiceChip(
                  avatar: const Icon(TablerIcons.printer, size: 16),
                  label: const Text('System Spooler'),
                  selected: state.printTransportMode == PrintTransportMode.systemSpooler,
                  onSelected: (_) => cubit.setPrintTransportMode(PrintTransportMode.systemSpooler),
                ),
                ChoiceChip(
                  avatar: const Icon(TablerIcons.bluetooth, size: 16),
                  label: const Text('Bluetooth Direct'),
                  selected: state.printTransportMode == PrintTransportMode.bluetoothDirect,
                  onSelected: (_) => cubit.setPrintTransportMode(PrintTransportMode.bluetoothDirect),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Live Connection Status Card
            if (state.printTransportMode == PrintTransportMode.clenterClient) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: state.isClenterConnected ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: AppRadii.sm,
                  border: Border.all(
                    color: state.isClenterConnected ? Colors.green.shade300 : Colors.amber.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          state.isClenterConnected ? TablerIcons.circleCheck : TablerIcons.alertTriangle,
                          color: state.isClenterConnected ? Colors.green.shade700 : Colors.amber.shade900,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.isClenterConnected
                                ? 'Clenter App Connected & Ready'
                                : 'Clenter not connected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: state.isClenterConnected ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(TablerIcons.refresh, size: 18),
                          tooltip: 'Check Clenter Connection',
                          onPressed: () => cubit.connectClenter(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isClenterConnected
                          ? 'Receipt will print via Clenter local thermal service.'
                          : 'Clenter not detected. Click below to reconnect or print smoothly via System Spooler.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.isClenterConnected ? const Color(0xFF135D44) : Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: const Icon(TablerIcons.refresh, size: 14),
                          label: Text(state.isClenterConnected ? 'Recheck' : 'Connect Clenter', style: const TextStyle(fontSize: 11)),
                          onPressed: () => cubit.connectClenter(),
                        ),
                        if (!state.isClenterConnected)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: const Icon(TablerIcons.printer, size: 14),
                            label: const Text('Use System Spooler', style: TextStyle(fontSize: 11)),
                            onPressed: () => cubit.setPrintTransportMode(PrintTransportMode.systemSpooler),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (state.printTransportMode == PrintTransportMode.systemSpooler) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: AppRadii.sm,
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(TablerIcons.circleCheck, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Print Spooler Ready',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF135D44)),
                          ),
                          Text(
                            'Universal printing to any connected printer or Android print service.',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Bluetooth Status Pill Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: state.isPrinterConnected ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: AppRadii.sm,
                  border: Border.all(
                    color: state.isPrinterConnected ? Colors.green.shade300 : Colors.amber.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          state.isPrinterConnected ? TablerIcons.circleCheck : TablerIcons.bluetooth,
                          color: state.isPrinterConnected ? Colors.green : Colors.amber.shade900,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.isPrinterConnected
                                ? 'Printer Connected: ${state.connectedPrinterName ?? "Thermal Printer"}'
                                : 'Bluetooth Printer Disconnected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: state.isPrinterConnected ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(TablerIcons.refresh, size: 20),
                          tooltip: 'Scan for Bluetooth Printers',
                          onPressed: () => cubit.refreshPrinters(),
                        ),
                      ],
                    ),
                    if (state.connectedPrinterAddress != null)
                      Text(
                        'Address: ${state.connectedPrinterAddress}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),

              if (!state.isPrinterConnected && state.pairedPrinters.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...state.pairedPrinters.take(2).map(
                      (dev) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(TablerIcons.bluetooth, size: 20),
                        title: Text(dev.name, style: const TextStyle(fontSize: 12)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                          child: const Text('Connect', style: TextStyle(fontSize: 11)),
                          onPressed: () => cubit.connectPrinter(dev),
                        ),
                      ),
                    ),
              ],
            ],

            const SizedBox(height: AppSpacing.md),

            // Diagnostic Self Test Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
              ),
              icon: const Icon(TablerIcons.checklist, size: 18),
              label: const Text('Print Diagnostic Test Ticket'),
              onPressed: state.receiptProcessing ? null : () => cubit.printDiagnosticTicket(),
            ),

            const Divider(height: 24),

            // Primary Print Action (Dispatches smoothly through selected transport)
            PrimaryButton(
              label: state.printTransportMode == PrintTransportMode.clenterClient
                  ? 'Print Receipt via Clenter'
                  : state.printTransportMode == PrintTransportMode.systemSpooler
                      ? 'Print Receipt via System Spooler'
                      : 'Print 58mm Thermal Receipt',
              icon: TablerIcons.printer,
              minHeight: 50,
              onPressed: state.receiptProcessing ? null : () => cubit.printReceiptSmooth(),
            ),

            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(TablerIcons.fileInvoice),
                    label: const Text('Print A4 PDF'),
                    onPressed: state.receiptProcessing ? null : () => cubit.printA4Pdf(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(TablerIcons.share),
                    label: const Text('Share PDF'),
                    onPressed: state.receiptProcessing ? null : () => cubit.shareLastReceipt(),
                  ),
                ),
              ],
            ),

            if (state.receiptProcessing) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, PosCubit cubit, PosState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(TablerIcons.history),
              label: const Text('View All Invoices'),
              onPressed: () => context.push('/invoices'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135D44),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
              ),
              icon: const Icon(TablerIcons.shoppingCartPlus),
              label: const Text(
                'Start New Sale',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () => cubit.newSale(),
            ),
          ],
        ),
      ),
    );
  }
}

