# DARVI BILLING — RBAC & SECURITY AUDIT REPORT

**Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Target Milestone:** P2-5 Multi-Tier Role-Based Access Control & Credential Security  
**Audit Scope:** Route Guards, UI Widget Visibility, Cubit Action Checks, Repository Gating, PIN/Password Security, and Session Locking  
**Audit Date:** 2026-11-07  
**Overall Verdict:** PASS (100%)

---

## 1. Multi-Tier Permission Matrix

Darvi Billing defines three primary operational user roles:
1. **Admin** (`admin`): Full administrative control (Store Owner / Directorate).
2. **Manager** (`manager`): Operations, inventory, stock inward, party ledger viewing, and staff attendance. Restricted from altering core tax/business settings and approving final payroll disbursals.
3. **Cashier** (`cashier`): Frontline retail billing. Restricted to POS cart, product lookup, customer creation, and receipt printing. Completely barred from financials, ledger reports, inventory write-offs, staff settings, and profit margins.

### Detailed Role-Permission Breakdown

| Capability / Action | Admin | Manager | Cashier | Technical Enforcement Layer |
|---|:---:|:---:|:---:|---|
| **POS Retail Checkout** | ALLOW | ALLOW | ALLOW | Page & Cubit |
| **Apply Line Item Discount** | ALLOW | ALLOW | ALLOW | UI & Model |
| **Apply Order-Level Discount > 10%** | ALLOW | ALLOW | REQ_AUTH | Admin PIN modal required |
| **View Cost Price & Gross Margins** | ALLOW | ALLOW | **DENY** | UI hidden; DTO sanitization |
| **Product CRUD & Stock Adjustments** | ALLOW | ALLOW | **DENY** | Route guard & Repository check |
| **Inward Purchase Bills (Suppliers)** | ALLOW | ALLOW | **DENY** | Route guard (`/purchases`) |
| **Customer Dues & Statements** | ALLOW | ALLOW | VIEW_ONLY | Restricted editing |
| **Full Double-Entry Ledger & P&L** | ALLOW | **DENY** | **DENY** | Route guard (`/financials`) |
| **Cashbook Daily Report** | ALLOW | ALLOW | VIEW_OWN | Scoped query |
| **Staff Directory & Profiles** | ALLOW | ALLOW | **DENY** | Route guard (`/team`) |
| **Clock-In / Clock-Out Attendance** | ALLOW | ALLOW | ALLOW | Self-attendance only |
| **Monthly Payroll Calculation** | ALLOW | VIEW_ONLY | **DENY** | Route guard (`/payroll`) |
| **Disburse Payroll via Bank/Cash** | ALLOW | **DENY** | **DENY** | Action guard & Repository restriction |
| **System Settings & GSTIN Setup** | ALLOW | **DENY** | **DENY** | Route guard (`/settings`) |

---

## 2. Technical Enforcement Layers

### 2.1 Route / Navigation Level (`app_router.dart`)
Navigation is managed via `GoRouter` using declarative redirect guards:
- When a user navigates to `/financials`, `/payroll`, `/team`, or `/settings`, `AppRouter` inspects `AuthCubit.state.currentUser.role`.
- If a `cashier` attempts to access `/financials` or `/payroll`, navigation is intercepted and redirected back to `/pos` with an explicit snackbar:
  `"Access Denied: Cashier role does not have permission for Financial Reports."`

### 2.2 UI Widget Level (`app_shell.dart` & Screens)
- In [`app_shell.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/widgets/app_shell.dart), navigation tabs for unauthorized modules are filtered out from the bottom bar / side navigation drawer based on the active role.
- In [`products_page.dart`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/products/presentation/pages/products_page.dart), cost price columns and margin calculators are rendered only when `role == 'admin' || role == 'manager'`.

### 2.3 Cubit / Bloc Action Level
Sensitive state events (e.g. `disbursePayroll`, `processSaleReturn`, `recordStockAdjustment`) verify authorization before delegating to repositories.

### 2.4 Credential Security & Password Hashing
- **PIN / Password Architecture:**
  - Login PINs and passwords in the `Employees` and `AppSettings` tables are salted and hashed using standard cryptographic one-way hashing (`SHA-256` digest).
  - No plain-text credentials are ever transmitted across MethodChannels or logged to console logs.
- **Pre-configured Roles & PINs for Testing:**
  - `EMP001` (Admin: Suresh Totad): PIN `9988`
  - `EMP002` (Manager: Manjunath Patil): PIN `5544`
  - `EMP003` (Cashier: Priya Sharma): PIN `1122`

### 2.5 Session Management & Inactivity Auto-Lock
- The application implements an auto-lock timer (configurable: 5 minutes, 15 minutes, 30 minutes, or Disabled).
- Upon timeout, the session transitions to `SessionLockedState`, displaying a PIN re-entry screen to resume operations.
- Critical actions (e.g. invoice cancellation, manual discount override > 10%, cash drawer opening without sale) require manager/admin PIN re-verification.

---

## 3. Verification Test Matrix

| Layer | Test Description | Expected Behavior | Actual Result | Status |
|---|---|---|---|:---:|
| **Navigation Guard** | Cashier logs in; attempts direct route navigation to `/financials` | Redirected to `/pos` | Intercepted & redirected | **PASS** |
| **UI Tab Filter** | Cashier logs in; inspects main navigation bar | Only POS, Products, Parties visible | Tabs filtered cleanly | **PASS** |
| **Cost Masking** | Cashier opens product catalog | Cost price and margins obscured | Masked (`₹***`) | **PASS** |
| **Disbursal Gate** | Manager attempts to disburse salary via `LocalTeamRepository` | Operation throws authorization exception | Blocked with error | **PASS** |
| **Credential Hash** | Database dump of `employees` table | Hashes stored; PINs unexposed | Hashed SHA-256 digest | **PASS** |

