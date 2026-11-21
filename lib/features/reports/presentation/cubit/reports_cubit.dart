import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/services/file_export_service.dart';
import '../../../../domain/entities/app_entities.dart';
import '../../../../domain/repositories/repositories.dart';

class ReportsState extends Equatable {
  const ReportsState({
    this.loading = false,
    this.error,
    this.dashboard = DashboardMetrics.empty,
    this.summary = ComprehensiveReportSummary.empty,
    this.invoices = const [],
    this.salesByProduct = const [],
    this.lowStockProducts = const [],
    this.gstRows = const [],
    this.trialBalanceRows = const [],
    this.purchaseRows = const [],
    this.inventoryRows = const [],
    this.hrSummary = HrReportSummary.empty,
    this.selectedTab = 0,
    this.from,
    this.to,
    this.lastExport,
  });

  final bool loading;
  final String? error;
  final DashboardMetrics dashboard;
  final ComprehensiveReportSummary summary;
  final List<SaleSummary> invoices;
  final List<SalesByProductMetric> salesByProduct;
  final List<ProductView> lowStockProducts;
  final List<GstReportRow> gstRows;
  final List<FinancialTrialBalanceRow> trialBalanceRows;
  final List<PurchaseReportRow> purchaseRows;
  final List<InventoryReportRow> inventoryRows;
  final HrReportSummary hrSummary;
  final int selectedTab;
  final DateTime? from;
  final DateTime? to;
  final File? lastExport;

  ReportsState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    DashboardMetrics? dashboard,
    ComprehensiveReportSummary? summary,
    List<SaleSummary>? invoices,
    List<SalesByProductMetric>? salesByProduct,
    List<ProductView>? lowStockProducts,
    List<GstReportRow>? gstRows,
    List<FinancialTrialBalanceRow>? trialBalanceRows,
    List<PurchaseReportRow>? purchaseRows,
    List<InventoryReportRow>? inventoryRows,
    HrReportSummary? hrSummary,
    int? selectedTab,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    File? lastExport,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      dashboard: dashboard ?? this.dashboard,
      summary: summary ?? this.summary,
      invoices: invoices ?? this.invoices,
      salesByProduct: salesByProduct ?? this.salesByProduct,
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      gstRows: gstRows ?? this.gstRows,
      trialBalanceRows: trialBalanceRows ?? this.trialBalanceRows,
      purchaseRows: purchaseRows ?? this.purchaseRows,
      inventoryRows: inventoryRows ?? this.inventoryRows,
      hrSummary: hrSummary ?? this.hrSummary,
      selectedTab: selectedTab ?? this.selectedTab,
      from: clearDates ? null : from ?? this.from,
      to: clearDates ? null : to ?? this.to,
      lastExport: lastExport ?? this.lastExport,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        dashboard,
        summary,
        invoices,
        salesByProduct,
        lowStockProducts,
        gstRows,
        trialBalanceRows,
        purchaseRows,
        inventoryRows,
        hrSummary,
        selectedTab,
        from,
        to,
        lastExport,
      ];
}

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit({
    required ReportsRepository reportsRepository,
    required SalesRepository salesRepository,
    required FileExportService exportService,
  })  : _reportsRepository = reportsRepository,
        _salesRepository = salesRepository,
        _exportService = exportService,
        super(const ReportsState());

  final ReportsRepository _reportsRepository;
  final SalesRepository _salesRepository;
  final FileExportService _exportService;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final dashboard = await _reportsRepository.getDashboardMetrics();
      final summary = await _reportsRepository.getComprehensiveSummary(
        from: state.from,
        to: state.to,
      );
      final salesByProduct =
          await _reportsRepository.salesByProduct(from: state.from, to: state.to);
      final lowStock = await _reportsRepository.lowStockProducts();
      final invoices = await _salesRepository.getInvoices(
        filter: InvoiceFilter(from: state.from, to: state.to),
      );
      final gstRows = await _reportsRepository.getGstReportRows(
        from: state.from,
        to: state.to,
      );
      final trialBalanceRows = await _reportsRepository.getFinancialTrialBalance(
        from: state.from,
        to: state.to,
      );
      final purchaseRows = await _reportsRepository.getPurchaseReportRows(
        from: state.from,
        to: state.to,
      );
      final inventoryRows = await _reportsRepository.inventoryReportRows();
      final hrSummary = await _reportsRepository.getHrReportSummary(
        month: state.from?.month,
        year: state.from?.year,
      );

      emit(
        state.copyWith(
          loading: false,
          dashboard: dashboard,
          summary: summary,
          invoices: invoices,
          salesByProduct: salesByProduct,
          lowStockProducts: lowStock,
          gstRows: gstRows,
          trialBalanceRows: trialBalanceRows,
          purchaseRows: purchaseRows,
          inventoryRows: inventoryRows,
          hrSummary: hrSummary,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void selectTab(int index) {
    emit(state.copyWith(selectedTab: index));
  }

  Future<void> setRange(DateTime? from, DateTime? to) async {
    emit(state.copyWith(from: from, to: to));
    await load();
  }

  Future<void> setPresetRange(String preset) async {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case '7days':
        start = now.subtract(const Duration(days: 7));
        end = now;
        break;
      case 'thisMonth':
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case 'all':
      default:
        start = null;
        end = null;
        break;
    }

    emit(state.copyWith(from: start, to: end, clearDates: start == null));
    await load();
  }

  Future<void> exportSalesCsv() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final rows = await _reportsRepository.salesReportRows(from: state.from, to: state.to);
      final file = await _exportService.exportSalesCsv(rows);
      await _exportService.shareFile(file);
      emit(state.copyWith(loading: false, lastExport: file));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> exportPurchasesCsv() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final file = await _exportService.exportPurchasesCsv(state.purchaseRows);
      await _exportService.shareFile(file);
      emit(state.copyWith(loading: false, lastExport: file));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> exportInventoryCsv() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final rows = await _reportsRepository.inventoryReportRows();
      final file = await _exportService.exportInventoryCsv(rows);
      await _exportService.shareFile(file);
      emit(state.copyWith(loading: false, lastExport: file));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> exportGstCsv() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final file = await _exportService.exportGstCsv(state.gstRows);
      await _exportService.shareFile(file);
      emit(state.copyWith(loading: false, lastExport: file));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> exportTrialBalanceCsv() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final file = await _exportService.exportTrialBalanceCsv(state.trialBalanceRows);
      await _exportService.shareFile(file);
      emit(state.copyWith(loading: false, lastExport: file));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> exportPdfReport({
    String businessName = 'Darvi Group Agri Tech',
    String gstin = '29BKZPA0053M1ZQ',
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final file = await _exportService.generateComprehensiveReportPdf(
        summary: state.summary,
        businessName: businessName,
        gstin: gstin,
        from: state.from,
        to: state.to,
      );
      await _exportService.shareFile(file);
      emit(state.copyWith(loading: false, lastExport: file));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> printPdfReport({
    String businessName = 'Darvi Group Agri Tech',
    String gstin = '29BKZPA0053M1ZQ',
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final file = await _exportService.generateComprehensiveReportPdf(
        summary: state.summary,
        businessName: businessName,
        gstin: gstin,
        from: state.from,
        to: state.to,
      );
      final bytes = await file.readAsBytes();
      await _exportService.printPdf(bytes);
      emit(state.copyWith(loading: false, lastExport: file));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
