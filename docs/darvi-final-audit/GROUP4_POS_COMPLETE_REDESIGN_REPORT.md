# DARVI BILLING — GROUP 4 COMPLETE POS WORKSPACE REDESIGN REPORT
## Billing Workspace + Cart/Checkout Review + Invoice Preview & SSEZNIK2POS 58mm Printing

**Entity:** Darvi Group Agri Tech (`29BKZPA0053M1ZQ`, Gokul Road, Hubli, Karnataka 580030)  
**Date:** November 7, 2026  
**Status:** COMPLETE & FULLY VERIFIED (88 / 88 tests passing, 0 compiler warnings/errors)  
**Hardware Target:** SSEZNIK2POS, Bluetooth Classic SPP (`00001101-0000-1000-8000-00805F9B34FB`), 58mm Thermal Printer (Font A, 32 Columns)  
**Architecture:** Drift + SQLite, Cubit BLoC, GoRouter, Double-Entry Balanced Ledger  
**Preceding Modules:** Products, Stock, POS, Employee HR, Attendance, Payroll & Incentives, Purchases, Parties, Financials & Accounts.

---

## 1. Executive Summary

Group 4 executes a ground-up redesign and replacement of the Billing/POS experience in **Darvi Billing**. The previous catalog-like screen has been completely overhauled into a high-speed, feature-rich retail POS workspace engineered specifically for rapid over-the-counter retail operations, agri-inputs distribution, and seed/fertilizer batch compliance.

The new architecture guarantees three seamlessly connected, responsive experiences:
1. **Screen 1: Billing Workspace (`PosWorkspaceView`)** — Ergonomic, multi-panel desktop/tablet and tabbed mobile interface for instant product discovery, barcode lookup, active cart manipulation, batch selection, bill holding, and customer management.
2. **Screen 2: Cart & Checkout Review (`PosCheckoutReviewView`)** — Dedicated full-screen review showing itemized breakdowns, intra-state GST tax computations (CGST 9% + SGST 9%), tender cash-back calculators, multi-row split payments, customer credit verification, and atomic checkout with concurrency locking.
3. **Screen 3: Invoice Preview & Printing (`PosInvoicePreviewView`)** — Real-time interactive 58mm thermal receipt paper simulator, Bluetooth Classic SPP pairing & chunked transmission to the SSEZNIK2POS hardware, diagnostic self-test printing, A4 tax invoice generation, and safe sale reset.

---

## 2. Design System & Layout Standards

All screens and UI components conform to the Darvi Design System:
- **Primary Color Palette:** Deep Forest Green (`#1B5E20`), Light Mint (`#E8F5E9`), Charcoal Slate (`#212121`), White (`#FFFFFF`), Alert Red (`#C62828`), and Warm Amber (`#FF8F00`).
- **Standard Header:** 56–60 px height (`PosHeader`), maintaining quick cashier identity, live Bluetooth printer status indicator, held bills badge, and invoice history navigation.
- **Button Sizing:**
  - Standard action buttons: 44–48 px.
  - Checkout CTA: 48–52 px prominent filled button with elevated contrast.
  - Compact counter controls: 36–40 px (`+` / `-` / batch buttons).
- **Typography & Readability:**
  - Standard body text: 13–14 px.
  - Section headers: 16–18 px semi-bold.
  - Screen titles: 20–22 px bold.
  - Thermal monospace preview: 12 px clean monospace rendering 32 columns.
- **Responsive Layout:**
  - **Desktop / Tablet (`width >= 900px`):** Dual-panel split screen (60% discovery, 40% active cart & financial summary).
  - **Mobile (`width < 900px`):** Full-screen product discovery with persistent bottom summary drawer and "View Cart / Checkout" navigation.

---

## 3. Screen 1: Billing Workspace (`PosWorkspaceView`)

