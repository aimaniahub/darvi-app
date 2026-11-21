# DARVI BILLING — FLUTTER UI KIT INTEGRATION & REDESIGN AUDIT
**Document:** `DARVI_UI_INTEGRATION_AUDIT.md`  
**Application:** Darvi Billing (Darvi Group Agri Tech)  
**Milestone:** Phase 1 (Audit) & Phase 2 (Reference Projects Inspection & Component Selection)  
**Date:** November 2026  
**Status:** Audit & Selection Complete — Awaiting Approval to Proceed with Phase 3

---

## 1. EXECUTIVE SUMMARY

The Darvi Billing application is a robust, enterprise-grade agri-tech POS and ERP solution built with Flutter, Dart, Drift (SQLite), and BLoC/Cubit. The business logic, database integrity, financial double-entry ledger, POS thermal printing, inventory FIFO/FEFO tracking, and employee payroll engines are complete, hardened, and verified with 88 automated tests.

However, a comprehensive UI audit reveals that many feature screens (`ProductsPage`, `PurchasesPage`, `PartiesPage`, `FinancialsPage`, `EmployeesPage`, `ReportsPage`) suffer from:
1. **Ad-hoc, repeated widget implementations:** Custom KPI badge rows, custom search/filter bars, and custom modal sheets are re-implemented inline in each page file rather than reusing a unified design system.
2. **Layout density and responsiveness inconsistencies:** On wider tablet/desktop screens, cards either stretch excessively or remain trapped in narrow mobile columns. Tables lack standardized sticky headers, row actions, and column sorting.
3. **Inconsistent input and label styling:** Some forms use floating labels that clip or shift during keyboard input, while others use static hint text without consistent semantic validation messages.

By inspecting the source code of three open-source Flutter reference projects—**Kite Flutter Admin Dashboard** (ColorlibHQ), **Flutter Templates** (fluttertemplates.dev / Bibek Timsina), and **Flutter E-Commerce UI Kit** (Furqankhanzada)—we have identified high-value, production-ready UI patterns. We have mapped these components to Darvi's design tokens (`#135D44` Deep Green, `#7CB342` Leaf Accent, `#F6F8F6` Background, White Surface, `#1E293B` Charcoal Text) and existing BLoC/Drift architecture.

---

## 2. PHASE 1: AUDIT OF EXISTING DARVI PROJECT

### 2.1 Complete Architectural Inventory

```
lib/
├── app/
│   ├── app.dart                   # Root application widget with MaterialApp & AppTheme
│   ├── app_dependencies.dart      # Service locator & repository initializations
│   ├── app_scope.dart             # InheritedWidget exposing AppDependencies
│   ├── splash_screen.dart         # Startup authentication splash
│   ├── router/
│   │   └── app_router.dart        # GoRouter navigation configuration (17 active routes)
│   └── theme/
│       └── app_theme.dart         # Design tokens: AppColors, AppSpacing, AppRadii, AppTheme
├── core/
│   ├── errors/app_exception.dart  # Strongly-typed domain exceptions
│   ├── l10n/                      # Internationalization & localizations
│   ├── models/app_models.dart     # UI and transfer models
│   ├── services/                  # Hardware & OS services (ESC/POS, PDF, Barcode, Thermal)
│   ├── state/                     # AppCubit, ViewState, base state machines
│   ├── utils/                     # Formatters, MoneyCalculator (decimal-accurate)
│   └── widgets/
│       ├── buttons.dart           # PrimaryButton, DangerButton
│       ├── cards.dart             # SummaryCard, DarviMetricCard, DarviChartCard, QuickActionButton
│       ├── fields.dart            # AppTextField, AmountField, AppDropdown
│       └── states.dart            # EmptyState, LoadingSkeleton
├── data/
│   ├── local/
│   │   ├── db/
│   │   │   ├── app_database.dart   # Drift SQLite tables (28 relational tables)
│   │   │   └── app_database.g.dart # Drift generated bindings
│   │   └── seed/seed_data.dart    # Initial database seeder
│   └── repositories/              # 16 concrete SQLite repositories
├── domain/entities/               # Domain entity models
└── features/                      # 14 distinct feature modules with Cubits, Pages, and Widgets
```

