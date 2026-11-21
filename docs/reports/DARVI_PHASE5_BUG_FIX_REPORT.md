# DARVI BILLING — PHASE 5: BUG FIX REPORT

**Date:** November 9, 2026  
**Auditor:** Antigravity Integration & QA Agent  
**Application:** Darvi Billing Flutter System  
**Audit Scope:** Full System Integration & Production Release Readiness  

---

## Summary of Remediated Defects

| ID | Module | Severity | Defect Description | Root Cause | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BUG-01** | Multi-Tenancy / Party Repo | **HIGH** | Unsafe cross-tenant data leakage in customer/supplier listings | Queries contained legacy `OR workspace_id IS NULL` clause | **FIXED** |
| **BUG-02** | Reports & Analytics | **CRITICAL** | Purchase overview, GST report, and expense totals silently zeroed out | Missing columns `balance_due`, `payment_status`, `is_cancelled` in SQLite table | **FIXED** |
| **BUG-03** | POS Sales & HR/Incentives | **HIGH** | Lack of employee attribution in checkout and missing incentive reversals on return | `SaleCheckoutInput` lacked `employeeId`; no sales return hook for `incentive_claims` | **FIXED** |
| **BUG-04** | Responsive UI / Layout | **MEDIUM** | RenderFlex overflow (36–40px) on mobile viewports in Reports and Settings | Unconstrained Row children in `_MiniMetric` and `_BusinessProfileSection` | **FIXED** |
| **BUG-05** | HR / Incentives Repo | **HIGH** | Missing `createIncentiveClaim` & `reverseIncentiveClaimForSale` implementations | Incomplete interface implementation for incentive lifecycle | **FIXED** |

---

## Detailed Bug Reports & Resolutions

### BUG-01: Cross-Workspace Data Leakage in LocalPartyRepository
- **File:** `lib/data/repositories/local_party_repository.dart`
- **Lines Modified:** 67, 141
- **Severity:** High
- **Description:** In multi-tenant environments, calling `getCustomers` or `getSuppliers` with a specific `workspaceId` returned records belonging to workspace `NULL` in addition to the target workspace.
- **Root Cause:** A legacy fallback clause `OR workspace_id IS NULL` was left in the query builder.
- **Resolution:** Removed the fallback clause. Both methods now strictly query `WHERE workspace_id = ? $activeClause`.
- **Verification:** Unit test `Workspace Isolation: strict filtering prevents cross-tenant data leakage` asserts that querying an unpopulated workspace ID (e.g. 999) returns exactly 0 records.

---

### BUG-02: Silent Query Failures in LocalReportsRepository
- **File:** `lib/data/repositories/local_reports_repository.dart`
- **Lines Modified:** 190–235, 326–334, 450–460
- **Severity:** Critical
- **Description:** All purchase metrics on the Reports Dashboard (Total Purchases, Outstanding Payables, Input GST), Expense totals, and Purchase Report tables showed 0 or were empty.
- **Root Cause:** The SQL statements selected physical columns `balance_due`, `payment_status`, `cgst`, `sgst`, `igst`, and `is_cancelled` from `purchase_invoices` and `expenses`. The physical SQLite schemas do not have these columns; they have `total_amount`, `paid_amount`, `status`, and `tax_total`. Because the queries were enclosed in `try { ... } catch (_) {}`, SQLite threw `no such column`, silently returning default 0 values.
- **Resolution:** 
  - Replaced `balance_due` with computed expression `(total_amount - paid_amount) AS balance_due`.
  - Replaced `payment_status` with `status AS payment_status`.
  - Replaced `cgst` / `sgst` with `(tax_total / 2.0) AS cgst`, `(tax_total / 2.0) AS sgst`.
  - Removed `is_cancelled` from `expenses` query.
- **Verification:** `Reports Repository queries execute cleanly with correct column mappings and aggregations` passed with exact verified balances.

---

### BUG-03: POS Sales Attribution & Closed-Loop Incentive Reversal
- **Files:** 
  - `lib/core/models/app_models.dart`
  - `lib/data/repositories/local_sales_repository.dart`
  - `lib/domain/repositories/repositories.dart`
  - `lib/data/repositories/local_employee_repository.dart`
- **Severity:** High
- **Description:** 
  1. Cashiers and field officers ringing up POS sales were not attributed on the `Sales` record via `employee_id`, preventing performance tracking and sales target calculations.
  2. Active commission rules in `incentive_rules` were not automatically evaluated at checkout.
  3. Processing a sales return (`returnItems`) left incentive claims in `pending`/`approved`/`paid` status, leading to unearned commissions being disbursed.
- **Root Cause:** `SaleCheckoutInput` omitted `employeeId`. Checkout logic had no trigger to create incentive claims, and `returnItems` lacked an incentive invalidation hook.
- **Resolution:**
  - Added `employeeId` field to `SaleCheckoutInput` and mapped it to `SalesCompanion.employeeId`.
  - Added post-checkout incentive evaluation matching `percentage_revenue` and `fixed_per_product` rules.
  - Added comprehensive return rollback: pending/approved claims are marked `rejected`; paid claims are marked `reversed` and an offsetting double-entry ledger reversal transaction is posted.
- **Verification:** Verified via end-to-end integration test `Complete Lifecycle: Product -> Inward Bill -> POS Sale -> Stock Deduction -> Ledger -> Return`.

---

### BUG-04: Mobile RenderFlex Overflows in Settings & Reports
- **Files:** 
  - `lib/features/reports/presentation/pages/reports_page.dart`
  - `lib/features/settings/presentation/pages/settings_page.dart`
- **Severity:** Medium
- **Description:** On screens with widths under 600px (standard phone viewports), layout overflow errors of 36px and 40px occurred in `_MiniMetric` and `_BusinessProfileSection`.
- **Root Cause:** Rows contained unconstrained text labels and fixed-width avatar/badge elements without responsive wrapping or `Expanded` constraints.
- **Resolution:**
  - In `reports_page.dart`: Wrapped metric title in `Expanded` with `TextOverflow.ellipsis`.
  - In `settings_page.dart`: Added `isMobile` check to dynamically layout the profile header and RBAC capability chips as responsive vertical columns when screen width is constrained.
- **Verification:** Widget tests in `phase4_4_reports_settings_access_test.dart` pump at 400x800 and 1366x900 viewports with zero RenderFlex exceptions.