### 3.1 Billing Header (`PosHeader`)
- **Cashier Identity:** Displays current cashier name (default: "Prasad Patil (Store Manager)"). Tapping triggers a cashier switch dialog with active employee profiles.
- **Printer Status Pill:** Real-time Bluetooth connection status (Connected: Green, Disconnected: Grey, Scanning: Amber). Tapping triggers quick device scan and connect.
- **Held Bills Counter & Modal:** Shows badge with count of parked transactions. Tapping opens `PosHeldBillsDialog` to resume or discard parked carts.
- **Quick Actions:** "Park Bill" with optional note, "Clear Cart / New Bill" with safety confirmation, and "Invoice History" button linking to historical sales records.

### 3.2 Product Discovery & Real-Time Filtering
- **Unified Search Bar:** Real-time database queries matching Product Name, SKU, and Barcode.
- **Barcode & Scanner Support:**
  - Manual text input with instant Enter/Tab trigger.
  - External USB / Bluetooth HID scanner listener.
  - Camera scanner modal integration for mobile POS stations.
  - Instant invalid barcode feedback without UI disruptions.
- **Category Filtering:** Horizontal scroll chips displaying category names with live product counts.
- **View Modes:** Toggle between **Grid View** (visual cards with stock status pills) and **Compact List View** (dense tabular view for high-volume cashiers).
- **Stock Pills & Batch Tags:**
  - Stock status: In Stock (Green), Low Stock (Orange <= 10), Out of Stock (Red).
  - Products with multiple active batches display an amber batch badge indicating available batches.

### 3.3 Product Selection & Batch Policy
- Tapping a product with a single batch or no batches adds it to the cart immediately and increments quantity.
- Tapping a product with multiple active batches launches `PosBatchSelectorDialog`, presenting:
  - Batch number and initial inward date.
  - Expiry date with near-expiry warning badges.
  - Available batch quantity.
  - One-tap selection that binds the specific `batchId` to the cart line item.
- **Inventory Safety Invariant:** Adding items to the cart does **NOT** decrement stock; stock deduction happens strictly at checkout.

### 3.4 Cart Panel & Line Item Controls
- **Customer Card (`PosCustomerCard`):**
  - Walk-in / General sale default.
  - Dropdown selector with live customer search, contact number, and credit balance indicator.
  - "+ Quick Add Customer" inline dialog allowing cashiers to register new customers without losing the active cart state.
  - Credit limit alerts when existing customer outstanding exceeds allowed limits.
- **Cart Line Items:**
  - Item name, SKU, and assigned batch number tag.
  - Quantity controls: increment (`+`), decrement (`-`), and direct numeric keyboard entry.
  - Line discount button (fixed rupee or percentage).
  - Unit price override for authorized cashiers.
  - Line note button (e.g. custom delivery instructions or bag markings).
  - Remove line item button.
- **Cart Financial Summary:**
  - Item count and total physical units.
  - Gross subtotal.
  - Item discounts total.
  - Order-level discount (% or ₹ toggle).
  - Tax toggle (18% GST CGST/SGST intra-state computation).
  - Live Grand Total.
  - "Proceed to Checkout Review" button (48–52 px).

---

## 4. Screen 2: Cart and Checkout Review (`PosCheckoutReviewView`)

### 4.1 Order Review Table
- Full tabular itemized breakdown before payment collection:
  - `#`, Product Name & SKU, Batch, Quantity, Unit, Unit Price, Line Discount, Line Total.
- Clear back button ("← Back to Cart") to adjust quantities if customer requests changes at the counter.

### 4.2 Comprehensive Tax & Financial Summary
- Formatted breakdown complying with Indian GST requirements:
  - **Gross Subtotal**
  - **Item Discounts Total**
  - **Order Discount**
  - **Taxable Value**
  - **Intra-State CGST (9%)**
  - **Intra-State SGST (9%)**
  - **Auto Round-off Delta**
  - **Final Grand Total Payable**