### 2.2 Existing GoRouter Route Map
| Route Path | Page Widget | Primary Purpose |
|---|---|---|
| `/login` | `LoginPage` | Authentication & session activation |
| `/home` | `HomeDashboardPage` | Executive overview, 12 KPIs, Quick Actions, Activity Feed |
| `/pos` | `PosPage` | Retail POS workspace, Cart review, Thermal ESC/POS receipting |
| `/products` | `ProductsPage` | Catalog, stock valuation, categories, batch/HSN/GST |
| `/inventory` | `InventoryOperationsPage` | Stock adjustments, transfers, FIFO/FEFO movements |
| `/purchases` | `PurchasesPage` | Inward supplier bills, purchase returns, debit notes |
| `/parties` | `PartiesPage` | Customer & Supplier directories, ledgers, statements |
| `/financials` | `FinancialsPage` | Cashbook, Accounts, Expenses, Double-Entry Ledger, P&L |
| `/employees` | `EmployeesPage` | Staff directory, Attendance register, Payroll, Incentives |
| `/plots` | `PlotsPage` | Vikshha Farmland plot registry & status grid |
| `/crm` | `CrmPage` | Farmland leads, site visit scheduling, conversion funnel |
| `/quotations` | `QuotationsPage` | Sales quotations, GST calculation, quotation-to-sale convert |
| `/bookings` | `BookingsPage` | Farmland plot booking lifecycle & advance receipts |
| `/deliveries` | `DeliveriesPage` | Inward & outward delivery dispatch tracking |
| `/reports` | `ReportsPage` | Sales analytics, GST reports, exportable PDF registers |
| `/reports/invoice/:id` | `InvoiceDetailPage` | Detailed invoice audit with payment breakdown |
| `/settings` | `SettingsPage` | Store details, Bluetooth printer SPP pairing, backup |

### 2.3 Drift SQLite Relational Database Inventory
* **Core & Multi-tenant:** `Workspaces`, `Users`, `Settings`
* **Inventory & Catalog:** `Products`, `Categories`, `Batches`, `StockMovements`, `InventoryAdjustments`, `StockTransfers`
* **Sales & POS:** `Sales`, `SaleItems`, `SaleReturns`, `SaleReturnItems`
* **Purchases & Inward:** `PurchaseInvoices`, `PurchaseInvoiceItems`, `PurchaseReturns`, `PurchaseReturnItems`
* **Parties & CRM:** `Customers`, `Suppliers`, `Leads`, `SiteVisits`
* **Agri Farmland Business:** `Projects`, `Plots`, `Bookings`, `Quotations`, `QuotationItems`, `Deliveries`
* **Financial Accounting:** `Accounts`, `Payments`, `Expenses`, `ExpenseCategories`, `LedgerEntries`
* **HR & Payroll:** `Employees`, `Attendances`, `Payrolls`, `Incentives`

### 2.4 Existing Cubits and State Management
1. `AppCubit`: Global auth session, active workspace, locale, theme.
2. `DashboardCubit`: Aggregates 12 cross-module business metrics.
3. `PosCubit`: Cart lines, held bills, discount rules, multi-mode payment, thermal printing.
4. `ProductsCubit`: Category filters, stock valuation, search, product mutation.
5. `PurchasesCubit`: Supplier purchase entries, debit notes, inward payments.
6. `PartiesCubit`: Customer receivables, supplier payables, statement generation.
7. `FinancialsCubit`: Accounts balance, cashbook filter, ledger audit, reconciliation.
8. `EmployeesCubit`: Staff profiles, daily attendance, payroll run, performance targets.
9. `CrmCubit`: Lead pipeline, site visit booking, quotation conversion.
10. `PlotCubit`: Farmland plot availability, stage tracking, pricing.
11. `QuotationCubit`: Estimate builder, line-level discount, tax calculations.
12. `BookingCubit`: Token advances, plot reservation, agreement tracking.
13. `DeliveryCubit`: Dispatch statuses, challan generation, delivery tracking.
14. `ReportsCubit`: Periodic sales report, GST summary, register PDF exports.

---

### 2.5 Audit of Design Gaps, Code Duplication & Weak Components

