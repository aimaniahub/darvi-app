import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';

import 'package:mini_pos_inventory/app/app_dependencies.dart';
import 'package:mini_pos_inventory/app/app_scope.dart';
import 'package:mini_pos_inventory/app/theme/app_theme.dart';
import 'package:mini_pos_inventory/core/errors/app_exception.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/core/widgets/widgets.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/features/employees/presentation/pages/employees_page.dart';
import 'package:mini_pos_inventory/features/employees/presentation/cubit/employees_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppDependencies deps;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureGroup1SchemaTables();
    await db.ensureGroup2SchemaTables();
    await db.ensureGroup3SchemaTables();
    await db.ensureGroup4SchemaTables();
    await db.sanitizeDateTimeColumns();
    await SeedData(db).ensureSeeded();

    deps = AppDependencies.forTesting(database: db);
  });

  tearDown(() async {
    await deps.dispose();
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(1366, 900)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: AppScope(
        dependencies: deps,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: child,
        ),
      ),
    );
  }

  group('DARVI PHASE 4.3 — EMPLOYEES, ATTENDANCE & PAYROLL INTEGRATION TESTS', () {
    testWidgets('1. EmployeesPage renders AppStatGrid with 6 KPIs, AppFilterBar, and Desktop Data Table',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const EmployeesPage()));
      await tester.pumpAndSettle();

      // Verify Header Titles
      expect(find.text('Employee Management & Profiles'), findsOneWidget);
      expect(
        find.text('Staff directory, role permissions, salaries & employee profiles'),
        findsOneWidget,
      );

      // Verify 6-KPI Stat Grid
      expect(find.byType(AppStatGrid), findsWidgets);
      expect(find.text('Total Staff'), findsOneWidget);
      expect(find.text('Active Employees'), findsOneWidget);
      expect(find.text('Inactive / On Leave'), findsOneWidget);
      expect(find.text('Cashiers & Store Staff'), findsOneWidget);
      expect(find.text('Field & Agronomists'), findsOneWidget);
      expect(find.text('Monthly Base Payroll'), findsOneWidget);

      // Verify Filter Bar
      expect(find.byType(AppFilterBar), findsOneWidget);
      expect(find.text('All Staff'), findsOneWidget);
      expect(find.text('Active Only'), findsOneWidget);
      expect(find.text('Inactive Only'), findsOneWidget);

      // Verify Desktop Table
      expect(find.byType(AppDataTable<EmployeeModel>), findsOneWidget);
      expect(find.text('Staff Member'), findsOneWidget);
      expect(find.text('Code & PIN'), findsOneWidget);
      expect(find.text('Role & Dept'), findsOneWidget);
      expect(find.text('Base Salary'), findsOneWidget);
    });

    test('2. Employee CRUD and RBAC Role Permission Enforcement', () async {
      final cubit = EmployeesCubit(employeeRepository: deps.employeeRepository);
      await cubit.load();

      // Verify initial seeded employees
      expect(cubit.state.employees.isNotEmpty, isTrue);
      final initialCount = cubit.state.employees.length;

      // Register new employee
      final newEmp = EmployeeModel(
        id: 0,
        workspaceId: 1,
        employeeCode: 'EMP-TEST-99',
        name: 'Suresh Patil',
        phone: '9845098450',
        email: 'suresh@darvi.in',
        role: 'cashier',
        designation: 'POS Terminal Cashier',
        department: 'Sales',
        loginPin: '8899',
        baseSalary: 24000.0,
        joiningDate: DateTime(2026, 1, 15),
        isActive: true,
        address: 'Dharwad Bypass',
        emergencyContact: '9845000000',
        employmentType: 'full_time',
        salaryType: 'monthly',
        allowances: 1200.0,
        fixedDeductions: 400.0,
      );

      await cubit.saveEmployee(newEmp);
      expect(cubit.state.employees.length, initialCount + 1);

      final added = cubit.state.employees.firstWhere((e) => e.employeeCode == 'EMP-TEST-99');
      expect(added.name, 'Suresh Patil');
      expect(added.role, 'cashier');

      // RBAC: Non-admin caller attempting to change role is rejected
      await cubit.changeEmployeeRole(
        employeeId: added.id,
        newRole: 'admin',
        callerRole: UserRole.cashier,
      );
      expect(cubit.state.error, contains('Permission denied'));

      // RBAC: Admin caller successfully changes role
      await cubit.changeEmployeeRole(
        employeeId: added.id,
        newRole: 'manager',
        callerRole: UserRole.admin,
      );
      final updatedRole = cubit.state.employees.firstWhere((e) => e.id == added.id);
      expect(updatedRole.role, 'manager');

      // RBAC: Non-admin attempting to deactivate is rejected
      await cubit.setEmployeeStatus(added.id, false, callerRole: UserRole.cashier);
      expect(cubit.state.error, contains('Permission denied'));

      // RBAC: Admin successfully deactivates
      await cubit.setEmployeeStatus(added.id, false, callerRole: UserRole.admin);
      final deactivated = cubit.state.employees.firstWhere((e) => e.id == added.id);
      expect(deactivated.isActive, isFalse);
    });

    test('3. Attendance Check-In/Out, Duplicate Prevention & Invalid Time Sequence', () async {
      final cubit = EmployeesCubit(employeeRepository: deps.employeeRepository);
      await cubit.load();
      final emp = cubit.state.employees.first;
      final today = DateTime.now();

      // Check-In
      await cubit.recordAttendance(
        employeeId: emp.id,
        date: today,
        checkIn: DateTime(today.year, today.month, today.day, 9, 15),
        status: 'present',
        workingHours: 8.0,
      );

      final attRecords = await deps.employeeRepository.getAttendance(date: today);
      expect(attRecords.any((a) => a.employeeId == emp.id && a.status == 'present'), isTrue);

      // Check-Out
      await cubit.recordAttendance(
        employeeId: emp.id,
        date: today,
        checkIn: DateTime(today.year, today.month, today.day, 9, 15),
        checkOut: DateTime(today.year, today.month, today.day, 18, 0),
        status: 'present',
        workingHours: 8.75,
      );

      // Duplicate prevention: ensures still exactly one attendance record for that date
      final updatedRecords = await deps.employeeRepository.getAttendance(date: today);
      final forEmp = updatedRecords.where((a) => a.employeeId == emp.id).toList();
      expect(forEmp.length, 1);
      expect(forEmp.first.checkOutTime, isNotNull);

      // Invalid time sequence: Check-Out before Check-In is rejected
      await cubit.recordAttendance(
        employeeId: emp.id,
        date: today,
        checkIn: DateTime(today.year, today.month, today.day, 18, 0),
        checkOut: DateTime(today.year, today.month, today.day, 9, 0),
        status: 'present',
      );
      expect(cubit.state.error, contains('Invalid time sequence'));

      // Attendance Correction with supervisor audit
      await cubit.correctAttendance(
        attendanceId: forEmp.first.id,
        status: 'present',
        workingHours: 9.0,
        reason: 'Authorized overtime shift',
        correctedBy: 'StoreManager',
      );

      final correctedRecords = await deps.employeeRepository.getAttendance(date: today);
      expect(correctedRecords.firstWhere((a) => a.id == forEmp.first.id).workingHours, 9.0);
    });

    test('4. Leave Request, Approval Workflow and Roster Integration', () async {
      final cubit = EmployeesCubit(employeeRepository: deps.employeeRepository);
      await cubit.load();
      final emp = cubit.state.employees.first;

      // Submit leave application
      final leave = LeaveRequestModel(
        id: 0,
        workspaceId: 1,
        employeeId: emp.id,
        startDate: DateTime.now().add(const Duration(days: 2)),
        endDate: DateTime.now().add(const Duration(days: 4)),
        totalDays: 3.0,
        leaveType: 'sick',
        reason: 'Medical treatment',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await cubit.requestLeave(leave);
      expect(cubit.state.leaves.any((l) => l.employeeId == emp.id && l.status == 'pending'), isTrue);

      final submitted = cubit.state.leaves.firstWhere((l) => l.employeeId == emp.id && l.status == 'pending');

      // Approve leave
      await cubit.approveLeave(
        leaveId: submitted.id,
        approved: true,
        remarks: 'Approved by Branch HR',
        approvedBy: 'Admin',
      );

      expect(cubit.state.leaves.firstWhere((l) => l.id == submitted.id).status, 'approved');
    });

    test('5. Payroll Run, Duplicate Run Prevention, Disbursal & Ledger Equilibrium', () async {
      final cubit = EmployeesCubit(employeeRepository: deps.employeeRepository);
      await cubit.load();
      final emp = cubit.state.employees.first;
      final accounts = await deps.accountRepository.getAccounts();
      expect(accounts.isNotEmpty, isTrue);

      final payingAccount = accounts.first;
      final initialBalance = payingAccount.balance;

      // Generate Monthly Payroll
      await cubit.generatePayroll(
        employeeId: emp.id,
        month: 11,
        year: 2026,
        basicSalary: 30000.0,
        incentive: 2500.0,
        allowances: 1500.0,
        deductions: 1000.0,
        notes: 'November regular salary run',
      );

      expect(cubit.state.payrollRecords.any((p) => p.employeeId == emp.id && p.month == 11), isTrue);
      final payroll = cubit.state.payrollRecords.firstWhere((p) => p.employeeId == emp.id && p.month == 11);

      // Verify Net Salary calculation: (30000 + 2500 + 1500) - 1000 = 33000
      expect(payroll.netSalary, 33000.0);
      expect(payroll.status, 'approved');

      // Disburse Salary payout to funding account
      await cubit.disburseSalary(payroll.id, payingAccount.id);

      // Verify status updated to paid
      final updatedPayroll = cubit.state.payrollRecords.firstWhere((p) => p.id == payroll.id);
      expect(updatedPayroll.status, 'paid');

      // Verify funding account debited in repository
      final updatedAccounts = await deps.accountRepository.getAccounts();
      final updatedPayingAccount = updatedAccounts.firstWhere((a) => a.id == payingAccount.id);
      expect(updatedPayingAccount.balance, initialBalance - 33000.0);

      // Verify Double-Entry General Ledger Equilibrium: sum(Debit) == sum(Credit)
      final ledgerEntries = await deps.ledgerRepository.getRecentLedgerEntries(limit: 200);
      final salaryEntries = ledgerEntries.where((e) => e.transactionType == 'salary' && e.referenceId == payroll.id).toList();
      expect(salaryEntries.length, 2);

      final totalDebits = salaryEntries.fold<double>(0.0, (acc, e) => acc + e.debit);
      final totalCredits = salaryEntries.fold<double>(0.0, (acc, e) => acc + e.credit);
      expect(totalDebits, 33000.0);
      expect(totalCredits, 33000.0);

      // Duplicate payout prevention: disbursing already paid salary must throw
      expect(
        () => deps.employeeRepository.disbursePayroll(payrollId: payroll.id, fromAccountId: payingAccount.id),
        throwsA(isA<AppException>()),
      );

      // Duplicate run prevention: re-processing paid payroll must throw
      expect(
        () => deps.employeeRepository.processPayroll(
          employeeId: emp.id,
          month: 11,
          year: 2026,
          basicSalary: 30000.0,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('6. POS Sales Attribution, Return Reversals & Incentive Claim Payout', () async {
      final cubit = EmployeesCubit(employeeRepository: deps.employeeRepository);
      await cubit.load();
      final emp = cubit.state.employees.first;
      final accounts = await deps.accountRepository.getAccounts();
      final payingAccount = accounts.first;

      // Calculate attributed sales with returns deducted
      final attr = await deps.employeeRepository.calculateSalesAttributed(
        employeeId: emp.id,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(attr.containsKey('netRevenue'), isTrue);
      expect(attr.containsKey('returnedAmount'), isTrue);
      expect((attr['netRevenue'] as num) >= 0, isTrue);

      // Create an incentive claim
      final claimId = await db.customInsert(
        'INSERT INTO incentive_claims (workspace_id, employee_id, amount, description, status, created_at) '
        'VALUES (1, ?, 1500.0, "Monthly target achievement bonus", "pending", ?)',
        variables: [Variable.withInt(emp.id), Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000)],
      );

      await cubit.load();
      expect(cubit.state.incentiveClaims.any((c) => c.id == claimId), isTrue);

      // Payout unapproved claim must fail
      expect(
        () => deps.employeeRepository.payoutIncentiveClaim(claimId: claimId, fromAccountId: payingAccount.id),
        throwsA(isA<AppException>()),
      );

      // Approve claim
      await cubit.approveIncentiveClaim(claimId, true);
      expect(cubit.state.incentiveClaims.firstWhere((c) => c.id == claimId).status, 'approved');

      // Disburse payout to account
      await cubit.payoutIncentiveClaim(claimId, payingAccount.id);
      expect(cubit.state.incentiveClaims.firstWhere((c) => c.id == claimId).status, 'paid');

      // Duplicate payout prevention on incentive claims
      expect(
        () => deps.employeeRepository.payoutIncentiveClaim(claimId: claimId, fromAccountId: payingAccount.id),
        throwsA(isA<AppException>()),
      );

      // Verify general ledger balance for incentive payout
      final ledgerEntries = await deps.ledgerRepository.getRecentLedgerEntries(limit: 200);
      final claimEntries = ledgerEntries.where((e) => e.transactionType == 'incentive' && e.referenceId == claimId).toList();
      expect(claimEntries.length, 2);
      expect(claimEntries.fold<double>(0.0, (acc, e) => acc + e.debit), 1500.0);
      expect(claimEntries.fold<double>(0.0, (acc, e) => acc + e.credit), 1500.0);
    });

    testWidgets('7. Responsive Viewport Adaptation between Desktop Table and Mobile Cards',
        (WidgetTester tester) async {
      // Mobile Viewport (375 x 812)
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const EmployeesPage(), size: const Size(375, 812)));
      await tester.pumpAndSettle();

      // On mobile, AppDataTable is swapped for AppCard.bordered rows
      expect(find.byType(AppCard), findsWidgets);
      expect(find.byType(AppDataTable<EmployeeModel>), findsNothing);
      expect(find.text('Total Staff'), findsOneWidget);

      // Switch to Attendance Tab on mobile
      final attendanceTabFinder = find.textContaining('Attendance & Leaves');
      await tester.ensureVisible(attendanceTabFinder);
      await tester.tap(attendanceTabFinder);
      await tester.pumpAndSettle();

      expect(find.text('Present Today'), findsOneWidget);
      expect(find.byType(AppStatGrid), findsWidgets);

      // Switch to Payroll Tab on mobile
      final payrollTabFinder = find.textContaining('Payroll & Incentives');
      await tester.ensureVisible(payrollTabFinder);
      await tester.tap(payrollTabFinder);
      await tester.pumpAndSettle();

      expect(find.text('Total Period Payroll'), findsOneWidget);
      expect(find.byType(AppStatGrid), findsWidgets);
    });
  });
}
