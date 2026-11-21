import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

enum PlotStatusFilter { all, available, reserved, booked, sold }

class PlotState {
  const PlotState({
    this.projects = const [],
    this.plots = const [],
    this.selectedProject,
    this.projectSummaries = const {},
    this.statusFilter = PlotStatusFilter.all,
    this.facingFilter = 'All',
    this.searchQuery = '',
    this.selectedPlotHistory = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Project> projects;
  final List<Plot> plots;
  final Project? selectedProject;
  final Map<int, Map<String, dynamic>> projectSummaries;
  final PlotStatusFilter statusFilter;
  final String facingFilter;
  final String searchQuery;
  final List<Map<String, dynamic>> selectedPlotHistory;
  final bool isLoading;
  final String? errorMessage;

  PlotState copyWith({
    List<Project>? projects,
    List<Plot>? plots,
    Project? Function()? selectedProject,
    Map<int, Map<String, dynamic>>? projectSummaries,
    PlotStatusFilter? statusFilter,
    String? facingFilter,
    String? searchQuery,
    List<Map<String, dynamic>>? selectedPlotHistory,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return PlotState(
      projects: projects ?? this.projects,
      plots: plots ?? this.plots,
      selectedProject: selectedProject != null ? selectedProject() : this.selectedProject,
      projectSummaries: projectSummaries ?? this.projectSummaries,
      statusFilter: statusFilter ?? this.statusFilter,
      facingFilter: facingFilter ?? this.facingFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedPlotHistory: selectedPlotHistory ?? this.selectedPlotHistory,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class PlotCubit extends Cubit<PlotState> {
  PlotCubit(this.plotRepository) : super(const PlotState());

  final PlotRepository plotRepository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      final projectsRaw = await plotRepository.getProjects();
      final projects = projectsRaw.cast<Project>();

      final summaries = <int, Map<String, dynamic>>{};
      for (final p in projects) {
        summaries[p.id] = await plotRepository.getProjectSummary(p.id);
      }

      final statusStr = state.statusFilter == PlotStatusFilter.all ? null : state.statusFilter.name;
      final facingStr = state.facingFilter == 'All' ? null : state.facingFilter;

      final plotsRaw = await plotRepository.getPlots(
        projectId: state.selectedProject?.id,
        status: statusStr,
        facing: facingStr,
        query: state.searchQuery,
      );
      final plots = plotsRaw.cast<Plot>();

      emit(state.copyWith(
        projects: projects,
        plots: plots,
        projectSummaries: summaries,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  void selectProject(Project? project) {
    emit(state.copyWith(selectedProject: () => project));
    load();
  }

  void filterStatus(PlotStatusFilter filter) {
    emit(state.copyWith(statusFilter: filter));
    load();
  }

  void filterFacing(String facing) {
    emit(state.copyWith(facingFilter: facing));
    load();
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    load();
  }

  Future<List<Map<String, dynamic>>> loadPlotHistory(int plotId) async {
    final history = await plotRepository.getPlotHistory(plotId);
    emit(state.copyWith(selectedPlotHistory: history));
    return history;
  }

  Future<void> saveProject({
    int? id,
    required String name,
    required String code,
    required String location,
    double totalArea = 0.0,
    int totalPlots = 0,
    String? description,
    String? amenities,
    String? legalStatus,
    String? address,
    String? gpsCoordinates,
    String status = 'active',
  }) async {
    await plotRepository.saveProject(
      id: id,
      name: name,
      code: code,
      location: location,
      totalArea: totalArea,
      totalPlots: totalPlots,
      description: description,
      amenities: amenities,
      legalStatus: legalStatus,
      address: address,
      gpsCoordinates: gpsCoordinates,
      status: status,
    );
    await load();
  }

  Future<void> savePlot({
    int? id,
    required int projectId,
    required String plotNumber,
    required String uniquePlotId,
    required String dimensions,
    required double areaSqFt,
    String? surveyNumber,
    String? facing,
    double pricePerSqFt = 0.0,
    String status = 'available',
    required double basePrice,
    required double totalPrice,
    String? cropType,
    String? plantationDetails,
    String? imagePath,
    String? documentPath,
    String? notes,
  }) async {
    await plotRepository.savePlot(
      id: id,
      projectId: projectId,
      plotNumber: plotNumber,
      uniquePlotId: uniquePlotId,
      dimensions: dimensions,
      areaSqFt: areaSqFt,
      surveyNumber: surveyNumber,
      facing: facing,
      pricePerSqFt: pricePerSqFt,
      status: status,
      basePrice: basePrice,
      totalPrice: totalPrice,
      cropType: cropType,
      plantationDetails: plantationDetails,
      imagePath: imagePath,
      documentPath: documentPath,
      notes: notes,
    );
    await load();
  }

  Future<void> updateStatus(int plotId, String status) async {
    await plotRepository.updatePlotStatus(plotId, status);
    await load();
  }

  Future<void> deletePlot(int plotId) async {
    await plotRepository.deletePlot(plotId);
    await load();
  }
}

