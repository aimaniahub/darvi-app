# DARVI BILLING — RBAC & SECURITY AUDIT REPORT

**Target Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Security Model:** Role-Based Access Control (RBAC) with SQLite Foreign Key Enforcement  
**Audit Date:** 2026-11-07  

---

## 1. Operational Roles & Permissions Matrix

| Functional Module | System Action | Admin Role | Manager Role | Cashier Role | Enforcement Mechanism |
|---|---|:---:|:---:|:---:|---|
| **POS Billing** | Scan & Add to Cart | Allowed | Allowed | Allowed | UI enabled |
| | Apply Item Discount | Allowed | Allowed | Restricted (Max 5%) | UI validation |
| | Apply Bill Discount | Allowed | Allowed | Restricted (Requires PIN) | Modal gate |
| | Change Selling Price | Allowed | Allowed | Restricted | Field disabled |
| | Process Checkout | Allowed | Allowed | Allowed | UI enabled |
| | Process Sales Return | Allowed | Allowed | Restricted | Route/Button gate |
| **Inventory** | View Products & Stock | Allowed | Allowed | Allowed | UI enabled |
| | Create / Edit Product | Allowed | Allowed | Restricted | Button hidden |
| | Delete Product | Allowed | Restricted | Restricted | Button hidden |
| | Stock Manual Adjustment | Allowed | Allowed | Restricted | Dialog gate |
| **Parties** | View Customers & Balance | Allowed | Allowed | Allowed | UI enabled |
| | Add / Edit Customer | Allowed | Allowed | Allowed | UI enabled |
| | Delete Customer | Allowed | Restricted | Restricted | Button hidden |
| | Supplier Management | Allowed | Allowed | Restricted | Tab hidden |
| **Purchases** | Inward Purchase Bills | Allowed | Allowed | Restricted | Route hidden |
| | Supplier Payments | Allowed | Allowed | Restricted | Dialog hidden |
| **Financials** | Cash Drawer Management | Allowed | Allowed | Allowed | Tab enabled |
| | Bank Account Transfers | Allowed | Restricted | Restricted | Action disabled |
| | Store Expense Entry | Allowed | Allowed | Restricted | Action gated |
| | General Ledger Audit | Allowed | Restricted | Restricted | Route hidden |
| **Staff & HR** | View Employee Directory | Allowed | Allowed | Restricted | Route hidden |
| | Attendance Logging | Allowed | Allowed | Self Only | UI enabled |
| | Payroll Calculation | Allowed | Restricted | Restricted | Tab hidden |
| | Salary Disbursal | Allowed | Restricted | Restricted | Action gated |
| | Incentive Rule Approval | Allowed | Restricted | Restricted | Button hidden |
| **Reports** | Daily Sales & Invoices | Allowed | Allowed | Own Sales Only | Query filter |
| | P&L and Margin Reports | Allowed | Restricted | Restricted | Card hidden |
| | Tax (GST) Reports | Allowed | Allowed | Restricted | Tab hidden |
| **Settings** | Business Profile & Tax | Allowed | Restricted | Restricted | Route hidden |
| | Database Reset & Backup | Allowed | Restricted | Restricted | Action gated |

---

## 2. Technical Security Controls

1. **Authentication:**
   - Cashiers log in via a fast 4-digit PIN stored in `employees.login_pin`.
   - Administrators authenticate with administrative credentials stored in `app_settings.admin_password`.
2. **Session Security:**
   - Sessions are managed by `AuthSession(role, loginTime)` inside `AppCubit`.
   - Route transitions are guarded by GoRouter redirect checks in [app_router.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/app/router/app_router.dart).
3. **Database Security:**
   - Direct SQL injection is prevented through parameterized prepared statements (`Variable.withInt()`, `Variable.withString()`, and `?` placeholders).
   - Foreign key integrity is strictly enforced via `PRAGMA foreign_keys = ON;`.