| Identified Problem Area | Current File(s) Affected | Technical & Design Weakness | Proposed Redesign Solution |
|---|---|---|---|
| **Inconsistent Metric & KPI Display** | `products_page.dart` (`_buildKpiBadge`), `purchases_page.dart` (Row 2 container), `parties_page.dart`, `financials_page.dart` | Ad-hoc horizontal scrolling badges and mismatched cards. Some have icons, some don't; some cards stretch arbitrarily. | Create centralized `AppStatCard` and `AppStatGrid` inspired by Kite's fixed-height responsive grid and tabular number typography. |
| **Scattered Search & Filter Toolbars** | `products_page.dart` (`_buildFilterBar`), `purchases_page.dart`, `parties_page.dart`, `crm_page.dart` | Each page writes its own 80-120 lines of `TextField`, `ChoiceChip` loops, refresh buttons, and clear actions. Filter styling varies across screens. | Build a modular `AppFilterBar` component with built-in search debounce, multi-status chips, active filter count, and reset button. |
| **Lack of Standard Data Table** | `financials_page.dart` (Ledger tab), `purchases_page.dart` (Bill history), `inventory_operations_page.dart` | Uses raw `DataTable` wrapped in nested horizontal/vertical `SingleChildScrollView` or unformatted `ListView.separated`. No column sorting, sticky headers, or consistent row action triggers. | Create `AppDataTable<T>` with responsive desktop scroll, sticky headers, typed sort callbacks, and dedicated row action affordances. |
| **Form Inputs & Label Scannability** | All modal bottom sheets and dialog editors (`products_page.dart`, `purchases_page.dart`, `employees_page.dart`) | Forms rely on Material floating labels inside text fields. When fields are dense or placed in two columns, floating labels collide or get truncated. | Implement `AppFormField` with persistent external top labels, semantic helper texts, and clear error banners inspired by Kite's `KiteField`. |
| **Master-Detail Responsive Layouts** | `parties_page.dart`, `plots_page.dart`, `reports_page.dart` | On tablet and desktop screens, clicking a customer or invoice pushes a full-screen view or modal bottom sheet rather than utilizing available screen width with a side-by-side pane. | Introduce `AppSplitView` (inspired by Flutter Templates) that automatically renders master-detail side-by-side on wide screens (> 800px) and stack navigation on mobile. |
| **Empty and Loading States** | `core/widgets/states.dart` | Current `EmptyState` is plain with a simple gray icon and text. No contextual action button or illustrated state variants (e.g. no connection, no search matches, zero transactions). | Introduce `AppEmptyState` with visual variants, actionable call-to-actions, and shimmer-capable `AppLoadingSkeleton`. |

---

## 3. PHASE 2: DEEP SOURCE CODE INSPECTION OF REFERENCE PROJECTS

We inspected the actual Dart source trees of all three reference repositories:

### 3.1 Project 1: Kite Flutter Admin Dashboard
* **Repository:** `https://github.com/ColorlibHQ/kite-flutter-admin-dashboard`
* **License:** MIT License (Copyright © 2026 Colorlib). Commercial use, modification, and distribution permitted with attribution notice.
* **Architecture:** Multi-package monorepo (`kite`, `packages/kite_ui`). Built using Flutter 3.41+, Dart 3.11+, Riverpod, GoRouter, `shadcn_ui: ^0.55.1`, `trina_grid: ^2.3.0` (pluto_grid fork), and `fl_chart: ^1.3.0`.
* **Key Components Inspected:**
  1. `packages/kite_ui/lib/src/stat_grid.dart` (`KiteStatGrid`):
     - **Layout Structure:** Computes column count via `LayoutBuilder`: `((maxWidth + spacing) / (minTileWidth + spacing)).floor().clamp(1, children.length)`. Lays out tiles at a constant height while allowing width to respond to the viewport. Prevents cards on wide screens from ballooning out of proportion.
  2. `packages/kite_ui/lib/src/card.dart` (`KiteCard`, `KiteStat`):
     - **Design:** Crisp borders (`c.border`), subtle radius (`KiteRadius.allLg`), tabular figures (`fontFeatures: [FontFeature.tabularFigures()]`) preventing horizontal jitter on animated or numeric values. Semantic delta tones (`KiteTone.success`, `danger`, `neutral`).
  3. `packages/kite_ui/lib/src/inputs.dart` (`KiteField`, `KiteInput`):
     - **Design:** External persistent labels (`style: t.small.copyWith(fontWeight: FontWeight.w500)`), accessibility semantics, live-region error announcements. Eliminates floating label layout shift.
  4. `packages/kite_ui/lib/src/badge.dart` (`KiteBadge`):
     - **Design:** Rounded pill badges (radius 999) with tone-based pastel container backgrounds and high-contrast foreground text.
  5. `lib/features/resources/resource_list_screen.dart` (`_Toolbar`):
     - **Design:** Unified `Wrap` toolbar combining search input (240px fixed width), status choice chips, ghost refresh button, primary add button, and clear filters link.
