import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/repositories/repositories.dart';

class LocalEmployeeRepository implements EmployeeRepository {
  LocalEmployeeRepository(this._db, this._ledgerRepository);

  final AppDatabase _db;
  final LedgerRepository _ledgerRepository;

  static DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val * 1000);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt() * 1000);
    if (val is String) {
      final asInt = int.tryParse(val);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      final dt = DateTime.tryParse(val);
      if (dt != null) return dt;
    }
    return DateTime.now();
  }

  static DateTime? _tryParseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val * 1000);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt() * 1000);
    if (val is String) {
      final asInt = int.tryParse(val);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      return DateTime.tryParse(val);
    }
    return null;
  }

  EmployeeModel _mapEmployee(dynamic r) {
    return EmployeeModel(
      id: r.data['id'] as int? ?? 0,
      workspaceId: r.data['workspace_id'] as int? ?? 1,
      employeeCode: r.data['employee_code'] as String? ?? '',
      name: r.data['name'] as String? ?? '',
      phone: r.data['phone'] as String? ?? '',
      email: r.data['email'] as String?,
      role: r.data['role'] as String? ?? 'cashier',
      designation: r.data['designation'] as String? ?? 'Staff',
      department: r.data['department'] as String? ?? 'Sales',
      loginPin: r.data['login_pin'] as String? ?? '1234',
      baseSalary: (r.data['base_salary'] as num? ?? 0.0).toDouble(),
      joiningDate: _parseDateTime(r.data['joining_date']),
      isActive: (r.data['is_active'] as int? ?? 1) == 1,
      dateOfBirth: r.data['date_of_birth'] as String?,
      gender: r.data['gender'] as String? ?? 'male',
      address: r.data['address'] as String?,
      emergencyContact: r.data['emergency_contact'] as String?,
      employmentType: r.data['employment_type'] as String? ?? 'full_time',
      workLocation: r.data['work_location'] as String? ?? 'Hubli Store',
      salaryType: r.data['salary_type'] as String? ?? 'monthly',
      allowances: (r.data['allowances'] as num? ?? 0.0).toDouble(),
      fixedDeductions: (r.data['fixed_deductions'] as num? ?? 0.0).toDouble(),
      bankAccountName: r.data['bank_account_name'] as String?,
      bankName: r.data['bank_name'] as String?,
      bankAccountNumber: r.data['bank_account_number'] as String?,
      bankIfsc: r.data['bank_ifsc'] as String?,
      shiftId: r.data['shift_id'] as int?,
    );
  }

  @override
  Future<List<EmployeeModel>> getEmployees({int workspaceId = 1, bool activeOnly = true, UserRole? callerRole}) async {
    final query = activeOnly
        ? 'SELECT * FROM employees WHERE workspace_id = ? AND is_active = 1 ORDER BY id ASC'
        : 'SELECT * FROM employees WHERE workspace_id = ? ORDER BY id ASC';
    final rows = await _db.customSelect(query, readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    final list = rows.map(_mapEmployee).toList();
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      return list.map((e) => e.redacted()).toList();
    }
    return list;
  }

  @override
  Future<EmployeeModel?> getEmployee(int id, {int? workspaceId, UserRole? callerRole}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM employees WHERE id = ? ${workspaceId != null ? 'AND workspace_id = ?' : ''}',
      readsFrom: {},
      variables: [
        Variable.withInt(id),
        if (workspaceId != null) Variable.withInt(workspaceId),
      ],
    ).get();
    if (rows.isEmpty) return null;
    final emp = _mapEmployee(rows.first);
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      return emp.redacted();
    }
    return emp;
  }

  @override
  Future<EmployeeModel?> getEmployeeByPin(String pin) async {
    final rows = await _db.customSelect(
      'SELECT * FROM employees WHERE is_active = 1',
      readsFrom: {},
    ).get();

    for (final row in rows) {
      final storedPin = row.data['login_pin'] as String? ?? '';
      final verifyResult = HashHelper.verify(pin.trim(), storedPin);
      if (verifyResult.matches) {
        final id = row.data['id'] as int;
        if (verifyResult.needsRehash) {
          final newHash = HashHelper.hashPin(pin.trim());
          await _db.customStatement(
            'UPDATE employees SET login_pin = ? WHERE id = ?',
            [newHash, id],
          );
        }
        return _mapEmployee(row);
      }
    }
    return null;
  }

  @override
  Future<int> upsertEmployee(EmployeeModel e, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Managing employees requires admin or manager permission');
    }

    // Duplicate validation on code
    final existingCode = await _db.customSelect(
      'SELECT id FROM employees WHERE workspace_id = ? AND employee_code = ? AND id != ?',
      readsFrom: {},
      variables: [Variable.withInt(e.workspaceId), Variable.withString(e.employeeCode.trim()), Variable.withInt(e.id)],
    ).get();
    if (existingCode.isNotEmpty) {
      throw AppException('Employee code "${e.employeeCode}" is already assigned to another employee.');
    }

    final pinToSave = e.loginPin.startsWith(r'$pbkdf2-sha256$')
        ? e.loginPin
        : HashHelper.hashPin(e.loginPin.trim());

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final joinSeconds = e.joiningDate.millisecondsSinceEpoch ~/ 1000;

    if (e.id <= 0) {
      await _db.customStatement('''
        INSERT INTO employees (
          workspace_id, employee_code, name, phone, email, role, designation, department,
          login_pin, base_salary, joining_date, is_active, date_of_birth, gender, address,
          emergency_contact, employment_type, work_location, salary_type, allowances,
          fixed_deductions, bank_account_name, bank_name, bank_account_number, bank_ifsc,
          shift_id, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        e.workspaceId,
        e.employeeCode.trim(),
        e.name.trim(),
        e.phone.trim(),
        e.email?.trim(),
        e.role,
        e.designation,
        e.department,
        pinToSave,
        e.baseSalary,
        joinSeconds,
        e.isActive ? 1 : 0,
        e.dateOfBirth,
        e.gender,
        e.address,
        e.emergencyContact,
        e.employmentType,
        e.workLocation,
        e.salaryType,
        e.allowances,
        e.fixedDeductions,
        e.bankAccountName,
        e.bankName,
        e.bankAccountNumber,
        e.bankIfsc,
        e.shiftId,
        nowSeconds,
      ]);
      final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      return last.data['id'] as int;
    } else {
      await _db.customStatement('''
        UPDATE employees SET
          employee_code = ?, name = ?, phone = ?, email = ?, role = ?, designation = ?,
          department = ?, login_pin = ?, base_salary = ?, is_active = ?, date_of_birth = ?,
          gender = ?, address = ?, emergency_contact = ?, employment_type = ?,
          work_location = ?, salary_type = ?, allowances = ?, fixed_deductions = ?,
          bank_account_name = ?, bank_name = ?, bank_account_number = ?, bank_ifsc = ?,
          shift_id = ?
        WHERE id = ?
      ''', [
        e.employeeCode.trim(),
        e.name.trim(),
        e.phone.trim(),
        e.email?.trim(),
        e.role,
        e.designation,
        e.department,
        pinToSave,
        e.baseSalary,
        e.isActive ? 1 : 0,
        e.dateOfBirth,
        e.gender,
        e.address,
        e.emergencyContact,
        e.employmentType,
        e.workLocation,
        e.salaryType,
        e.allowances,
        e.fixedDeductions,
        e.bankAccountName,
        e.bankName,
        e.bankAccountNumber,
        e.bankIfsc,
        e.shiftId,
        e.id,
      ]);
      return e.id;
    }
  }

  @override
  Future<void> setEmployeeStatus(int id, bool isActive, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin) {
      throw AppException('Access denied: Changing employee status requires admin permission');
    }
    await _db.customStatement('UPDATE employees SET is_active = ? WHERE id = ?', [isActive ? 1 : 0, id]);
  }

  @override
  Future<bool> canDeleteEmployee(int id) async {
    final attCount = await _db.customSelect(
      'SELECT COUNT(*) as count FROM attendances WHERE employee_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).getSingle();
    if ((attCount.data['count'] as num) > 0) return false;

    final payCount = await _db.customSelect(
      'SELECT COUNT(*) as count FROM payroll_records WHERE employee_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).getSingle();
    if ((payCount.data['count'] as num) > 0) return false;

    final salesCount = await _db.customSelect(
      'SELECT COUNT(*) as count FROM sales WHERE employee_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).getSingle();
    if ((salesCount.data['count'] as num) > 0) return false;

    final claimCount = await _db.customSelect(
      'SELECT COUNT(*) as count FROM incentive_claims WHERE employee_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(id)],
    ).getSingle();
    if ((claimCount.data['count'] as num) > 0) return false;

    return true;
  }

  @override
  Future<void> deleteEmployee(int id, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin) {
      throw AppException('Access denied: Deleting employee requires admin permission');
    }
    final canDel = await canDeleteEmployee(id);
    if (!canDel) {
      throw AppException('Cannot permanently delete employee with historical records. Deactivate the employee instead.');
    }
    await _db.customStatement('DELETE FROM employees WHERE id = ?', [id]);
  }

  // -------------------------------------------------------------
  // SHIFTS
  // -------------------------------------------------------------

  @override
  Future<List<ShiftModel>> getShifts({int workspaceId = 1}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM shifts WHERE workspace_id = ? ORDER BY id ASC',
      readsFrom: {},
      variables: [Variable.withInt(workspaceId)],
    ).get();

    return rows.map((r) {
      return ShiftModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        name: r.data['name'] as String? ?? 'General Shift',
        startTime: r.data['start_time'] as String? ?? '09:00',
        endTime: r.data['end_time'] as String? ?? '18:00',
        breakMinutes: r.data['break_minutes'] as int? ?? 30,
        graceMinutes: r.data['grace_minutes'] as int? ?? 15,
        isOvernight: (r.data['is_overnight'] as int? ?? 0) == 1,
        isActive: (r.data['is_active'] as int? ?? 1) == 1,
      );
    }).toList();
  }

  @override
  Future<int> saveShift(ShiftModel s) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (s.id <= 0) {
      await _db.customStatement('''
        INSERT INTO shifts (workspace_id, name, start_time, end_time, break_minutes, grace_minutes, is_overnight, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [s.workspaceId, s.name, s.startTime, s.endTime, s.breakMinutes, s.graceMinutes, s.isOvernight ? 1 : 0, s.isActive ? 1 : 0, nowSeconds]);
      final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      return last.data['id'] as int;
    } else {
      await _db.customStatement('''
        UPDATE shifts SET name = ?, start_time = ?, end_time = ?, break_minutes = ?, grace_minutes = ?, is_overnight = ?, is_active = ?
        WHERE id = ?
      ''', [s.name, s.startTime, s.endTime, s.breakMinutes, s.graceMinutes, s.isOvernight ? 1 : 0, s.isActive ? 1 : 0, s.id]);
      return s.id;
    }
  }

  @override
  Future<void> deleteShift(int id) async {
    await _db.customStatement('UPDATE shifts SET is_active = 0 WHERE id = ?', [id]);
  }

  // -------------------------------------------------------------
  // ATTENDANCE
  // -------------------------------------------------------------

  @override
  Future<List<AttendanceModel>> getAttendance({int workspaceId = 1, required DateTime date}) async {
    final rows = await _db.customSelect('''
      SELECT * FROM attendances WHERE workspace_id = ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();

    return rows.where((r) {
      final itemDate = _parseDateTime(r.data['date']);
      return itemDate.year == date.year && itemDate.month == date.month && itemDate.day == date.day;
    }).map((r) {
      return AttendanceModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        employeeId: r.data['employee_id'] as int? ?? 0,
        date: _parseDateTime(r.data['date']),
        checkInTime: _tryParseDateTime(r.data['check_in_time']),
        checkOutTime: _tryParseDateTime(r.data['check_out_time']),
        status: r.data['status'] as String? ?? 'present',
        workingHours: (r.data['working_hours'] as num? ?? 8.0).toDouble(),
        notes: r.data['notes'] as String?,
        shiftId: r.data['shift_id'] as int?,
        breakMinutes: r.data['break_minutes'] as int? ?? 0,
        isLate: (r.data['is_late'] as int? ?? 0) == 1,
        overtimeHours: (r.data['overtime_hours'] as num? ?? 0.0).toDouble(),
        correctedBy: r.data['corrected_by'] as String?,
        correctionReason: r.data['correction_reason'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> recordAttendance({
    int workspaceId = 1,
    required int employeeId,
    required DateTime date,
    DateTime? checkIn,
    DateTime? checkOut,
    String status = 'present',
    double workingHours = 8.0,
    String? notes,
    int? shiftId,
    int breakMinutes = 0,
    bool isLate = false,
    double overtimeHours = 0.0,
  }) async {
    final dateSeconds = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/ 1000;
    final checkInSeconds = checkIn != null ? checkIn.millisecondsSinceEpoch ~/ 1000 : null;
    final checkOutSeconds = checkOut != null ? checkOut.millisecondsSinceEpoch ~/ 1000 : null;

    if (checkIn != null && checkOut != null && checkOut.isBefore(checkIn)) {
      throw AppException('Invalid time sequence: Check-out time cannot be earlier than check-in time.');
    }

    final existing = await _db.customSelect(
      'SELECT id FROM attendances WHERE workspace_id = ? AND employee_id = ? AND date = ?',
      readsFrom: {},
      variables: [Variable.withInt(workspaceId), Variable.withInt(employeeId), Variable.withInt(dateSeconds)],
    ).get();

    if (existing.isNotEmpty) {
      final attId = existing.first.data['id'] as int;
      await _db.customStatement('''
        UPDATE attendances SET
          check_in_time = COALESCE(?, check_in_time),
          check_out_time = COALESCE(?, check_out_time),
          status = ?,
          working_hours = ?,
          notes = ?,
          shift_id = ?,
          break_minutes = ?,
          is_late = ?,
          overtime_hours = ?
        WHERE id = ?
      ''', [
        checkInSeconds,
        checkOutSeconds,
        status,
        workingHours,
        notes,
        shiftId,
        breakMinutes,
        isLate ? 1 : 0,
        overtimeHours,
        attId,
      ]);
    } else {
      await _db.customStatement('''
        INSERT INTO attendances (
          workspace_id, employee_id, date, check_in_time, check_out_time,
          status, working_hours, notes, shift_id, break_minutes, is_late, overtime_hours
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        workspaceId,
        employeeId,
        dateSeconds,
        checkInSeconds,
        checkOutSeconds,
        status,
        workingHours,
        notes,
        shiftId,
        breakMinutes,
        isLate ? 1 : 0,
        overtimeHours,
      ]);
    }
  }

  @override
  Future<void> correctAttendance({
    required int attendanceId,
    required String status,
    double? workingHours,
    DateTime? checkIn,
    DateTime? checkOut,
    required String reason,
    required String correctedBy,
  }) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final checkInSeconds = checkIn != null ? checkIn.millisecondsSinceEpoch ~/ 1000 : null;
    final checkOutSeconds = checkOut != null ? checkOut.millisecondsSinceEpoch ~/ 1000 : null;

    if (checkIn != null && checkOut != null && checkOut.isBefore(checkIn)) {
      throw AppException('Invalid time sequence: Check-out time cannot be earlier than check-in time.');
    }

    final rows = await _db.customSelect('SELECT * FROM attendances WHERE id = ?', readsFrom: {}, variables: [Variable.withInt(attendanceId)]).get();
    if (rows.isEmpty) throw AppException('Attendance record not found');
    final oldRecord = rows.first;
    final empId = oldRecord.data['employee_id'] as int;
    final oldStatus = oldRecord.data['status'] as String? ?? '';

    await _db.transaction(() async {
      await _db.customStatement('''
        UPDATE attendances SET
          status = ?,
          working_hours = COALESCE(?, working_hours),
          check_in_time = COALESCE(?, check_in_time),
          check_out_time = COALESCE(?, check_out_time),
          corrected_by = ?,
          correction_reason = ?
        WHERE id = ?
      ''', [
        status,
        workingHours,
        checkInSeconds,
        checkOutSeconds,
        correctedBy,
        reason,
        attendanceId,
      ]);

      // Audit log entry
      await _db.customStatement('''
        INSERT INTO employee_audit_logs (workspace_id, employee_id, action, field_name, old_value, new_value, performed_by, created_at)
        VALUES (1, ?, 'attendance_correction', 'status', ?, ?, ?, ?)
      ''', [empId, oldStatus, status, correctedBy, nowSeconds]);
    });
  }

  @override
  Future<List<AttendanceSummaryModel>> getMonthlyAttendanceSummary({
    required int month,
    required int year,
    int workspaceId = 1,
  }) async {
    final employees = await getEmployees(workspaceId: workspaceId, activeOnly: false);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final startSeconds = DateTime(year, month, 1).millisecondsSinceEpoch ~/ 1000;
    final endSeconds = DateTime(year, month, daysInMonth, 23, 59, 59).millisecondsSinceEpoch ~/ 1000;

    final rows = await _db.customSelect('''
      SELECT * FROM attendances
      WHERE workspace_id = ? AND date >= ? AND date <= ?
    ''', readsFrom: {}, variables: [Variable.withInt(workspaceId), Variable.withInt(startSeconds), Variable.withInt(endSeconds)]).get();

    final result = <AttendanceSummaryModel>[];

    for (final emp in employees) {
      final empRows = rows.where((r) => (r.data['employee_id'] as int? ?? 0) == emp.id).toList();

      int present = 0;
      int absent = 0;
      int halfDay = 0;
      int onLeave = 0;
      double overtime = 0.0;
      int lateDays = 0;

      for (final r in empRows) {
        final st = r.data['status'] as String? ?? 'present';
        if (st == 'present') {
          present++;
        } else if (st == 'absent') {
          absent++;
        } else if (st == 'half_day') {
          halfDay++;
        } else if (st == 'on_leave') {
          onLeave++;
        }

        overtime += (r.data['overtime_hours'] as num? ?? 0.0).toDouble();
        if ((r.data['is_late'] as int? ?? 0) == 1) lateDays++;
      }

      result.add(AttendanceSummaryModel(
        employeeId: emp.id,
        employeeName: emp.name,
        totalDays: daysInMonth,
        presentDays: present,
        absentDays: absent,
        halfDays: halfDay,
        leaveDays: onLeave,
        overtimeHours: overtime,
        lateDays: lateDays,
      ));
    }

    return result;
  }

  // -------------------------------------------------------------
  // LEAVES
  // -------------------------------------------------------------

  @override
  Future<List<LeaveRequestModel>> getLeaves({int? employeeId, int workspaceId = 1}) async {
    final query = employeeId != null
        ? 'SELECT * FROM leave_requests WHERE workspace_id = ? AND employee_id = ? ORDER BY id DESC'
        : 'SELECT * FROM leave_requests WHERE workspace_id = ? ORDER BY id DESC';
    final vars = employeeId != null
        ? [Variable.withInt(workspaceId), Variable.withInt(employeeId)]
        : [Variable.withInt(workspaceId)];

    final rows = await _db.customSelect(query, readsFrom: {}, variables: vars).get();

    return rows.map((r) {
      return LeaveRequestModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        employeeId: r.data['employee_id'] as int? ?? 0,
        startDate: _parseDateTime(r.data['start_date']),
        endDate: _parseDateTime(r.data['end_date']),
        totalDays: (r.data['total_days'] as num? ?? 1.0).toDouble(),
        leaveType: r.data['leave_type'] as String? ?? 'casual',
        reason: r.data['reason'] as String?,
        status: r.data['status'] as String? ?? 'pending',
        approvedBy: r.data['approved_by'] as String?,
        approverRemarks: r.data['approver_remarks'] as String?,
        createdAt: _parseDateTime(r.data['created_at']),
      );
    }).toList();
  }

  @override
  Future<int> requestLeave(LeaveRequestModel leave) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final startSeconds = leave.startDate.millisecondsSinceEpoch ~/ 1000;
    final endSeconds = leave.endDate.millisecondsSinceEpoch ~/ 1000;

    await _db.customStatement('''
      INSERT INTO leave_requests (
        workspace_id, employee_id, start_date, end_date, total_days,
        leave_type, reason, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?)
    ''', [
      leave.workspaceId,
      leave.employeeId,
      startSeconds,
      endSeconds,
      leave.totalDays,
      leave.leaveType,
      leave.reason,
      nowSeconds,
    ]);

    final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
    return last.data['id'] as int;
  }

  @override
  Future<void> approveLeave({
    required int leaveId,
    required bool approved,
    String? remarks,
    String? approvedBy,
  }) async {
    final rows = await _db.customSelect('SELECT * FROM leave_requests WHERE id = ?', readsFrom: {}, variables: [Variable.withInt(leaveId)]).get();
    if (rows.isEmpty) throw AppException('Leave request not found');

    final req = rows.first;
    final empId = req.data['employee_id'] as int;
    final status = approved ? 'approved' : 'rejected';
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      await _db.customStatement('''
        UPDATE leave_requests SET status = ?, approved_by = ?, approver_remarks = ? WHERE id = ?
      ''', [status, approvedBy ?? 'Admin', remarks, leaveId]);

      if (approved) {
        // Automatically record attendance as on_leave for the dates
        final startDt = _parseDateTime(req.data['start_date']);
        final endDt = _parseDateTime(req.data['end_date']);
        var curr = DateTime(startDt.year, startDt.month, startDt.day);
        final end = DateTime(endDt.year, endDt.month, endDt.day);

        while (!curr.isAfter(end)) {
          final currSeconds = curr.millisecondsSinceEpoch ~/ 1000;
          await _db.customStatement('''
            INSERT INTO attendances (workspace_id, employee_id, date, status, working_hours, notes)
            VALUES (1, ?, ?, 'on_leave', 0.0, 'Approved Leave')
            ON CONFLICT DO UPDATE SET status = 'on_leave', working_hours = 0.0, notes = 'Approved Leave'
          ''', [empId, currSeconds]);
          curr = curr.add(const Duration(days: 1));
        }
      }

      await _db.customStatement('''
        INSERT INTO employee_audit_logs (workspace_id, employee_id, action, field_name, old_value, new_value, performed_by, created_at)
        VALUES (1, ?, 'leave_action', 'status', 'pending', ?, ?, ?)
      ''', [empId, status, approvedBy ?? 'Admin', nowSeconds]);
    });
  }

  // -------------------------------------------------------------
  // HOLIDAYS
  // -------------------------------------------------------------

  @override
  Future<List<HolidayModel>> getHolidays({int workspaceId = 1}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM holidays WHERE workspace_id = ? ORDER BY date ASC',
      readsFrom: {},
      variables: [Variable.withInt(workspaceId)],
    ).get();

    return rows.map((r) {
      return HolidayModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        name: r.data['name'] as String? ?? '',
        date: r.data['date'] as String? ?? '',
        description: r.data['description'] as String?,
        isOptional: (r.data['is_optional'] as int? ?? 0) == 1,
      );
    }).toList();
  }

  @override
  Future<int> saveHoliday(HolidayModel h) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (h.id <= 0) {
      await _db.customStatement('''
        INSERT INTO holidays (workspace_id, name, date, description, is_optional, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [h.workspaceId, h.name, h.date, h.description, h.isOptional ? 1 : 0, nowSeconds]);
      final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      return last.data['id'] as int;
    } else {
      await _db.customStatement('''
        UPDATE holidays SET name = ?, date = ?, description = ?, is_optional = ? WHERE id = ?
      ''', [h.name, h.date, h.description, h.isOptional ? 1 : 0, h.id]);
      return h.id;
    }
  }

  // -------------------------------------------------------------
  // PAYROLL
  // -------------------------------------------------------------

  @override
  Future<List<PayrollRecordModel>> getPayrollRecords({int workspaceId = 1, int? month, int? year, UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Accessing payroll requires admin or manager permission');
    }
    String query = 'SELECT * FROM payroll_records WHERE workspace_id = ?';
    final vars = <Variable>[Variable.withInt(workspaceId)];

    if (month != null) {
      query += ' AND month = ?';
      vars.add(Variable.withInt(month));
    }
    if (year != null) {
      query += ' AND year = ?';
      vars.add(Variable.withInt(year));
    }

    query += ' ORDER BY year DESC, month DESC, id DESC';

    final rows = await _db.customSelect(query, readsFrom: {}, variables: vars).get();

    return rows.map((r) {
      return PayrollRecordModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        employeeId: r.data['employee_id'] as int? ?? 0,
        month: r.data['month'] as int? ?? 1,
        year: r.data['year'] as int? ?? 2026,
        basicSalary: (r.data['basic_salary'] as num? ?? 0.0).toDouble(),
        incentiveAmount: (r.data['incentive_amount'] as num? ?? 0.0).toDouble(),
        allowances: (r.data['allowances'] as num? ?? 0.0).toDouble(),
        deductions: (r.data['deductions'] as num? ?? 0.0).toDouble(),
        netSalary: (r.data['net_salary'] as num? ?? 0.0).toDouble(),
        status: r.data['status'] as String? ?? 'draft',
        paidFromAccountId: r.data['paid_from_account_id'] as int?,
        paidDate: _tryParseDateTime(r.data['paid_date']),
        notes: r.data['notes'] as String?,
      );
    }).toList();
  }

  @override
  Future<int> processPayroll({
    int workspaceId = 1,
    required int employeeId,
    required int month,
    required int year,
    required double basicSalary,
    double incentiveAmount = 0.0,
    double allowances = 0.0,
    double deductions = 0.0,
    String? notes,
    UserRole? callerRole,
  }) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Processing payroll requires admin or manager permission');
    }
    final net = (basicSalary + incentiveAmount + allowances) - deductions;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final existing = await _db.customSelect(
      'SELECT id, status FROM payroll_records WHERE workspace_id = ? AND employee_id = ? AND month = ? AND year = ?',
      readsFrom: {},
      variables: [Variable.withInt(workspaceId), Variable.withInt(employeeId), Variable.withInt(month), Variable.withInt(year)],
    ).get();

    if (existing.isNotEmpty) {
      if ((existing.first.data['status'] as String? ?? '') == 'paid') {
        throw AppException('Payroll for this employee and period has already been disbursed and cannot be re-processed.');
      }
      final pid = existing.first.data['id'] as int;
      await _db.customStatement('''
        UPDATE payroll_records SET
          basic_salary = ?, incentive_amount = ?, allowances = ?, deductions = ?, net_salary = ?, status = 'approved', notes = ?
        WHERE id = ?
      ''', [basicSalary, incentiveAmount, allowances, deductions, net, notes, pid]);
      return pid;
    } else {
      await _db.customStatement('''
        INSERT INTO payroll_records (
          workspace_id, employee_id, month, year, basic_salary, incentive_amount,
          allowances, deductions, net_salary, status, notes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'approved', ?, ?)
      ''', [workspaceId, employeeId, month, year, basicSalary, incentiveAmount, allowances, deductions, net, notes, nowSeconds]);

      final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      return last.data['id'] as int;
    }
  }

  @override
  Future<void> disbursePayroll({required int payrollId, required int fromAccountId, UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Disbursing payroll requires admin or manager permission');
    }
    final rows = await _db.customSelect('SELECT * FROM payroll_records WHERE id = ?', readsFrom: {}, variables: [Variable.withInt(payrollId)]).get();
    if (rows.isEmpty) throw AppException('Payroll record not found');
    final row = rows.first;
    if ((row.data['status'] as String? ?? '') == 'paid') {
      throw AppException('Payroll has already been disbursed and paid.');
    }
    final netSalary = (row.data['net_salary'] as num).toDouble();
    final empId = row.data['employee_id'] as int;
    final wsId = row.data['workspace_id'] as int? ?? 1;
    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      await _db.customStatement('''
        UPDATE payroll_records SET status = 'paid', paid_from_account_id = ?, paid_date = ? WHERE id = ?
      ''', [fromAccountId, nowSeconds, payrollId]);

      // Double-entry financial ledger transaction:
      // Debit: Salary Expense Account
      // Credit: Cash/Bank/UPI Asset Account
      await _ledgerRepository.postTransaction(
        workspaceId: wsId,
        entries: [
          LedgerPostingItem(
            transactionType: 'salary',
            referenceType: 'salary',
            referenceId: payrollId,
            partyType: 'employee',
            partyId: empId,
            debit: netSalary,
            credit: 0.0,
            narration: 'Darvi Group Salary disbursement for Employee #$empId',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'salary',
            referenceType: 'salary',
            referenceId: payrollId,
            accountId: fromAccountId,
            debit: 0.0,
            credit: netSalary,
            narration: 'Salary payout from Account #$fromAccountId for Employee #$empId',
            createdAt: now,
          ),
        ],
      );
    });
  }

  // -------------------------------------------------------------
  // SALES ATTRIBUTION & TARGETS
  // -------------------------------------------------------------

  @override
  Future<List<SalesTargetModel>> getSalesTargets({int? employeeId, int workspaceId = 1}) async {
    final query = employeeId != null
        ? 'SELECT * FROM sales_targets WHERE workspace_id = ? AND employee_id = ? ORDER BY id DESC'
        : 'SELECT * FROM sales_targets WHERE workspace_id = ? ORDER BY id DESC';
    final vars = employeeId != null
        ? [Variable.withInt(workspaceId), Variable.withInt(employeeId)]
        : [Variable.withInt(workspaceId)];

    final rows = await _db.customSelect(query, readsFrom: {}, variables: vars).get();

    return rows.map((r) {
      return SalesTargetModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        employeeId: r.data['employee_id'] as int? ?? 0,
        targetType: r.data['target_type'] as String? ?? 'revenue',
        targetAmount: (r.data['target_amount'] as num? ?? 0.0).toDouble(),
        currentAmount: (r.data['current_amount'] as num? ?? 0.0).toDouble(),
        startDate: _parseDateTime(r.data['start_date']),
        endDate: _parseDateTime(r.data['end_date']),
        status: r.data['status'] as String? ?? 'in_progress',
      );
    }).toList();
  }

  @override
  Future<int> saveSalesTarget(SalesTargetModel target) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final startSeconds = target.startDate.millisecondsSinceEpoch ~/ 1000;
    final endSeconds = target.endDate.millisecondsSinceEpoch ~/ 1000;

    if (target.id <= 0) {
      await _db.customStatement('''
        INSERT INTO sales_targets (
          workspace_id, employee_id, month, year, target_revenue, target_type, target_amount, current_amount,
          start_date, end_date, status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        target.workspaceId,
        target.employeeId,
        target.startDate.month,
        target.startDate.year,
        target.targetAmount,
        target.targetType,
        target.targetAmount,
        target.currentAmount,
        startSeconds,
        endSeconds,
        target.status,
        nowSeconds,
      ]);
      final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
      return last.data['id'] as int;
    } else {
      await _db.customStatement('''
        UPDATE sales_targets SET
          target_type = ?, target_amount = ?, current_amount = ?,
          start_date = ?, end_date = ?, status = ?
        WHERE id = ?
      ''', [
        target.targetType,
        target.targetAmount,
        target.currentAmount,
        startSeconds,
        endSeconds,
        target.status,
        target.id,
      ]);
      return target.id;
    }
  }

  @override
  Future<Map<String, dynamic>> calculateSalesAttributed({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
    int workspaceId = 1,
  }) async {
    final startSeconds = startDate.millisecondsSinceEpoch ~/ 1000;
    final endSeconds = endDate.millisecondsSinceEpoch ~/ 1000;

    // Sales attributed to employee
    final salesRows = await _db.customSelect('''
      SELECT id, total, status FROM sales
      WHERE workspace_id = ? AND employee_id = ? AND created_at >= ? AND created_at <= ?
    ''', readsFrom: {}, variables: [
      Variable.withInt(workspaceId),
      Variable.withInt(employeeId),
      Variable.withInt(startSeconds),
      Variable.withInt(endSeconds),
    ]).get();

    double totalRevenue = 0.0;
    int completedInvoices = 0;
    int returnedInvoices = 0;
    double returnedAmount = 0.0;

    for (final r in salesRows) {
      final st = r.data['status'] as String? ?? 'completed';
      final tot = (r.data['total'] as num? ?? 0.0).toDouble();

      if (st == 'completed') {
        completedInvoices++;
        totalRevenue += tot;
      } else if (st == 'returned') {
        returnedInvoices++;
        returnedAmount += tot;
      }
    }

    final netRevenue = (totalRevenue - returnedAmount).clamp(0.0, double.infinity);

    return {
      'employeeId': employeeId,
      'completedInvoices': completedInvoices,
      'returnedInvoices': returnedInvoices,
      'grossRevenue': totalRevenue,
      'returnedAmount': returnedAmount,
      'netRevenue': netRevenue,
    };
  }

  @override
  Future<double> calculateIncentivesFromSales({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
    int workspaceId = 1,
  }) async {
    final attr = await calculateSalesAttributed(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
      workspaceId: workspaceId,
    );

    final netRevenue = (attr['netRevenue'] as num? ?? 0.0).toDouble();
    if (netRevenue <= 0) return 0.0;

    final rules = await getIncentiveRules(workspaceId: workspaceId);
    double totalIncentive = 0.0;

    for (final rule in rules) {
      if (!rule.isActive) continue;

      if (rule.ruleType == 'percentage_revenue') {
        if (netRevenue >= rule.thresholdAmount) {
          totalIncentive += (netRevenue * (rule.rewardRate / 100.0));
        }
      } else if (rule.ruleType == 'fixed_bonus') {
        if (netRevenue >= rule.thresholdAmount) {
          totalIncentive += rule.rewardRate;
        }
      }
    }

    return totalIncentive;
  }

  // -------------------------------------------------------------
  // INCENTIVE RULES & CLAIMS
  // -------------------------------------------------------------

  @override
  Future<List<IncentiveRuleModel>> getIncentiveRules({int workspaceId = 1}) async {
    final rows = await _db.customSelect('SELECT * FROM incentive_rules WHERE workspace_id = ?', readsFrom: {}, variables: [Variable.withInt(workspaceId)]).get();
    return rows.map((r) {
      return IncentiveRuleModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        name: r.data['name'] as String? ?? '',
        ruleType: r.data['rule_type'] as String? ?? 'percentage_revenue',
        thresholdAmount: (r.data['threshold_amount'] as num? ?? 0.0).toDouble(),
        rewardRate: (r.data['reward_rate'] as num? ?? 0.0).toDouble(),
        targetProductId: r.data['target_product_id'] as int?,
        targetCategoryId: r.data['target_category_id'] as int?,
        isActive: (r.data['is_active'] as int? ?? 1) == 1,
      );
    }).toList();
  }

  @override
  Future<int> createIncentiveRule(IncentiveRuleModel rule) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement('''
      INSERT INTO incentive_rules (workspace_id, name, rule_type, threshold_amount, reward_rate, target_product_id, target_category_id, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [rule.workspaceId, rule.name, rule.ruleType, rule.thresholdAmount, rule.rewardRate, rule.targetProductId, rule.targetCategoryId, rule.isActive ? 1 : 0, nowSeconds]);
    final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
    return last.data['id'] as int;
  }

  @override
  Future<List<IncentiveClaimModel>> getIncentiveClaims({int workspaceId = 1, String? status}) async {
    final query = status != null
        ? 'SELECT * FROM incentive_claims WHERE workspace_id = ? AND status = ? ORDER BY id DESC'
        : 'SELECT * FROM incentive_claims WHERE workspace_id = ? ORDER BY id DESC';
    final vars = status != null
        ? [Variable.withInt(workspaceId), Variable.withString(status)]
        : [Variable.withInt(workspaceId)];

    final rows = await _db.customSelect(query, readsFrom: {}, variables: vars).get();
    return rows.map((r) {
      return IncentiveClaimModel(
        id: r.data['id'] as int? ?? 0,
        workspaceId: r.data['workspace_id'] as int? ?? 1,
        employeeId: r.data['employee_id'] as int? ?? 0,
        saleId: r.data['sale_id'] as int?,
        amount: (r.data['amount'] as num? ?? 0.0).toDouble(),
        description: r.data['description'] as String? ?? '',
        status: r.data['status'] as String? ?? 'pending',
        createdAt: _parseDateTime(r.data['created_at']),
        processedAt: _tryParseDateTime(r.data['processed_at']),
        paidFromAccountId: r.data['paid_from_account_id'] as int?,
        paidDate: _tryParseDateTime(r.data['paid_date']),
      );
    }).toList();
  }

  @override
  Future<void> approveIncentiveClaim(int claimId, bool approve, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Approving incentives requires admin or manager permission');
    }
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement('''
      UPDATE incentive_claims SET status = ?, processed_at = ? WHERE id = ?
    ''', [approve ? 'approved' : 'rejected', nowSeconds, claimId]);
  }

  @override
  Future<void> payoutIncentiveClaim({
    required int claimId,
    required int fromAccountId,
    UserRole? callerRole,
  }) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Disbursing incentives requires admin or manager permission');
    }
    final rows = await _db.customSelect('SELECT * FROM incentive_claims WHERE id = ?', readsFrom: {}, variables: [Variable.withInt(claimId)]).get();
    if (rows.isEmpty) throw AppException('Incentive claim not found');

    final claim = rows.first;
    final currentStatus = claim.data['status'] as String? ?? '';
    if (currentStatus == 'paid') {
      throw AppException('Incentive claim has already been disbursed and paid.');
    }
    if (currentStatus != 'approved') {
      throw AppException('Only approved incentive claims can be paid.');
    }
    final empId = claim.data['employee_id'] as int;
    final amount = (claim.data['amount'] as num? ?? 0.0).toDouble();
    final wsId = claim.data['workspace_id'] as int? ?? 1;
    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    await _db.transaction(() async {
      await _db.customStatement('''
        UPDATE incentive_claims SET status = 'paid', paid_from_account_id = ?, paid_date = ? WHERE id = ?
      ''', [fromAccountId, nowSeconds, claimId]);

      // Double-entry financial ledger transaction:
      // Debit: Incentive Expense (party: employee)
      // Credit: Cash/Bank/UPI Asset Account
      await _ledgerRepository.postTransaction(
        workspaceId: wsId,
        entries: [
          LedgerPostingItem(
            transactionType: 'incentive',
            referenceType: 'incentive_claim',
            referenceId: claimId,
            partyType: 'employee',
            partyId: empId,
            debit: amount,
            credit: 0.0,
            narration: 'Darvi Group Incentive Payout for Employee #$empId',
            createdAt: now,
          ),
          LedgerPostingItem(
            transactionType: 'incentive',
            referenceType: 'incentive_claim',
            referenceId: claimId,
            accountId: fromAccountId,
            debit: 0.0,
            credit: amount,
            narration: 'Incentive payout from Account #$fromAccountId for Employee #$empId',
            createdAt: now,
          ),
        ],
      );
    });
  }

  @override
  Future<int> createIncentiveClaim(IncentiveClaimModel claim) async {
    if (claim.saleId != null) {
      final existing = await _db.customSelect(
        'SELECT id FROM incentive_claims WHERE sale_id = ? AND employee_id = ?',
        readsFrom: {},
        variables: [Variable.withInt(claim.saleId!), Variable.withInt(claim.employeeId)],
      ).get();
      if (existing.isNotEmpty) {
        return existing.first.data['id'] as int;
      }
    }

    final nowSeconds = claim.createdAt.millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement('''
      INSERT INTO incentive_claims (workspace_id, employee_id, sale_id, amount, description, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      claim.workspaceId,
      claim.employeeId,
      claim.saleId,
      claim.amount,
      claim.description,
      claim.status,
      nowSeconds,
    ]);

    final last = await _db.customSelect('SELECT last_insert_rowid() as id', readsFrom: {}).getSingle();
    return last.data['id'] as int;
  }

  @override
  Future<void> reverseIncentiveClaimForSale(int saleId, {UserRole? callerRole}) async {
    if (callerRole != null && callerRole != UserRole.admin && callerRole != UserRole.manager) {
      throw AppException('Access denied: Reversing incentives requires admin or manager permission');
    }
    final claims = await _db.customSelect(
      'SELECT * FROM incentive_claims WHERE sale_id = ?',
      readsFrom: {},
      variables: [Variable.withInt(saleId)],
    ).get();

    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    for (final claim in claims) {
      final cid = claim.data['id'] as int;
      final cstatus = claim.data['status'] as String? ?? 'pending';
      final camount = (claim.data['amount'] as num? ?? 0.0).toDouble();
      final cEmployeeId = claim.data['employee_id'] as int? ?? 1;
      final cAccountId = claim.data['paid_from_account_id'] as int? ?? 1;
      final wsId = claim.data['workspace_id'] as int? ?? 1;

      if (cstatus == 'pending' || cstatus == 'approved') {
        await _db.customStatement('''
          UPDATE incentive_claims SET status = 'rejected', processed_at = ? WHERE id = ?
        ''', [nowSeconds, cid]);
      } else if (cstatus == 'paid') {
        await _db.customStatement('''
          UPDATE incentive_claims SET status = 'reversed', processed_at = ? WHERE id = ?
        ''', [nowSeconds, cid]);

        await _ledgerRepository.postTransaction(
          workspaceId: wsId,
          entries: [
            LedgerPostingItem(
              transactionType: 'incentive',
              referenceType: 'incentive_reversal',
              referenceId: cid,
              partyType: 'employee',
              partyId: cEmployeeId,
              debit: 0.0,
              credit: camount,
              narration: 'Reversal of incentive claim #$cid due to invoice return',
              createdAt: now,
            ),
            LedgerPostingItem(
              transactionType: 'incentive',
              referenceType: 'incentive_reversal',
              referenceId: cid,
              accountId: cAccountId,
              debit: camount,
              credit: 0.0,
              narration: 'Refund/Reversal to account #$cAccountId for incentive #$cid',
              createdAt: now,
            ),
          ],
        );
      }
    }
  }
}
