import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/core/errors/app_exception.dart';
import 'package:mini_pos_inventory/core/models/app_models.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/data/repositories/local_employee_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_ledger_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_sales_repository.dart';

void main() {
  late AppDatabase db;
  late LocalLedgerRepository ledgerRepo;
  late LocalEmployeeRepository employeeRepo;
  late LocalSalesRepository salesRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledgerRepo = LocalLedgerRepository(db);
    employeeRepo = LocalEmployeeRepository(db, ledgerRepo);
    salesRepo = LocalSalesRepository(db, ledgerRepo);

    await SeedData(db).ensureSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  group('GROUP 2 - Employee Management Suite', () {
    test('1. Employee registration with all 6 sections and retrieval', () async {
      final emp = EmployeeModel(
        id: 0,
        workspaceId: 1,
        employeeCode: 'EMP999',
        name: 'Ravi Kumar',
        phone: '9876543210',
        email: 'ravi.kumar@darvigroup.com',
        role: 'field_officer',
        designation: 'Senior Agri Field Officer',
        department: 'Operations',
        loginPin: '4321',
        baseSalary: 28000.0,
        joiningDate: DateTime(2025, 5, 1),
        isActive: true,
        dateOfBirth: '1992-08-15',
        gender: 'male',
        address: 'Gokul Road, Hubli',
        emergencyContact: '9876500000',
        employmentType: 'full_time',
        workLocation: 'Dharwad Sector',
        salaryType: 'monthly',
        allowances: 3500.0,
        fixedDeductions: 800.0,
        bankAccountName: 'Ravi Kumar',
        bankName: 'State Bank of India',
        bankAccountNumber: '30291823719',
        bankIfsc: 'SBIN0001234',
        shiftId: 1,
      );

      final id = await employeeRepo.upsertEmployee(emp);
      expect(id, greaterThan(0));

      final retrieved = await employeeRepo.getEmployee(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Ravi Kumar');
      expect(retrieved.employeeCode, 'EMP999');
      expect(retrieved.role, 'field_officer');
      expect(retrieved.baseSalary, 28000.0);
      expect(retrieved.allowances, 3500.0);
      expect(retrieved.bankName, 'State Bank of India');
    });

    test('2. Duplicate employee code prevention', () async {
      final emp1 = EmployeeModel(
        id: 0,
        workspaceId: 1,
        employeeCode: 'EMP_DUP_01',
        name: 'Staff One',
        phone: '9111111111',
        role: 'cashier',
        designation: 'Cashier',
        loginPin: '1111',
        joiningDate: DateTime.now(),
      );
      await employeeRepo.upsertEmployee(emp1);

      final emp2 = EmployeeModel(
        id: 0,
        workspaceId: 1,
        employeeCode: 'EMP_DUP_01', // duplicate code
        name: 'Staff Two',
        phone: '9222222222',
        role: 'cashier',
        designation: 'Cashier',
        loginPin: '2222',
        joiningDate: DateTime.now(),
      );

      expect(() => employeeRepo.upsertEmployee(emp2), throwsA(isA<AppException>()));
    });

    test('3. Safe deactivation prevents permanent deletion of employees with history', () async {
      final emps = await employeeRepo.getEmployees();
      final cashier = emps.firstWhere((e) => e.employeeCode == 'EMP003');

      // Log an attendance record for this cashier
      await employeeRepo.recordAttendance(
        employeeId: cashier.id,
        date: DateTime.now(),
        status: 'present',
      );

      // Verify canDeleteEmployee returns false
      final canDelete = await employeeRepo.canDeleteEmployee(cashier.id);
      expect(canDelete, isFalse);

      // Attempting hard delete must throw AppException
      expect(() => employeeRepo.deleteEmployee(cashier.id), throwsA(isA<AppException>()));

      // Deactivation succeeds safely
      await employeeRepo.setEmployeeStatus(cashier.id, false);
      final updated = await employeeRepo.getEmployee(cashier.id);
      expect(updated!.isActive, isFalse);
    });
  });

  group('GROUP 2 - Attendance, Shifts & Leaves Suite', () {
    test('4. Shift configuration CRUD', () async {
      final shift = ShiftModel(
        id: 0,
        workspaceId: 1,
        name: 'Night Watch Shift',
        startTime: '22:00',
        endTime: '06:00',
        breakMinutes: 45,
        graceMinutes: 10,
        isOvernight: true,
        isActive: true,
      );

      final id = await employeeRepo.saveShift(shift);
      expect(id, greaterThan(0));

      final allShifts = await employeeRepo.getShifts();
      expect(allShifts.any((s) => s.name == 'Night Watch Shift'), isTrue);
    });

    test('5. Daily Attendance, Correction and Audit Logging', () async {
      final emps = await employeeRepo.getEmployees();
      final emp = emps.first;

      final today = DateTime.now();
      await employeeRepo.recordAttendance(
        employeeId: emp.id,
        date: today,
        status: 'absent',
        workingHours: 0.0,
      );

      final attRecords = await employeeRepo.getAttendance(date: today);
      final record = attRecords.firstWhere((a) => a.employeeId == emp.id);
      expect(record.status, 'absent');

      // Manual correction
      await employeeRepo.correctAttendance(
        attendanceId: record.id,
        status: 'present',
        workingHours: 8.0,
        reason: 'Staff arrived on time; biometric machine was offline.',
        correctedBy: 'Admin Totad',
      );

      final updatedRecords = await employeeRepo.getAttendance(date: today);
      final updatedRecord = updatedRecords.firstWhere((a) => a.employeeId == emp.id);
      expect(updatedRecord.status, 'present');
      expect(updatedRecord.workingHours, 8.0);
      expect(updatedRecord.correctedBy, 'Admin Totad');

      // Verify audit log entry exists
      final auditLog = await db.customSelect(
        'SELECT * FROM employee_audit_logs WHERE employee_id = ? AND action = ?',
        readsFrom: {},
        variables: [Variable.withInt(emp.id), Variable.withString('attendance_correction')],
      ).get();
      expect(auditLog.isNotEmpty, isTrue);
      expect(auditLog.first.data['old_value'], 'absent');
      expect(auditLog.first.data['new_value'], 'present');
    });

    test('6. Leave request, approval and automatic attendance marking', () async {
      final emps = await employeeRepo.getEmployees();
      final emp = emps.first;

      final start = DateTime(2026, 6, 10);
      final end = DateTime(2026, 6, 12);

      final leaveId = await employeeRepo.requestLeave(LeaveRequestModel(
        id: 0,
        workspaceId: 1,
        employeeId: emp.id,
        startDate: start,
        endDate: end,
        totalDays: 3.0,
        leaveType: 'casual',
        reason: 'Attending agricultural technology expo in Bengaluru',
        createdAt: DateTime.now(),
      ));
      expect(leaveId, greaterThan(0));

      // Approve leave
      await employeeRepo.approveLeave(
        leaveId: leaveId,
        approved: true,
        remarks: 'Approved for expo attendance',
        approvedBy: 'Managing Director',
      );

      final leaves = await employeeRepo.getLeaves(employeeId: emp.id);
      final approvedLeave = leaves.firstWhere((l) => l.id == leaveId);
      expect(approvedLeave.status, 'approved');
      expect(approvedLeave.approvedBy, 'Managing Director');

      // Verify attendance for that day is marked as on_leave
      final attJune10 = await employeeRepo.getAttendance(date: start);
      final empAtt = attJune10.firstWhere((a) => a.employeeId == emp.id);
      expect(empAtt.status, 'on_leave');
    });

    test('7. Monthly attendance summary calculation', () async {
      final summaries = await employeeRepo.getMonthlyAttendanceSummary(month: 11, year: 2026);
      expect(summaries.isNotEmpty, isTrue);
      expect(summaries.first.totalDays, 30); // November has 30 days
    });
  });

  group('GROUP 2 - Payroll & Double-Entry Ledger Suite', () {
    test('8. Monthly Payroll Generation, Approval and Disbursement with Double-Entry Ledger balance', () async {
      final emps = await employeeRepo.getEmployees();
      final emp = emps.firstWhere((e) => e.employeeCode == 'EMP002'); // Store Manager

      final payrollId = await employeeRepo.processPayroll(
        employeeId: emp.id,
        month: 11,
        year: 2026,
        basicSalary: 30000.0,
        allowances: 3000.0,
        incentiveAmount: 2500.0,
        deductions: 500.0,
        notes: 'November 2026 approved payroll',
      );
      expect(payrollId, greaterThan(0));

      final records = await employeeRepo.getPayrollRecords(month: 11, year: 2026);
      final record = records.firstWhere((r) => r.id == payrollId);
      expect(record.netSalary, 35000.0); // (30000 + 3000 + 2500) - 500
      expect(record.status, 'approved');

      // Disburse from Account #2 (HDFC Bank)
      await employeeRepo.disbursePayroll(payrollId: payrollId, fromAccountId: 2);

      final updatedRecords = await employeeRepo.getPayrollRecords(month: 11, year: 2026);
      final updatedRecord = updatedRecords.firstWhere((r) => r.id == payrollId);
      expect(updatedRecord.status, 'paid');
      expect(updatedRecord.paidFromAccountId, 2);
      expect(updatedRecord.paidDate, isNotNull);

      // Verify Double-Entry Ledger Posting:
      // Entry 1: Debit Salary Expense = 35000.0
      // Entry 2: Credit HDFC Bank = 35000.0
      final entries = await ledgerRepo.getRecentLedgerEntries(limit: 20);
      final salaryDebit = entries.firstWhere((e) => e.partyId == emp.id && e.debit == 35000.0);
      final salaryCredit = entries.firstWhere((e) => e.accountId == 2 && e.credit == 35000.0);

      expect(salaryDebit.partyType, 'employee');
      expect(salaryDebit.partyId, emp.id);
      expect(salaryCredit.accountId, 2);
    });
  });

  group('GROUP 2 - POS Sales Attribution & Incentives Suite', () {
    test('9. Attributing POS sales to employee and incentive rule calculation', () async {
      final emps = await employeeRepo.getEmployees();
      final cashier = emps.firstWhere((e) => e.employeeCode == 'EMP003');

      // Create a completed sale attributed to this cashier
      final products = await db.select(db.products).get();
      final prod = products.first;

      await salesRepo.checkout(SaleCheckoutInput(
        customerId: 1,
        items: [
          CartItem(
            productId: prod.id,
            name: prod.name,
            sku: prod.sku,
            cost: prod.cost,
            price: prod.price,
            qty: 10,
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        paid: prod.price * 10,
      ));

      // Attribute the sale to this cashier in SQLite
      final lastSale = await db.customSelect('SELECT id FROM sales ORDER BY id DESC LIMIT 1', readsFrom: {}).getSingle();
      final saleId = lastSale.data['id'] as int;
      await db.customStatement('UPDATE sales SET employee_id = ? WHERE id = ?', [cashier.id, saleId]);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final attribution = await employeeRepo.calculateSalesAttributed(
        employeeId: cashier.id,
        startDate: start,
        endDate: end,
      );

      expect(attribution['completedInvoices'], greaterThanOrEqualTo(1));
      expect(attribution['grossRevenue'], greaterThan(0));

      // Calculate incentive based on rule
      final incentive = await employeeRepo.calculateIncentivesFromSales(
        employeeId: cashier.id,
        startDate: start,
        endDate: end,
      );
      expect(incentive, greaterThanOrEqualTo(0.0));
    });

    test('10. Incentive Claim Approval and Ledger Payout', () async {
      final emps = await employeeRepo.getEmployees();
      final emp = emps.first;

      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.customStatement('''
        INSERT INTO incentive_claims (workspace_id, employee_id, amount, description, status, created_at)
        VALUES (1, ?, 1500.0, 'October Sales Target Overachievement Bonus', 'pending', ?)
      ''', [emp.id, nowSeconds]);

      final lastClaim = await db.customSelect('SELECT id FROM incentive_claims ORDER BY id DESC LIMIT 1', readsFrom: {}).getSingle();
      final claimId = lastClaim.data['id'] as int;

      // Approve claim
      await employeeRepo.approveIncentiveClaim(claimId, true);
      var claims = await employeeRepo.getIncentiveClaims();
      var claim = claims.firstWhere((c) => c.id == claimId);
      expect(claim.status, 'approved');

      // Payout claim from Account #1 (Cash)
      await employeeRepo.payoutIncentiveClaim(claimId: claimId, fromAccountId: 1);

      claims = await employeeRepo.getIncentiveClaims();
      claim = claims.firstWhere((c) => c.id == claimId);
      expect(claim.status, 'paid');
      expect(claim.paidFromAccountId, 1);

      // Verify Double-Entry Ledger Posting:
      // Entry 1: Debit Incentive Expense = 1500.0
      // Entry 2: Credit Cash Account #1 = 1500.0
      final entries = await ledgerRepo.getRecentLedgerEntries(limit: 10);
      final claimDebit = entries.firstWhere((e) => e.referenceId == claimId && e.debit == 1500.0);
      final claimCredit = entries.firstWhere((e) => e.referenceId == claimId && e.credit == 1500.0);

      expect(claimDebit.partyType, 'employee');
      expect(claimCredit.accountId, 1);
    });
  });
}