* **Dependencies & Reusability Assessment:**
  - `kite_ui` depends on `shadcn_ui ^0.55.1` and `trina_grid ^2.3.0`. `shadcn_ui` is a fast-moving, pre-1.0 third-party framework that overrides Flutter's native Material 3 theme and introduces version constraints.
  - **Verdict:** Do **not** drag `shadcn_ui` or `trina_grid` into Darvi. Instead, **directly adapt the pure Dart layout algorithms, typography rules (tabular figures), `StatGrid` math, and `Toolbar` patterns into native Flutter Material 3 widgets**. This provides 100% of the visual elegance and responsiveness without external dependency risk.

---

### 3.2 Project 2: Flutter Templates (fluttertemplates.dev)
* **Repository:** `https://github.com/bimsina/fluttertemplates.dev`
* **License:** MIT License (Copyright © 2022 Bibek Timsina). Permitted for open-source and commercial use with attribution.
* **Architecture:** Monorepo with `flutter_apps/core/lib/`. Pure Flutter 3 Material 3 implementations with minimal dependencies (`cupertino_icons: ^1.0.8`, `salomon_bottom_bar: 3.3.2`).
* **Key Components Inspected:**
  1. `flutter_apps/core/lib/dashboard/kpi_cards.dart` (`_Kpi`, `KpiCards`):
     - **Design:** Structured KPI model containing `value`, `target`, `prefix`, `suffix`, `percentVsTarget`, and `higherIsBetter`. Renders current value, comparison to target, and a sleek `LinearProgressIndicator` (height 4px, radius 2px).
  2. `flutter_apps/core/lib/dashboard/data_table.dart` (`DataTableScreen`):
     - **Design:** Pure Flutter `DataTable` in a dual-axis scrollable canvas with explicit action columns (`Edit`, `Delete`) and standardized modal confirmation dialogs.
  3. `flutter_apps/core/lib/ecommerce/product_grid.dart` & `product_list.dart`:
     - **Design:** Responsive cross-axis count based on viewport (`maxWidth > 600 ? 3 : 2`), text-scaler aware card aspect ratio (`childAspectRatio: 0.75 / textScaler.scale(1)`), preventing overflow on devices with larger font accessibility settings.
  4. `flutter_apps/core/lib/ecommerce/shopping_cart.dart` (`ShoppingCart`, `CartLine`):
     - **Design:** `Dismissible` swipe-to-delete with red background indicator, quantity stepper (`IconButton` decrement/increment), and fixed checkout summary footer.
  5. `flutter_apps/core/lib/finance/transaction_history.dart` (`TransactionHistory`):
     - **Design:** High-density ledger list tiles with circular category avatars, party/merchant headings, relative dates, and color-coded signed amount text (`+` green, `-` neutral/red).
  6. `flutter_apps/core/lib/finance/wallet_overview.dart` (`WalletOverview`):
     - **Design:** Financial balance cards displaying account balance, card/account number masks, and quick deposit/transfer pill buttons.
  7. `flutter_apps/core/lib/layouts/split_view.dart` (`SplitView`):
     - **Layout:** Master-detail split layout checking `constraints.maxWidth < 600`. Wide screens render fixed 250px master list alongside flexible detail pane; narrow screens render stack navigation.
  8. `flutter_apps/core/lib/states/empty_no_data.dart` (`EmptyNoData`):
     - **Design:** Centered container with outline icon (size 80), headline, descriptive subtitle, and primary call-to-action button.
* **Dependencies & Reusability Assessment:**
  - Written in 100% pure Flutter Material widgets with no incompatible dependencies.
  - **Verdict:** Readily adaptable into Darvi's core design system and feature modules. Highly compatible with Flutter 3.29+ and Dart 3.7+.

---

