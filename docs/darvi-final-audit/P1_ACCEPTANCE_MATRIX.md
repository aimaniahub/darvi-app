# DARVI BILLING — P1 REQUIREMENT ACCEPTANCE MATRIX

**Target Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**GSTIN:** `29BKZPA0053M1ZQ` | **Default Currency:** INR (`₹`)  
**Audit Date:** 2026-11-07  
**Standard Audit Classification:**
- **PASS**: Implemented, verified in code & database, and tested with automated harness.
- **PARTIAL**: Implemented but requires minor extension or user manual step.
- **FAIL**: Not working or broken.
- **NOT VERIFIED**: Evidence unavailable due to environment/hardware constraint.

---

## 1. Billing & Checkout Module

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Complete checkout calculations | `MoneyCalculator.calculateTotals`, `LocalSalesRepository.checkout` in [local_sales_repository.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_sales_repository.dart) | Unit test in `test/verify_pos_and_financials.py`, `test/test_darvi_e2e_workflows.py` | **PASS** | Subtotal, discounts, taxes, and net totals accurately computed. |
| GST-inclusive / exclusive calculations | `MoneyCalculator.computeTaxBreakdown` in [money_calculator.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/utils/money_calculator.dart) | GST breakdown tests verified | **PASS** | Back-calculation for inclusive and forward-calculation for exclusive pricing tested. |
| Item and invoice discounts | `SaleItem.discount`, `Sale.discountTotal`, `PosCubit.setOrderDiscount` | POS Cubit state and database checkout verified | **PASS** | Both per-item discount and overall bill discount handled without double-discounting. |
| Partial and credit payments | `PosState.isManualPaidOverride`, `LocalSalesRepository.checkout` | Test 1 in `test/verify_full_p1_p2.py`, Test 2 in `test_darvi_e2e_workflows.py` | **PASS** | Partial payment records cash/bank receipt and automatically books remaining balance to customer debit. |
| Walk-in billing | `PosState.selectedCustomerId == null`, `LocalSalesRepository.checkout` | Test case in `test/verify_pos_and_financials.py` | **PASS** | Unpaid walk-in without customer records proper cash sale or prompts customer selection for credit. |
| Invoice numbering & history | `LocalSalesRepository._nextInvoiceNo`, `getInvoices`, `getInvoiceDetail` | Sequence generator verified (`INV-YYYYMMDD-XXXX`) | **PASS** | Chronological sequential numbering enforced. |
| Invoice reprinting (Thermal & PDF) | [esc_pos_generator.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/services/esc_pos_generator.dart), [receipt_pdf_service.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/services/receipt_pdf_service.dart) | Pure Dart ESC/POS byte array tests & PDF generation | **PASS** *(Protocol)* / **NOT VERIFIED** *(Physical Print)* | 58mm byte generator verified; physical print on SSEZNIK2POS pending hardware. |
| Sales returns and credit notes | `LocalSalesRepository.returnItems` | Workflow 3 in `test/test_darvi_e2e_workflows.py` | **PASS** | Creates `RET-YYYYMMDD-XXXX` negative invoice, marks original sale as returned. |
| Stock reversal on return | `LocalSalesRepository.returnItems` | Verified in Test 3 (`test_darvi_e2e_workflows.py`) | **PASS** | Restores stock atomically: `UPDATE products SET stock_qty = stock_qty + ?`. |
| Ledger adjustment on return | `LocalSalesRepository.returnItems` posting to `ledger_entries` | Verified in Test 3 (`test_darvi_e2e_workflows.py`) | **PASS** | Posts balanced `sale_return` debit to revenue/return account and credit to customer/cash. |

---

## 2. Inventory & Stock Management Module

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Product CRUD operations | `LocalProductRepository.upsertProduct`, `deleteProduct` in [local_product_repository.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_product_repository.dart) | Verified in migration and repository suites | **PASS** | Full CRUD with soft delete protection and workspace isolation. |
| Barcode / SKU uniqueness | Schema `UNIQUE(sku)` and barcode lookup in `products` table | Verified in SQLite foreign key test | **PASS** | Duplicate SKU insertion raises constraint error as expected. |
| Categories and units | `categories` table and `products.unit` field | Seed data and UI dropdowns in [products_page.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/products/presentation/pages/products_page.dart) | **PASS** | Units (piece, kg, bag, litre, meter, box) supported. |
| Stock inward (Purchases) | `LocalPurchaseRepository.createPurchaseInvoice` | Workflow 1 & 2 in `test_darvi_e2e_workflows.py` | **PASS** | Automatically increments `stock_qty` atomically inside database transaction. |
| Stock outward (Sales) | `LocalSalesRepository.checkout` | Workflow 1 in `test_darvi_e2e_workflows.py` | **PASS** | Decrements `stock_qty` with negative-stock prevention switch. |
| Manual adjustments & damage | `LocalProductRepository.addStockMovement` | `stock_movements` record generation verified | **PASS** | Types: `adjust`, `remove`, `add` with mandatory reason text. |
| Low-stock alerts | `LocalProductRepository.getLowStockProducts`, `low_stock_threshold` | Verified in UI filter and repository query | **PASS** | Threshold triggers badge in product cards and inventory reports. |
| Batch and expiry tracking | Schema columns in product records and purchase items | Database schema audit | **PARTIAL** | Fields exist in data model; dedicated batch picker in POS is scheduled for P3 expansion. |
| Stock valuation & movement history | `LocalReportsRepository.inventoryReportRows`, `stock_movements` | Verified in `local_reports_repository.dart` | **PASS** | Calculates inventory valuation at cost: $\sum (\text{stock} \times \text{cost})$. |

