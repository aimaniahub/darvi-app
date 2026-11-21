# QuickStock POS Source Code Audit: Screen & Navigation Inventory

**Document ID:** `docs/darvi-audit/SCREEN_INVENTORY.md`  
**Audit Date:** November 2026  
**Auditor:** Senior Flutter Architect & Software Auditor  

---

## 1. Complete Screen Inventory

An exhaustive audit of the `lib/` directory confirmed that **only 8 screens/views exist** in the QuickStock POS codebase.

```
Existing Screens in Codebase:
1. LoginPage              (/login)
2. AppShellPage           (/) [Shell wrapper with bottom navigation]
3. PosPage                (/pos)
4. ProductsPage           (/products)
5. ReportsPage            (/reports)
6. InvoiceDetailPage      (/reports/invoice/:id)
7. SettingsPage           (/settings)
8. BarcodeScannerPage     (Pushed via MaterialPageRoute from POS / Services)
```

---

## 2. Exhaustive Audit of Existing Screens

### 1. `LoginPage`
- **Source File:** `lib/features/auth/presentation/pages/login_page.dart`
- **Route:** `/login`
- **Navigation Entry Point:** Initial route if unauthenticated (`AppRouter.redirect`).
- **Main UI Components:** Centered card (`maxWidth: 460`), App Title text, Cashier PIN text field (`TextEditingController(text: '1234')`), "Continue as Cashier" `PrimaryButton`, Admin Password text field, "Continue as Admin" `OutlinedButton`, error banner.
- **Available Actions:**
  - Enter cashier PIN -> `context.read<AppCubit>().loginCashier(pin)`
  - Enter admin password -> `context.read<AppCubit>().loginAdmin(password)`
- **State Management:** `BlocBuilder<AppCubit, AppState>` + `BlocListener<AppCubit, AppState>` redirecting to `/pos` on auth success.
- **Data Source:** `AppSettings` table via `LocalAuthRepository` (`cashierPin`, `adminPassword`).
- **Do Actions Work?** Yes. Authenticates against the single PIN/password stored in settings table.
- **Completeness:** Complete for single-store demo; **Incomplete for enterprise**.
- **Missing Features:** No individual staff selection, no employee profiles, no forgot password/PIN reset flow, no biometric auth.
- **UI Improvements Needed:** Branded Darvi logo, workspace selector dropdown, clean keypad/numpad for cashier PIN.

---

### 2. `AppShellPage`
- **Source File:** `lib/features/shell/presentation/pages/app_shell_page.dart`
- **Route:** Shell wrapper wrapping child routes (`/pos`, `/products`, `/reports`, `/settings`).
- **Navigation Entry Point:** Root shell container for authenticated sessions.
- **Main UI Components:** `Scaffold` with `SafeArea(child: child)` and Material 3 `NavigationBar` with 4 destination tabs:
  1. `Icons.point_of_sale` ("POS")
  2. `Icons.inventory_2_outlined` ("Products")
  3. `Icons.assessment_outlined` ("Reports")
  4. `Icons.settings_outlined` ("Settings")
- **Available Actions:** Tab switching via `context.go(_tabs[index])`.
- **State Management:** Stateless; computes active tab index from `currentPath.startsWith(_tabs[i])`.
- **Data Source:** Routing state from `GoRouter`.
- **Do Actions Work?** Yes.
- **Completeness:** Basic shell.
- **Missing Features:** No drawer navigation or adaptive navigation rail for tablets/desktops; completely omits links to Customers, Suppliers, Purchases, Ledgers, Expenses, or Staff.
- **UI Improvements Needed:** Replace 4-tab bar with an extensible Navigation Drawer or split bottom navigation to accommodate Darvi Billing modules.

---

### 3. `PosPage`
- **Source File:** `lib/features/pos/presentation/pages/pos_page.dart`
- **Route:** `/pos` (Tab 0)
- **Navigation Entry Point:** Bottom navigation tab or post-login redirect.
- **Main UI Components:**
  - Top `AppBar` with title and Barcode Scanner action button.
  - Search `AppTextField` with instant product query filter.
  - Horizontal category `FilterChip` list ('All', Dynamic Category chips, 'Low stock' toggle chip).
  - Responsive layout: Wide screens (>= 1000px) render side-by-side split (`_ProductsPane` left, `_CartPane` right); compact screens render stacked column.
  - Bottom `_CheckoutBar` displaying Total, Change amount, and "Checkout" button.
  - Checkout bottom sheet modal with Order Discount input, Payment Method dropdown (CASH, CARD, SPLIT), Paid amount input, Total/Change summary cards, and confirm button.
  - Post-checkout confirmation banner with "Print receipt", "Share PDF", and "New sale" buttons.