### 3.3 Project 3: Flutter E-Commerce UI Kit
* **Repository:** `https://github.com/Furqankhanzada/flutter_eCommerce_ui_kit`
* **License:** No formal LICENSE file included in repository root (declared in README as "completely free for everyone").
* **Architecture:** Legacy Flutter project targeting SDK `">=2.12.0 <3.0.0"` with outdated dependencies (`carousel_slider: ^4.0.0`, `cached_network_image: ^3.0.0`, `provider: ^6.0.3`, `intl: ^0.17.0`).
* **Key Components Inspected:**
  1. `lib/cart.dart` (`CartList`):
     - Dismissible cart row with item image, price, title, and quantity.
  2. `lib/shop/shop.dart` & `lib/shop/search.dart`:
     - Grid of e-commerce items with floating shopping cart icons and search field.
* **Dependencies & Reusability Assessment:**
  - The codebase has outdated null-safety constraints and dependencies that conflict with Darvi's modern Flutter environment.
  - **Verdict:** Do **not** import any code files directly from this repository. Its mobile cart row layout pattern (thumbnail + title + unit price + inline delete) has already been synthesized into modern Flutter 3.x in Darvi's Group 4 POS redesign (`cart_item_tile.dart`).

---

## 4. COMPONENT SELECTION & ADAPTATION MATRIX

The table below lists each selected component from the reference repositories, its origin, dependencies, and how it will be adapted into Darvi's design system:

| Reference Source File | Component Name | Origin License | External Dependencies | Darvi Target File | Adaptation Strategy |
|---|---|---|---|---|---|
| `kite/packages/kite_ui/lib/src/stat_grid.dart` | `KiteStatGrid` | MIT (Colorlib) | Pure Dart / Flutter | `lib/core/widgets/app_stat_grid.dart` | Adapt column computation math. Replace shadcn spacing with `AppSpacing`. Ensure zero card ballooning on desktop. |
| `kite/packages/kite_ui/lib/src/card.dart` | `KiteStat` & `KiteCard` | MIT (Colorlib) | Pure Flutter | `lib/core/widgets/app_stat_card.dart` | Adopt tabular figures font feature (`FontFeature.tabularFigures()`), tone deltas, and clean borders using `AppColors.primary` & `AppColors.border`. |
| `kite/packages/kite_ui/lib/src/inputs.dart` | `KiteField` | MIT (Colorlib) | Pure Flutter | `lib/core/widgets/app_text_field.dart` | Implement `AppFormField` with persistent external top label, clear helper text, and accessible error message. |
| `kite/packages/kite_ui/lib/src/badge.dart` | `KiteBadge` | MIT (Colorlib) | Pure Flutter | `lib/core/widgets/app_badge.dart` | Extract pill badge design with semantic status tones (success, warning, error, info, neutral) matching Darvi palette. |
| `kite/lib/features/resources/resource_list_screen.dart` | `_Toolbar` | MIT (Colorlib) | Pure Flutter | `lib/core/widgets/app_filter_bar.dart` | Create unified toolbar with responsive search field, horizontal status chips, refresh button, and reset action. |
| `fluttertemplates/flutter_apps/core/lib/dashboard/kpi_cards.dart` | `_Kpi` & progress bar | MIT (B. Timsina) | Pure Flutter | `lib/core/widgets/app_stat_card.dart` | Incorporate target percentage and micro `LinearProgressIndicator` into `AppStatCard` for sales & payroll targets. |
| `fluttertemplates/flutter_apps/core/lib/dashboard/data_table.dart` | `DataTableScreen` | MIT (B. Timsina) | Pure Flutter | `lib/core/widgets/app_data_table.dart` | Build reusable generic `AppDataTable<T>` supporting sticky headers, custom column builders, and dedicated row action buttons. |
| `fluttertemplates/flutter_apps/core/lib/ecommerce/product_grid.dart` | `ProductGrid` | MIT (B. Timsina) | Pure Flutter | `lib/features/products/presentation/widgets/product_grid_view.dart` | Implement text-scale-aware grid layout with dynamic cross-axis counts for POS & Products screens. |
| `fluttertemplates/flutter_apps/core/lib/finance/transaction_history.dart` | `TransactionHistory` | MIT (B. Timsina) | Pure Flutter | `lib/features/financials/presentation/widgets/transaction_tile.dart` | Adapt transaction list tile with circular category icons, party names, and signed currency amounts. |
| `fluttertemplates/flutter_apps/core/lib/layouts/split_view.dart` | `SplitView` | MIT (B. Timsina) | Pure Flutter | `lib/core/widgets/app_split_view.dart` | Create responsive layout widget that toggles between split master-detail (tablet/desktop) and stack list (mobile). |
| `fluttertemplates/flutter_apps/core/lib/states/empty_no_data.dart` | `EmptyNoData` | MIT (B. Timsina) | Pure Flutter | `lib/core/widgets/app_empty_state.dart` | Create standardized empty state with custom Tabler icon, headline, description, and primary button callback. |

