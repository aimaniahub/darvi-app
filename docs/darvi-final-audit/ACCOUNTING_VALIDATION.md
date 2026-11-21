# DARVI BILLING — ACCOUNTING VALIDATION REPORT

**Target Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Audit Scope:** Double-Entry Equilibrium, Ledger Invariant, GST Segregation, Transaction Rollback  
**Audit Date:** 2026-11-07  

---

## 1. Accounting Invariant Equation & Formal Proof

The Darvi Billing accounting engine operates on the strict general ledger invariant:

$$\sum_{i=1}^{N} \text{Debit}_i \equiv \sum_{i=1}^{N} \text{Credit}_i \quad \forall \text{ transactions in } \text{workspace } W$$

Under no circumstances can an unbalanced journal entry be committed. The database repository methods (`LocalLedgerRepository.postTransaction`) validate that:

$$|\sum \text{Debit} - \sum \text{Credit}| < 0.0001$$

If any deviation occurs, the transaction throws an `AppException('Unbalanced ledger transaction')` and rolls back all database modifications.

---

## 2. Standard Posting Groups Verification

### 2.1 Sale with GST Separation and Partial Credit
- **Transaction Purpose:** POS sale for ₹1062.00 (₹900.00 Net Product Price + 18% GST ₹162.00). Customer pays ₹500.00 via UPI; ₹562.00 remains on credit.
- **Ledger Entries Generated:**
  1. `Credit` - `revenue`: ₹900.00
  2. `Credit` - `tax_payable`: ₹162.00
  3. `Debit` - `account` (UPI Account #3): ₹500.00
  4. `Debit` - `party` (Customer #2): ₹562.00
- **Validation:**
  - $\sum \text{Debits} = 500.00 + 562.00 = 1062.00$
  - $\sum \text{Credits} = 900.00 + 162.00 = 1062.00$
  - **Result:** **BALANCED** ($\Delta = 0.00$)

### 2.2 Inward Purchase Bill with Supplier Credit
- **Transaction Purpose:** 40 units purchased at ₹300.00 = ₹12,000.00. Paid ₹2,000.00 from Bank Account; ₹10,000.00 remains payable to supplier.
- **Ledger Entries Generated:**
  1. `Debit` - `purchase`: ₹12,000.00
  2. `Credit` - `supplier` (Supplier #1): ₹12,000.00
  3. `Debit` - `supplier` (Supplier #1): ₹2,000.00
  4. `Credit` - `account` (Bank Account #2): ₹2,000.00
- **Validation:**
  - $\sum \text{Debits} = 12000.00 + 2000.00 = 14000.00$
  - $\sum \text{Credits} = 12000.00 + 2000.00 = 14000.00$
  - Supplier net payable balance derived from ledger = $12000.00 - 2000.00 = 10000.00$
  - **Result:** **BALANCED** ($\Delta = 0.00$)

### 2.3 Store Expense Payment
- **Transaction Purpose:** Monthly shop electricity and tea expenses of ₹800.00 paid from Cash Drawer.
- **Ledger Entries Generated:**
  1. `Debit` - `expense` (Category: `utilities`): ₹800.00
  2. `Credit` - `account` (Cash Drawer #1): ₹800.00
- **Validation:**
  - $\sum \text{Debits} = 800.00 \equiv \sum \text{Credits} = 800.00$
  - **Result:** **BALANCED** ($\Delta = 0.00$)

### 2.4 Staff Salary Disbursal
- **Transaction Purpose:** Salary payment of ₹21,000.00 disbursed via Bank Transfer.
- **Ledger Entries Generated:**
  1. `Debit` - `payroll` (Salary Expense): ₹21,000.00
  2. `Credit` - `account` (Bank Account #2): ₹21,000.00
- **Validation:**
  - $\sum \text{Debits} = 21000.00 \equiv \sum \text{Credits} = 21000.00$
  - **Result:** **BALANCED** ($\Delta = 0.00$)

### 2.5 Sales Return & Credit Note
- **Transaction Purpose:** Customer returns ₹1,600.00 worth of damaged goods.
- **Ledger Entries Generated:**
  1. `Debit` - `sale_return`: ₹1,600.00
  2. `Credit` - `account` (Cash Refund) or `party` (Customer Credit Note): ₹1,600.00
- **Validation:**
  - $\sum \text{Debits} = 1600.00 \equiv \sum \text{Credits} = 1600.00$
  - Stock quantity restored atomically.
  - **Result:** **BALANCED** ($\Delta = 0.00$)

---

## 3. Reversal & Anti-Duplication Controls

1. **Anti-Duplication in Payroll:**
   - Payroll records enforce unique `(workspace_id, employee_id, month, year)`.
   - The status transitions strictly from `pending` -> `approved` -> `disbursed`.
   - Once marked `disbursed`, subsequent calls to `disbursePayroll` throw an `AppException('Payroll record already disbursed')`.

2. **Transaction Rollback Testing:**
   - In SQLite test harnesses, intentional errors injected mid-checkout or mid-purchase trigger full database rollbacks. Zero orphaned records or unbalanced ledger rows persist.

