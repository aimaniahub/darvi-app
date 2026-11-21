# DARVI BILLING — END-TO-END INTEGRATION TEST REPORT

**Target Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Test Harness:** Python 3.12 / SQLite 3.49 Automated Integration Harness (`test/test_darvi_e2e_workflows.py`)  
**Audit Date:** 2026-11-07  

---

## 1. Test Suite Summary

```text
======================================================================
Ran 6 tests in 0.006s

OK (100% Passed)
======================================================================
```

All 6 comprehensive integration workflows executed cleanly without assertion failures or schema integrity errors.

---

## 2. Individual Workflow Execution Log

### Workflow 1: Product Lifecycle (Creation → Purchase Inward → POS Sale → Printing)
- **Input:**
  - Product created: "Bio Fertiliser 50kg" (SKU: `SKU-BIO-50`, HSN: `3101`, GST: 5%, Cost: ₹400.0, Price: ₹600.0). Initial stock: `0`.
  - Inward Purchase: 100 units from "Karnataka Agro Mills" for ₹40,000.00. Paid ₹10,000.00 from Bank; ₹30,000.00 payable.
  - Stock after purchase: `100`.
  - POS Sale: 10 units sold for ₹6,000.00 + 5% GST (₹300.00) = ₹6,300.00 cash.
  - Stock after sale: `90`.
- **Validation:**
  - Product stock accurately transitioned from `0` → `100` → `90`.
  - General ledger generated balanced postings for purchase and sale.
  - **Status: PASS**

### Workflow 2: Customer Credit Sale & Subsequent Settlement
- **Input:**
  - Customer registered: "Basavaraj Patil" (GSTIN: `29BPT1234M1Z1`).
  - Credit Sale: Invoice for ₹5,000.00. Customer paid ₹1,000.00 cash; ₹4,000.00 booked as outstanding debt.
  - Verification: Customer ledger balance queried: Due = ₹4,000.00.
  - Settlement: Customer pays ₹4,000.00 via UPI (Account #3).
  - Verification: Customer ledger balance queried: Due = ₹0.00.
- **Validation:**
  - Single source of truth ledger accurately tracks open dues and settlements without balance drift.
  - **Status: PASS**

### Workflow 3: Sales Return Stock Restoration & Reversal
- **Input:**
  - Product "Drip Irrigation Pipe 16mm" with initial stock `50`.
  - Sale of 5 units (Stock = `45`).
  - Return of 2 units (Return invoice `RET-20261107-0001` for ₹1,600.00).
- **Validation:**
  - Stock restored atomically to `47`.
  - Ledger posting generated balanced debit of ₹1,600.00 to returns and credit of ₹1,600.00 to cash refund.
  - **Status: PASS**

### Workflow 4: Employee Attendance, Prorated Payroll & Bank Disbursal
- **Input:**
  - Staff "Ramesh Kumar" registered with monthly base salary of ₹24,000.00.
  - 25 days marked present in October 2026.
  - Calculated net pay: $(25 / 30) \times 24000.00 = ₹20,000.00$.
  - Disbursed from Bank Account #2.
- **Validation:**
  - Disbursal recorded in `payroll_records` with timestamp.
  - Paired ledger entries created: Debit `payroll` ₹20,000.00, Credit `bank` ₹20,000.00.
  - **Status: PASS**

### Workflow 5: Sales Incentive Calculation, Approval & Cash Payout
- **Input:**
  - Incentive rule active: 2% commission on equipment sales exceeding ₹10,000.00.
  - Staff "Sunil Gowda" logs a ₹50,000.00 irrigation pump sale.
  - Generated claim: $50000.00 \times 0.02 = ₹1,000.00$.
  - Claim approved and paid out from Cash Drawer #1.
- **Validation:**
  - Claim status updated to `approved`.
  - Debit `incentive_payout` ₹1,000.00 balances Credit `cash_drawer` ₹1,000.00.
  - **Status: PASS**

### Workflow 6: Multi-Tenant Workspace Isolation
- **Input:**
  - Workspace 1 ("Darvi Group Agri Tech", Hubli).
  - Workspace 2 ("Darvi Branch 2", Dharwad).
  - Products, accounts, and ledger entries created independently in both workspaces.
- **Validation:**
  - Workspace 1 queries returned strictly Workspace 1 entities.
  - Workspace 2 queries returned strictly Workspace 2 entities.
  - Zero cross-tenant data leakage observed.
  - **Status: PASS**