---

## 5. REUSABLE CORE DESIGN SYSTEM ARCHITECTURE (PHASE 3 BLUEPRINT)

In Phase 3, we will organize the central design system into clean, modular files inside `lib/core/`:

```
lib/core/
├── theme/
│   ├── app_colors.dart         # Extracted & formalized brand tokens (#135D44, #7CB342, #F6F8F6, etc.)
│   ├── app_typography.dart     # Tabular figures, headline styles, dense body styles
│   ├── app_spacing.dart        # 4, 8, 12, 16, 24, 32px spacing scales
│   ├── app_dimensions.dart     # Standard component heights: Button 44-48px, Input 48-52px, Filter 36-40px
│   └── app_theme.dart          # Light & Dark ThemeData using ColorScheme & component themes
└── widgets/
    ├── app_button.dart         # Primary, Outlined, Danger, and Ghost button variants
    ├── app_text_field.dart     # Standard inputs and persistent-label AppFormField
    ├── app_search_field.dart   # Instant search bar with clear button and leading icon
    ├── app_dropdown.dart       # Form dropdown with consistent border radius & label
    ├── app_card.dart           # Elevated & bordered white card container with consistent padding
    ├── app_stat_card.dart      # KPI stat card with tabular figures, delta badges, target progress
    ├── app_stat_grid.dart      # Viewport-adaptive fixed-height grid layout
    ├── app_badge.dart          # Semantic status pills (success, warning, error, info)
    ├── app_filter_bar.dart     # Toolbar with search, status chips, refresh, and clear filters
    ├── app_data_table.dart     # Responsive generic data table with pagination and row actions
    ├── app_split_view.dart     # Master-detail responsive split view for tablet/desktop
    ├── app_empty_state.dart    # Rich empty state with icon, message, and call-to-action
    ├── app_loading_state.dart  # Smooth shimmer/skeleton loaders matching row heights
    └── app_dialog.dart         # Standardized confirmation and action modal dialogs
```

---

## 6. BUSINESS LOGIC & DRIFT INTEGRATION PRESERVATION (PHASE 4 & 5 GATES)

Every imported and adapted component will connect directly to existing systems:
1. **No mock data:** All components bind directly to existing Cubit states (`state.products`, `state.invoices`, `state.metrics`, `state.customers`, `state.ledgerEntries`).
2. **Double-entry financial ledger integrity:** Payment and expense actions trigger real SQLite transactions via `LocalLedgerRepository` and `LocalAccountRepository`.
3. **Database stability:** No schema migrations or table modifications required. Existing Drift models and companion classes will be preserved intact.
4. **Thermal printing and barcode hardware:** Group 4 SSEZNIK2POS 58mm printer service and camera barcode scanning remain fully operational.

---

## 7. EXECUTION ROADMAP

* [x] **Phase 1:** Complete audit of existing Darvi architecture, routes, database, and widget duplication.
* [x] **Phase 2:** Deep inspection of Kite, Flutter Templates, and E-Commerce UI Kit source trees; selection matrix created.
* [ ] **Phase 3:** Create central design system in `lib/core/theme/` and `lib/core/widgets/`.
* [ ] **Phase 4:** Adapt and integrate components across feature pages:
  - Step 4.1: Dashboard & Reports (Kite StatGrid, KPI cards).
  - Step 4.2: Products & Inventory (Product grid, search/filter bar, stock table).
  - Step 4.3: Purchases & Financials (Purchases toolbar, ledger data table, cashbook tiles).
  - Step 4.4: Parties & CRM (Customer/Supplier master-detail split view, status badges).
  - Step 4.5: Employees & Payroll (Attendance table, staff cards, target progress).
* [ ] **Phase 5 & 6:** Verify strict business logic preservation and responsive layouts across mobile, tablet, and desktop.
* [ ] **Phase 7:** Automated testing (`flutter test`, `flutter analyze`) and compilation verification.
* [ ] **Phase 8:** Final delivery report `DARVI_UI_INTEGRATION_REPORT.md`.

---
*End of Audit and Component Selection Document (`DARVI_UI_INTEGRATION_AUDIT.md`)*

