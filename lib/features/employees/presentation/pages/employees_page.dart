import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/employees_cubit.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => EmployeesCubit(employeeRepository: deps.employeeRepository)..load(),
      child: const _EmployeesView(),
    );
  }
}

class _EmployeesView extends StatefulWidget {
  const _EmployeesView();

  @override
  State<_EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<_EmployeesView> {
  final TextEditingController _searchController = TextEditingController();
  String _employeeStatusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE
  String? _selectedRoleFilter;
  String? _selectedDepartmentFilter;

  // Module 2 sub-tab: 0 = Daily Register, 1 = Monthly Summary, 2 = Leave Requests
  int _attendanceSubTab = 0;
  final DateTime _attendanceDate = DateTime.now();

  // Module 3 sub-tab: 0 = Payroll Processing, 1 = Incentives & Targets
  int _payrollSubTab = 0;
  int _payrollNavIndex = 0; // 0=Overview, 1=Generate, 2=Pending, 3=Paid, 4=Payslips, 5=History
  int _incentivesNavIndex = 0; // 0=Overview, 1=Rules, 2=Pending Claims, 3=Approved Claims, 4=Paid, 5=History, 6=Performance
  String _payrollStatusFilter = 'ALL'; // ALL, PENDING, PAID

  // Sales attribution employee selection
  int? _attributionEmployeeId;

  // Sorting state for data tables
  int? _empSortColumnIndex;
  bool _empSortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  UserRole _getCurrentUserRole(BuildContext context) {
    try {
      final appCubit = AppScope.of(context).appCubit;
      return appCubit.state.session?.role ?? UserRole.admin;
    } catch (_) {
      return UserRole.admin;
    }
  }

  // -------------------------------------------------------------
  // FILTERING & SORTING LOGIC
  // -------------------------------------------------------------

  List<EmployeeModel> _getFilteredEmployees(List<EmployeeModel> employees) {
    var list = employees.where((e) {
      if (_employeeStatusFilter == 'ACTIVE' && !e.isActive) return false;
      if (_employeeStatusFilter == 'INACTIVE' && e.isActive) return false;
      if (_selectedRoleFilter != null && _selectedRoleFilter!.isNotEmpty && e.role != _selectedRoleFilter) {
        return false;
      }
      if (_selectedDepartmentFilter != null && _selectedDepartmentFilter!.isNotEmpty && e.department != _selectedDepartmentFilter) {
        return false;
      }
      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        final matchName = e.name.toLowerCase().contains(q);
        final matchCode = e.employeeCode.toLowerCase().contains(q);
        final matchPhone = e.phone.toLowerCase().contains(q);
        final matchDesignation = e.designation.toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchPhone && !matchDesignation) return false;
      }
      return true;
    }).toList();

    if (_empSortColumnIndex != null) {
      list.sort((a, b) {
        int comp;
        switch (_empSortColumnIndex) {
          case 0:
            comp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 1:
            comp = a.employeeCode.toLowerCase().compareTo(b.employeeCode.toLowerCase());
            break;
          case 4:
            comp = a.baseSalary.compareTo(b.baseSalary);
            break;
          default:
            comp = 0;
        }
        return _empSortAscending ? comp : -comp;
      });
    }

