import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

enum CrmStageFilter { all, newStage, contacted, interested, siteVisit, negotiation, converted, lost }

class CrmState {
  const CrmState({
    this.leads = const [],
    this.siteVisits = const [],
    this.employees = const [],
    this.projects = const [],
    this.followUps = const [],
    this.overdueFollowUpsCount = 0,
    this.stageFilter = CrmStageFilter.all,
    this.sourceFilter = 'All',
    this.priorityFilter = 'All',
    this.searchQuery = '',
    this.selectedLeadId,
    this.selectedLeadActivities = const [],
    this.selectedLeadDocuments = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Lead> leads;
  final List<SiteVisit> siteVisits;
  final List<dynamic> employees;
  final List<Project> projects;
  final List<Map<String, dynamic>> followUps;
  final int overdueFollowUpsCount;
  final CrmStageFilter stageFilter;
  final String sourceFilter;
  final String priorityFilter;
  final String searchQuery;
  final int? selectedLeadId;
  final List<dynamic> selectedLeadActivities;
  final List<Map<String, dynamic>> selectedLeadDocuments;
  final bool isLoading;
  final String? errorMessage;

  CrmState copyWith({
    List<Lead>? leads,
    List<SiteVisit>? siteVisits,
    List<dynamic>? employees,
    List<Project>? projects,
    List<Map<String, dynamic>>? followUps,
    int? overdueFollowUpsCount,
    CrmStageFilter? stageFilter,
    String? sourceFilter,
    String? priorityFilter,
    String? searchQuery,
    int? selectedLeadId,
    List<dynamic>? selectedLeadActivities,
    List<Map<String, dynamic>>? selectedLeadDocuments,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return CrmState(
      leads: leads ?? this.leads,
      siteVisits: siteVisits ?? this.siteVisits,
      employees: employees ?? this.employees,
      projects: projects ?? this.projects,
      followUps: followUps ?? this.followUps,
      overdueFollowUpsCount: overdueFollowUpsCount ?? this.overdueFollowUpsCount,
      stageFilter: stageFilter ?? this.stageFilter,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLeadId: selectedLeadId ?? this.selectedLeadId,
      selectedLeadActivities: selectedLeadActivities ?? this.selectedLeadActivities,
      selectedLeadDocuments: selectedLeadDocuments ?? this.selectedLeadDocuments,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class CrmCubit extends Cubit<CrmState> {
  CrmCubit({
    required this.crmRepository,
    required this.employeeRepository,
    required this.plotRepository,
  }) : super(const CrmState());

  final CrmRepository crmRepository;
  final EmployeeRepository employeeRepository;
  final PlotRepository plotRepository;

  String? _mapFilterToDb(CrmStageFilter filter) {
    switch (filter) {
      case CrmStageFilter.all:
        return null;
      case CrmStageFilter.newStage:
        return 'new';
      case CrmStageFilter.contacted:
        return 'contacted';
      case CrmStageFilter.interested:
        return 'interested';
      case CrmStageFilter.siteVisit:
        return 'site_visit';
      case CrmStageFilter.negotiation:
        return 'negotiation';
      case CrmStageFilter.converted:
        return 'converted';
      case CrmStageFilter.lost:
        return 'lost';
    }
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      final stageStr = _mapFilterToDb(state.stageFilter);
      final sourceStr = state.sourceFilter == 'All' ? null : state.sourceFilter;
      final prioStr = state.priorityFilter == 'All' ? null : state.priorityFilter;

      final leadsRaw = await crmRepository.getLeads(
        stage: stageStr,
        source: sourceStr,
        priority: prioStr,
        query: state.searchQuery,
      );
      final leads = leadsRaw.cast<Lead>();

      final visitsRaw = await crmRepository.getSiteVisits();
      final visits = visitsRaw.cast<SiteVisit>();

      final followUps = await crmRepository.getFollowUps();
      final overdueCount = await crmRepository.getOverdueFollowUpsCount();

      final emps = await employeeRepository.getEmployees();
      final projsRaw = await plotRepository.getProjects();
      final projs = projsRaw.cast<Project>();

      List<dynamic> leadActivities = state.selectedLeadActivities;
      List<Map<String, dynamic>> leadDocs = state.selectedLeadDocuments;
      if (state.selectedLeadId != null) {
        leadActivities = await crmRepository.getLeadActivities(state.selectedLeadId!);
        leadDocs = await crmRepository.getDocuments(
          entityType: 'lead',
          entityId: state.selectedLeadId!,
        );
      }

      emit(state.copyWith(
        leads: leads,
        siteVisits: visits,
        followUps: followUps,
        overdueFollowUpsCount: overdueCount,
        employees: emps,
        projects: projs,
        selectedLeadActivities: leadActivities,
        selectedLeadDocuments: leadDocs,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: () => e.toString()));
    }
  }

  void filterStage(CrmStageFilter filter) {
    emit(state.copyWith(stageFilter: filter));
    load();
  }

  void filterSource(String source) {
    emit(state.copyWith(sourceFilter: source));
    load();
  }

  void filterPriority(String priority) {
    emit(state.copyWith(priorityFilter: priority));
    load();
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    load();
  }

  Future<dynamic> checkDuplicatePhone(String phone, {int? excludeId}) async {
    return crmRepository.checkDuplicateLead(phone: phone, excludeId: excludeId);
  }

  Future<void> saveLead({
    int? id,
    required String name,
    required String phone,
    String? alternatePhone,
    String? email,
    String? address,
    String? city,
    String? district,
    String source = 'Walk-in',
    String priority = 'medium',
    int? interestedProjectId,
    int? interestedPlotId,
    String? interestedPlotSize,
    double budget = 0.0,
    String? requirements,
    String stage = 'new',
    int? assignedEmployeeId,
    DateTime? nextFollowUpDate,
    String? notes,
  }) async {
    await crmRepository.saveLead(
      id: id,
      name: name,
      phone: phone,
      alternatePhone: alternatePhone,
      email: email,
      address: address,
      city: city,
      district: district,
      source: source,
      priority: priority,
      interestedProjectId: interestedProjectId,
      interestedPlotId: interestedPlotId,
      interestedPlotSize: interestedPlotSize,
      budget: budget,
      requirements: requirements,
      stage: stage,
      assignedEmployeeId: assignedEmployeeId,
      nextFollowUpDate: nextFollowUpDate,
      notes: notes,
    );
    await load();
  }

  Future<void> deleteLead(int leadId) async {
    await crmRepository.deleteLead(leadId);
    if (state.selectedLeadId == leadId) {
      emit(state.copyWith(selectedLeadId: null, selectedLeadActivities: [], selectedLeadDocuments: []));
    }
    await load();
  }

  Future<void> selectLead(int? leadId) async {
    if (leadId == null) {
      emit(state.copyWith(selectedLeadId: null, selectedLeadActivities: [], selectedLeadDocuments: []));
      return;
    }
    final activities = await crmRepository.getLeadActivities(leadId);
    final docs = await crmRepository.getDocuments(entityType: 'lead', entityId: leadId);
    emit(state.copyWith(
      selectedLeadId: leadId,
      selectedLeadActivities: activities,
      selectedLeadDocuments: docs,
    ));
  }

  Future<void> updateStage(int leadId, String stage) async {
    await crmRepository.updateLeadStage(leadId, stage);
    await load();
  }

  Future<void> logActivity({
    required int leadId,
    int? employeeId,
    required String activityType,
    required String notes,
  }) async {
    await crmRepository.logLeadActivity(
      leadId: leadId,
      employeeId: employeeId,
      activityType: activityType,
      notes: notes,
    );
    if (state.selectedLeadId == leadId) {
      final activities = await crmRepository.getLeadActivities(leadId);
      emit(state.copyWith(selectedLeadActivities: activities));
    }
    await load();
  }

  Future<void> createFollowUp({
    int? leadId,
    int? customerId,
    int? employeeId,
    required DateTime scheduledDate,
    String? remarks,
  }) async {
    await crmRepository.createFollowUp(
      leadId: leadId,
      customerId: customerId,
      employeeId: employeeId,
      scheduledDate: scheduledDate,
      remarks: remarks,
    );
    await load();
  }

  Future<void> updateFollowUpStatus(
    int followUpId,
    String status, {
    String? remarks,
    DateTime? rescheduleDate,
  }) async {
    await crmRepository.updateFollowUpStatus(
      followUpId,
      status,
      remarks: remarks,
      rescheduleDate: rescheduleDate,
    );
    await load();
  }

  Future<void> scheduleSiteVisit({
    required int leadId,
    int? projectId,
    int? plotId,
    required DateTime scheduledDate,
    int? conductedByEmployeeId,
    String? feedback,
  }) async {
    await crmRepository.scheduleSiteVisit(
      leadId: leadId,
      projectId: projectId,
      plotId: plotId,
      scheduledDate: scheduledDate,
      conductedByEmployeeId: conductedByEmployeeId,
      feedback: feedback,
    );
    await load();
  }

  Future<void> updateSiteVisitStatus(
    int visitId,
    String status, {
    String? feedback,
    DateTime? nextFollowUpDate,
  }) async {
    await crmRepository.updateSiteVisitStatus(
      visitId,
      status,
      feedback: feedback,
      nextFollowUpDate: nextFollowUpDate,
    );
    await load();
  }

  Future<Map<String, dynamic>> loadCustomerCrmProfile(int customerId) async {
    return crmRepository.getCustomerCrmProfile(customerId);
  }

  Future<int> convertToCustomer(int leadId) async {
    final customerId = await crmRepository.convertLeadToCustomer(leadId);
    await load();
    return customerId;
  }
}