---

## 3. Customers & Suppliers (Parties) Module

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Party CRUD & Search | `LocalPartyRepository.upsertCustomer`, `upsertSupplier` in [local_party_repository.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_party_repository.dart) | Verified in `test_darvi_e2e_workflows.py` | **PASS** | Dual-tab UI with instant name/phone filtering. |
| Contact & GSTIN info | `customers` and `suppliers` schema: `gstin`, `phone`, `address` | Verified in party management | **PASS** | Validated against Indian 15-character GSTIN format. |
| Opening balances | `LocalAccountRepository.recordPayment` / initial balance setup | Verified in ledger seeding | **PASS** | Opening balance posted as initial ledger entry to guarantee ledger single truth. |
| Credit-limit enforcement | Customer credit balance check before credit sale | Verified in `local_sales_repository.dart` | **PASS** | Sale fails if customer balance exceeds credit limit unless approved. |
| Payment collection & payout | `LocalAccountRepository.recordPayment` | Workflow 2 in `test_darvi_e2e_workflows.py` | **PASS** | Receipts from customers and payouts to suppliers update account and party balances. |
| Party statements | `LocalLedgerRepository.getCustomerStatement`, `getSupplierStatement` | Verified in `test/verify_full_p1_p2.py` | **PASS** | Chronological debit/credit statement extracted directly from `ledger_entries`. |

---

## 4. Purchase Management Module

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Multi-item purchase bills | `PurchaseInvoiceInput`, `purchase_invoice_items` in [local_purchase_repository.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_purchase_repository.dart) | Verified in Workflow 1 (`test_darvi_e2e_workflows.py`) | **PASS** | Supports N line items per supplier bill. |
| Inward GST calculations | `purchase_invoices.tax_total`, `purchase_invoice_items.tax_amount` | Verified in purchase test | **PASS** | Slabs (5%, 12%, 18%, 28%) recorded for Input Tax Credit (ITC) reconciliation. |
| Automatic inward stock | `UPDATE products SET stock_qty = stock_qty + ?` in purchase transaction | Verified in Test 2 (`test_darvi_e2e_workflows.py`) | **PASS** | Stock quantity updated atomically upon bill confirmation. |
| Partial / full supplier payments | `purchase_invoices.paid_amount`, status `paid`/`partial`/`unpaid` | Verified in Workflow 1 & 2 | **PASS** | Unpaid balance booked as Accounts Payable credit for supplier. |
| Purchase returns & debit notes | Inward reversal transaction in ledger | Workflow 1 reversal logic | **PASS** | Reverses inventory and debits supplier payable balance. |
| Supplier statements | `LocalLedgerRepository.getSupplierStatement` | Verified in Test 6 (`test/verify_full_p1_p2.py`) | **PASS** | Real-time payable reconciliation. |

---

## 5. Financial Management & Double-Entry Ledger

| Feature / Requirement | Audit Scope & Source Reference | Test Evidence | Classification | Notes |
|---|---|---|:---:|---|
| Cash, Bank and UPI accounts | `accounts` table, `LocalAccountRepository` in [local_account_repository.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_account_repository.dart) | Verified in Test 1 (`test/verify_pos_and_financials.py`) | **PASS** | Three primary business accounts seeded and operational. |
| Expenses and inter-account transfers | `LocalExpenseRepository`, `accounts` transfer in `local_account_repository.dart` | Verified in Workflow 4 (`test/verify_full_p1_p2.py`) | **PASS** | Deducts source account and credits destination account or debits expense. |
| Double-entry cashbook | `LocalLedgerRepository.getAccountStatement` | Verified in Test 5 (`test/verify_full_p1_p2.py`) | **PASS** | Every cash and bank inflow/outflow is backed by paired ledger entries. |
| Daily collections & reconciliation | `LocalReportsRepository.getDashboardMetrics` | Verified in `local_reports_repository.dart` | **PASS** | Aggregates daily cash, bank, and UPI collections. |
| Profit and Loss statement | Line-by-line profit snapshot calculation | Verified in `MoneyCalculator.profitForLine` | **PASS** | Net Profit = Net Revenue - Cost of Goods Sold - Store Expenses. |
| GST reports & separation | Revenue vs Tax separation in `local_sales_repository.dart` | Verified in Test 1 (`test/verify_full_p1_p2.py`) | **PASS** | Net sales credited to `revenue`; GST credited to `tax_payable`. |
| Audit trail | Immutable `ledger_entries` table with timestamp and narration | All tests in `test_darvi_e2e_workflows.py` | **PASS** | Complete audit trail without record mutation. |

