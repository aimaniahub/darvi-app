# DARVI BILLING — PHASE 5.1 FINANCIAL HARDENING REPORT

**Audit Date:** November 9, 2026  
**Auditor / Agent:** Antigravity System Architect  
**Scope:** Financial Invariant Hardening, Mathematical Partial Return & Incentive Reversals, GST Tax Accuracy, and Accounting Reconciliation.

---

## EXECUTIVE SUMMARY

In Phase 5.1, the financial ledger and sales return sub-systems of **Darvi Billing** were hardened against edge cases, accounting imbalances, and state desynchronizations. The primary defect identified was the naive total cancellation of sales incentive claims upon any return action (including single-unit partial returns). Furthermore, GST calculations were audited to strictly support intrastate (CGST + SGST) vs interstate (IGST) split accounting, per-line item tax allocations prior to discounting, credit note treatment for sales returns, and excluded draft/cancelled states.

Every financial operation is wrapped in ACID SQLite transactions, preserving double-entry ledger balance invariants:
$$\sum \text{Debit} = \sum \text{Credit}$$

---

## 1. PARTIAL SALES RETURN & INCENTIVE REVERSAL HARDENING

### 1.1 Defect Analysis in Prior Versions
Previously, when a return occurred against a sale (`LocalSalesRepository.returnItems`), any associated incentive claim was unconditionally set to `status = 'rejected'` and its entire amount zeroed out. This caused:
1. Sales agents losing 100% of their commission even when a customer only returned 1 out of 10 items.
2. Inability to track incremental or multiple sequential returns against a single invoice.
3. Lack of ledger reversal for claims that had already been paid out to the employee.

### 1.2 Mathematical Proportional Reversal Algorithm
In `lib/data/repositories/local_sales_repository.dart`, the incentive reversal algorithm was re-engineered:
- For **percentage revenue rules** ($R\%$), the reversal amount for each returned item is calculated on its actual post-discount line value:
  $$\text{ItemReversal} = \left(\frac{\text{original.lineTotal}}{\text{original.qty}}\right) \times \text{returnQty} \times \frac{R}{100}$$
- For **fixed-rate per product rules** (\$F per unit of Product $P$):
  $$\text{ItemReversal} = \text{returnQty} \times F$$
- **Cap and Invariant Guarantee:**
  $$\text{Reversal} = \min\Big(\text{CalculatedReversal}, \;\max(0.0, \text{OriginalClaimAmount} - \text{PriorReversed})\Big)$$
- **Claim Status Transitions:**
  - If $\text{RemainingAmount} \le 0.0$ or $\text{isFullReturn}$:
    - Pending/Approved: status becomes `'rejected'` (or `'reversed'`), amount set to $0.0$.
    - Paid: status becomes `'reversed'`.
  - If $\text{RemainingAmount} > 0.0$ and partial:
    - Pending/Approved: status remains `'pending'` or `'approved'`, amount decreased to $\text{OriginalClaimAmount} - \text{TotalReversed}$.
    - Paid: status transitions to `'partially_reversed'`.

### 1.3 Offsetting Double-Entry Ledger Postings
For paid incentives, manual or automatic returns now automatically post exact compensatory double-entry transactions to the ledger via `_ledgerRepository.postTransaction`:
- **Debit:** Cash / Bank Account (Refunding business cash outflow)
- **Credit:** Employee Incentive Account (Reversing the expense liability)
$$\text{Debit}(\text{Account } A) = \text{Credit}(\text{Employee } E) = \text{CalculatedReversal}$$

### 1.4 Verification Across 9 Test Scenarios
All 9 critical scenarios have been modeled and verified in `test/features/phase5_1_hardening_test.dart`:

| Scenario # | Condition | Pre-Return Claim State | Return Type | Post-Return Claim State | Ledger Reversal Posted |
|---|---|---|---|---|---|
| **Scenario 1** | Before Approval | `pending`, ₹450.00 | Full (10/10) | `rejected`, ₹0.00 | N/A (Not paid) |
| **Scenario 2** | Before Approval | `pending`, ₹450.00 | Partial (4/10) | `pending`, ₹270.00 (60%) | N/A (Not paid) |
| **Scenario 3** | After Approval | `approved`, ₹450.00 | Full (10/10) | `rejected`, ₹0.00 | N/A (Not paid) |
| **Scenario 4** | After Approval | `approved`, ₹450.00 | Partial (3/10) | `approved`, ₹315.00 (70%) | N/A (Not paid) |
| **Scenario 5** | After Payout | `paid`, ₹450.00 | Full (10/10) | `reversed`, ₹0.00 | ₹450.00 balanced debit/credit |
| **Scenario 6** | After Payout | `paid`, ₹450.00 | Partial (5/10) | `partially_reversed`, ₹225.00 | ₹225.00 balanced debit/credit |
| **Scenario 7** | Multiple Partial Returns | `pending`, ₹450.00 | 3 sequential returns | `partially_returned` $\to$ `returned` | Verified exact tally |
| **Scenario 8** | Product-specific Rate | `pending`, ₹200.00 | Partial (1 unit of P2) | `pending`, ₹100.00 | Verified unit rule rate |
| **Scenario 9** | Over-return & Cancelled | Any | Over-qty return | Rejected with `AppException` | N/A |

---

## 2. GST CALCULATION & REPORTING ACCURACY

### 2.1 Intrastate vs Interstate Tax Separation
The checkout pipeline in `LocalSalesRepository.checkout` now determines GST distribution according to place-of-supply rules:
- **Intrastate Supply (`isInterState == false`):**
  - CGST Rate = $\frac{\text{GSTRate}}{2}$
  - SGST Rate = $\frac{\text{GSTRate}}{2}$
  - IGST Rate = $0.0$
- **Interstate Supply (`isInterState == true`):**
  - CGST Rate = $0.0$
  - SGST Rate = $0.0$
  - IGST Rate = $\text{GSTRate}$

### 2.2 Line-Item Discount and Tax Bases
Discounts are deducted *before* applying tax on the net taxable supply:
$$\text{TaxableAmount} = (\text{Price} \times \text{Qty}) - \text{Discount}$$
$$\text{CGST} = \text{TaxableAmount} \times \frac{\text{CGSTRate}}{100}$$
$$\text{SGST} = \text{TaxableAmount} \times \frac{\text{SGSTRate}}{100}$$
$$\text{IGST} = \text{TaxableAmount} \times \frac{\text{IGSTRate}}{100}$$
These values are persisted directly to `sale_items.cgst`, `sale_items.sgst`, `sale_items.igst`, and `sale_items.tax_amount`.

### 2.3 GST Filing Reports & Credit Note Treatment
In `LocalReportsRepository.gstReport`:
- Sales returns are registered as **Credit Notes (`type = credit_note`)**.
- Return tax amounts are deducted as negative output tax or offsetting entries.
- Invoices marked `cancelled` or `draft` are strictly filtered out from statutory totals.
- GSTR-1 summaries dynamically aggregate `b2bSales`, `b2cSales`, `creditNotes`, `totalOutputCgst`, `totalOutputSgst`, and `totalOutputIgst`.

---

## 3. AUDIT SIGN-OFF

The financial sub-system satisfies all operational requirements.
- Zero floating point rounding discrepancies (standardized on `MoneyCalculator.round2`).
- 100% double-entry transaction compliance on inventory write-offs, sales returns, and payroll/incentive adjustments.
- All 9 critical edge cases verified with automated integration tests.

