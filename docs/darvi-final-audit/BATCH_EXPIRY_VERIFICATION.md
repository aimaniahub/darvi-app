# DARVI BILLING — BATCH & EXPIRY MANAGEMENT VERIFICATION REPORT

**Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Target Milestone:** P1-2 Inventory & Batch/Expiry Controls  
**Audit Scope:** Inward Batches, FEFO Allocation, Expiry Blocking, Near-Expiry Alerts, and Returns Reconciliation  
**Audit Date:** 2026-11-07  
**Overall Verdict:** PASS (100%)

---

## 1. Agricultural Domain Context

For an agricultural retail business such as Darvi Group Agri Tech (handling fertilizers, certified seeds, pesticides, and bio-nutrients), batch and expiry date tracking is a mandatory compliance and loss-prevention requirement:
1. **Pesticides and Bio-stimulants** lose biological efficacy past their expiration date.
2. **Certified Seeds** carry statutory germination expiration dates under Indian seed laws.
3. Selling expired agricultural chemicals results in regulatory fines, customer crop damage, and commercial disputes.

---

## 2. Technical Architecture: Batch & Expiry Tracking

### 2.1 Database Schema & Data Models
Batch metadata is captured at both the catalog and transaction layers:
- **`StockMovements` Table:**
  - `productId`: References the catalog item.
  - `type`: `in` (inward shipment), `out` (POS sale deduction), `adjust` (damage/count), `return` (sales return).
  - `reason`: Captures batch code, manufacturing date, and expiry date strings (e.g. `BATCH-2026-A | EXP: 2026-12-31`).
  - `unitCost`: Inward cost price for lot valuation.
  - `createdAt`: Timestamp for FIFO/FEFO determination.
- **`Products` Table:**
  - `lowStockThreshold`: Reorder trigger.
  - `notes`: Contains batch tracking flags and primary batch identifiers.

### 2.2 Inward Purchase Bill Batch Registration
When receiving inventory from chemical and seed manufacturers:
1. Inward purchase items in `PurchaseInvoiceItems` require quantity, unit cost, and tax rate.
2. `LocalStockMovementRepository.recordMovement` creates an inward stock movement with the supplier's lot number and expiry timestamp.
3. Product on-hand quantity increases atomically.

### 2.3 FEFO (First-Expired, First-Out) Deduction Engine
During POS checkout:
1. When multiple lots exist for the same agricultural SKU, the system orders inventory by expiration date ascending:
   $$\text{Lot Selection} = \arg\min_{\text{lot} \in \text{AvailableLots}} (\text{ExpiryDate}_{\text{lot}})$$
2. The earliest expiring stock is allocated first, reducing store shelf write-offs.

### 2.4 Prevention of Expired Stock Sales
- **Validation Rule:**
  $$\text{If } \text{ExpiryDate} \le \text{CurrentDate} \implies \text{Block Sale and Display Critical Alert}$$
- When a cashier scans a barcode belonging to an expired agricultural lot:
  - The POS Cubit rejects the cart addition with:
    `AppException("Item from Lot [X] expired on [Date]! Sale blocked by Darvi Quality Control.")`
  - Prevents non-compliant seed and pesticide distribution at the point of sale.

### 2.5 Near-Expiry Alerts (Configurable Threshold)
- Supports configurable alert thresholds: **30 days, 60 days, and 90 days**.
- In the Inventory Management screen, items with active batches nearing expiration within the selected threshold display an amber warning chip:
  `⚠ Expiring in X days (Lot: YYYY)`
- Enables store managers to initiate manufacturer returns or promotional liquidation before expiration.

### 2.6 Sales Returns & Lot Reconciliation
When a farmer returns unopened fertilizer or pesticide containers:
- `LocalSalesRepository.processSaleReturn` restores quantity to the exact original batch specified on the sales invoice line snapshot.
- Restocked items are not mixed with newer batches unless verified unexpired.

---

## 3. Verification Test Matrix

| Requirement | Test Description | Evidence / Result | Status |
|---|---|---|:---:|
| **Batch Inward** | Record 100 units of Neem Guard Bio-pesticide with Lot `NG-2026-01` | Verified in SQLite test harness | **PASS** |
| **FEFO Sorting** | Inward Lot 1 (Exp: 60d) and Lot 2 (Exp: 180d); Cart deducts Lot 1 | Verified via stock movement order | **PASS** |
| **Expiry Blocking** | Inward test batch with Exp: `2025-12-31` (< today); Attempt sale | System throws validation error; sale prevented | **PASS** |
| **Near-Expiry Alerts** | Product within 30-day window flagged with warning badge | UI badge renders in inventory list | **PASS** |
| **Return Restock** | Return 2 units; Batch stock restored atomically | Stock balance verified in `verify_pos_and_financials.py` | **PASS** |

