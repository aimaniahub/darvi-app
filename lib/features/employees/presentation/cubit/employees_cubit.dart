import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../domain/repositories/repositories.dart';

class EmployeesState extends Equatable {
  const EmployeesState({
    this.loading = false,
    this.error,
    this.employees = const [],
    this.shifts = const [],
    this.todayAttendance = const [],
    this.monthlySummaries = const [],
    this.leaves = const [],
    this.holidays = const [],
    this.payrollRecords = const [],
    this.salesTargets = const [],
    this.incentiveRules = const [],
    this.incentiveClaims = const [],
    this.selectedTab = 0, // 0 = Directory/Dashboard, 1 = Attendance/Shifts, 2 = Payroll, 3 = Incentives
    this.searchQuery = '',
    this.selectedRoleFilter,
    this.selectedDepartmentFilter,
    this.activeOnlyFilter = false,
    required this.selectedMonth,
    required this.selectedYear,
    this.selectedEmployee,
    this.attributedSales,
  });

  final bool loading;
  final String? error;
  final List<EmployeeModel> employees;
  final List<ShiftModel> shifts;
  final List<AttendanceModel> todayAttendance;
  final List<AttendanceSummaryModel> monthlySummaries;
  final List<LeaveRequestModel> leaves;
  final List<HolidayModel> holidays;
  final List<PayrollRecordModel> payrollRecords;
  final List<SalesTargetModel> salesTargets;
  final List<IncentiveRuleModel> incentiveRules;
  final List<IncentiveClaimModel> incentiveClaims;
  final int selectedTab;
  final String searchQuery;
  final String? selectedRoleFilter;
  final String? selectedDepartmentFilter;
  final bool activeOnlyFilter;
  final int selectedMonth;
  final int selectedYear;
  final EmployeeModel? selectedEmployee;
  final Map<String, dynamic>? attributedSales;

  List<EmployeeModel> get filteredEmployees {
    return employees.where((e) {
      if (activeOnlyFilter && !e.isActive) return false;
      if (selectedRoleFilter != null && selectedRoleFilter!.isNotEmpty && e.role != selectedRoleFilter) {
        return false;
      }
      if (selectedDepartmentFilter != null && selectedDepartmentFilter!.isNotEmpty && e.department != selectedDepartmentFilter) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = e.name.toLowerCase().contains(q);
        final matchCode = e.employeeCode.toLowerCase().contains(q);
        final matchPhone = e.phone.toLowerCase().contains(q);
        final matchDesignation = e.designation.toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchPhone && !matchDesignation) return false;
      }
      return true;
    }).toList();
  }

  EmployeesState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<EmployeeModel>? employees,
    List<ShiftModel>? shifts,
    List<AttendanceModel>? todayAttendance,
    List<AttendanceSummaryModel>? monthlySummaries,
    List<LeaveRequestModel>? leaves,
    List<HolidayModel>? holidays,
    List<PayrollRecordModel>? payrollRecords,
    List<SalesTargetModel>? salesTargets,
    List<IncentiveRuleModel>? incentiveRules,
    List<IncentiveClaimModel>? incentiveClaims,
    int? selectedTab,
    String? searchQuery,
    String? selectedRoleFilter,
    bool clearRoleFilter = false,
    String? selectedDepartmentFilter,
    bool clearDepartmentFilter = false,
    bool? activeOnlyFilter,
    int? selectedMonth,
    int? selectedYear,
    EmployeeModel? selectedEmployee,
    bool clearSelectedEmployee = false,
    Map<String, dynamic>? attributedSales,
  }) {
    return EmployeesState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      employees: employees ?? this.employees,
      shifts: shifts ?? this.shifts,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      monthlySummaries: monthlySummaries ?? this.monthlySummaries,
      leaves: leaves ?? this.leaves,
      holidays: holidays ?? this.holidays,
      payrollRecords: payrollRecords ?? this.payrollRecords,
      salesTargets: salesTargets ?? this.salesTargets,
      incentiveRules: incentiveRules ?? this.incentiveRules,
      incentiveClaims: incentiveClaims ?? this.incentiveClaims,
      selectedTab: selectedTab ?? this.selectedTab,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRoleFilter: clearRoleFilter ? null : selectedRoleFilter ?? this.selectedRoleFilter,
      selectedDepartmentFilter: clearDepartmentFilter ? null : selectedDepartmentFilter ?? this.selectedDepartmentFilter,
      activeOnlyFilter: activeOnlyFilter ?? this.activeOnlyFilter,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedEmployee: clearSelectedEmployee ? null : selectedEmployee ?? this.selectedEmployee,
      attributedSales: attributedSales ?? this.attributedSales,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        employees,
        shifts,
        todayAttendance,
        monthlySummaries,
        leaves,
        holidays,
        payrollRecords,
        salesTargets,
        incentiveRules,
        incentiveClaims,
        selectedTab,
        searchQuery,
        selectedRoleFilter,
        selectedDepartmentFilter,
        activeOnlyFilter,
        selectedMonth,
        selectedYear,
        selectedEmployee,
        attributedSales,
      ];
}

