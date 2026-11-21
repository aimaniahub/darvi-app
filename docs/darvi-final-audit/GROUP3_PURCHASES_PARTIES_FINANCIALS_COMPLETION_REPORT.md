# DARVI GROUP AGRI TECH — GROUP 3 MASTER IMPLEMENTATION REPORT
## Complete Purchases + Customer/Supplier Management + Financial Management & Accounts

**Entity:** Darvi Group Agri Tech (`29BKZPA0053M1ZQ`, Gokul Road, Hubli, Karnataka 580030)  
**Date:** November 7, 2026  
**Status:** COMPLETE & VERIFIED (72 / 72 tests passing, 0 compiler warnings/errors)  
**Architecture:** Drift + SQLite (in-memory & persistent), Cubit BLoC, GoRouter, Double-Entry Balanced Ledger  
**Previous Groups Verified:** Products, Stock, POS, Employee Management, Attendance, Payroll and Incentives.

---

## 1. Executive Summary

Group 3 delivers the foundational B2B commercial and accounting backbone of the **Darvi Billing** system for Darvi Group Agri Tech. The three core modules—**Purchase Management**, **Customer & Supplier (Parties) Management**, and **Financial Management & Accounts**—have been completed end-to-end with interconnected database tables, transactional repositories, reactive Cubits, and Material 3 UI dashboards, modals, profile sheets, and reports.

### Key Architectural Invariants Guaranteed
1. **Strict Double-Entry Balance Invariant:** Every financial transaction posts balanced debit and credit entries (`Total Debit == Total Credit`). If an unbalanced transaction is attempted, an `AppException` is thrown and the SQLite transaction rolls back.
2. **Stock & Batch Integrity:** Purchase bills automatically increment inventory quantities, generate `stock_movements` log rows with references, and create batch inward records with manufacturing and expiry dates. Returns deduct stock and debit notes adjust supplier balances.
3. **Safe Reversals Over Historical Overwrites:** Modifying or cancelling a purchase bill or expense never mutates or drops historical ledger history; it writes balanced reversing entries and reposts current corrected records.
4. **Party Credit & Exposure Monitoring:** Customer credit limits, payment terms, and real-time receivables/payables are calculated from immutable double-entry ledger entries.

---

## 2. Module 1: Purchase Management Implementation

### 2.1 Purchase Dashboard & Metrics
- **Location:** `lib/features/purchases/presentation/pages/purchases_page.dart`
- **Computed Metrics (derived from real SQLite purchase and ledger records):**
  - **Total Purchases:** Aggregate inward purchase value across all valid bills.
  - **Today's Purchases:** Current date inward volume.
  - **Monthly Purchases:** Current month-to-date purchases.
  - **Total Paid:** Inward disbursements made to suppliers.
  - **Total Outstanding:** Unsettled supplier liability.
  - **Pending Supplier Invoices:** Count of unpaid or partially paid purchase bills.
  - **Purchase Returns / Debit Notes:** Total refunded or credited via debit notes.
  - **Recently Received Stock:** Toggleable live view of recent stock inward movements.
- **Filter Bar:** Date range picker (From/To), Supplier selection filter, Payment Status filter (`All`, `Unpaid`, `Partial`, `Paid`, `Cancelled`), and live Search by bill number or internal reference.

### 2.2 Multi-Item Purchase Invoice Creation Workflow
- **Modal:** `_openCreatePurchaseInvoiceSheet()` with full state persistence.
- **Supplier Selection & Inline Registration:**
  - Select existing supplier from dropdown with real-time balance indicator.
  - Inline supplier quick registration modal without losing the in-progress bill state.
  - Supplier GSTIN, contact person, mobile, and payment terms auto-populated.
  - Internal purchase reference number generation.
- **Multi-Item Entry Table:**
  - Select existing catalog products or add multiple lines.
  - Line quantity, purchase unit (`bag`, `kg`, `litre`, `bottle`, `packet`, `unit`), unit cost, and line discount.
  - HSN code, GST rate (`0%`, `5%`, `12%`, `18%`, `28%`).
  - Batch number, manufacturing date, expiry date.
  - Line total dynamically computed.
