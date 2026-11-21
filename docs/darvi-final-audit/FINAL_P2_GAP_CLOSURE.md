# DARVI BILLING — FINAL P2 GAP CLOSURE AUDIT REPORT

**Entity:** Darvi Group Agri Tech  
**GSTIN:** 29BKZPA0053M1ZQ  
**Location:** #2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030  
**Application:** Darvi Billing v1.0.0 (Production Candidate)  
**Audit Date:** 2026-11-07  
**Status:** COMPLETE (P2 Closed)

---

## 1. Executive Summary: P2 Requirements

Phase 2 (P2) encompasses human resource management, team hierarchy, daily biometric/clock attendance, prorated payroll, staff sales commissions and incentives, and multi-tier role-based access control (RBAC).

All requirements are audited against source code, repository logic, SQLite constraints, and Flutter navigation/UI guards.

| Milestone | Area | Status | Code Artifacts | Test Verification |
|---|---|:---:|---|---|
| **P2-1** | Team & Employee Profiles | **PASS** | [`team_page.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/team/presentation/pages/team_page.dart)<br>[`local_team_repository.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_team_repository.dart) | Drift schema constraints & seed data |
| **P2-2** | Attendance & Leave | **PASS** | [`attendance_page.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/team/presentation/pages/attendance_page.dart)<br>[`local_team_repository.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_team_repository.dart) | Workflow 6 in `test_darvi_e2e_workflows.py` |
| **P2-3** | Prorated Payroll & PDF | **PASS** | [`payroll_page.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/team/presentation/pages/payroll_page.dart)<br>[`local_team_repository.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_team_repository.dart) | `verify_full_p1_p2.py` Test 4 |
| **P2-4** | Incentives & Sales Commission | **PASS** | [`incentives_page.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/team/presentation/pages/incentives_page.dart)<br>[`local_team_repository.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_team_repository.dart) | Workflow 7 in `test_darvi_e2e_workflows.py` |
| **P2-5** | Multi-Tier RBAC & Auth Security | **PASS** | [`app_router.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/routing/app_router.dart)<br>[`auth_cubit.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/auth/presentation/cubit/auth_cubit.dart)<br>[`app_shell.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/widgets/app_shell.dart) | `RBAC_FINAL_SECURITY_AUDIT.md` |

---

## 2. Detailed Verification by Milestone

### 2.1 Team & Employee Profiles (P2-1)
- **Role Tiering:** Supports 5 business designations: `admin`, `manager`, `cashier`, `agronomist`, `field_officer`.
- **Database Schema:** `Employees` table enforces unique `employee_code`, `workspace_id` foreign key, secure `login_pin`, `base_salary`, and `department`.
- **Pre-seeded Staff:**
  - Admin: Suresh Totad (`EMP001`), PIN: `9988`
  - Manager: Manjunath Patil (`EMP002`), PIN: `5544`
  - Cashier: Priya Sharma (`EMP003`), PIN: `1122`
- **Result:** **PASS**

---

### 2.2 Attendance & Leave Tracking (P2-2)
- **Clock-In / Clock-Out:**
  - `LocalTeamRepository.recordAttendance(employeeId, date, status, checkIn, checkOut, workingHours)`.
  - Calculates actual working hours. Statuses: `present`, `absent`, `half_day`, `on_leave`.
- **Leave Request & Approvals:**
  - `LeaveRequests` table captures `leave_type` (`casual`, `sick`, `earned`, `unpaid`), date ranges, and reasons.
  - Managers and Admins can approve or reject leave requests.
- **Monthly Attendance Summary:**
  - Aggregates total days present, half-days, and unpaid leaves to supply accurate multiplier days into the payroll engine.
- **Result:** **PASS**

---

### 2.3 Prorated Payroll & Payslip Generation (P2-3)
- **Salary Computation Engine:**
  - Formula: $\text{Gross Salary} = (\text{Base Salary} \times \frac{\text{Present Days} + 0.5 \times \text{Half Days}}{\text{Working Days in Month}}) + \text{Incentives} + \text{Allowances} - \text{Deductions}$.
- **Anti-Duplication Constraint:**
  - SQLite UNIQUE index on `payroll_records(workspace_id, employee_id, month, year)` prevents duplicate payroll creation for the same month.
- **Double-Entry Ledger Disbursal:**
  - Disbursal posts balanced transactions:
    - `Debit`: `payroll` (Salary Expense)
    - `Credit`: `account` (Selected Cash Drawer or Bank Account)
- **Result:** **PASS**

---

### 2.4 Staff Sales Incentives & Attribution (P2-4)
- **Attribution:**
  - Every POS sale can be attributed to an employee via `Sales.employee_id`.
- **Incentive Rules:**
  - Supports percentage-of-revenue (e.g. 2% on retail sales) and fixed-per-unit commissions (e.g. ₹10 per fertilizer packet).
- **Claim Approval & Reversal:**
  - Sales returns automatically reverse employee incentive claims generated from the original invoice.
- **Result:** **PASS**

---

### 2.5 Multi-Tier RBAC & Security (P2-5)
- **Three Core Tiers:**
  1. `admin`: Unrestricted access across all 8 modules, financial reports, payroll disbursal, and system settings.
  2. `manager`: Access to POS, inventory, party management, employee attendance, and purchasing; restricted from system settings and final salary approval.
  3. `cashier`: Restricted exclusively to POS checkout, product catalog viewing, and thermal receipt printing; barred from financial reports, inventory adjustments, and staff administration.
- **GoRouter Route Guards:**
  - `AppRouter` intercepts navigation transitions and redirects unauthorized roles to `/pos` with an access denied snackbar.
- **Result:** **PASS**

---

## 3. P2 Gap Closure Summary

| P2 Requirement Category | Total Criteria | PASS | PARTIAL | FAIL | NOT VERIFIED |
|---|:---:|:---:|:---:|:---:|:---:|
| Employee Directory & Roles | 4 | 4 | 0 | 0 | 0 |
| Attendance & Leave Engine | 5 | 5 | 0 | 0 | 0 |
| Prorated Payroll Engine | 5 | 5 | 0 | 0 | 0 |
| Sales Incentives & Commission | 5 | 5 | 0 | 0 | 0 |
| RBAC Navigation & UI Gating | 5 | 5 | 0 | 0 | 0 |
| **Total P2 Requirements** | **24** | **24 (100%)** | **0** | **0** | **0** |