    return list;
  }

  // -------------------------------------------------------------
  // BUILD METHOD
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentUserRole = _getCurrentUserRole(context);
    final isAdmin = currentUserRole == UserRole.admin;

    return BlocConsumer<EmployeesCubit, EmployeesState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<EmployeesCubit>();
        final selectedTab = state.selectedTab.clamp(0, 2);

        final activeCount = state.employees.where((e) => e.isActive).length;
        final todayPresent = state.todayAttendance.where((a) => a.status == 'present').length;
        final pendingLeaves = state.leaves.where((l) => l.status == 'pending').length;
        final currentPeriodStr = DateFormat('MMM yyyy').format(DateTime(state.selectedYear, state.selectedMonth));

        final isMobile = MediaQuery.of(context).size.width < 768;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: isMobile
                ? (selectedTab == 0
                    ? 'Employees'
                    : selectedTab == 1
                        ? 'Attendance'
                        : 'Payroll')
                : (selectedTab == 0
                    ? 'Employee Management & Profiles'
                    : selectedTab == 1
                        ? 'Attendance & Leave Central'
                        : 'Payroll Processing & Incentives'),
            subtitle: isMobile
                ? null
                : (selectedTab == 0
                    ? 'Staff directory, role permissions, salaries & employee profiles'
                    : selectedTab == 1
                        ? 'Clock-in/out register, shifts, holidays & leave approvals'
                        : 'Period earnings, overtime, tax deductions, pay slips & commissions'),
            actions: [
              IconButton(
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                tooltip: 'Refresh Workspace Data',
                onPressed: () => cubit.load(),
              ),
              if (!isMobile) ...[
                if (selectedTab == 0 && isAdmin)
                  AppButton.primary(
                    label: 'Add Staff',
                    icon: TablerIcons.userPlus,
                    onPressed: () => _openEmployeeEditor(context),
                  )
                else if (selectedTab == 1) ...[
                  AppButton.secondary(
                    label: 'Shifts',
                    icon: TablerIcons.clock,
                    onPressed: () => _openShiftsDialog(context, state),
                  ),
                  AppButton.primary(
                    label: 'Apply Leave',
                    icon: TablerIcons.calendarOff,
                    onPressed: () => _openApplyLeaveDialog(context, state),
                  ),
                ] else if (selectedTab == 2) ...[
                  AppButton.secondary(
                    label: 'Targets & Rules',
                    icon: TablerIcons.award,
                    onPressed: () => _openTargetOrRuleDialog(context, state),
                  ),
                  AppButton.primary(
                    label: 'Run Payroll',
                    icon: TablerIcons.calculator,
                    onPressed: () => _openRunPayrollDialog(context, state),
                  ),
                ],
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton(
                        context,
                        label: isMobile
                            ? 'Staff Directory'
                            : 'Staff Directory (${state.employees.length} total, $activeCount active)',
                        icon: TablerIcons.idBadge,
                        isSelected: selectedTab == 0,
                        onTap: () => cubit.setTab(0),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildTabButton(
                        context,
                        label: isMobile
                            ? 'Attendance & Leaves'
                            : 'Attendance & Leaves (Present: $todayPresent | Leaves: $pendingLeaves)',
                        icon: TablerIcons.calendarCheck,
                        isSelected: selectedTab == 1,
                        onTap: () => cubit.setTab(1),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildTabButton(
                        context,
                        label: isMobile
                            ? 'Payroll & Incentives'
                            : 'Payroll & Incentives ($currentPeriodStr)',
                        icon: TablerIcons.receipt,
                        isSelected: selectedTab == 2,
                        onTap: () => cubit.setTab(2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: state.loading && state.employees.isEmpty
              ? const AppLoadingSkeleton(count: 6)
              : selectedTab == 0
                  ? _buildEmployeeManagement(context, state, isAdmin)
                  : selectedTab == 1
                      ? _buildAttendanceAndLeave(context, state, isAdmin)
                      : _buildPayrollAndIncentives(context, state, isAdmin),
        );
      },
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavActionChip(String label, IconData icon, bool isSelected, VoidCallback onTap, {bool isPrimary = false}) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected
            ? Colors.white
            : (isPrimary ? AppColors.primary : AppColors.textSecondary),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isPrimary ? AppColors.primaryDark : AppColors.textPrimary),
        ),
      ),
      backgroundColor: isSelected
          ? AppColors.primary
          : (isPrimary ? AppColors.primaryContainer.withValues(alpha: 0.5) : Colors.grey.shade100),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isPrimary ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: onTap,
    );
  }

  // =============================================================
  // MODULE 1: EMPLOYEE MANAGEMENT
  // =============================================================

  Widget _buildEmployeeManagement(BuildContext context, EmployeesState state, bool isAdmin) {
    final cubit = context.read<EmployeesCubit>();
    final currentUserRole = _getCurrentUserRole(context);
    final filtered = _getFilteredEmployees(state.employees);

    final totalCount = state.employees.length;
    final activeCount = state.employees.where((e) => e.isActive).length;
    final inactiveCount = totalCount - activeCount;
    final cashiersCount = state.employees.where((e) => e.role == 'cashier').length;
    final fieldStaffCount = state.employees.where((e) => e.role == 'field_officer' || e.role == 'agronomist').length;
    final totalMonthlyBase = state.employees.where((e) => e.isActive).fold<double>(0.0, (acc, e) => acc + e.baseSalary);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 6-KPI Stat Grid
          AppStatGrid(
            minTileWidth: 180,
            children: [
              AppStatCard(
                title: 'Total Staff',
                value: '$totalCount',
                icon: TablerIcons.users,
                subtitle: 'Registered personnel',
              ),
              AppStatCard(
                title: 'Active Employees',
                value: '$activeCount',
                icon: TablerIcons.userCheck,
                accentColor: AppColors.leafAccent,
                subtitle: 'Operational',
              ),
              AppStatCard(
                title: 'Inactive / On Leave',
                value: '$inactiveCount',
                icon: TablerIcons.userOff,
                accentColor: AppColors.warning,
                subtitle: 'Temporarily inactive',
              ),
              AppStatCard(
                title: 'Cashiers & Store Staff',
                value: '$cashiersCount',
                icon: TablerIcons.cashRegister,
                subtitle: 'POS authorized',
              ),
              AppStatCard(
                title: 'Field & Agronomists',
                value: '$fieldStaffCount',
                icon: TablerIcons.plant,
                subtitle: 'Agritech consulting',
              ),
              AppStatCard(
                title: 'Monthly Base Payroll',
                value: '₹${totalMonthlyBase.toStringAsFixed(0)}',
                icon: TablerIcons.wallet,
                accentColor: AppColors.primary,
                subtitle: 'Active base compensation',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Filter Toolbar
          AppFilterBar(
            key: const ValueKey('staff_filter_bar'),
            searchController: _searchController,
            searchHint: 'Search by name, ID code, phone, role...',
            onSearchChanged: (_) => setState(() {}),
            onSearchClear: () {
              _searchController.clear();
              setState(() {});
            },
            filterOptions: const [
              FilterOption(id: 'ALL', label: 'All Staff'),
              FilterOption(id: 'ACTIVE', label: 'Active Only'),
              FilterOption(id: 'INACTIVE', label: 'Inactive Only'),
            ],
            selectedFilterId: _employeeStatusFilter,
            onFilterSelected: (id) => setState(() => _employeeStatusFilter = id),
            trailingAction: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedRoleFilter,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Roles')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                      DropdownMenuItem(value: 'field_officer', child: Text('Field Officer')),
                      DropdownMenuItem(value: 'agronomist', child: Text('Agronomist')),
                    ],
                    onChanged: (val) => setState(() => _selectedRoleFilter = val),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedDepartmentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Depts')),
                      DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                      DropdownMenuItem(value: 'Agri-Consulting', child: Text('Agri-Consulting')),
                      DropdownMenuItem(value: 'Warehouse', child: Text('Warehouse')),
                      DropdownMenuItem(value: 'Operations', child: Text('Operations')),
                      DropdownMenuItem(value: 'Accounts', child: Text('Accounts')),
                    ],
                    onChanged: (val) => setState(() => _selectedDepartmentFilter = val),
                  ),
                ),
                if (isAdmin)
                  AppButton.primary(
                    label: '+ New Employee',
                    icon: TablerIcons.userPlus,
                    onPressed: () => _openEmployeeEditor(context),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Adaptive Table / Cards
          if (filtered.isEmpty)
            const AppEmptyState(
              icon: TablerIcons.users,
              title: 'No staff records found',
              message: 'Try adjusting your search criteria, role filters, or add a new employee.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return AppDataTable<EmployeeModel>(
                    minWidth: 950,
                    sortColumnIndex: _empSortColumnIndex,
                    sortAscending: _empSortAscending,
                    onSort: (colIdx, asc) => setState(() {
                      _empSortColumnIndex = colIdx;
                      _empSortAscending = asc;
                    }),
                    onRowTap: (emp) => _openEmployeeProfileSheet(context, emp, state),
                    columns: [
                      AppDataColumn<EmployeeModel>(
                        title: 'Staff Member',
                        sortable: true,
                        cellBuilder: (ctx, emp, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: emp.isActive ? AppColors.primary : Colors.grey.shade400,
                              child: Text(
                                emp.name.isNotEmpty ? emp.name.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    emp.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    emp.designation,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppDataColumn<EmployeeModel>(
                        title: 'Code & PIN',
                        sortable: true,
                        cellBuilder: (ctx, emp, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emp.employeeCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('PIN: ****', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      AppDataColumn<EmployeeModel>(
                        title: 'Role & Dept',
                        cellBuilder: (ctx, emp, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppBadge.neutral(label: emp.role.replaceAll('_', ' ').toUpperCase()),
                            const SizedBox(width: 4),
                            Text('(${emp.department})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      AppDataColumn<EmployeeModel>(
                        title: 'Phone & Email',
                        cellBuilder: (ctx, emp, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emp.phone, style: const TextStyle(fontSize: 13)),
                            if (emp.email != null && emp.email!.isNotEmpty)
                              Text(emp.email!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      AppDataColumn<EmployeeModel>(
                        title: 'Base Salary',
                        numeric: true,
                        sortable: true,
                        cellBuilder: (ctx, emp, _) => Text(
                          '₹${emp.baseSalary.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                      ),
                      AppDataColumn<EmployeeModel>(
                        title: 'Status',
                        cellBuilder: (ctx, emp, _) => emp.isActive ? AppBadge.success(label: 'Active') : AppBadge.error(label: 'Inactive'),
                      ),
                      AppDataColumn<EmployeeModel>(
                        title: 'Actions',
                        cellBuilder: (ctx, emp, _) => PopupMenuButton<String>(
                          icon: const Icon(TablerIcons.dotsVertical, size: 18),
                          onSelected: (action) {
                            if (action == 'view_profile') {
                              _openEmployeeProfileSheet(context, emp, state);
                            } else if (action == 'edit') {
                              _openEmployeeEditor(context, existing: emp);
                            } else if (action == 'change_role') {
                              _openRoleChangeDialog(context, emp);
                            } else if (action == 'toggle_status') {
                              cubit.setEmployeeStatus(emp.id, !emp.isActive, callerRole: currentUserRole);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'view_profile', child: Text('View Profile & Audit')),
                            if (isAdmin) ...[
                              const PopupMenuItem(value: 'edit', child: Text('Edit Staff Details')),
                              const PopupMenuItem(value: 'change_role', child: Text('Change Role (RBAC)')),
                              PopupMenuItem(
                                value: 'toggle_status',
                                child: Text(emp.isActive ? 'Deactivate Staff' : 'Reactivate Staff'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    items: filtered,
                  );
                }

                // Mobile Card View
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, idx) {
                    final emp = filtered[idx];
                    return AppCard.bordered(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: emp.isActive ? AppColors.primary : Colors.grey.shade400,
                              child: Text(
                                emp.name.isNotEmpty ? emp.name.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          emp.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      emp.isActive ? AppBadge.success(label: 'Active') : AppBadge.error(label: 'Inactive'),
                                    ],
                                  ),
                                  Text(
                                    '${emp.employeeCode} • ${emp.designation} (${emp.department})',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Base: ₹${emp.baseSalary.toStringAsFixed(0)} • Phone: ${emp.phone}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(TablerIcons.chevronRight, size: 20),
                              onPressed: () => _openEmployeeProfileSheet(context, emp, state),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  // =============================================================
  // MODULE 2: ATTENDANCE & LEAVE MANAGEMENT
  // =============================================================

  Widget _buildAttendanceAndLeave(BuildContext context, EmployeesState state, bool isAdmin) {
    final activeStaff = state.employees.where((e) => e.isActive).toList();

    // Derived Attendance KPIs
    final presentToday = state.todayAttendance.where((a) => a.status == 'present').length;
    final lateToday = state.todayAttendance.where((a) => a.isLate).length;
    final onLeaveToday = state.todayAttendance.where((a) => a.status == 'on_leave').length;
    final absentToday = (activeStaff.length - presentToday - onLeaveToday).clamp(0, activeStaff.length);
    final totalWorkingForce = activeStaff.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5-KPI Attendance Stat Grid
          AppStatGrid(
            minTileWidth: 180,
            children: [
              AppStatCard(
                title: 'Present Today',
                value: '$presentToday',
                icon: TablerIcons.userCheck,
                accentColor: AppColors.primary,
                subtitle: 'Clocked-in staff',
              ),
              AppStatCard(
                title: 'Absent Today',
                value: '$absentToday',
                icon: TablerIcons.userX,
                accentColor: AppColors.error,
                subtitle: 'Unreported / Absent',
              ),
              AppStatCard(
                title: 'Late Arrivals',
                value: '$lateToday',
                icon: TablerIcons.clockExclamation,
                accentColor: AppColors.warning,
                subtitle: 'Exceeded shift grace',
              ),
              AppStatCard(
                title: 'On Approved Leave',
                value: '$onLeaveToday',
                icon: TablerIcons.calendarOff,
                accentColor: AppColors.leafAccent,
                subtitle: 'Scheduled absence',
              ),
              AppStatCard(
                title: 'Total Active Force',
                value: '$totalWorkingForce',
                icon: TablerIcons.buildingCommunity,
                subtitle: 'Active roster count',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Sub-Tab Switcher: 0 = Daily Register, 1 = Monthly Summary, 2 = Leave Requests
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.md,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSubTabChip('Daily Register (${DateFormat('dd MMM').format(_attendanceDate)})', TablerIcons.calendarEvent, _attendanceSubTab == 0, () {
                    setState(() => _attendanceSubTab = 0);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildSubTabChip('Monthly Summary', TablerIcons.calendarStats, _attendanceSubTab == 1, () {
                    setState(() => _attendanceSubTab = 1);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildSubTabChip('Leave Requests (${state.leaves.length})', TablerIcons.receiptOff, _attendanceSubTab == 2, () {
                    setState(() => _attendanceSubTab = 2);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Filter & Operations Toolbar
          AppFilterBar(
            key: const ValueKey('attendance_filter_bar'),
            searchController: _searchController,
            searchHint: 'Search staff by name or code...',
            onSearchChanged: (_) => setState(() {}),
            onSearchClear: () {
              _searchController.clear();
              setState(() {});
            },
            filterOptions: const [
              FilterOption(id: 'ALL', label: 'All Active'),
            ],
            selectedFilterId: 'ALL',
            onFilterSelected: (_) {},
            trailingAction: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppButton.secondary(
                  label: 'Holidays',
                  icon: TablerIcons.calendarEvent,
                  onPressed: () => _openHolidaysDialog(context, state),
                ),
                AppButton.secondary(
                  label: 'Shifts',
                  icon: TablerIcons.clock,
                  onPressed: () => _openShiftsDialog(context, state),
                ),
                AppButton.primary(
                  label: '+ Manual Entry',
                  icon: TablerIcons.calendarPlus,
                  onPressed: () => _openManualAttendanceDialog(context, state),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Sub-Tab Content
          if (_attendanceSubTab == 0)
            _buildDailyAttendanceRegister(context, state, activeStaff, isAdmin)
          else if (_attendanceSubTab == 1)
            _buildMonthlyAttendanceSummary(context, state)
          else
            _buildLeaveManagementSection(context, state, isAdmin),
        ],
      ),
    );
  }

  Widget _buildSubTabChip(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadii.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyAttendanceRegister(
    BuildContext context,
    EmployeesState state,
    List<EmployeeModel> staff,
    bool isAdmin,
  ) {
    final cubit = context.read<EmployeesCubit>();
    final query = _searchController.text.trim().toLowerCase();

    final filteredStaff = staff.where((e) {
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) || e.employeeCode.toLowerCase().contains(query);
    }).toList();

    if (filteredStaff.isEmpty) {
      return const AppEmptyState(
        icon: TablerIcons.calendarX,
        title: 'No staff available for attendance',
        message: 'Ensure active employees are registered in Staff Directory.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 850) {
          return AppDataTable<EmployeeModel>(
            minWidth: 920,
            columns: [
              AppDataColumn<EmployeeModel>(
                title: 'Employee',
                cellBuilder: (ctx, emp, _) {
                  final att = state.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
                  final isPresent = att?.status == 'present';

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isPresent ? AppColors.primary : Colors.grey.shade400,
                        child: Text(
                          emp.name.isNotEmpty ? emp.name.substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                            Text('${emp.employeeCode} • ${emp.designation}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              AppDataColumn<EmployeeModel>(
                title: 'Shift Assignment',
                cellBuilder: (ctx, emp, _) {
                  final shift = state.shifts.where((s) => s.id == emp.shiftId).firstOrNull;
                  return Text(shift != null ? '${shift.name} (${shift.startTime}-${shift.endTime})' : 'General Shift (09:00 - 18:00)', style: const TextStyle(fontSize: 12));
                },
              ),
              AppDataColumn<EmployeeModel>(
                title: 'Check-In',
                cellBuilder: (ctx, emp, _) {
                  final att = state.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
                  final isClockedIn = att?.checkInTime != null;

                  return isClockedIn
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(TablerIcons.check, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(DateFormat('hh:mm a').format(att!.checkInTime!), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        )
                      : Text('Not Clocked', style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
                },
              ),
              AppDataColumn<EmployeeModel>(
                title: 'Check-Out',
                cellBuilder: (ctx, emp, _) {
                  final att = state.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
                  final isClockedOut = att?.checkOutTime != null;

                  return isClockedOut
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(TablerIcons.logout, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(DateFormat('hh:mm a').format(att!.checkOutTime!), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        )
                      : Text('Pending Exit', style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
                },
              ),
              AppDataColumn<EmployeeModel>(
                title: 'Hours & OT',
                numeric: true,
                cellBuilder: (ctx, emp, _) {
                  final att = state.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
                  final hrs = att?.workingHours ?? 8.0;
                  final ot = att?.overtimeHours ?? 0.0;
                  return Text('${hrs.toStringAsFixed(1)} hrs${ot > 0 ? " (+${ot.toStringAsFixed(1)} OT)" : ""}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12));
                },
              ),
              AppDataColumn<EmployeeModel>(
                title: 'Status',
                cellBuilder: (ctx, emp, _) {
                  final att = state.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
                  if (att == null) return AppBadge.neutral(label: 'Unmarked');
                  if (att.status == 'present') {
                    return att.isLate ? AppBadge.warning(label: 'Late Present') : AppBadge.success(label: 'Present');
                  }
                  if (att.status == 'on_leave') return AppBadge.info(label: 'On Leave');
                  return AppBadge.error(label: 'Absent');
                },
              ),
              AppDataColumn<EmployeeModel>(
                title: 'Actions',
                cellBuilder: (ctx, emp, _) {
                  final att = state.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
                  final isClockedIn = att?.checkInTime != null;
                  final isClockedOut = att?.checkOutTime != null;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isClockedIn)
                        IconButton(
                          icon: const Icon(TablerIcons.login, size: 18, color: AppColors.primary),
                          tooltip: 'One-Click Clock In',
                          onPressed: () => cubit.markAttendance(employeeId: emp.id, status: 'present'),
                        )
                      else if (!isClockedOut)
                        IconButton(
                          icon: const Icon(TablerIcons.logout, size: 18, color: Colors.blue),
                          tooltip: 'One-Click Clock Out',
                          onPressed: () {
                            final now = DateTime.now();
                            cubit.recordAttendance(
                              employeeId: emp.id,
                              date: now,
                              checkOut: now,
                              status: 'present',
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(TablerIcons.edit, size: 18, color: Colors.orange),
                        tooltip: 'Correct / Adjust Record',
                        onPressed: () => _openAttendanceCorrectionDialog(context, emp, att),
                      ),
                    ],
                  );
                },
              ),
            ],
            items: filteredStaff,
          );
        }

        // Mobile Cards
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredStaff.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, idx) {
            final emp = filteredStaff[idx];
            final att = state.todayAttendance.where((a) => a.employeeId == emp.id).firstOrNull;
            final isClockedIn = att?.checkInTime != null;
            final isClockedOut = att?.checkOutTime != null;

            return AppCard.bordered(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            emp.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (att == null)
                          AppBadge.neutral(label: 'Unmarked')
                        else if (att.status == 'present')
                          att.isLate ? AppBadge.warning(label: 'Late Present') : AppBadge.success(label: 'Present')
                        else
                          AppBadge.error(label: att.status.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'In: ${isClockedIn ? DateFormat('hh:mm a').format(att!.checkInTime!) : "--"} • Out: ${isClockedOut ? DateFormat('hh:mm a').format(att!.checkOutTime!) : "--"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      alignment: WrapAlignment.end,
                      children: [
                        if (!isClockedIn)
                          AppButton.secondary(
                            label: 'Clock In',
                            icon: TablerIcons.login,
                            onPressed: () => cubit.markAttendance(employeeId: emp.id, status: 'present'),
                          )
                        else if (!isClockedOut)
                          AppButton.secondary(
                            label: 'Clock Out',
                            icon: TablerIcons.logout,
                            onPressed: () {
                              final now = DateTime.now();
                              cubit.recordAttendance(
                                employeeId: emp.id,
                                date: now,
                                checkOut: now,
                                status: 'present',
                              );
                            },
                          ),
                        AppButton.ghost(
                          label: 'Adjust',
                          icon: TablerIcons.edit,
                          onPressed: () => _openAttendanceCorrectionDialog(context, emp, att),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyAttendanceSummary(BuildContext context, EmployeesState state) {
    if (state.monthlySummaries.isEmpty) {
      return const AppEmptyState(
        icon: TablerIcons.calendarStats,
        title: 'No monthly attendance aggregates',
        message: 'No recorded attendance entries exist for the selected month and year.',
      );
    }

    return AppDataTable<AttendanceSummaryModel>(
      minWidth: 800,
      columns: [
        AppDataColumn<AttendanceSummaryModel>(
          title: 'Employee Name',
          cellBuilder: (ctx, summary, _) {
            final emp = state.employees.where((e) => e.id == summary.employeeId).firstOrNull;
            return Text(emp?.name ?? 'Employee #${summary.employeeId}', style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        AppDataColumn<AttendanceSummaryModel>(
          title: 'Present Days',
          numeric: true,
          cellBuilder: (ctx, summary, _) => Text('${summary.presentDays} d', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
        ),
        AppDataColumn<AttendanceSummaryModel>(
          title: 'Late Days',
          numeric: true,
          cellBuilder: (ctx, summary, _) => Text('${summary.lateDays} d', style: const TextStyle(color: AppColors.warning)),
        ),
        AppDataColumn<AttendanceSummaryModel>(
          title: 'Half Days',
          numeric: true,
          cellBuilder: (ctx, summary, _) => Text('${summary.halfDays} d'),
        ),
        AppDataColumn<AttendanceSummaryModel>(
          title: 'Absent Days',
          numeric: true,
          cellBuilder: (ctx, summary, _) => Text('${summary.absentDays} d', style: const TextStyle(color: AppColors.error)),
        ),
        AppDataColumn<AttendanceSummaryModel>(
          title: 'Total Days',
          numeric: true,
          cellBuilder: (ctx, summary, _) => Text('${summary.totalDays} d', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        AppDataColumn<AttendanceSummaryModel>(
          title: 'Overtime Hours',
          numeric: true,
          cellBuilder: (ctx, summary, _) => Text('${summary.overtimeHours.toStringAsFixed(1)} hrs', style: const TextStyle(color: AppColors.primary)),
        ),
      ],
      items: state.monthlySummaries,
    );
  }

  Widget _buildLeaveManagementSection(BuildContext context, EmployeesState state, bool isAdmin) {
    if (state.leaves.isEmpty) {
      return const AppEmptyState(
        icon: TablerIcons.calendarOff,
        title: 'No leave requests on record',
        message: 'Employees can apply for casual, sick, earned, or unpaid leaves.',
      );
    }

    return AppDataTable<LeaveRequestModel>(
      minWidth: 850,
      columns: [
        AppDataColumn<LeaveRequestModel>(
          title: 'Employee',
          cellBuilder: (ctx, leave, _) {
            final emp = state.employees.where((e) => e.id == leave.employeeId).firstOrNull;
            return Text(emp?.name ?? 'Staff #${leave.employeeId}', style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        AppDataColumn<LeaveRequestModel>(
          title: 'Leave Type',
          cellBuilder: (ctx, leave, _) => AppBadge.info(label: leave.leaveType.toUpperCase()),
        ),
        AppDataColumn<LeaveRequestModel>(
          title: 'Duration',
          cellBuilder: (ctx, leave, _) {
            final startStr = DateFormat('dd MMM yyyy').format(leave.startDate);
            final endStr = DateFormat('dd MMM yyyy').format(leave.endDate);
            return Text('$startStr to $endStr', style: const TextStyle(fontSize: 12));
          },
        ),
        AppDataColumn<LeaveRequestModel>(
          title: 'Reason',
          cellBuilder: (ctx, leave, _) => Text(leave.reason ?? 'No reason stated', style: const TextStyle(fontSize: 12)),
        ),
        AppDataColumn<LeaveRequestModel>(
          title: 'Status',
          cellBuilder: (ctx, leave, _) {
            if (leave.status == 'approved') return AppBadge.success(label: 'Approved');
            if (leave.status == 'rejected') return AppBadge.error(label: 'Rejected');
            return AppBadge.warning(label: 'Pending Approval');
          },
        ),
        AppDataColumn<LeaveRequestModel>(
          title: 'Actions',
          cellBuilder: (ctx, leave, _) {
            final isPending = leave.status == 'pending';
            if (!isPending || !isAdmin) {
              return Text(leave.status == 'approved' ? 'Processed' : 'Closed', style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(TablerIcons.check, size: 18, color: AppColors.success),
                  tooltip: 'Approve Leave',
                  onPressed: () => _openLeaveApprovalDialog(context, leave, true),
                ),
                IconButton(
                  icon: const Icon(TablerIcons.x, size: 18, color: AppColors.error),
                  tooltip: 'Reject Leave',
                  onPressed: () => _openLeaveApprovalDialog(context, leave, false),
                ),
              ],
            );
          },
        ),
      ],
      items: state.leaves,
    );
  }

  // =============================================================
  // MODULE 3: PAYROLL & INCENTIVES
  // =============================================================

  Widget _buildPayrollAndIncentives(BuildContext context, EmployeesState state, bool isAdmin) {
    final cubit = context.read<EmployeesCubit>();

    final totalPayroll = state.payrollRecords.fold<double>(0.0, (acc, p) => acc + p.netSalary);
    final paidSalaries = state.payrollRecords.where((p) => p.status == 'paid').fold<double>(0.0, (acc, p) => acc + p.netSalary);
    final outstandingSalaries = (totalPayroll - paidSalaries).clamp(0.0, double.infinity);
    final pendingCount = state.payrollRecords.where((p) => p.status != 'paid').length;
    final totalIncentiveClaims = state.incentiveClaims.fold<double>(0.0, (acc, c) => acc + c.amount);

    final filteredRecords = state.payrollRecords.where((p) {
      if (_payrollStatusFilter == 'PENDING') return p.status != 'paid';
      if (_payrollStatusFilter == 'PAID') return p.status == 'paid';
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5-KPI Payroll Stat Grid
          AppStatGrid(
            minTileWidth: 180,
            children: [
              AppStatCard(
                title: 'Total Period Payroll',
                value: '₹${totalPayroll.toStringAsFixed(0)}',
                icon: TablerIcons.calculator,
                accentColor: AppColors.primary,
                subtitle: 'Computed net salary',
              ),
              AppStatCard(
                title: 'Staff Included',
                value: '${state.payrollRecords.length}',
                icon: TablerIcons.users,
                subtitle: 'Processed employees',
              ),
              AppStatCard(
                title: 'Pending Payouts',
                value: '$pendingCount (₹${outstandingSalaries.toStringAsFixed(0)})',
                icon: TablerIcons.alertCircle,
                accentColor: AppColors.warning,
                subtitle: 'Awaiting disbursal',
              ),
              AppStatCard(
                title: 'Disbursed Salary',
                value: '₹${paidSalaries.toStringAsFixed(0)}',
                icon: TablerIcons.circleCheck,
                accentColor: AppColors.leafAccent,
                subtitle: 'Ledger debited',
              ),
              AppStatCard(
                title: 'Incentive Claims',
                value: '₹${totalIncentiveClaims.toStringAsFixed(0)}',
                icon: TablerIcons.award,
                subtitle: 'Attributed commissions',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Sub-Tab Switcher: 0 = Payroll Processing, 1 = Incentives & Targets
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.md,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSubTabChip('Payroll Central', TablerIcons.receipt, _payrollSubTab == 0, () {
                    setState(() => _payrollSubTab = 0);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildSubTabChip('Sales Targets & Incentives', TablerIcons.award, _payrollSubTab == 1, () {
                    setState(() => _payrollSubTab = 1);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Prominent Payroll & Incentives Action Controls
          if (_payrollSubTab == 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildNavActionChip('Overview', TablerIcons.dashboard, _payrollNavIndex == 0, () {
                      setState(() {
                        _payrollNavIndex = 0;
                        _payrollStatusFilter = 'ALL';
                      });
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Generate Payroll', TablerIcons.calculator, _payrollNavIndex == 1, () {
                      setState(() => _payrollNavIndex = 1);
                      _openRunPayrollDialog(context, state);
                    }, isPrimary: true),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Pending Approvals ($pendingCount)', TablerIcons.clock, _payrollNavIndex == 2, () {
                      setState(() {
                        _payrollNavIndex = 2;
                        _payrollStatusFilter = 'PENDING';
                      });
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Paid Payroll', TablerIcons.circleCheck, _payrollNavIndex == 3, () {
                      setState(() {
                        _payrollNavIndex = 3;
                        _payrollStatusFilter = 'PAID';
                      });
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Payslips', TablerIcons.printer, _payrollNavIndex == 4, () {
                      setState(() {
                        _payrollNavIndex = 4;
                        _payrollStatusFilter = 'ALL';
                      });
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Payroll History', TablerIcons.history, _payrollNavIndex == 5, () {
                      setState(() {
                        _payrollNavIndex = 5;
                        _payrollStatusFilter = 'ALL';
                      });
                    }),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildNavActionChip('Overview', TablerIcons.dashboard, _incentivesNavIndex == 0, () {
                      setState(() => _incentivesNavIndex = 0);
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Incentive Rules', TablerIcons.award, _incentivesNavIndex == 1, () {
                      setState(() => _incentivesNavIndex = 1);
                      _openTargetOrRuleDialog(context, state);
                    }, isPrimary: true),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Pending Claims (${state.incentiveClaims.where((c) => c.status == 'pending').length})', TablerIcons.clock, _incentivesNavIndex == 2, () {
                      setState(() => _incentivesNavIndex = 2);
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Approved Claims (${state.incentiveClaims.where((c) => c.status == 'approved').length})', TablerIcons.check, _incentivesNavIndex == 3, () {
                      setState(() => _incentivesNavIndex = 3);
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Paid Incentives (${state.incentiveClaims.where((c) => c.status == 'paid').length})', TablerIcons.cash, _incentivesNavIndex == 4, () {
                      setState(() => _incentivesNavIndex = 4);
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Incentive History', TablerIcons.history, _incentivesNavIndex == 5, () {
                      setState(() => _incentivesNavIndex = 5);
                    }),
                    const SizedBox(width: 6),
                    _buildNavActionChip('Employee Performance', TablerIcons.chartLine, _incentivesNavIndex == 6, () {
                      setState(() => _incentivesNavIndex = 6);
                    }),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),

          // Sub-Tab 0: Payroll Processing
          if (_payrollSubTab == 0) ...[
            // Period & Status Filter Toolbar
            AppFilterBar(
              key: const ValueKey('payroll_filter_bar'),
              filterOptions: const [
                FilterOption(id: 'ALL', label: 'All Runs'),
                FilterOption(id: 'PENDING', label: 'Pending Payout'),
                FilterOption(id: 'PAID', label: 'Paid / Disbursed'),
              ],
              selectedFilterId: _payrollStatusFilter,
              onFilterSelected: (id) => setState(() => _payrollStatusFilter = id),
              trailingAction: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: state.selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (i) => i + 1).map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                        );
                      }).toList(),
                      onChanged: (m) {
                        if (m != null) cubit.setMonthYear(m, state.selectedYear);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: state.selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      items: [2025, 2026, 2027].map((y) {
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }).toList(),
                      onChanged: (y) {
                        if (y != null) cubit.setMonthYear(state.selectedMonth, y);
                      },
                    ),
                  ),
                  AppButton.primary(
                    label: '+ Run Month Payroll',
                    icon: TablerIcons.calculator,
                    onPressed: () => _openRunPayrollDialog(context, state),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (filteredRecords.isEmpty)
              const AppEmptyState(
                icon: TablerIcons.receiptOff,
                title: 'No payroll records computed for this period',
                message: 'Click "+ Run Month Payroll" to compute payable days, allowances, overtime and net salaries.',
              )
            else
              AppDataTable<PayrollRecordModel>(
                minWidth: 920,
                columns: [
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Employee',
                    cellBuilder: (ctx, payroll, _) {
                      final emp = state.employees.where((e) => e.id == payroll.employeeId).firstOrNull;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(emp?.name ?? 'Employee #${payroll.employeeId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${emp?.employeeCode ?? "EMP"} • ${emp?.designation ?? ""}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      );
                    },
                  ),
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Basic Salary',
                    numeric: true,
                    cellBuilder: (ctx, payroll, _) => Text('₹${payroll.basicSalary.toStringAsFixed(2)}'),
                  ),
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Allowances',
                    numeric: true,
                    cellBuilder: (ctx, payroll, _) => Text('₹${payroll.allowances.toStringAsFixed(2)}'),
                  ),
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Incentives',
                    numeric: true,
                    cellBuilder: (ctx, payroll, _) => Text('₹${payroll.incentiveAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary)),
                  ),
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Deductions',
                    numeric: true,
                    cellBuilder: (ctx, payroll, _) => Text('₹${payroll.deductions.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.error)),
                  ),
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Net Salary',
                    numeric: true,
                    cellBuilder: (ctx, payroll, _) => Text(
                      '₹${payroll.netSalary.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                  ),
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Status',
                    cellBuilder: (ctx, payroll, _) => payroll.status == 'paid' ? AppBadge.success(label: 'Paid & Posted') : AppBadge.warning(label: 'Approved / Pending'),
                  ),
                  AppDataColumn<PayrollRecordModel>(
                    title: 'Actions',
                    cellBuilder: (ctx, payroll, _) {
                      final emp = state.employees.where((e) => e.id == payroll.employeeId).firstOrNull;
                      final isPaid = payroll.status == 'paid';

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPaid && isAdmin)
                            AppButton.primary(
                              label: 'Disburse',
                              icon: TablerIcons.cash,
                              onPressed: () => _openDisburseSalaryDialog(context, payroll, emp),
                            )
                          else
                            AppButton.secondary(
                              label: 'Payslip',
                              icon: TablerIcons.printer,
                              onPressed: () => _openPayslipDialog(context, payroll, emp),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                items: filteredRecords,
              ),
          ] else ...[
            // Sub-Tab 1: Incentives & Sales Targets
            _buildIncentivesAndTargetsView(context, state, isAdmin),
          ],
        ],
      ),
    );
  }

  Widget _buildIncentivesAndTargetsView(BuildContext context, EmployeesState state, bool isAdmin) {
    final cubit = context.read<EmployeesCubit>();

    final showPerformanceOnly = _incentivesNavIndex == 6;
    final showRulesOnly = _incentivesNavIndex == 1;
    final showClaimsOnly = _incentivesNavIndex >= 2 && _incentivesNavIndex <= 5;
    final showAll = _incentivesNavIndex == 0;

    final displayedClaims = state.incentiveClaims.where((c) {
      if (_incentivesNavIndex == 2) return c.status == 'pending';
      if (_incentivesNavIndex == 3) return c.status == 'approved';
      if (_incentivesNavIndex == 4) return c.status == 'paid';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Sales Attribution Calculator Card (Visible in Overview or Performance tab)
        if (showAll || showPerformanceOnly) ...[
          AppCard.bordered(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(TablerIcons.calculator, size: 20, color: AppColors.primary),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'POS Sales Attribution & Return Reversals Calculator',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Calculates gross orders attributed to the staff member, deducts sales returns and cancellations, and produces net qualifying incentive revenue.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: _attributionEmployeeId,
                          decoration: const InputDecoration(
                            labelText: 'Select Staff Member',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: state.employees.map((e) {
                            return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role})'));
                          }).toList(),
                          onChanged: (id) {
                            setState(() => _attributionEmployeeId = id);
                            if (id != null) {
                              cubit.calculateAttributedSalesForEmployee(id);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (state.attributedSales != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.sm,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatPill('Completed Invoices', '${state.attributedSales!['completedInvoices']}', AppColors.textPrimary),
                          _buildStatPill('Gross Revenue', '₹${(state.attributedSales!['grossRevenue'] as num).toStringAsFixed(2)}', AppColors.primary),
                          _buildStatPill('Returned Invoices', '${state.attributedSales!['returnedInvoices']}', AppColors.error),
                          _buildStatPill('Reversed Amount', '₹${(state.attributedSales!['returnedAmount'] as num).toStringAsFixed(2)}', AppColors.error),
                          _buildStatPill('Net Qualifying Revenue', '₹${(state.attributedSales!['netRevenue'] as num).toStringAsFixed(2)}', AppColors.leafAccent),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 2. Sales Targets Section (Visible in Overview or Rules tab)
        if (showAll || showRulesOnly) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Individual Sales Targets & Incentive Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (isAdmin)
                AppButton.secondary(
                  label: '+ Assign Target',
                  icon: TablerIcons.target,
                  onPressed: () => _openTargetOrRuleDialog(context, state),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.salesTargets.isEmpty)
            const AppEmptyState(
              icon: TablerIcons.targetOff,
              title: 'No sales targets assigned',
              message: 'Create monthly target slabs for cashiers, field officers, or agronomists.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.salesTargets.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, idx) {
                final t = state.salesTargets[idx];
                final emp = state.employees.where((e) => e.id == t.employeeId).firstOrNull;
                final percent = t.progressPercent;

                return AppCard.bordered(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${emp?.name ?? "Employee"} • Target: ₹${t.targetAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${percent.toStringAsFixed(1)}% Achieved', style: TextStyle(fontWeight: FontWeight.bold, color: percent >= 100 ? AppColors.success : AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: t.progressRatio,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(percent >= 100 ? AppColors.success : AppColors.primary),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 6),
                        Text('Achieved: ₹${t.currentAmount.toStringAsFixed(2)} (${DateFormat('MMM yyyy').format(t.startDate)})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 3. Incentive Claims & Approval Table (Visible in Overview or Claims tabs)
        if (showAll || showClaimsOnly) ...[
          Text(
            _incentivesNavIndex == 2
                ? 'Pending Incentive Claims (${displayedClaims.length})'
                : _incentivesNavIndex == 3
                    ? 'Approved Claims Ready for Payout (${displayedClaims.length})'
                    : _incentivesNavIndex == 4
                        ? 'Disbursed / Settled Incentives (${displayedClaims.length})'
                        : 'Incentive Claims & Payouts (${displayedClaims.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (displayedClaims.isEmpty)
            AppEmptyState(
              icon: TablerIcons.awardOff,
              title: _incentivesNavIndex == 2
                  ? 'No pending claims'
                  : _incentivesNavIndex == 3
                      ? 'No approved claims pending payout'
                      : 'No commission claims recorded',
              message: 'Incentive claims generated from sales milestones will appear here.',
            )
          else
            AppDataTable<IncentiveClaimModel>(
              minWidth: 850,
              columns: [
                AppDataColumn<IncentiveClaimModel>(
                  title: 'Staff Member',
                  cellBuilder: (ctx, claim, _) {
                    final emp = state.employees.where((e) => e.id == claim.employeeId).firstOrNull;
                    return Text(emp?.name ?? 'Employee #${claim.employeeId}', style: const TextStyle(fontWeight: FontWeight.bold));
                  },
                ),
                AppDataColumn<IncentiveClaimModel>(
                  title: 'Claim Amount',
                  numeric: true,
                  cellBuilder: (ctx, claim, _) => Text('₹${claim.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                AppDataColumn<IncentiveClaimModel>(
                  title: 'Milestone Basis',
                  cellBuilder: (ctx, claim, _) => Text(claim.description, style: const TextStyle(fontSize: 12)),
                ),
                AppDataColumn<IncentiveClaimModel>(
                  title: 'Status',
                  cellBuilder: (ctx, claim, _) {
                    if (claim.status == 'paid') return AppBadge.success(label: 'Paid');
                    if (claim.status == 'approved') return AppBadge.info(label: 'Approved');
                    if (claim.status == 'rejected') return AppBadge.error(label: 'Rejected');
                    return AppBadge.warning(label: 'Pending Approval');
                  },
                ),
                AppDataColumn<IncentiveClaimModel>(
                  title: 'Actions',
                  cellBuilder: (ctx, claim, _) {
                    final isPaid = claim.status == 'paid';
                    final isApproved = claim.status == 'approved';

                    if (claim.status == 'pending' && isAdmin) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(TablerIcons.check, size: 18, color: AppColors.success),
                            tooltip: 'Approve Claim',
                            onPressed: () => _openIncentiveClaimApprovalDialog(context, claim, true),
                          ),
                          IconButton(
                            icon: const Icon(TablerIcons.x, size: 18, color: AppColors.error),
                            tooltip: 'Reject Claim',
                            onPressed: () => _openIncentiveClaimApprovalDialog(context, claim, false),
                          ),
                        ],
                      );
                    } else if (isApproved && isAdmin) {
                      return AppButton.primary(
                        label: 'Payout',
                        icon: TablerIcons.cash,
                        onPressed: () => _openPayoutClaimDialog(context, claim),
                      );
                    }
                    return Text(isPaid ? 'Settled' : 'Closed', style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
                  },
                ),
              ],
              items: displayedClaims,
            ),
        ],
      ],
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // =============================================================
  // DIALOGS & DRAWERS
  // =============================================================

  void _openEmployeeEditor(BuildContext context, {EmployeeModel? existing}) {
    final cubit = context.read<EmployeesCubit>();

    final codeCtrl = TextEditingController(text: existing?.employeeCode ?? 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final emergencyCtrl = TextEditingController(text: existing?.emergencyContact ?? '');
    final desigCtrl = TextEditingController(text: existing?.designation ?? 'Store Staff');
    final pinCtrl = TextEditingController(text: existing?.loginPin ?? '1234');
    final baseSalaryCtrl = TextEditingController(text: (existing?.baseSalary ?? 20000.0).toStringAsFixed(0));
    final allowancesCtrl = TextEditingController(text: (existing?.allowances ?? 1500.0).toStringAsFixed(0));
    final deductionsCtrl = TextEditingController(text: (existing?.fixedDeductions ?? 500.0).toStringAsFixed(0));
    final bankNameCtrl = TextEditingController(text: existing?.bankName ?? 'State Bank of India');
    final bankHolderCtrl = TextEditingController(text: existing?.bankAccountName ?? '');
    final bankAccCtrl = TextEditingController(text: existing?.bankAccountNumber ?? '');
    final bankIfscCtrl = TextEditingController(text: existing?.bankIfsc ?? 'SBIN0001234');

    String selectedDept = existing?.department ?? 'Sales';
    String selectedRole = existing?.role ?? 'cashier';
    String selectedEmpType = existing?.employmentType ?? 'full_time';
    bool isActive = existing?.isActive ?? true;
    DateTime joiningDate = existing?.joiningDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Material(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: Scaffold(
                  appBar: AppHeader(
                    title: existing == null ? 'Register New Staff Member' : 'Edit Staff Details',
                    breadcrumbs: const ['Staff & Payroll'],
                    showBackButton: true,
                    onBackPressed: () => Navigator.of(context).pop(),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: AppButton.primary(
                          label: 'Save Employee',
                          icon: TablerIcons.deviceFloppy,
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Name and Phone number are required.')),
                              );
                              return;
                            }

                            final emp = EmployeeModel(
                              id: existing?.id ?? 0,
                              workspaceId: 1,
                              employeeCode: codeCtrl.text.trim(),
                              name: nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                              role: selectedRole,
                              designation: desigCtrl.text.trim(),
                              department: selectedDept,
                              loginPin: pinCtrl.text.trim(),
                              baseSalary: double.tryParse(baseSalaryCtrl.text) ?? 0.0,
                              joiningDate: joiningDate,
                              isActive: isActive,
                              address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                              emergencyContact: emergencyCtrl.text.trim().isEmpty ? null : emergencyCtrl.text.trim(),
                              employmentType: selectedEmpType,
                              salaryType: 'monthly',
                              allowances: double.tryParse(allowancesCtrl.text) ?? 0.0,
                              fixedDeductions: double.tryParse(deductionsCtrl.text) ?? 0.0,
                              bankName: bankNameCtrl.text.trim().isEmpty ? null : bankNameCtrl.text.trim(),
                              bankAccountName: bankHolderCtrl.text.trim().isEmpty ? null : bankHolderCtrl.text.trim(),
                              bankAccountNumber: bankAccCtrl.text.trim().isEmpty ? null : bankAccCtrl.text.trim(),
                              bankIfsc: bankIfscCtrl.text.trim().isEmpty ? null : bankIfscCtrl.text.trim(),
                              shiftId: existing?.shiftId,
                            );

                            cubit.saveEmployee(emp);
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ),
                    ],
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Core Personal & Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: AppTextField(controller: codeCtrl, label: 'Employee ID / Code *')),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(flex: 2, child: AppTextField(controller: nameCtrl, label: 'Full Legal Name *')),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: AppTextField(controller: phoneCtrl, label: 'Mobile Number *', keyboardType: TextInputType.phone)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: AppTextField(controller: emailCtrl, label: 'Email Address', keyboardType: TextInputType.emailAddress)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(flex: 2, child: AppTextField(controller: addressCtrl, label: 'Residential Address')),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: AppTextField(controller: emergencyCtrl, label: 'Emergency Contact Phone')),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        const Text('2. Organizational & Role Placement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdown<String>(
                                label: 'Department',
                                value: selectedDept,
                                items: const [
                                  DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                                  DropdownMenuItem(value: 'Agri-Consulting', child: Text('Agri-Consulting')),
                                  DropdownMenuItem(value: 'Warehouse', child: Text('Warehouse')),
                                  DropdownMenuItem(value: 'Operations', child: Text('Operations')),
                                  DropdownMenuItem(value: 'Accounts', child: Text('Accounts')),
                                ],
                                onChanged: (v) => setSheetState(() => selectedDept = v ?? selectedDept),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: AppTextField(controller: desigCtrl, label: 'Designation')),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppDropdown<String>(
                                label: 'Assigned Role (RBAC)',
                                value: selectedRole,
                                items: const [
                                  DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                                  DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                                  DropdownMenuItem(value: 'field_officer', child: Text('Field Officer')),
                                  DropdownMenuItem(value: 'agronomist', child: Text('Agronomist')),
                                ],
                                onChanged: (v) => setSheetState(() => selectedRole = v ?? selectedRole),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdown<String>(
                                label: 'Employment Type',
                                value: selectedEmpType,
                                items: const [
                                  DropdownMenuItem(value: 'full_time', child: Text('Full-Time')),
                                  DropdownMenuItem(value: 'part_time', child: Text('Part-Time')),
                                  DropdownMenuItem(value: 'contract', child: Text('Contract')),
                                  DropdownMenuItem(value: 'seasonal', child: Text('Seasonal')),
                                ],
                                onChanged: (v) => setSheetState(() => selectedEmpType = v ?? selectedEmpType),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppTextField(
                                controller: pinCtrl,
                                label: 'Login PIN (4 or 6 Digits) *',
                                obscureText: true,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        const Text('3. Salary Structure & Allowances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: AmountField(controller: baseSalaryCtrl, label: 'Monthly Base Salary (₹) *')),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: AmountField(controller: allowancesCtrl, label: 'Standard Allowances (₹)')),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: AmountField(controller: deductionsCtrl, label: 'Fixed Deductions (₹)')),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        const Text('4. Bank Account & Settlement Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: AppTextField(controller: bankNameCtrl, label: 'Bank Name')),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: AppTextField(controller: bankHolderCtrl, label: 'Account Holder Name')),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: AppTextField(controller: bankAccCtrl, label: 'Account Number', keyboardType: TextInputType.number)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: AppTextField(controller: bankIfscCtrl, label: 'IFSC Code')),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        Row(
                          children: [
                            Switch(
                              value: isActive,
                              activeColor: AppColors.primary,
                              onChanged: (v) => setSheetState(() => isActive = v),
                            ),
                            const SizedBox(width: 8),
                            const Text('Employee is Active and Available on Roster', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openEmployeeProfileSheet(BuildContext context, EmployeeModel emp, EmployeesState state) {
    final attendanceLogs = state.todayAttendance.where((a) => a.employeeId == emp.id).toList();
    final leaves = state.leaves.where((l) => l.employeeId == emp.id).toList();
    final payrolls = state.payrollRecords.where((p) => p.employeeId == emp.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: DefaultTabController(
              length: 5,
              child: Scaffold(
                appBar: AppHeader(
                  title: emp.name,
                  breadcrumbs: const ['Staff & Payroll'],
                  subtitle: '${emp.employeeCode} • ${emp.designation} (${emp.department})',
                  showBackButton: true,
                  onBackPressed: () => Navigator.of(context).pop(),
                  badge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: emp.isActive ? AppColors.successContainer : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      emp.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: emp.isActive ? AppColors.successText : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  bottom: const TabBar(
                    isScrollable: true,
                    labelColor: AppColors.primary,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'Personal & Contact'),
                      Tab(text: 'Salary & Employment'),
                      Tab(text: 'Attendance History'),
                      Tab(text: 'Leave History'),
                      Tab(text: 'Payroll & Slips'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    // Tab 1: Personal & Contact
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('Mobile Phone', emp.phone),
                          _buildProfileRow('Email', emp.email ?? 'Not provided'),
                          _buildProfileRow('Residential Address', emp.address ?? 'Not provided'),
                          _buildProfileRow('Emergency Contact', emp.emergencyContact ?? 'Not provided'),
                          _buildProfileRow('Employment Status', emp.isActive ? 'Active Staff' : 'Inactive / On Hold'),
                        ],
                      ),
                    ),
                    // Tab 2: Salary & Employment
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('Department', emp.department),
                          _buildProfileRow('Designation', emp.designation),
                          _buildProfileRow('Role (RBAC)', emp.role.toUpperCase()),
                          _buildProfileRow('Employment Type', emp.employmentType.toUpperCase()),
                          _buildProfileRow('Joining Date', DateFormat('dd MMMM yyyy').format(emp.joiningDate)),
                          _buildProfileRow('Base Salary', '₹${emp.baseSalary.toStringAsFixed(2)} / month'),
                          _buildProfileRow('Allowances', '₹${emp.allowances.toStringAsFixed(2)}'),
                          _buildProfileRow('Fixed Deductions', '₹${emp.fixedDeductions.toStringAsFixed(2)}'),
                          _buildProfileRow('Bank Account', '${emp.bankName ?? "N/A"} - ${emp.bankAccountNumber ?? "N/A"} (${emp.bankIfsc ?? ""})'),
                        ],
                      ),
                    ),
                    // Tab 3: Attendance History
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: attendanceLogs.isEmpty
                          ? const AppEmptyState(icon: TablerIcons.calendarOff, title: 'No attendance logs today', message: 'Historical records are compiled in Monthly Attendance.')
                          : ListView.builder(
                              itemCount: attendanceLogs.length,
                              itemBuilder: (context, i) {
                                final a = attendanceLogs[i];
                                return ListTile(
                                  title: Text('Date: ${DateFormat('yyyy-MM-dd').format(a.date)}'),
                                  subtitle: Text('In: ${a.checkInTime != null ? DateFormat('hh:mm a').format(a.checkInTime!) : "--"} | Out: ${a.checkOutTime != null ? DateFormat('hh:mm a').format(a.checkOutTime!) : "--"}'),
                                  trailing: AppBadge.success(label: a.status.toUpperCase()),
                                );
                              },
                            ),
                    ),
                    // Tab 4: Leave History
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: leaves.isEmpty
                          ? const AppEmptyState(icon: TablerIcons.receiptOff, title: 'No leave records', message: 'Staff member has not applied for leaves.')
                          : ListView.builder(
                              itemCount: leaves.length,
                              itemBuilder: (context, i) {
                                final l = leaves[i];
                                return ListTile(
                                  title: Text('${l.leaveType.toUpperCase()} (${DateFormat('dd MMM').format(l.startDate)} - ${DateFormat('dd MMM').format(l.endDate)})'),
                                  subtitle: Text('Reason: ${l.reason}'),
                                  trailing: AppBadge.info(label: l.status.toUpperCase()),
                                );
                              },
                            ),
                    ),
                    // Tab 5: Payroll & Slips
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: payrolls.isEmpty
                          ? const AppEmptyState(icon: TablerIcons.receipt, title: 'No payroll records', message: 'Payrolls generated for this employee will appear here.')
                          : ListView.builder(
                              itemCount: payrolls.length,
                              itemBuilder: (context, i) {
                                final p = payrolls[i];
                                return ListTile(
                                  title: Text('Period: ${DateFormat('MMMM yyyy').format(DateTime(p.year, p.month))}'),
                                  subtitle: Text('Base: ₹${p.basicSalary.toStringAsFixed(0)} | Allowances: ₹${p.allowances.toStringAsFixed(0)} | Deductions: ₹${p.deductions.toStringAsFixed(0)}'),
                                  trailing: Text('₹${p.netSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _openRoleChangeDialog(BuildContext context, EmployeeModel emp) {
    final cubit = context.read<EmployeesCubit>();
    final currentUserRole = _getCurrentUserRole(context);
    String selectedRole = emp.role;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Change Role: ${emp.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assign an operational role with Role-Based Access Control (RBAC):', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedRole,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'New Role'),
                    items: const [
                      DropdownMenuItem(value: 'cashier', child: Text('Cashier (POS & Sales only)')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager (Store & Inward operations)')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrator (Full system authority)')),
                      DropdownMenuItem(value: 'field_officer', child: Text('Field Officer (CRM & Visits)')),
                      DropdownMenuItem(value: 'agronomist', child: Text('Agronomist (Consulting & Plots)')),
                    ],
                    onChanged: (v) => setDlgState(() => selectedRole = v ?? selectedRole),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Confirm Role Change',
                  onPressed: () {
                    cubit.changeEmployeeRole(
                      employeeId: emp.id,
                      newRole: selectedRole,
                      callerRole: currentUserRole,
                    );
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openManualAttendanceDialog(BuildContext context, EmployeesState state) {
    final cubit = context.read<EmployeesCubit>();
    int? selectedEmpId = state.employees.firstOrNull?.id;
    final DateTime date = DateTime.now();
    String status = 'present';
    final hoursCtrl = TextEditingController(text: '8.0');
    final otCtrl = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Manual Attendance Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedEmpId,
                      decoration: const InputDecoration(labelText: 'Staff Member', border: OutlineInputBorder()),
                      items: state.employees.map((e) {
                        return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.employeeCode})'));
                      }).toList(),
                      onChanged: (v) => setDlgState(() => selectedEmpId = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: status,
                      decoration: const InputDecoration(labelText: 'Attendance Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'present', child: Text('Present (Full Day)')),
                        DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                        DropdownMenuItem(value: 'absent', child: Text('Absent')),
                        DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
                      ],
                      onChanged: (v) => setDlgState(() => status = v ?? status),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: AppTextField(controller: hoursCtrl, label: 'Working Hours', keyboardType: TextInputType.number)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: AppTextField(controller: otCtrl, label: 'Overtime Hours', keyboardType: TextInputType.number)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Log Attendance',
                  onPressed: () {
                    if (selectedEmpId != null) {
                      cubit.recordAttendance(
                        employeeId: selectedEmpId!,
                        date: date,
                        checkIn: status == 'present' ? DateTime(date.year, date.month, date.day, 9, 0) : null,
                        checkOut: status == 'present' ? DateTime(date.year, date.month, date.day, 18, 0) : null,
                        status: status,
                        workingHours: double.tryParse(hoursCtrl.text) ?? 8.0,
                        overtimeHours: double.tryParse(otCtrl.text) ?? 0.0,
                      );
                    }
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAttendanceCorrectionDialog(BuildContext context, EmployeeModel emp, AttendanceModel? att) {
    final cubit = context.read<EmployeesCubit>();
    String status = att?.status ?? 'present';
    final hoursCtrl = TextEditingController(text: (att?.workingHours ?? 8.0).toStringAsFixed(1));
    final reasonCtrl = TextEditingController();
    final correctedByCtrl = TextEditingController(text: 'Admin');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Adjust Attendance: ${emp.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Audit trail requires correction reason and supervisor identification:'),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: status,
                      decoration: const InputDecoration(labelText: 'Corrected Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'present', child: Text('Present')),
                        DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                        DropdownMenuItem(value: 'absent', child: Text('Absent')),
                        DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
                      ],
                      onChanged: (v) => setDlgState(() => status = v ?? status),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(controller: hoursCtrl, label: 'Adjusted Hours', keyboardType: TextInputType.number),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(controller: reasonCtrl, label: 'Correction Reason *'),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(controller: correctedByCtrl, label: 'Approved By (Supervisor) *'),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Save Correction',
                  onPressed: () {
                    if (att != null && att.id > 0) {
                      cubit.correctAttendance(
                        attendanceId: att.id,
                        status: status,
                        workingHours: double.tryParse(hoursCtrl.text) ?? 8.0,
                        reason: reasonCtrl.text.trim().isEmpty ? 'Supervisor correction' : reasonCtrl.text.trim(),
                        correctedBy: correctedByCtrl.text.trim().isEmpty ? 'Admin' : correctedByCtrl.text.trim(),
                      );
                    }
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openApplyLeaveDialog(BuildContext context, EmployeesState state) {
    final cubit = context.read<EmployeesCubit>();
    int? selectedEmpId = state.employees.firstOrNull?.id;
    String leaveType = 'casual';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Apply Staff Leave'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedEmpId,
                      decoration: const InputDecoration(labelText: 'Staff Member', border: OutlineInputBorder()),
                      items: state.employees.map((e) {
                        return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.employeeCode})'));
                      }).toList(),
                      onChanged: (v) => setDlgState(() => selectedEmpId = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: leaveType,
                      decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'casual', child: Text('Casual Leave (Paid)')),
                        DropdownMenuItem(value: 'sick', child: Text('Sick Leave (Paid)')),
                        DropdownMenuItem(value: 'earned', child: Text('Earned Leave (Paid)')),
                        DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Leave (Loss of Pay)')),
                      ],
                      onChanged: (v) => setDlgState(() => leaveType = v ?? leaveType),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(TablerIcons.calendar, size: 16),
                            label: Text(DateFormat('dd MMM').format(startDate)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 180)),
                              );
                              if (picked != null) setDlgState(() => startDate = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(TablerIcons.calendar, size: 16),
                            label: Text(DateFormat('dd MMM').format(endDate)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now().add(const Duration(days: 180)),
                              );
                              if (picked != null) setDlgState(() => endDate = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(controller: reasonCtrl, label: 'Reason for Leave *'),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Submit Application',
                  onPressed: () {
                    if (selectedEmpId != null) {
                      cubit.requestLeave(
                        LeaveRequestModel(
                          id: 0,
                          workspaceId: 1,
                          employeeId: selectedEmpId!,
                          startDate: startDate,
                          endDate: endDate,
                          leaveType: leaveType,
                          reason: reasonCtrl.text.trim().isEmpty ? 'Personal reasons' : reasonCtrl.text.trim(),
                          status: 'pending',
                          createdAt: DateTime.now(),
                        ),
                      );
                    }
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openLeaveApprovalDialog(BuildContext context, LeaveRequestModel leave, bool approve) {
    final cubit = context.read<EmployeesCubit>();
    final remarksCtrl = TextEditingController(text: approve ? 'Approved by Admin' : 'Rejected');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(approve ? 'Approve Leave Request' : 'Reject Leave Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(approve ? 'Approving will automatically mark attendance on scheduled days as On Leave.' : 'Provide rejection remarks:'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: remarksCtrl, label: 'Remarks / Comments'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            AppButton.primary(
              label: approve ? 'Confirm Approval' : 'Confirm Rejection',
              onPressed: () {
                cubit.approveLeave(
                  leaveId: leave.id,
                  approved: approve,
                  remarks: remarksCtrl.text.trim(),
                  approvedBy: 'Admin',
                );
                Navigator.pop(dialogCtx);
              },
            ),
          ],
        );
      },
    );
  }

  void _openShiftsDialog(BuildContext context, EmployeesState state) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Work Shifts & Schedules'),
              IconButton(
                icon: const Icon(TablerIcons.plus, size: 20),
                tooltip: 'Add Shift',
                onPressed: () => _openShiftEditorDialog(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: state.shifts.isEmpty
                ? const Text('No custom shifts created. Default is 09:00 - 18:00.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.shifts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final s = state.shifts[i];
                      return ListTile(
                        leading: const Icon(TablerIcons.clock, color: AppColors.primary),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${s.startTime} to ${s.endTime} • Grace: ${s.graceMinutes}m • Break: ${s.breakMinutes}m'),
                        trailing: s.isActive ? AppBadge.success(label: 'Active') : AppBadge.error(label: 'Inactive'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _openShiftEditorDialog(BuildContext context, {ShiftModel? existing}) {
    final cubit = context.read<EmployeesCubit>();
    final nameCtrl = TextEditingController(text: existing?.name ?? 'Evening Shift');
    final startCtrl = TextEditingController(text: existing?.startTime ?? '14:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '22:00');
    final graceCtrl = TextEditingController(text: (existing?.graceMinutes ?? 15).toString());
    final breakCtrl = TextEditingController(text: (existing?.breakMinutes ?? 45).toString());

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Configure Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameCtrl, label: 'Shift Name *'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: AppTextField(controller: startCtrl, label: 'Start Time (HH:mm)')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: AppTextField(controller: endCtrl, label: 'End Time (HH:mm)')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: AppTextField(controller: graceCtrl, label: 'Grace Period (mins)', keyboardType: TextInputType.number)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: AppTextField(controller: breakCtrl, label: 'Break (mins)', keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            AppButton.primary(
              label: 'Save Shift',
              onPressed: () {
                cubit.saveShift(
                  ShiftModel(
                    id: existing?.id ?? 0,
                    workspaceId: 1,
                    name: nameCtrl.text.trim(),
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    graceMinutes: int.tryParse(graceCtrl.text) ?? 15,
                    breakMinutes: int.tryParse(breakCtrl.text) ?? 45,
                    isActive: true,
                  ),
                );
                Navigator.pop(dialogCtx);
              },
            ),
          ],
        );
      },
    );
  }

  void _openHolidaysDialog(BuildContext context, EmployeesState state) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Company & Public Holidays'),
              IconButton(
                icon: const Icon(TablerIcons.plus, size: 20),
                tooltip: 'Add Holiday',
                onPressed: () => _openHolidayEditorDialog(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: state.holidays.isEmpty
                ? const Text('No holidays logged for this workspace.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.holidays.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final h = state.holidays[i];
                      return ListTile(
                        leading: const Icon(TablerIcons.calendarSmile, color: AppColors.primary),
                        title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(h.date),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _openHolidayEditorDialog(BuildContext context) {
    final cubit = context.read<EmployeesCubit>();
    final nameCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add Holiday'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(controller: nameCtrl, label: 'Holiday Name *'),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(TablerIcons.calendar, size: 16),
                    label: Text(DateFormat('dd MMMM yyyy').format(pickedDate)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: pickedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2028),
                      );
                      if (d != null) setDlgState(() => pickedDate = d);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Save Holiday',
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      cubit.saveHoliday(
                        HolidayModel(
                          id: 0,
                          workspaceId: 1,
                          name: nameCtrl.text.trim(),
                          date: DateFormat('yyyy-MM-dd').format(pickedDate),
                        ),
                      );
                    }
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openRunPayrollDialog(BuildContext context, EmployeesState state) {
    final cubit = context.read<EmployeesCubit>();
    int? selectedEmpId = state.employees.firstOrNull?.id;
    final selectedEmp = state.employees.where((e) => e.id == selectedEmpId).firstOrNull;

    final basicCtrl = TextEditingController(text: (selectedEmp?.baseSalary ?? 25000.0).toStringAsFixed(0));
    final allowCtrl = TextEditingController(text: (selectedEmp?.allowances ?? 1500.0).toStringAsFixed(0));
    final incCtrl = TextEditingController(text: '0.0');
    final dedCtrl = TextEditingController(text: (selectedEmp?.fixedDeductions ?? 500.0).toStringAsFixed(0));
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final b = double.tryParse(basicCtrl.text) ?? 0.0;
            final a = double.tryParse(allowCtrl.text) ?? 0.0;
            final i = double.tryParse(incCtrl.text) ?? 0.0;
            final d = double.tryParse(dedCtrl.text) ?? 0.0;
            final net = (b + a + i) - d;

            return AlertDialog(
              title: Text('Run Payroll: ${DateFormat('MMMM yyyy').format(DateTime(state.selectedYear, state.selectedMonth))}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedEmpId,
                      decoration: const InputDecoration(labelText: 'Select Staff Member', border: OutlineInputBorder()),
                      items: state.employees.map((e) {
                        return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.employeeCode})'));
                      }).toList(),
                      onChanged: (id) {
                        setDlgState(() {
                          selectedEmpId = id;
                          final emp = state.employees.where((e) => e.id == id).firstOrNull;
                          if (emp != null) {
                            basicCtrl.text = emp.baseSalary.toStringAsFixed(0);
                            allowCtrl.text = emp.allowances.toStringAsFixed(0);
                            dedCtrl.text = emp.fixedDeductions.toStringAsFixed(0);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: AmountField(controller: basicCtrl, label: 'Base Salary', onChanged: (_) => setDlgState(() {}))),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: AmountField(controller: allowCtrl, label: 'Allowances', onChanged: (_) => setDlgState(() {}))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: AmountField(controller: incCtrl, label: 'Incentives', onChanged: (_) => setDlgState(() {}))),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: AmountField(controller: dedCtrl, label: 'Deductions', onChanged: (_) => setDlgState(() {}))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadii.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Payable Salary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(controller: notesCtrl, label: 'Payroll Notes / Remarks'),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Approve & Save Payroll',
                  onPressed: () {
                    if (selectedEmpId != null) {
                      cubit.generatePayroll(
                        employeeId: selectedEmpId!,
                        month: state.selectedMonth,
                        year: state.selectedYear,
                        basicSalary: b,
                        allowances: a,
                        incentive: i,
                        deductions: d,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );
                    }
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDisburseSalaryDialog(BuildContext context, PayrollRecordModel payroll, EmployeeModel? emp) async {
    final cubit = context.read<EmployeesCubit>();
    final deps = AppScope.of(context);
    final accounts = await deps.accountRepository.getAccounts();

    if (!context.mounted) return;

    int selectedAccountId = accounts.firstOrNull?.id ?? 1;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Disburse Salary Payout'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disbursing ₹${payroll.netSalary.toStringAsFixed(2)} for ${emp?.name ?? "Employee"}'),
                  const SizedBox(height: 4),
                  const Text('Posting to double-entry general ledger: Debit Salary Expense, Credit Asset Account.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedAccountId,
                    decoration: const InputDecoration(labelText: 'Payout From Account', border: OutlineInputBorder()),
                    items: accounts.map((acc) {
                      return DropdownMenuItem(value: acc.id, child: Text('${acc.name} (Bal: ₹${acc.balance.toStringAsFixed(0)})'));
                    }).toList(),
                    onChanged: (v) => setDlgState(() => selectedAccountId = v ?? selectedAccountId),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Confirm Disbursement',
                  onPressed: () {
                    cubit.disburseSalary(payroll.id, selectedAccountId);
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openPayslipDialog(BuildContext context, PayrollRecordModel p, EmployeeModel? emp) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Salary Payslip Voucher'),
              AppBadge.success(label: p.status.toUpperCase()),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Center(
                    child: Column(
                      children: [
                        Text('DARVI GROUP AGRI TECH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                        Text('Hubli Main Branch • Karnataka, India', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('Salary Pay Slip & Payment Confirmation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  // Employee Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Staff: ${emp?.name ?? "Employee"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Code: ${emp?.employeeCode ?? "EMP"}', style: const TextStyle(fontSize: 12)),
                          Text('Role: ${emp?.role.toUpperCase() ?? ""}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Period: ${DateFormat('MMMM yyyy').format(DateTime(p.year, p.month))}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Dept: ${emp?.department ?? "Sales"}', style: const TextStyle(fontSize: 12)),
                          if (p.paidDate != null) Text('Paid: ${DateFormat('dd-MM-yyyy').format(p.paidDate!)}', style: const TextStyle(fontSize: 12, color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Breakdown Table
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(8.0), child: Text('Basic Salary')),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text('₹${p.basicSalary.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                      ]),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(8.0), child: Text('Allowances')),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text('₹${p.allowances.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                      ]),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(8.0), child: Text('Sales Incentives / Bonus')),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text('₹${p.incentiveAmount.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                      ]),
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(8.0), child: Text('Statutory / Advance Deductions')),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text('₹${p.deductions.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                      ]),
                      TableRow(
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08)),
                        children: [
                          const Padding(padding: EdgeInsets.all(8.0), child: Text('NET PAYABLE SALARY', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text('₹${p.netSalary.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
            AppButton.primary(
              label: 'Print Voucher',
              icon: TablerIcons.printer,
              onPressed: () => Navigator.pop(dialogCtx),
            ),
          ],
        );
      },
    );
  }

  void _openTargetOrRuleDialog(BuildContext context, EmployeesState state) {
    final cubit = context.read<EmployeesCubit>();
    int? selectedEmpId = state.employees.firstOrNull?.id;
    final targetRevCtrl = TextEditingController(text: '100000');
    final ruleNameCtrl = TextEditingController(text: 'Monthly Sales 2% Bonus');
    final thresholdCtrl = TextEditingController(text: '50000');
    final rewardRateCtrl = TextEditingController(text: '2.0');
    String ruleType = 'percentage_revenue';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            title: const Text('Sales Targets & Incentive Rules'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(
                    labelColor: AppColors.primary,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'Assign Target'),
                      Tab(text: 'New Rule'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 250,
                    child: TabBarView(
                      children: [
                        // Assign Target
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: selectedEmpId,
                                decoration: const InputDecoration(labelText: 'Staff Member', border: OutlineInputBorder()),
                                items: state.employees.map((e) {
                                  return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role})'));
                                }).toList(),
                                onChanged: (v) => selectedEmpId = v,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AmountField(controller: targetRevCtrl, label: 'Target Revenue (₹) *'),
                              const SizedBox(height: AppSpacing.md),
                              AppButton.primary(
                                label: 'Save Target',
                                onPressed: () {
                                  if (selectedEmpId != null) {
                                    cubit.saveSalesTarget(
                                      SalesTargetModel(
                                        id: 0,
                                        workspaceId: 1,
                                        employeeId: selectedEmpId!,
                                        targetType: 'revenue',
                                        targetAmount: double.tryParse(targetRevCtrl.text) ?? 100000.0,
                                        currentAmount: 0.0,
                                        startDate: DateTime(state.selectedYear, state.selectedMonth, 1),
                                        endDate: DateTime(state.selectedYear, state.selectedMonth + 1, 0, 23, 59, 59),
                                        status: 'in_progress',
                                      ),
                                    );
                                  }
                                  Navigator.pop(dialogCtx);
                                },
                              ),
                            ],
                          ),
                        ),
                        // New Rule
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              AppTextField(controller: ruleNameCtrl, label: 'Rule Name *'),
                              const SizedBox(height: AppSpacing.sm),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: ruleType,
                                decoration: const InputDecoration(labelText: 'Rule Type', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'percentage_revenue', child: Text('Percentage on Revenue (%)')),
                                  DropdownMenuItem(value: 'fixed_bonus', child: Text('Fixed Cash Bonus (₹)')),
                                ],
                                onChanged: (v) => ruleType = v ?? ruleType,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(child: AmountField(controller: thresholdCtrl, label: 'Min Threshold (₹)')),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(child: AppTextField(controller: rewardRateCtrl, label: 'Reward Rate (% or ₹)', keyboardType: TextInputType.number)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppButton.primary(
                                label: 'Create Incentive Rule',
                                onPressed: () {
                                  cubit.createIncentiveRule(
                                    IncentiveRuleModel(
                                      id: 0,
                                      workspaceId: 1,
                                      name: ruleNameCtrl.text.trim(),
                                      ruleType: ruleType,
                                      thresholdAmount: double.tryParse(thresholdCtrl.text) ?? 0.0,
                                      rewardRate: double.tryParse(rewardRateCtrl.text) ?? 2.0,
                                      isActive: true,
                                    ),
                                  );
                                  Navigator.pop(dialogCtx);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
            ],
          ),
        );
      },
    );
  }

  void _openIncentiveClaimApprovalDialog(BuildContext context, IncentiveClaimModel claim, bool approve) {
    final cubit = context.read<EmployeesCubit>();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(approve ? 'Approve Incentive Claim' : 'Reject Incentive Claim'),
          content: Text('Confirm ${approve ? "approval" : "rejection"} of claim #CD-${claim.id} for ₹${claim.amount.toStringAsFixed(2)}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            AppButton.primary(
              label: approve ? 'Approve' : 'Reject',
              onPressed: () {
                cubit.approveIncentiveClaim(claim.id, approve);
                Navigator.pop(dialogCtx);
              },
            ),
          ],
        );
      },
    );
  }

  void _openPayoutClaimDialog(BuildContext context, IncentiveClaimModel claim) async {
    final cubit = context.read<EmployeesCubit>();
    final deps = AppScope.of(context);
    final accounts = await deps.accountRepository.getAccounts();

    if (!context.mounted) return;

    int selectedAccountId = accounts.firstOrNull?.id ?? 1;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Disburse Incentive Claim Payout'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disbursing ₹${claim.amount.toStringAsFixed(2)} for incentive claim #CD-${claim.id}'),
                  const SizedBox(height: 4),
                  const Text('Double-entry ledger posting: Debit Incentive Expense, Credit Asset Account.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedAccountId,
                    decoration: const InputDecoration(labelText: 'Payout From Account', border: OutlineInputBorder()),
                    items: accounts.map((acc) {
                      return DropdownMenuItem(value: acc.id, child: Text('${acc.name} (Bal: ₹${acc.balance.toStringAsFixed(0)})'));
                    }).toList(),
                    onChanged: (v) => setDlgState(() => selectedAccountId = v ?? selectedAccountId),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                AppButton.primary(
                  label: 'Disburse Payout',
                  onPressed: () {
                    cubit.payoutIncentiveClaim(claim.id, selectedAccountId);
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