- **Tax & Invoice Calculation Engine:**
  - Gross subtotal.
  - Item discount total.
  - Invoice-level discount with real-time recalculation.
  - Support for **Tax Inclusive (MRP)** and **Tax Exclusive** rates.
  - Intra-state (CGST + SGST) vs Inter-state (IGST) automatic breakdown.
  - Auto round-off to nearest rupee.
  - Grand total and outstanding balance calculated before save.
- **Payment Information:**
  - Full payment, partial payment, or zero-down credit purchase.
  - Payment account selection (`Store Cash Drawer`, `Company Bank Account`, `Store UPI Account`).
  - Payment reference number (UTR / Cheque).

### 2.3 Atomic Save & Rollback
- Confirmation executes atomically in an SQLite transaction:
  1. Validates unique supplier bill number for the supplier.
  2. Creates `purchase_invoices` header.
  3. Creates `purchase_invoice_items` line records with snapshots.
  4. Inserts `product_batches` inward record with expiry tracking.
  5. Increments `products.stock_qty`.
  6. Creates `stock_movements` record of type `purchase`.
  7. If payment made upfront, creates `payments` disbursement record.
  8. Posts balanced ledger transaction:
     - Debit: Inventory Asset (Subtotal)
     - Debit: Input Tax Asset / CGST / SGST / IGST (Tax Total)
     - Credit: Supplier Payable (Total Bill Amount)
     - If upfront payment: Debit Supplier Payable, Credit Account Asset.
  9. Commits atomically.

### 2.4 Safe Invoice Editing & Cancellation
- **Safe Editing (`editPurchaseInvoice`):**
  - Reverses previous stock quantities from products and batches.
  - Inserts stock movement adjustment reversal log.
  - Posts balanced reversing ledger entries.
  - Inwardly applies new item quantities and new batches.
  - Updates supplier liability and posts corrected double-entry records.
- **Safe Cancellation (`cancelPurchaseInvoice`):**
  - Marks bill `is_cancelled = 1`.
  - Deducts received inventory from products and batches.
  - Reverses supplier payable ledger liability.
  - If payments were made, posts refund entries back to the payment account.

### 2.5 Purchase Returns & Debit Notes
- **Implementation:** `createPurchaseReturn()` in `local_purchase_repository.dart`.
- Select original purchase invoice and items.
- Strict validation: return quantity cannot exceed purchased quantity minus already returned quantity.
- Generates debit note number (`DN-YYYY-XXXX`).
- Deducts stock from inventory and product batch.
- Posts balanced reversal: Debit Supplier Liability, Credit Inventory Asset, Credit Input GST Reversal.
- Updates invoice `returned_amount` and `returned_qty`.

### 2.6 Purchase Detail Sheet & Reporting
- Dedicated bottom sheet with 5 tabs:
  1. **Items Breakdown:** Product name, SKU, purchase unit, unit cost, batch, returned count, and line total.
  2. **GST & Totals:** Gross subtotal, discounts, taxable value, CGST, SGST, IGST, round-off, grand total, and due balance.
  3. **Payment History:** All disbursements made against this invoice with account names and reference numbers.
  4. **Debit Notes:** List of returned goods, reasons, and debit note amounts.
  5. **Ledger Audit:** Immutable double-entry ledger entries with debit/credit badges.
- **Reporting:** Supplier-wise purchase volume, product-wise inward costs, monthly trends, and GST input tax credit summary.

---

## 3. Module 2: Customer and Supplier Management Implementation

### 3.1 Parties Dashboard
- **Location:** `lib/features/parties/presentation/pages/parties_page.dart`
- **7 Summary Metrics:**
  - Total Customers & Active Customers.
  - Total Suppliers & Active Suppliers.
  - Total Customer Receivables (from ledger).
  - Total Supplier Payables (from ledger).
  - Customers with Outstanding Balances.
  - Suppliers Awaiting Payment.
- Tabbed interface between **Customers Directory** and **Suppliers Directory** with instant search by name, code, phone, or GSTIN.