### 4.3 Payment Methods & Receiving Accounts
- **Tabbed Payment Selector:**
  - **Cash:** Tender amount text field, Quick Cash Buttons (`Exact`, `+₹100`, `+₹500`, `+₹2,000`), and live **Change Due** calculation.
  - **UPI / QR:** Direct collection with transaction reference / UTR field.
  - **Bank Transfer (NEFT/RTGS/IMPS):** Reference number tracking.
  - **Debit / Credit Card:** POS terminal approval code tracking.
  - **Split Payment:** Multi-row payment allocator allowing dynamic combination (e.g. ₹500 Cash + ₹700 UPI). Displays dynamic remaining balance to allocate.
  - **Credit Sale:** Deferred payment for approved customers. Checks customer's credit limit and warns if exposure is exceeded.
- **Receiving Account Selector:** Dropdown to direct funds into specific financial ledger accounts (`Store Cash Drawer`, `Company Bank Account`, `Store UPI Account`).

### 4.4 Atomic Checkout & Concurrency Gate
- **Double-Tap Protection:** Cubit sets `isProcessingCheckout = true` synchronously before executing database operations; UI disables button and displays progress indicator, eliminating duplicate invoice generation.
- **Transactional Invariant:**
  - Validates cart contents and batch availability.
  - Atomically writes `sales` and `sale_items` records.
  - Deducts stock from specific `product_batches` if selected, otherwise applies FIFO/FEFO fallback.
  - Records `stock_movements` log row.
  - Posts balanced double-entry ledger entries:
    - Debit: Receiving Asset Account (`Cash Drawer`, `Bank`, or `Customer Receivable`)
    - Credit: Sales Revenue (`Income`)
    - Credit: Output CGST & SGST (`Tax Payable`)
  - Automatically transitions state to **Screen 3: Invoice Preview & Printing**.

---

## 5. Screen 3: Invoice Preview & SSEZNIK2POS 58mm Printing (`PosInvoicePreviewView`)

### 5.1 Post-Checkout Success Banner
- Prominent green confirmation banner displaying Invoice Number (`INV-XXXXXX`), Date/Time, and Grand Total.

### 5.2 58mm Thermal Paper Simulator (`PosThermalReceiptPreview`)
- Realistic paper styling with subtle shadow, dashed perforation dividers, and exact 32-column monospace preview matching the physical printout.
- Sections:
  1. Header: Store Name (`Darvi Group Agri Tech`), Address (`Gokul Road, Hubli`), Phone, GSTIN (`29BKZPA0053M1ZQ`).
  2. Meta: Invoice ID, Date, Time, Cashier Name, Customer Name & Mobile.
  3. Table: Item name, quantity × price, line total.
  4. Financials: Gross Subtotal, Discount, Taxable, CGST (9%), SGST (9%), Round-off, Net Payable.
  5. Payment details & Tender/Change breakdown.
  6. Footer: "Thank you for visiting Darvi Group!", "Goods once sold cannot be returned without bill."

### 5.3 Bluetooth Classic SPP Printer Management
- **Hardware Integration:** Configured for SSEZNIK2POS (UUID `00001101-0000-1000-8000-00805F9B34FB`).
- **Connection Controls:** Quick pair, scan, connect, and disconnect actions.
- **Chunked ESC/POS Transmission:** ESC/POS bytes are chunked (128-byte segments with 15ms delays) to eliminate Bluetooth buffer overrun and incomplete printing on 58mm portable printers.
- **Diagnostic Hardware Ticket:** Built-in "Print Self-Test Ticket" action sending alignment checks, font test, and 32-column rule to verify paper feed and printer health.

### 5.4 Actions & Reset Safety
- **Print Thermal (ESC/POS):** Sends receipt bytes to Bluetooth printer.
- **Print / Share A4 PDF:** Generates GST-compliant A4 PDF using `ReceiptPdfService` for formal customer records or WhatsApp sharing.
- **Repeated Print Invariant:** Printing or reprinting can be executed unlimited times; it performs byte generation and I/O only, with **zero side effects** on inventory or double-entry ledgers.
- **Start New Sale:** Clears active cart, customer selection, and payment buffers, returning cleanly to Screen 1 (Billing Workspace).