- **Available Actions:**
  - Scan barcode -> opens `BarcodeScannerPage`.
  - Filter by search or category.
  - Tap product card -> adds item to cart or increments quantity.
  - Increment/decrement item quantity in cart.
  - Swipe cart tile to delete item from cart.
  - Tap "Disc" on cart tile -> modal dialog to apply line discount.
  - Tap price on cart tile -> modal dialog to edit item unit price (Admin role only).
  - Tap "Checkout" -> opens checkout bottom sheet.
  - Submit checkout -> runs database transaction, generates invoice, restocks/deducts inventory.
  - Tap "Print receipt" -> invokes OS print dialog via `ReceiptPdfService`.
  - Tap "Share PDF" -> opens system share sheet.
- **State Management:** `BlocProvider` creating `PosCubit`.
- **Data Source:** `LocalProductRepository`, `LocalSalesRepository`, `LocalSettingsRepository`, `LocalPartyRepository`.
- **Do Actions Work?**
  - Cart, line discounts, barcode scanning, checkout, and PDF sharing work.
  - **Defect in Checkout Modal:** Customer selection is NOT exposed in the checkout modal sheet UI. `selectedCustomerId` defaults to `customers.first.id` during load, but the user cannot select or change the customer during billing!
  - **Defect in State Update:** When adding items, `paid` is assigned from the old state total before the new cart total is calculated.
- **Completeness:** Partial.
- **Missing Features:** Customer selection picker, customer quick-create button, GST tax slab breakdown preview (CGST/SGST/IGST), roundoff handling, quotation conversion, employee attribution (who made the sale).
- **UI Improvements Needed:** Dedicated customer selection dropdown/search bar in POS header, quick cash tender buttons (₹100, ₹500, ₹2000, Exact).

---

### 4. `ProductsPage`
- **Source File:** `lib/features/products/presentation/pages/products_page.dart`
- **Route:** `/products` (Tab 1)
- **Navigation Entry Point:** Bottom navigation tab.
- **Main UI Components:**
  - Search field, category chips filter, low-stock filter.
  - Product list tiles showing photo thumbnail, title, SKU, category name, price, stock badge.
  - Floating action button ("Add product", Admin only).
  - Swipe-to-delete dismissible tile (Admin only) with confirmation dialog.
  - Long-press stock action bottom sheet (Add stock, Remove stock, Adjust stock).
  - Add/Edit product bottom sheet modal:
    - Image section: Camera capture, Gallery picker, or remote URL input.
    - Fields: Name, SKU, Barcode, Category dropdown, Cost, Price, Stock qty, Low-stock threshold, Unit (piece/kg), Notes.
- **Available Actions:** Add product, edit product, delete product, quick stock adjustment (Add/Remove/Adjust).
- **State Management:** `BlocProvider` creating `ProductsCubit`.
- **Data Source:** `LocalProductRepository`.
- **Do Actions Work?** Yes. Product creation, editing, deletion, and stock adjustments function.
- **Completeness:** Moderate.
- **Missing Features:**
  - **No Category Management UI:** Categories can only be selected from pre-seeded values. There is no button to add, rename, or delete categories from the UI.
  - **No Batch/Lot tracking:** No expiration dates or batch numbers.
  - **No HSN/SAC code:** Crucial for Indian GST billing.
  - **Direct stock editing flaw:** Editing stock in `_showProductEditor` overwrites the `stockQty` column directly without recording an entry in `StockMovements`.
- **UI Improvements Needed:** Category management modal, barcode generation preview, multi-tier pricing (Wholesale vs Retail).

---

### 5. `ReportsPage`
- **Source File:** `lib/features/reports/presentation/pages/reports_page.dart`
- **Route:** `/reports` (Tab 2)
- **Navigation Entry Point:** Bottom navigation tab.
- **Main UI Components:**
  - Date range picker card ("Pick" / "Reset").
  - Summary metric cards: Today sales, Month sales, Today profit, Month profit.
  - Exports card: "Export sales CSV", "Export inventory CSV".
  - Best sellers card (top 5 products by quantity).
  - Sales by product card (renders horizontal progress bars for top 8 products).
  - Low stock card (top 10 low-stock items with red badges).
  - Invoice history card (list of last 25 invoices with status badges and navigation tap).
- **Available Actions:**
  - Date range filter -> triggers reload of metrics and invoices.
  - Export Sales CSV -> triggers file creation and system share sheet.
  - Export Inventory CSV -> triggers file creation and system share sheet.
  - Tap invoice row -> navigates to `/reports/invoice/:id`.
- **State Management:** `BlocProvider` creating `ReportsCubit`.
- **Data Source:** `LocalReportsRepository` + `LocalSalesRepository`.
- **Do Actions Work?** Yes.
- **Completeness:** Functional for basic metrics; **Incomplete for accounting**.
- **Missing Features:** No GST tax reports (GSTR-1, GSTR-3B summary), no customer outstanding balance summary, no employee sales performance reports, no export to PDF or Excel.
- **UI Improvements Needed:** Replace progress bars with real chart visualizations (`fl_chart`), add tabbed report views (Financial, Inventory, Tax, Staff).

---