### 3.2 Customer Registration & Editing (14 Fields)
1. Customer Full Legal Name
2. Customer Code (unique validation, auto-generated e.g. `CUST-AGRI-001`)
3. Primary Mobile
4. Alternate Mobile / Landline
5. Email Address
6. Billing / Delivery Address
7. State (with GST state code resolution, defaults to Karnataka)
8. GSTIN (15-character formatted)
9. Customer Type (`individual`, `business`, `gst_registered`, `walk_in`)
10. Opening Balance
11. Credit Limit (defaults to ₹10,000, customizable up to enterprise scale)
12. Credit Period Days (defaults to 30 days)
13. Notes / Dealership remarks
14. Active status toggle
- Duplicate code check enforces uniqueness.
- Soft-delete protection prevents deletion of customers with transaction history.

### 3.3 Supplier Registration & Editing (12 Fields)
1. Supplier Legal Company Name
2. Supplier Code (unique validation, e.g. `SUP-KAC-001`)
3. Contact Person Name
4. Primary Mobile Phone
5. Email Address
6. Business Address
7. GSTIN
8. State (Karnataka default)
9. Opening Balance
10. Payment Terms (`Net 15`, `Net 30`, `Net 45`, `Immediate`, `Custom`)
11. Notes & Dealership details
12. Active status toggle

### 3.4 Customer Collections Workflow
- Dialog: `_openCustomerCollectionDialog()`
- Displays current customer outstanding ledger balance.
- Input collection amount, payment method (Cash, Bank, UPI), target account, payment date, reference number, and narration.
- **Invoice Allocation:** Supports allocating collection against multiple outstanding sales invoices.
- Records payment in `payments` and inserts allocation records in `party_payment_allocations`.
- Posts double-entry ledger entry:
  - Debit: Financial Account Asset (Cash / Bank increases)
  - Credit: Customer Receivable (Customer liability decreases)
- Reconciles trial balance immediately.

### 3.5 Supplier Payouts Workflow
- Dialog: `_openSupplierPayoutDialog()`
- Displays current supplier outstanding liability.
- Input payout amount, source account, payment method, reference, and date.
- Supports invoice allocation to specific purchase bills.
- Records payout in `payments`, updates `purchase_invoices.paid_amount` and status (`partial` / `paid`).
- Posts double-entry ledger entry:
  - Debit: Supplier Payable (Supplier liability decreases)
  - Credit: Financial Account Asset (Cash / Bank decreases)

### 3.6 Auditable Opening Balances
- `adjustPartyOpeningBalance()` in `LocalPartyRepository`.
- Rather than destructively overwriting past balances, posts an auditable opening balance adjustment entry balanced against Capital/Equity (`reference_type = 'equity'`).
- Preserves full audit history and trial balance integrity.

### 3.7 Party Profiles (Dedicated 4–5 Tab Sheets)
- **Customer Profile:**
  - Overview: Contact info, GSTIN, credit limit, credit period, utilization percentage, outstanding balance.
  - Sales Invoices: List of all sales bills with dates, payment method, status, and totals.
  - Collections: Payment history received with account references.
  - Ledger Statement: Chronological Dr/Cr statement with running balance.
- **Supplier Profile:**
  - Overview: Contact person, terms, GSTIN, address, total purchases, total paid, and outstanding payable.
  - Purchase Bills: Listing of all inward invoices with status and outstanding amounts.
  - Payouts: Listing of disbursements made to supplier.
  - Returns / Debit Notes: Issued debit notes.
  - Ledger Statement: Full Dr/Cr running ledger.

---

## 4. Module 3: Financial Management and Accounts Implementation

### 4.1 Financial Dashboard
- **Location:** `lib/features/financials/presentation/pages/financials_page.dart`
- **Computed Real-Time KPIs:**
  - Cash Balance (from Cash Drawer ledger).
  - Bank Balances (from Bank accounts ledger).
  - UPI Balances (from UPI accounts ledger).
  - Total Liquid Balance.
  - Today's Collections.
  - Today's Payments / Payouts.
  - Monthly Operating Expenses.
  - Customer Receivables.
  - Supplier Payables.
  - Payroll Paid (Month-to-date).
  - Incentives Paid (Month-to-date).
- Action Bar: Quick access to **Money Received**, **Money Paid**, **Account Transfer**, and **Record Expense**.

### 4.2 Account Management
- Supports Cash, Bank, and UPI accounts.
- Fields: Name, type, account number, opening balance, bank name, IFSC code, UPI ID, default account switch, active switch.
- **Balance Protection:** `deactivateAccount()` explicitly checks if the account has a non-zero ledger balance; if non-zero, deactivation is blocked with an `AppException` to prevent orphaned funds.