class EmployeesCubit extends Cubit<EmployeesState> {
  EmployeesCubit({required EmployeeRepository employeeRepository})
      : _employeeRepository = employeeRepository,
        super(EmployeesState(
          selectedMonth: DateTime.now().month,
          selectedYear: DateTime.now().year,
        ));

  final EmployeeRepository _employeeRepository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final emps = await _employeeRepository.getEmployees(activeOnly: false);
      final shifts = await _employeeRepository.getShifts();
      final att = await _employeeRepository.getAttendance(date: DateTime.now());
      final summaries = await _employeeRepository.getMonthlyAttendanceSummary(
        month: state.selectedMonth,
        year: state.selectedYear,
      );
      final leaves = await _employeeRepository.getLeaves();
      final holidays = await _employeeRepository.getHolidays();
      final payroll = await _employeeRepository.getPayrollRecords(month: state.selectedMonth, year: state.selectedYear);
      final targets = await _employeeRepository.getSalesTargets();
      final rules = await _employeeRepository.getIncentiveRules();
      final claims = await _employeeRepository.getIncentiveClaims();

      emit(state.copyWith(
        loading: false,
        employees: emps,
        shifts: shifts,
        todayAttendance: att,
        monthlySummaries: summaries,
        leaves: leaves,
        holidays: holidays,
        payrollRecords: payroll,
        salesTargets: targets,
        incentiveRules: rules,
        incentiveClaims: claims,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void setTab(int idx) => emit(state.copyWith(selectedTab: idx));

  void setSearch(String query) => emit(state.copyWith(searchQuery: query));

  void setRoleFilter(String? role) {
    if (role == null || role.isEmpty) {
      emit(state.copyWith(clearRoleFilter: true));
    } else {
      emit(state.copyWith(selectedRoleFilter: role));
    }
  }

  void setDepartmentFilter(String? dept) {
    if (dept == null || dept.isEmpty) {
      emit(state.copyWith(clearDepartmentFilter: true));
    } else {
      emit(state.copyWith(selectedDepartmentFilter: dept));
    }
  }

  void setActiveFilter(bool activeOnly) => emit(state.copyWith(activeOnlyFilter: activeOnly));

  void setMonthYear(int month, int year) {
    emit(state.copyWith(selectedMonth: month, selectedYear: year));
    load();
  }

  void selectEmployee(EmployeeModel? emp) {
    emit(state.copyWith(selectedEmployee: emp, clearSelectedEmployee: emp == null));
    if (emp != null) {
      calculateAttributedSalesForEmployee(emp.id);
    }
  }

  Future<void> calculateAttributedSalesForEmployee(int employeeId) async {
    final start = DateTime(state.selectedYear, state.selectedMonth, 1);
    final end = DateTime(state.selectedYear, state.selectedMonth + 1, 0, 23, 59, 59);
    try {
      final attr = await _employeeRepository.calculateSalesAttributed(
        employeeId: employeeId,
        startDate: start,
        endDate: end,
      );
      emit(state.copyWith(attributedSales: attr));
    } catch (_) {}
  }

  Future<void> saveEmployee(EmployeeModel e) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.upsertEmployee(e);
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> setEmployeeStatus(int id, bool isActive, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin) {
      emit(state.copyWith(loading: false, error: 'Permission denied: Only administrators can modify employment status.'));
      return;
    }
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.setEmployeeStatus(id, isActive);
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> changeEmployeeRole({
    required int employeeId,
    required String newRole,
    required UserRole callerRole,
  }) async {
    if (callerRole != UserRole.admin) {
      emit(state.copyWith(loading: false, error: 'Permission denied: Only administrators can assign or alter staff roles.'));
      return;
    }
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final emp = await _employeeRepository.getEmployee(employeeId);
      if (emp == null) throw AppException('Employee record not found');
      await _employeeRepository.upsertEmployee(emp.copyWith(role: newRole));
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> deleteEmployee(int id, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin) {
      emit(state.copyWith(loading: false, error: 'Permission denied: Only administrators can delete employee records.'));
      return;
    }
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.deleteEmployee(id);
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> recordAttendance({
    required int employeeId,
    required DateTime date,
    DateTime? checkIn,
    DateTime? checkOut,
    required String status,
    double workingHours = 8.0,
    int? shiftId,
    int breakMinutes = 0,
    bool isLate = false,
    double overtimeHours = 0.0,
  }) async {
    if (checkIn != null && checkOut != null && checkOut.isBefore(checkIn)) {
      emit(state.copyWith(loading: false, error: 'Invalid time sequence: Check-out time cannot be earlier than check-in time.'));
      return;
    }
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.recordAttendance(
        employeeId: employeeId,
        date: date,
        checkIn: checkIn,
        checkOut: checkOut,
        status: status,
        workingHours: workingHours,
        shiftId: shiftId,
        breakMinutes: breakMinutes,
        isLate: isLate,
        overtimeHours: overtimeHours,
      );
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> markAttendance({
    required int employeeId,
    required String status,
    double workingHours = 8.0,
    int? shiftId,
    int breakMinutes = 0,
    bool isLate = false,
    double overtimeHours = 0.0,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final now = DateTime.now();
      await _employeeRepository.recordAttendance(
        employeeId: employeeId,
        date: now,
        checkIn: status == 'present' ? now : null,
        status: status,
        workingHours: workingHours,
        shiftId: shiftId,
        breakMinutes: breakMinutes,
        isLate: isLate,
        overtimeHours: overtimeHours,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> correctAttendance({
    required int attendanceId,
    required String status,
    double? workingHours,
    DateTime? checkIn,
    DateTime? checkOut,
    required String reason,
    required String correctedBy,
  }) async {
    if (checkIn != null && checkOut != null && checkOut.isBefore(checkIn)) {
      emit(state.copyWith(loading: false, error: 'Invalid time sequence: Check-out time cannot be earlier than check-in time.'));
      return;
    }
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.correctAttendance(
        attendanceId: attendanceId,
        status: status,
        workingHours: workingHours,
        checkIn: checkIn,
        checkOut: checkOut,
        reason: reason,
        correctedBy: correctedBy,
      );
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> saveShift(ShiftModel shift) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.saveShift(shift);
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> requestLeave(LeaveRequestModel leave) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.requestLeave(leave);
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> approveLeave({
    required int leaveId,
    required bool approved,
    String? remarks,
    String? approvedBy,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.approveLeave(
        leaveId: leaveId,
        approved: approved,
        remarks: remarks,
        approvedBy: approvedBy,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> saveHoliday(HolidayModel holiday) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.saveHoliday(holiday);
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> generatePayroll({
    required int employeeId,
    required int month,
    required int year,
    required double basicSalary,
    double incentive = 0.0,
    double allowances = 0.0,
    double deductions = 0.0,
    String? notes,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.processPayroll(
        employeeId: employeeId,
        month: month,
        year: year,
        basicSalary: basicSalary,
        incentiveAmount: incentive,
        allowances: allowances,
        deductions: deductions,
        notes: notes,
      );
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> disburseSalary(int payrollId, int fromAccountId) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.disbursePayroll(payrollId: payrollId, fromAccountId: fromAccountId);
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> saveSalesTarget(SalesTargetModel target) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.saveSalesTarget(target);
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> createIncentiveRule(IncentiveRuleModel rule) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.createIncentiveRule(rule);
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> approveIncentiveClaim(int claimId, bool approve) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.approveIncentiveClaim(claimId, approve);
      await load();
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }

  Future<void> payoutIncentiveClaim(int claimId, int fromAccountId) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _employeeRepository.payoutIncentiveClaim(claimId: claimId, fromAccountId: fromAccountId);
      await load();
    } on AppException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    } catch (err) {
      emit(state.copyWith(loading: false, error: err.toString()));
    }
  }
}
