import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../core/state/app_cubit.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.cubit});

  final SettingsCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => cubit ?? (SettingsCubit(
        settingsRepository: deps.settingsRepository,
        authRepository: deps.authRepository,
        receiptPdfService: deps.receiptPdfService,
      )..load()),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isMobile = MediaQuery.of(context).size.width < 768;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: l10n.tr('settings'),
            subtitle: 'Store configuration, tax rates, users, roles & system backups',
            actions: [
              IconButton(
                onPressed: state.loading ? null : () => context.read<SettingsCubit>().load(),
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                tooltip: 'Refresh',
              ),
              IconButton(
                onPressed: () => context.read<AppCubit>().logout(),
                icon: const Icon(TablerIcons.logout, color: AppColors.error),
                tooltip: 'Logout',
              ),
            ],
          ),
          body: state.loading && state.backups.isEmpty && state.users.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: AppLoadingSkeleton(count: 6),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _SettingsSubTabs(
                      selectedTab: state.selectedTab,
                      onTabSelected: (idx) => context.read<SettingsCubit>().selectTab(idx),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    switch (state.selectedTab) {
                      0 => _BusinessProfileSection(state: state, isMobile: isMobile),
                      1 => _InvoiceAndSystemSection(state: state),
                      2 => _ThermalPrinterSection(state: state),
                      3 => _BackupAndRestoreSection(state: state, isMobile: isMobile),
                      4 => _AccessManagementSection(state: state, isMobile: isMobile),
                      5 => _PermissionMatrixAndAuditSection(state: state, isMobile: isMobile),
                      _ => const SizedBox.shrink(),
                    },
                  ],
                ),
        );
      },
    );
  }
}