### 4.3 Inter-Account Fund Transfers
- Implementation: `transferFunds()` in `local_account_repository.dart`.
- Select source account and destination account.
- Verifies source account has sufficient balance before initiating transfer.
- Inserts transfer record in `payments`.
- Posts balanced double-entry ledger entry:
  - Debit: Destination Account Asset (balance increases)
  - Credit: Source Account Asset (balance decreases)
  - Narration: Transfer reference and purpose.

### 4.4 Operating Expense Management & Recoverable Input GST
- Implementation: `local_expense_repository.dart`.
- Categories: `Rent`, `Electricity`, `Tea/Snacks`, `Transport`, `Marketing`, `Repairs`, `Utilities`, `Other`.
- Supports vendor/payee, reference number, invoice attachment URL, net expense amount, and recoverable input GST (`tax_amount`).
- **Accounting Posting:**
  - Debit: Operating Expense (Net amount)
  - Debit: Input Tax Asset / Recoverable GST (`tax_amount`)
  - Credit: Financial Account Asset (Gross amount paid)
- **Safe Cancellation (`cancelExpense`):** Reverses expense and tax debits and refunds the financial account with full balance reconciliation.

### 4.5 Cashbook Journal
- Generates chronological list of all cash and bank inflows/outflows.
- Date, description, account name, reference, type (`receipt`, `payment`, `transfer`), Debit, Credit, and Running Balance.

### 4.6 System-Wide Double-Entry Ledger & Trial Balance Reconciliation
- Comprehensive double-entry audit viewer with date, transaction type, and account filters.
- `reconcileBalances()` performs 4 verification checks:
  1. **Trial Balance Invariant:** `Total Debit == Total Credit` (diff `< 0.01`).
  2. **Accounts Reconciliation:** Ledger balance vs account registry.
  3. **Customer Receivables:** Sum of customer debits minus credits.
  4. **Supplier Payables:** Sum of supplier credits minus debits.
- **Profit & Loss Statement Engine:** Computes Net Sales (Revenue minus discounts), Cost of Goods Sold (COGS from line item cost snapshots), Gross Profit, Operating Expenses by category, and Net Profit.

---

## 5. Automated Verification & Test Results

An automated Flutter test suite was created in `test/group3_purchases_parties_financials_test.dart` and executed alongside all existing project test suites:

```
flutter test test/group3_purchases_parties_financials_test.dart
```

### Test Suite Execution Matrix (All 18 Tests Passed)

| # | Test Scenario | Module | Result |
|---|---------------|--------|--------|
| **1.1** | Multi-item purchase invoice creation, stock inward, batch tracking, supplier payable ledger | Purchases | **PASS** |
| **1.2** | Duplicate purchase invoice number prevention for same supplier | Purchases | **PASS** |
| **1.3** | Safe purchase editing: reversals of previous stock and ledger, applying new quantities | Purchases | **PASS** |
| **1.4** | Purchase return / debit note: reduces stock, reverses batch & GST, credits supplier | Purchases | **PASS** |
| **1.5** | Validation: Cannot return more items than purchased | Purchases | **PASS** |
| **1.6** | Purchase dashboard metrics and purchase report summaries | Purchases | **PASS** |
| **2.1** | Customer registration with 14 fields and duplicate code validation | Parties | **PASS** |
| **2.2** | Supplier registration with 12 fields and duplicate code validation | Parties | **PASS** |
| **2.3** | Customer collection workflow with invoice allocation and balanced ledger posting | Parties | **PASS** |
| **2.4** | Supplier payout workflow with invoice allocation and balanced ledger posting | Parties | **PASS** |
| **2.5** | Auditable opening balance adjustments create balanced ledger entries | Parties | **PASS** |
| **2.6** | Party profile queries for customer and supplier statements & transactions | Parties | **PASS** |
| **3.1** | Account management and deactivation balance protection | Financials | **PASS** |
| **3.2** | Inter-account fund transfer between Cash, Bank, and UPI accounts | Financials | **PASS** |
| **3.3** | Expense recording with recoverable input GST and safe cancellation reversal | Financials | **PASS** |
| **3.4** | Cashbook generation and chronological transaction tracking | Financials | **PASS** |
| **3.5** | Financial dashboard metrics and P&L statement generation | Financials | **PASS** |
| **3.6** | System-Wide Double-Entry Ledger Trial Balance Verification (Total Dr == Total Cr) | Financials | **PASS** |