### 6. `InvoiceDetailPage`
- **Source File:** `lib/features/invoices/presentation/pages/invoice_detail_page.dart`
- **Route:** `/reports/invoice/:id` (Subroute under `/reports`)
- **Navigation Entry Point:** Tapping an invoice item in `ReportsPage`.
- **Main UI Components:**
  - `AppBar` displaying `sale.invoiceNo`.
  - Invoice summary card (Total, Date, Payment method).
  - Items card displaying line items, snapshot unit price, snapshot cost, discount, and return quantity selector (`+` / `-` buttons).
  - Totals breakdown card: Subtotal, Discount, Tax, Grand Total, Paid, Change.
  - Action button: "Return selected items" (enabled when any return quantity > 0).
- **Available Actions:**
  - Adjust return quantity per line item.
  - Submit return -> restocks inventory, writes negative line items in a return invoice (`RET-YYYYMMDD-XXXX`), marks original sale as `returned`.
- **State Management:** `BlocProvider` creating `InvoiceDetailCubit`.
- **Data Source:** `LocalSalesRepository`.
- **Do Actions Work?** Yes, return execution functions.
- **Defects & Limitations:**
  - Marking any item as returned marks the *entire* sale status as `returned` (no partial return status).
  - Does NOT adjust customer ledger or record refund payment.
  - No button to re-print or share the invoice receipt from this detail page!
- **UI Improvements Needed:** Add "Print Receipt" and "Share PDF" action buttons in the `AppBar`, display customer contact info, display return history audit trail.

---

### 7. `SettingsPage`
- **Source File:** `lib/features/settings/presentation/pages/settings_page.dart`
- **Route:** `/settings` (Tab 3)
- **Navigation Entry Point:** Bottom navigation tab.
- **Main UI Components:**
  - Store settings card: Store name, Currency (`EGP`), Tax rate (`0.14`), Tax enabled switch, Allow negative stock switch.
  - Receipt card: Receipt header text field, Receipt footer text field.
  - Credentials card: Cashier PIN text field, Admin password text field.
  - Language card: Language dropdown (`English`, `Arabic`).
  - Save `PrimaryButton` and Logout `AppBar` action button.
- **Available Actions:** Edit settings, toggle tax/negative stock, change PIN/password, switch language, logout.
- **State Management:** `BlocBuilder<AppCubit, AppState>`.
- **Data Source:** `AppSettings` table via `LocalSettingsRepository`.
- **Do Actions Work?** Yes. Changes persist to SQLite and update the runtime app locale and theme.
- **Completeness:** Basic store configuration only.
- **Missing Features:**
  - No Bluetooth printer pairing or selection.
  - No business address or GSTIN fields.
  - No invoice prefix customization.
  - No backup/restore or database export.
  - No multiple workspace management.
- **UI Improvements Needed:** Group settings into modular sub-pages: Business Profile, Hardware & Thermal Printer, Tax & Invoicing, Staff & Security, Database Backup.

---

### 8. `BarcodeScannerPage`
- **Source File:** `lib/features/shared/widgets/barcode_scanner_page.dart`
- **Route:** None (Pushed as a modal `MaterialPageRoute`).
- **Navigation Entry Point:** Barcode scanner icon in `PosPage` `AppBar`.
- **Main UI Components:** Full screen `MobileScanner` camera viewfinder with an `AppBar`.
- **Available Actions:** Point camera at barcode -> detects code -> pops route returning scanned barcode string.
- **State Management:** `StatefulWidget` with local boolean flag `_handled` to prevent duplicate scans.
- **Data Source:** Camera feed via `mobile_scanner`.
- **Do Actions Work?** Yes.
- **Completeness:** Functional.
- **UI Improvements Needed:** Add flashlight (torch) toggle button, camera flip button, scan target overlay box.

---

## 3. Advertised Features That LACK Screens in QuickStock POS

The upstream documentation suggests broader capabilities, but the source code audit reveals that the following modules **have NO screens, NO routes, and NO UI representation whatsoever**:

| Module | Exists in DB? | Exists in Repositories? | Exists in UI / Routes? | Verdict |
|---|---|---|---|---|
| **Purchases Management** | Yes (`Purchases` table) | Yes (`addStockMovement(type: purchase)`) | **NO** | Zero UI to record purchases, select suppliers, or enter purchase bills. |
| **Customer Management** | Yes (`Customers` table) | Yes (`LocalPartyRepository`) | **NO** | No screen to view, create, edit, or search customers. |
| **Customer Ledger** | No | No | **NO** | Completely absent. |
| **Supplier Management** | Yes (`Suppliers` table) | Yes (`LocalPartyRepository`) | **NO** | No screen to view, create, or edit suppliers. |
| **Supplier Ledger** | No | No | **NO** | Completely absent. |
| **Payments / Accounts** | No | No | **NO** | Completely absent. |
| **Expenses** | No | No | **NO** | Completely absent. |
| **Employee & Staff** | No | No | **NO** | Completely absent. |
| **Incentives & Targets** | No | No | **NO** | Completely absent. |
| **Bluetooth Printer Setup** | No | Stub only | **NO** | Completely absent. |
| **Quotations** | No | No | **NO** | Completely absent. |

