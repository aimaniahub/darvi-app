# DARVI BILLING — P2.5 COMPLETE SCREEN & FUNCTIONALITY AUDIT

**Target:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Date:** November 2026  
**Auditor:** Antigravity Pairing Assistant  

---

## 1. Executive Summary

This audit assesses every route, screen, navigation destination, dialog, bottom sheet, and action control in the Darvi Billing application to identify missing screens, incomplete UI components, broken navigation, or disconnected controls before implementing the P2.5 Business Dashboard and UI redesign.

---

## 2. Screen-by-Screen Audit Matrix

| Module | Route / Component | Exists? | UI Completeness | Data Integration | Actions & Buttons | Mobile / Tablet Status | Deficiencies & Action Required |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Home Dashboard** | `/home` | ❌ **Missing** | ❌ Missing | ❌ None | ❌ None | ❌ None | **P2.5 Primary Deliverable:** Build dedicated Business Home Dashboard with real KPIs, charts, quick actions, and activity feeds. |
| **Authentication** | `/login` | ✅ Yes | ⚠️ Basic | ✅ AuthRepo | ✅ Login works | ⚠️ Fixed width | Add Darvi green branding, leaf accent, and responsive centering. |
| **POS Billing** | `/pos` | ✅ Yes | ✅ Complete | ✅ SalesRepo | ✅ Functional | ✅ Responsive | Cart sync, GST calculation, discounts, partial payments all working. |
| **Stock & Products** | `/products` | ✅ Yes | ⚠️ Moderate | ✅ ProductRepo | ✅ CRUD works | ⚠️ Basic layout | Add quick stock adjustment dialog, low-stock filter chips, responsive grid on tablet. |
| **Purchases** | `/purchases` | ✅ Yes | ⚠️ Basic list | ✅ PurchaseRepo | ⚠️ Incomplete | ⚠️ Mobile only | Missing invoice detail sheet, missing search and payment status filters. |
| **Customers & Suppliers**| `/parties` | ✅ Yes | ⚠️ Moderate | ✅ PartyRepo | ✅ Functional | ⚠️ Needs polish | Add ledger passbook/statement modal for each party, filter by balance. |
| **Financials** | `/financials` | ✅ Yes | ⚠️ Incomplete | ✅ AccountRepo | ⚠️ Partial | ⚠️ Narrow cards | Currently only has 3 accounts and basic expenses. Missing full Double-Entry Ledger view and Cashbook tabs. |
| **Staff & HR** | `/employees` | ✅ Yes | ⚠️ Moderate | ✅ EmployeeRepo | ⚠️ Partial | ⚠️ Tabs basic | Has Staff, Attendance, Payroll tabs. Missing Incentives rules and claims management. |
| **Plots Management** | `/plots` | ✅ Yes | ✅ Complete | ✅ PlotRepo | ✅ Functional | ✅ Responsive | Has project filter, status chips, registration dialog, detail sheet. |
| **Farmland CRM** | `/crm` | ✅ Yes | ✅ Complete | ✅ CrmRepo | ✅ Functional | ✅ Responsive | Has 7 pipeline stages, lead editor, site visit dialog, activity log. |
| **Quotations** | `/quotations`| ✅ Yes | ✅ Complete | ✅ QuotationRepo | ✅ Functional | ✅ Responsive | Line items, GST breakdown, PDF quotation generator, sale conversion. |
| **Bookings** | `/bookings` | ✅ Yes | ✅ Complete | ✅ BookingRepo | ✅ Functional | ✅ Responsive | Plot double-booking prevention, 4-stage installments, refund flow. |
| **Deliveries** | `/deliveries`| ✅ Yes | ✅ Complete | ✅ DeliveryRepo | ✅ Functional | ✅ Responsive | Delivery orders, carrier info, tracking #, delivery lifecycle. |
| **Reports** | `/reports` | ✅ Yes | ⚠️ Moderate | ✅ ReportsRepo | ✅ Functional | ⚠️ Mobile list | Has sales and inventory tables. Needs cleaner visual hierarchy and date range picker. |
| **Settings** | `/settings` | ✅ Yes | ✅ Complete | ✅ SettingsRepo | ✅ Functional | ⚠️ Standard form | Store settings, tax, cashier PIN, receipt header/footer. |
| **App Shell** | Nav Bar / Drawer | ⚠️ Old | ⚠️ Outdated | ✅ Router | ⚠️ Missing Home | ⚠️ Mobile only | Redirects to `/pos` instead of `/home`. Bottom bar lacks proper 5-tab structure (Home, Billing, Stock, CRM, More). Needs tablet NavigationRail. |

---

## 3. Key Deficiencies to Resolve in P2.5

1. **Missing Default Business Home Dashboard (`/home`):**
   - Application currently drops users into `/pos` instead of a business management dashboard.
   - Users cannot see overall business health: today's sales, receivables, payables, monthly expenses, plot availability, or CRM leads.
2. **Missing Interactive Visual Analytics:**
   - No interactive sales trends, revenue vs expense charts, or payment method breakdowns.
3. **Application Shell & Navigation Restructuring:**
   - Bottom bar needs: **Home**, **Billing**, **Stock**, **CRM**, **More**.
   - Tablet/desktop displays must support a `NavigationRail` or sidebar rather than stretching mobile bottom navigation across 1200px.
   - Top AppBar needs workspace branding, active user role, notification badge, and printer indicator.
4. **Financials & HR Enhancement:**
   - Financials page must include full double-entry ledger audit log and account passbooks.
   - Employees page must include incentive rules and claims approval.
5. **Purchases & Parties Polish:**
   - Purchase invoice detail view with item breakdown and payment status badges.
   - Party ledger passbook view showing debits, credits, and running balance.