### Full Project Regression Test Run
```
flutter test
Result: 00:16 +72: All tests passed! (72 passing tests across entire project)
```

### Static Analysis
```
flutter analyze --no-fatal-infos
Result: 0 errors, 0 warnings across all production and test files.
```

---

## 6. Verification Checklist Against Master Spec

- [x] **1.1 Purchase dashboard:** Total purchases, today, monthly, paid, outstanding, pending count, returns total, recent received stock toggle, and multi-criteria filters.
- [x] **1.2 Purchase invoice creation:** Supplier selection, inline registration, GSTIN, HSN, batches, multi-product line entry, tax inclusive/exclusive toggle, CGST/SGST/IGST, payment accounts.
- [x] **1.3 Purchase validation:** Mandatory supplier, positive quantities, batch details, duplicate invoice number prevention for same supplier.
- [x] **1.4 Purchase save workflow:** Atomic execution, stock inward, batch creation, movement logs, supplier payable posting, balanced ledger entries.
- [x] **1.5 Purchase invoice history:** List view with date, supplier, amount, status badge, search, and action menus.
- [x] **1.6 Purchase details:** 5-tab detail sheet covering item breakdown, GST calculations, payment history, debit notes, and ledger audit.
- [x] **1.7 Purchase editing:** Safe stock and ledger reversal without deleting historical audit trails.
- [x] **1.8 Purchase payments:** Full and partial payment recording, source account selection, remaining payable calculation.
- [x] **1.9 Purchase returns & debit notes:** Original invoice linking, excess return prevention, stock reduction, batch deduction, GST reversal, debit note generation.
- [x] **1.10 Purchase reporting:** Supplier-wise, product-wise, monthly trends, GST input summary.
- [x] **2.1 Parties dashboard:** Customer and supplier counts, receivables, payables, outstanding balances, tabbed directory.
- [x] **2.2 Customer registration:** 14 fields including code, phone, alternate phone, email, state, GSTIN, credit limit, credit period days, opening balance.
- [x] **2.3 Supplier registration:** 12 fields including contact person, payment terms, opening balance, notes, and active switch.
- [x] **2.4 Customer and supplier editing:** Authorized changes preserving financial integrity.
- [x] **2.5 Party profiles:** Dedicated tabbed sheets with transactions, collections/payouts, debit notes, and running ledger.
- [x] **2.6 Customer collections:** Outstanding balance display, receipt recording, invoice-wise allocation, balanced ledger posting.
- [x] **2.7 Supplier payouts:** Outstanding balance display, disbursement recording, invoice-wise allocation, balanced ledger posting.
- [x] **2.8 Opening balances:** Auditable adjustments via equity offset.
- [x] **2.9 Credit management:** Exposure tracking, credit limit checks, credit terms.
- [x] **2.10 Party statements:** Running balances with Dr/Cr entries.
- [x] **3.1 Financial dashboard:** Cash, bank, UPI balances, today's collections, payments, monthly expenses, receivables, payables, payroll paid, incentives paid.
- [x] **3.2 Account management:** Cash/Bank/UPI account creation, IFSC, bank name, balance-protected deactivation.
- [x] **3.3 Money received & 3.4 Money paid:** Receipts and payouts with ledger updates.
- [x] **3.5 Fund transfers:** Inter-account transfers with balance verification and Dr/Cr posting.
- [x] **3.6 Operating expenses:** Expense categories, recoverable input GST, vendor/payee tracking, safe cancellation with fund reversal.
- [x] **3.7 Cashbook:** Inflow/outflow journal with running balance.
- [x] **3.8 Balanced ledger & 3.9 Reconciliation & 3.10 Financial reporting:** Double-entry audit viewer, trial balance invariant verification, P&L reporting.

---

## 7. Sign-Off & Conclusion

Group 3 Master Implementation for **Darvi Billing** is complete, fully functional, and verified with zero regressions across the codebase. All financial, inventory, party, and purchase transactions operate through atomic SQLite transactions maintaining double-entry accounting integrity.