---

## 6. Database Schema Enhancements

To support held bills and rich POS line item snapshots, `ensureGroup4SchemaTables()` was executed:

```sql
-- 1. Held Bills Table
CREATE TABLE IF NOT EXISTS held_bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  workspace_id TEXT NOT NULL,
  reference_note TEXT,
  customer_id INTEGER,
  customer_name TEXT,
  customer_phone TEXT,
  cart_data TEXT NOT NULL,
  order_discount REAL NOT NULL DEFAULT 0.0,
  tax_enabled INTEGER NOT NULL DEFAULT 1,
  tax_rate REAL NOT NULL DEFAULT 18.0,
  subtotal REAL NOT NULL DEFAULT 0.0,
  total_amount REAL NOT NULL DEFAULT 0.0,
  item_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

-- 2. Extended Sales Table Columns
ALTER TABLE sales ADD COLUMN cashier_name TEXT;
ALTER TABLE sales ADD COLUMN notes TEXT;
ALTER TABLE sales ADD COLUMN payment_details TEXT;

-- 3. Extended Sale Items Columns
ALTER TABLE sale_items ADD COLUMN batch_id INTEGER;
ALTER TABLE sale_items ADD COLUMN batch_number TEXT;
ALTER TABLE sale_items ADD COLUMN unit TEXT;
ALTER TABLE sale_items ADD COLUMN line_note TEXT;
ALTER TABLE sale_items ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0.0;
ALTER TABLE sale_items ADD COLUMN tax_rate REAL NOT NULL DEFAULT 0.0;
ALTER TABLE sale_items ADD COLUMN hsn_code TEXT;
```

---

## 7. Verification & Test Suite Summary

A dedicated test suite was created in `test/group4_pos_redesign_test.dart` containing 16 comprehensive end-to-end and unit tests:

| Test ID | Test Description | Result |
|---|---|---|
| **1.1** | Product search & discovery filters by name, SKU, and barcode | **PASS** |
| **1.2** | Grid vs List layout mode toggling | **PASS** |
| **1.3** | Cart manipulations: add, batch assignment, qty, line discount, and price override | **PASS** |
| **1.4** | Bill discount (fixed vs percentage) and GST intra-state calculation | **PASS** |
| **1.5** | Quick add customer preserves active cart state | **PASS** |
| **1.6** | Park / Hold bill lifecycle: park, list, resume, delete | **PASS** |
| **2.1** | Cash tender and accurate change due calculation | **PASS** |
| **2.2** | Multi-row Split Payments debit respective accounts atomically | **PASS** |
| **2.3** | Credit sale debits customer receivable and tracks credit limit exposure | **PASS** |
| **2.4** | Concurrency gate prevents double-tap checkout duplicate sales | **PASS** |
| **2.5** | Specific batch assignment decrements that batch directly | **PASS** |
| **3.1** | Successful checkout automatically transitions to Screen 3 with invoice details | **PASS** |
| **3.2** | SSEZNIK2POS 58mm thermal ESC/POS byte sequence generation adheres to 32 columns | **PASS** |
| **3.3** | Diagnostic hardware self-test ticket byte generation | **PASS** |
| **3.4** | Strict Invariant: Repeated printing never modifies inventory or double-entry ledger | **PASS** |
| **3.5** | Start New Sale safely resets state and returns to Billing Workspace | **PASS** |

### Complete Test Run Status
- **Group 4 Test Suite:** 16 / 16 PASSED (`00:03`).
- **Entire Repository Test Suite:** 88 / 88 PASSED (`00:08`).
- **Flutter Analyzer:** 0 Errors, 0 Warnings.

---

## 8. Conclusion

The Darvi Billing POS workspace is now a production-grade, lightning-fast retail point-of-sale system. All three screens operate cohesively, supporting barcode workflows, multi-batch inward tracking, flexible multi-tender payments, and robust Bluetooth 58mm thermal printing tailored to the SSEZNIK2POS hardware.