class _SettingsSubTabs extends StatelessWidget {
  const _SettingsSubTabs({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final int selectedTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (0, 'Business Profile & Brand', AppIcons.bank),
      (1, 'Invoice & System Config', AppIcons.invoice),
      (2, 'SSEZNIK2POS 58mm Printer', AppIcons.print),
      (3, 'Backup & Restore', AppIcons.download),
      (4, 'Users & Access Control', AppIcons.userPlus),
      (5, 'Permission Matrix & Audit', AppIcons.receipt),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = selectedTab == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: Icon(
                t.$3,
                size: 16,
                color: isSelected ? AppColors.primary : Colors.grey.shade700,
              ),
              label: Text(
                t.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.grey.shade800,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primaryContainer.withValues(alpha: 0.4),
              onSelected: (_) => onTabSelected(t.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 0: BUSINESS PROFILE & BRAND
// ---------------------------------------------------------------------------
class _BusinessProfileSection extends StatefulWidget {
  const _BusinessProfileSection({required this.state, this.isMobile = false});

  final SettingsState state;
  final bool isMobile;

  @override
  State<_BusinessProfileSection> createState() => _BusinessProfileSectionState();
}

class _BusinessProfileSectionState extends State<_BusinessProfileSection> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _gstinCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _stateCodeCtrl;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.state.businessProfile;
    _nameCtrl = TextEditingController(text: p.businessName);
    _taglineCtrl = TextEditingController(text: p.businessSlogan);
    _gstinCtrl = TextEditingController(text: p.gstin);
    _addressCtrl = TextEditingController(text: p.address);
    _phoneCtrl = TextEditingController(text: p.phone);
    _emailCtrl = TextEditingController(text: p.email);
    _stateCtrl = TextEditingController(text: p.state);
    _stateCodeCtrl = TextEditingController(text: p.stateCode);
    _footerCtrl = TextEditingController(text: p.invoiceFooter);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _gstinCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _stateCtrl.dispose();
    _stateCodeCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: widget.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/darvi_logo.png',
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(AppIcons.bank, size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.state.businessProfile.businessName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.state.businessProfile.businessSlogan,
                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      AppBadge.success(label: 'GST: ${widget.state.businessProfile.gstin}'),
                    ],
                  )
                : Row(
                    children: [
                      Image.asset(
                        'assets/darvi_logo.png',
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(AppIcons.bank, size: 40, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.state.businessProfile.businessName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              widget.state.businessProfile.businessSlogan,
                              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      AppBadge.success(label: 'GST: ${widget.state.businessProfile.gstin}'),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Corporate Profile & Identity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: _nameCtrl, label: 'Company / Business Name'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: _taglineCtrl, label: 'Tagline / Slogan'),
                const SizedBox(height: AppSpacing.sm),
                if (widget.isMobile) ...[
                  AppTextField(controller: _gstinCtrl, label: 'GSTIN Registration'),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: _stateCodeCtrl, label: 'State Code'),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: _stateCtrl, label: 'State of Registration'),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: _phoneCtrl, label: 'Helpline / Phone'),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: AppTextField(controller: _gstinCtrl, label: 'GSTIN Registration')),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(width: 120, child: AppTextField(controller: _stateCodeCtrl, label: 'State Code')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: AppTextField(controller: _stateCtrl, label: 'State of Registration')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: AppTextField(controller: _phoneCtrl, label: 'Helpline / Phone')),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: _emailCtrl, label: 'Official Email'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: _addressCtrl, label: 'Registered Office Address', maxLines: 2),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: _footerCtrl, label: 'Receipt Footer Slogan / Notice', maxLines: 2),
                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  label: 'Save Business Profile',
                  icon: AppIcons.check,
                  loading: widget.state.loading,
                  onPressed: () {
                    final updated = widget.state.businessProfile.copyWith(
                      businessName: _nameCtrl.text.trim(),
                      businessSlogan: _taglineCtrl.text.trim(),
                      gstin: _gstinCtrl.text.trim(),
                      address: _addressCtrl.text.trim(),
                      phone: _phoneCtrl.text.trim(),
                      email: _emailCtrl.text.trim(),
                      state: _stateCtrl.text.trim(),
                      stateCode: _stateCodeCtrl.text.trim(),
                      invoiceFooter: _footerCtrl.text.trim(),
                    );
                    context.read<SettingsCubit>().updateBusinessProfile(updated);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: INVOICE & SYSTEM CONFIGURATION
// ---------------------------------------------------------------------------
class _InvoiceAndSystemSection extends StatefulWidget {
  const _InvoiceAndSystemSection({required this.state});

  final SettingsState state;

  @override
  State<_InvoiceAndSystemSection> createState() => _InvoiceAndSystemSectionState();
}

class _InvoiceAndSystemSectionState extends State<_InvoiceAndSystemSection> {
  late final TextEditingController _storeNameCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _taxRateCtrl;
  late final TextEditingController _prefixCtrl;
  late final TextEditingController _suffixCtrl;
  late final TextEditingController _termsCtrl;
  late bool _taxEnabled;
  late bool _allowNegative;
  late String _language;
  late String _roundOffMode;

  @override
  void initState() {
    super.initState();
    final s = widget.state.appSettings;
    final p = widget.state.businessProfile;
    _storeNameCtrl = TextEditingController(text: s.storeName);
    _currencyCtrl = TextEditingController(text: s.currency);
    _taxRateCtrl = TextEditingController(text: (s.taxRate * 100).toStringAsFixed(1));
    _prefixCtrl = TextEditingController(text: p.invoicePrefix);
    _suffixCtrl = TextEditingController(text: p.invoiceSuffix);
    _termsCtrl = TextEditingController(text: p.paymentTerms);
    _taxEnabled = s.taxEnabled;
    _allowNegative = s.allowNegativeStock;
    _language = s.language;
    _roundOffMode = p.roundOffMode;
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _currencyCtrl.dispose();
    _taxRateCtrl.dispose();
    _prefixCtrl.dispose();
    _suffixCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invoice, Taxation & POS Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _storeNameCtrl, label: 'Store Name (POS Header)'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: AppTextField(controller: _currencyCtrl, label: 'Currency Symbol / Code (₹, INR)')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AppTextField(controller: _taxRateCtrl, label: 'Default Tax Rate (%)', keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: AppTextField(controller: _prefixCtrl, label: 'Invoice Prefix (e.g. DARVI-)')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AppTextField(controller: _suffixCtrl, label: 'Invoice Suffix (Optional)')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(controller: _termsCtrl, label: 'Default Payment Terms (e.g. Immediate, 30 Days)'),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Automated Tax Calculations (GST)', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Calculate CGST, SGST, IGST on sales invoices and purchases'),
              value: _taxEnabled,
              onChanged: (val) => setState(() => _taxEnabled = val),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow Negative Inventory Stock', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Permit sales at checkout even if registered stock is 0'),
              value: _allowNegative,
              onChanged: (val) => setState(() => _allowNegative = val),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Language & Localization', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _language,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'kn', child: Text('Kannada')),
                          DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _language = v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invoice Round-off Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _roundOffMode,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('No Round-off (Exact decimals)')),
                          DropdownMenuItem(value: 'nearest_one', child: Text('Nearest ₹1 (Commercial)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _roundOffMode = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Save Invoice & System Preferences',
              icon: AppIcons.check,
              loading: widget.state.loading,
              onPressed: () {
                final ratePercent = double.tryParse(_taxRateCtrl.text.trim()) ?? 14.0;
                final updatedSettings = widget.state.appSettings.copyWith(
                  storeName: _storeNameCtrl.text.trim(),
                  currency: _currencyCtrl.text.trim(),
                  taxRate: ratePercent / 100.0,
                  taxEnabled: _taxEnabled,
                  allowNegativeStock: _allowNegative,
                  language: _language,
                );
                final updatedProfile = widget.state.businessProfile.copyWith(
                  invoicePrefix: _prefixCtrl.text.trim(),
                  invoiceSuffix: _suffixCtrl.text.trim(),
                  paymentTerms: _termsCtrl.text.trim(),
                  roundOffMode: _roundOffMode,
                );

                final cubit = context.read<SettingsCubit>();
                cubit.updateAppSettings(updatedSettings);
                cubit.updateBusinessProfile(updatedProfile);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: SSEZNIK2POS 58MM BLUETOOTH THERMAL PRINTER
// ---------------------------------------------------------------------------
class _ThermalPrinterSection extends StatelessWidget {
  const _ThermalPrinterSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final statusTone = switch (state.printerStatus) {
      BluetoothPrinterStatus.connected => AppBadgeTone.success,
      BluetoothPrinterStatus.connecting => AppBadgeTone.info,
      BluetoothPrinterStatus.error => AppBadgeTone.error,
      _ => AppBadgeTone.neutral,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(AppIcons.bluetooth, size: 28, color: Colors.blue),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SSEZNIK2POS Thermal Printer (58mm)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        state.connectedPrinterAddress != null
                            ? 'Connected to ${state.connectedPrinterAddress}'
                            : 'Bluetooth Classic SPP (UUID 00001101-0000-1000-8000-00805F9B34FB)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                AppBadge(
                  label: state.printerStatus.name.toUpperCase(),
                  tone: statusTone,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppButton.outlined(
              label: 'Scan / Discover Paired Devices',
              icon: AppIcons.refresh,
              loading: state.isScanningDevices,
              onPressed: () => context.read<SettingsCubit>().scanBluetoothPrinters(),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton.primary(
              label: 'Print ESC/POS Self-Test',
              icon: AppIcons.print,
              loading: state.loading,
              onPressed: () => context.read<SettingsCubit>().testPrint(),
            ),
            if (state.printerStatus == BluetoothPrinterStatus.connected) ...[
              const SizedBox(width: AppSpacing.sm),
              AppButton.outlined(
                label: 'Disconnect',
                onPressed: () => context.read<SettingsCubit>().disconnectPrinter(),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: Device listing
            Expanded(
              flex: 3,
              child: Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paired Bluetooth Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.sm),
                      if (state.pairedDevices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: AppEmptyState(
                            title: 'No Bluetooth paired devices found',
                            message: 'Ensure Bluetooth is ON and SSEZNIK2POS is paired in OS settings.',
                            icon: AppIcons.bluetooth,
                          ),
                        )
                      else
                        ...state.pairedDevices.map((d) {
                          final isConnected = state.connectedPrinterAddress == d.address;
                          return ListTile(
                            dense: true,
                            leading: const Icon(AppIcons.print),
                            title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(d.address),
                            trailing: isConnected
                                ? const AppBadge.success(label: 'CONNECTED')
                                : OutlinedButton(
                                    onPressed: () => context.read<SettingsCubit>().connectPrinter(d.address),
                                    child: const Text('Connect'),
                                  ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Right column: Live 58mm Receipt Preview
            Expanded(
              flex: 2,
              child: Card(
                color: const Color(0xFFFAFAFA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(AppIcons.receipt, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('58mm Thermal Receipt Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('DARVI GROUP AGRI TECH', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Hubli, Karnataka - 9986890777', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                            Text('GSTIN: 29BKZPA0053M1ZQ', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                            Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Inv: INV-20261108-001\nDate: 08 Nov 2026 14:30\nCashier: Staff Admin', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                            ),
                            Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('NPK 19-19-19 (50kg) x1', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                                Text('₹1,450.00', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Neem Oil Bio 1L x2', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                                Text('₹720.00', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                              ],
                            ),
                            Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal:', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                                Text('₹2,170.00', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('CGST (2.5%):', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                                Text('₹54.25', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('SGST (2.5%):', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                                Text('₹54.25', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5)),
                              ],
                            ),
                            Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('TOTAL:', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11)),
                                Text('₹2,170.00', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text('||| |||| || ||||| |||||||', style: TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 11)),
                            Text('INV-20261108-001', style: TextStyle(fontFamily: 'monospace', fontSize: 8)),
                            SizedBox(height: 6),
                            Text('Improving Agriculture, Improving lives.\nThank you! Visit again.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 8.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 3: BACKUP & DISASTER RECOVERY
// ---------------------------------------------------------------------------
class _BackupAndRestoreSection extends StatelessWidget {
  const _BackupAndRestoreSection({required this.state, required this.isMobile});

  final SettingsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(AppIcons.stock, size: 28, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Database Backup & Integrity Protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Exports complete Drift SQLite schema, products, inventory, accounts, and sales with SHA-256 validation.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                AppButton.primary(
                  label: 'Create Instant Backup',
                  icon: AppIcons.download,
                  loading: state.loading,
                  onPressed: () => context.read<SettingsCubit>().createBackup(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backup History & Safe Restores (${state.backups.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                if (state.backups.isEmpty)
                  const AppEmptyState(
                    title: 'No backup archives yet',
                    message: 'Click "Create Instant Backup" above to generate a secure recovery snapshot.',
                    icon: AppIcons.stock,
                  )
                else if (isMobile)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.backups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final b = state.backups[idx];
                      return ListTile(
                        dense: true,
                        title: Text(b.filename, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${AppFormatters.shortDate(b.createdAt)} • ${b.recordCount} records • ${(b.fileSize / 1024).toStringAsFixed(1)} KB'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(AppIcons.check, size: 18),
                              tooltip: 'Verify SHA-256',
                              onPressed: () => context.read<SettingsCubit>().validateBackup(b.filePath),
                            ),
                            IconButton(
                              icon: const Icon(AppIcons.share, size: 18),
                              tooltip: 'Share Backup File',
                              onPressed: () => context.read<SettingsCubit>().shareBackup(b.filePath),
                            ),
                            IconButton(
                              icon: const Icon(TablerIcons.rotateRectangle, color: Colors.red, size: 18),
                              tooltip: 'Restore Backup',
                              onPressed: () => _showRestoreConfirmDialog(context, b),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  AppDataTable<BackupRecord>(
                    minWidth: 700,
                    columns: [
                      AppDataColumn<BackupRecord>(
                        title: 'Filename',
                        cellBuilder: (ctx, b, idx) => Text(b.filename, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      AppDataColumn<BackupRecord>(
                        title: 'Created Date',
                        cellBuilder: (ctx, b, idx) => Text(AppFormatters.shortDate(b.createdAt)),
                      ),
                      AppDataColumn<BackupRecord>(
                        title: 'Records',
                        numeric: true,
                        cellBuilder: (ctx, b, idx) => Text('${b.recordCount} rows'),
                      ),
                      AppDataColumn<BackupRecord>(
                        title: 'File Size',
                        numeric: true,
                        cellBuilder: (ctx, b, idx) => Text('${(b.fileSize / 1024).toStringAsFixed(1)} KB'),
                      ),
                      AppDataColumn<BackupRecord>(
                        title: 'Integrity Status',
                        cellBuilder: (ctx, b, idx) => const AppBadge.success(label: 'SHA-256 OK'),
                      ),
                      AppDataColumn<BackupRecord>(
                        title: 'Actions',
                        cellBuilder: (ctx, b, idx) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => context.read<SettingsCubit>().validateBackup(b.filePath),
                              icon: const Icon(AppIcons.check, size: 14),
                              label: const Text('Verify'),
                            ),
                            TextButton.icon(
                              onPressed: () => context.read<SettingsCubit>().shareBackup(b.filePath),
                              icon: const Icon(AppIcons.share, size: 14),
                              label: const Text('Share'),
                            ),
                            TextButton.icon(
                              onPressed: () => _showRestoreConfirmDialog(context, b),
                              icon: const Icon(TablerIcons.rotateRectangle, color: Colors.red, size: 14),
                              label: const Text('Restore', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    items: state.backups,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRestoreConfirmDialog(BuildContext context, BackupRecord backup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(TablerIcons.alertTriangle, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Database Restore'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to restore from ${backup.filename}?'),
            const SizedBox(height: 8),
            const Text(
              'WARNING: This operation will overwrite current operational tables with snapshot records. Ensure you create a current backup before proceeding.',
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SettingsCubit>().restoreBackup(backup.filePath);
            },
            child: const Text('Proceed with Restore'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 4: USERS & ACCESS CONTROL (ACCESS MANAGEMENT)
// ---------------------------------------------------------------------------
class _AccessManagementSection extends StatelessWidget {
  const _AccessManagementSection({required this.state, required this.isMobile});

  final SettingsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                _RoleFilterChip(label: 'All Roles', isSelected: state.selectedUserRoleFilter == null, onTap: () => context.read<SettingsCubit>().filterUsers(roleFilter: '')),
                _RoleFilterChip(label: 'Admin', isSelected: state.selectedUserRoleFilter == 'admin', onTap: () => context.read<SettingsCubit>().filterUsers(roleFilter: 'admin')),
                _RoleFilterChip(label: 'Manager', isSelected: state.selectedUserRoleFilter == 'manager', onTap: () => context.read<SettingsCubit>().filterUsers(roleFilter: 'manager')),
                _RoleFilterChip(label: 'Cashier', isSelected: state.selectedUserRoleFilter == 'cashier', onTap: () => context.read<SettingsCubit>().filterUsers(roleFilter: 'cashier')),
                _RoleFilterChip(label: 'Field Officer', isSelected: state.selectedUserRoleFilter == 'field_officer', onTap: () => context.read<SettingsCubit>().filterUsers(roleFilter: 'field_officer')),
                _RoleFilterChip(label: 'Agronomist', isSelected: state.selectedUserRoleFilter == 'agronomist', onTap: () => context.read<SettingsCubit>().filterUsers(roleFilter: 'agronomist')),
              ],
            ),
            AppButton.primary(
              label: 'Add User',
              icon: AppIcons.add,
              onPressed: () => _showAddUserDialog(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Directory (${state.filteredUsers.length} staff accounts)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                if (state.filteredUsers.isEmpty)
                  const AppEmptyState(
                    title: 'No users found',
                    message: 'No users match the active role filter or search query.',
                    icon: AppIcons.user,
                  )
                else if (isMobile)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.filteredUsers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final u = state.filteredUsers[idx];
                      return ListTile(
                        dense: true,
                        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('@${u.username} • ${u.phone} • ${u.userRole.displayName}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch.adaptive(
                              value: u.isActive,
                              onChanged: (val) => context.read<SettingsCubit>().toggleUserActive(u.id, val),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _showEditUserDialog(context, u);
                                } else if (action == 'reset') {
                                  _showResetCredentialsDialog(context, u);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit User')),
                                const PopupMenuItem(value: 'reset', child: Text('Reset Password/PIN')),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  AppDataTable<UserModel>(
                    minWidth: 750,
                    columns: [
                      AppDataColumn<UserModel>(
                        title: 'Full Name',
                        cellBuilder: (ctx, u, idx) => Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      AppDataColumn<UserModel>(
                        title: 'Username',
                        cellBuilder: (ctx, u, idx) => Text('@${u.username}'),
                      ),
                      AppDataColumn<UserModel>(
                        title: 'Role',
                        cellBuilder: (ctx, u, idx) => AppBadge(
                          label: u.userRole.displayName,
                          tone: u.userRole == UserRole.admin ? AppBadgeTone.error : AppBadgeTone.info,
                        ),
                      ),
                      AppDataColumn<UserModel>(
                        title: 'Phone / Contact',
                        cellBuilder: (ctx, u, idx) => Text(u.phone),
                      ),
                      AppDataColumn<UserModel>(
                        title: 'Status',
                        cellBuilder: (ctx, u, idx) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppBadge(
                              label: u.isActive ? 'Active' : 'Disabled',
                              tone: u.isActive ? AppBadgeTone.success : AppBadgeTone.neutral,
                            ),
                            const SizedBox(width: 4),
                            Switch.adaptive(
                              value: u.isActive,
                              onChanged: (val) => context.read<SettingsCubit>().toggleUserActive(u.id, val),
                            ),
                          ],
                        ),
                      ),
                      AppDataColumn<UserModel>(
                        title: 'Actions',
                        cellBuilder: (ctx, u, idx) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showEditUserDialog(context, u),
                              icon: const Icon(AppIcons.edit, size: 14),
                              label: const Text('Edit'),
                            ),
                            TextButton.icon(
                              onPressed: () => _showResetCredentialsDialog(context, u),
                              icon: const Icon(AppIcons.clock, size: 14),
                              label: const Text('Reset PIN'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    items: state.filteredUsers,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    UserRole selectedRole = UserRole.cashier;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Add Staff User Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: nameCtrl, label: 'Full Name'),
                const SizedBox(height: 8),
                AppTextField(controller: usernameCtrl, label: 'Username (Unique)'),
                const SizedBox(height: 8),
                AppTextField(controller: phoneCtrl, label: 'Phone Number'),
                const SizedBox(height: 8),
                AppTextField(controller: emailCtrl, label: 'Email (Optional)'),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Assigned Role', border: OutlineInputBorder()),
                  items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.displayName))).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 8),
                AppTextField(controller: passwordCtrl, label: 'Password (For Admin/Web Login)', obscureText: true),
                const SizedBox(height: 8),
                AppTextField(controller: pinCtrl, label: '4-Digit POS Cashier PIN', keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || usernameCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogCtx);
                context.read<SettingsCubit>().createUser(
                  name: nameCtrl.text.trim(),
                  username: usernameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  role: selectedRole,
                  password: passwordCtrl.text.trim().isEmpty ? null : passwordCtrl.text.trim(),
                  pin: pinCtrl.text.trim().isEmpty ? null : pinCtrl.text.trim(),
                );
              },
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emailCtrl = TextEditingController(text: user.email ?? '');
    UserRole selectedRole = user.userRole;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('Edit User: @${user.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameCtrl, label: 'Full Name'),
              const SizedBox(height: 8),
              AppTextField(controller: phoneCtrl, label: 'Phone Number'),
              const SizedBox(height: 8),
              AppTextField(controller: emailCtrl, label: 'Email'),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Assigned Role', border: OutlineInputBorder()),
                items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.displayName))).toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                final updated = user.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  role: selectedRole.value,
                );
                context.read<SettingsCubit>().updateUser(user: updated);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetCredentialsDialog(BuildContext context, UserModel user) {
    final passwordCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Credentials: @${user.username}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: passwordCtrl, label: 'New Password (Optional)', obscureText: true),
            const SizedBox(height: 8),
            AppTextField(controller: pinCtrl, label: 'New 4-Digit PIN (Optional)', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SettingsCubit>().resetCredentials(
                id: user.id,
                newPassword: passwordCtrl.text.trim().isEmpty ? null : passwordCtrl.text.trim(),
                newPin: pinCtrl.text.trim().isEmpty ? null : pinCtrl.text.trim(),
              );
            },
            child: const Text('Update Credentials'),
          ),
        ],
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      onSelected: (_) => onTap(),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 5: PERMISSION MATRIX & AUDIT LOG
// ---------------------------------------------------------------------------
class _PermissionMatrixAndAuditSection extends StatelessWidget {
  const _PermissionMatrixAndAuditSection({required this.state, required this.isMobile});

  final SettingsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final modules = PermissionModule.values;
    final actions = PermissionAction.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Role-Based Access Control (RBAC) Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            children: UserRole.values.map((r) {
                              final isSel = state.selectedMatrixRole == r;
                              return ChoiceChip(
                                label: Text(r.displayName, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                selected: isSel,
                                selectedColor: AppColors.primaryContainer,
                                onSelected: (_) => context.read<SettingsCubit>().selectMatrixRole(r),
                              );
                            }).toList(),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('Role-Based Access Control (RBAC) Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          Wrap(
                            spacing: AppSpacing.xs,
                            children: UserRole.values.map((r) {
                              final isSel = state.selectedMatrixRole == r;
                              return ChoiceChip(
                                label: Text(r.displayName, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                selected: isSel,
                                selectedColor: AppColors.primaryContainer,
                                onSelected: (_) => context.read<SettingsCubit>().selectMatrixRole(r),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Green checkmarks denote sanctioned operations under Darvi security enforcement.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowColor: WidgetStateProperty.all(AppColors.primaryContainer.withValues(alpha: 0.3)),
                    columns: [
                      const DataColumn(label: Text('Module / System', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...actions.map((a) => DataColumn(label: Text(a.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                    ],
                    rows: modules.map((m) {
                      return DataRow(
                        cells: [
                          DataCell(Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w500))),
                          ...actions.map((a) {
                            final allowed = PermissionMatrix.can(state.selectedMatrixRole, m, a);
                            return DataCell(
                              Center(
                                child: allowed
                                    ? const Icon(AppIcons.check, color: Colors.green, size: 18)
                                    : const Icon(TablerIcons.x, color: Colors.grey, size: 16),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Activity & Security Audit Trail (${state.activityLogs.length} events)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                if (state.activityLogs.isEmpty)
                  const AppEmptyState(
                    title: 'No activity logs logged',
                    message: 'User authentication, settings changes, and backups will be logged here.',
                    icon: AppIcons.receipt,
                  )
                else if (isMobile)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.activityLogs.take(20).length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final l = state.activityLogs[idx];
                      return ListTile(
                        dense: true,
                        title: Text('${l.username} • ${l.action}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${l.details}\n${AppFormatters.shortDate(l.createdAt)}'),
                        trailing: AppBadge(label: l.module.toUpperCase(), tone: AppBadgeTone.info),
                      );
                    },
                  )
                else
                  AppDataTable<UserActivityLog>(
                    minWidth: 700,
                    columns: [
                      AppDataColumn<UserActivityLog>(
                        title: 'Timestamp',
                        cellBuilder: (ctx, l, idx) => Text(AppFormatters.shortDate(l.createdAt)),
                      ),
                      AppDataColumn<UserActivityLog>(
                        title: 'User',
                        cellBuilder: (ctx, l, idx) => Text(l.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      AppDataColumn<UserActivityLog>(
                        title: 'Module',
                        cellBuilder: (ctx, l, idx) => AppBadge(label: l.module.toUpperCase(), tone: AppBadgeTone.neutral),
                      ),
                      AppDataColumn<UserActivityLog>(
                        title: 'Action',
                        cellBuilder: (ctx, l, idx) => Text(l.action, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      AppDataColumn<UserActivityLog>(
                        title: 'Details',
                        cellBuilder: (ctx, l, idx) => Text(l.details),
                      ),
                    ],
                    items: state.activityLogs.take(30).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
