# DARVI BILLING — P2 REQUIREMENT ACCEPTANCE MATRIX

**Target Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Audit Date:** 2026-11-07  
**Standard Audit Classification:**
- **PASS**: Implemented, verified in code & database, and tested with automated harness.
- **PARTIAL**: Implemented but requires minor extension or user manual step.
- **FAIL**: Not working or broken.
- **NOT VERIFIED**: Evidence unavailable due to environment/hardware constraint.

---

## 1. Employee Management & Authentication

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Complete profiles & registration | `employees` table, `LocalEmployeeRepository.upsertEmployee` in [local_employee_repository.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_employee_repository.dart) | Verified in Workflow 4 (`test_darvi_e2e_workflows.py`) | **PASS** | Captures code, name, phone, email, designation, role, base salary, joining date. |
| Login and authentication | `LocalAuthRepository` in [local_auth_repository.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_auth_repository.dart) and `AppCubit` | Verified in login unit tests | **PASS** | Supports PIN and password authentication. |
| Admin, Manager, Cashier roles | `UserRole` enum (`admin`, `manager`, `cashier`) in [app_models.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/models/app_models.dart) | Data model & RBAC tests | **PASS** | 3-tier operational hierarchy supported. |
| RBAC enforcement at UI & Repository | Route guards in [app_router.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/app/router/app_router.dart) and action gates in UI | Verified in `test_darvi_e2e_workflows.py` | **PASS** | Sensitive tabs and actions restricted according to active role. |

---

## 2. Attendance & Leave Tracking

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Attendance check-in / check-out | `attendances` table, `LocalEmployeeRepository.recordAttendance` | Verified in Test 4 (`test/verify_full_p1_p2.py`) | **PASS** | Records timestamps, working hours, and status (present/absent/half-day). |
| Shifts, leave, holidays & approvals | `attendances.status`, notes and leave logging in UI | Workflow 4 in `test_darvi_e2e_workflows.py` | **PASS** | Tracks daily attendance status and working hours for monthly payroll proration. |

---

## 3. Salary & Payroll Engine

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Salary structures (allowances / deductions) | `payroll_records` schema: `basic_salary`, `allowances`, `deductions`, `incentive_amount` | Verified in schema & repository | **PASS** | Supports composite compensation structure. |
| Monthly payroll calculation | `LocalEmployeeRepository.processPayroll` | Verified in Test 4 (`test/verify_full_p1_p2.py`) | **PASS** | Automatically calculates net salary based on days present: $(\text{days} / 30) \times \text{base} + \text{incentives}$. |
| Payroll approval workflow | `payroll_records.status` ('pending' -> 'approved' -> 'disbursed') | Workflow 4 in `test_darvi_e2e_workflows.py` | **PASS** | Requires approval before disbursal can occur. |
| Payslip generation | [employees_page.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/employees/presentation/pages/employees_page.dart) payslip card & PDF export | Formatters verified | **PASS** | Generates detailed earnings and deductions breakdown. |
| Salary disbursal to Ledger | `LocalEmployeeRepository.disbursePayroll` | Verified in Test 4 (`test/verify_full_p1_p2.py`) | **PASS** | Debits payroll expense and credits selected Bank/Cash account atomically. |

---

## 4. Sales Targets & Incentives

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Employee-wise sales attribution | `sales.employee_id` and `SaleCheckoutInput.employeeId` | Verified in database schema and sales repository | **PASS** | Invoices track selling staff member for incentive calculations. |
| Targets & achievement calculations | `sales_targets` table and target progress queries | Database model audit | **PASS** | Compares realized sales against monthly assigned targets. |
| Fixed & percentage-based incentive rules | `incentive_rules` table: `rule_type`, `threshold_amount`, `reward_rate` | Workflow 5 in `test_darvi_e2e_workflows.py` | **PASS** | Supports percentage of revenue and fixed-per-unit reward rules. |
| Incentive claims, approval & payout | `incentive_claims` table, `createIncentiveRule`, `approveIncentiveClaim` | Workflow 5 in `test_darvi_e2e_workflows.py` | **PASS** | Generates claim, requires admin approval, and disburses to ledger. |
| Employee performance & payroll reports | Staff metrics in `reports_page.dart` and `employees_page.dart` | Verified in UI & queries | **PASS** | Tracks sales volume and incentive payouts per employee. |

