# QuickStock POS Source Code Audit: Directory Structure & File Map

**Document ID:** `docs/darvi-audit/DIRECTORY_STRUCTURE.md`  
**Audit Date:** November 2026  
**Auditor:** Senior Flutter Architect & Software Auditor  

---

## 1. Project Directory Tree

```
mini_pos_inventory/
├── .gitattributes
├── .gitignore
├── .metadata
├── analysis_options.yaml
├── devtools_options.yaml
├── LICENSE
├── pubspec.lock
├── pubspec.yaml
├── README.md
├── android/
│   ├── .gitignore
│   ├── build.gradle.kts
│   ├── gradle.properties
│   ├── settings.gradle.kts
│   ├── app/
│   │   ├── build.gradle.kts
│   │   └── src/
│   │       ├── debug/AndroidManifest.xml
│   │       ├── main/
│   │       │   ├── AndroidManifest.xml
│   │       │   ├── kotlin/com/example/mini_pos_inventory/MainActivity.kt
│   │       │   └── res/
│   │       └── profile/AndroidManifest.xml
│   └── gradle/wrapper/
│       └── gradle-wrapper.properties
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── app_dependencies.dart
│   │   ├── app_scope.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── core/
│   │   ├── errors/
│   │   │   └── app_exception.dart
│   │   ├── l10n/
│   │   │   └── app_localizations.dart
│   │   ├── models/
│   │   │   └── app_models.dart
│   │   ├── services/
│   │   │   ├── barcode_scanner_service_impl.dart
│   │   │   ├── file_export_service.dart
│   │   │   ├── receipt_pdf_service.dart
│   │   │   └── stub_services.dart
│   │   ├── state/
│   │   │   ├── app_cubit.dart
│   │   │   └── view_state.dart
│   │   ├── utils/
│   │   │   ├── formatters.dart
│   │   │   └── money_calculator.dart
│   │   └── widgets/
│   │       ├── buttons.dart
│   │       ├── cards.dart
│   │       ├── fields.dart
│   │       └── states.dart
│   ├── data/
│   │   ├── local/
│   │   │   ├── db/
│   │   │   │   ├── app_database.dart
│   │   │   │   └── app_database.g.dart
│   │   │   └── seed/
│   │   │       └── seed_data.dart
│   │   └── repositories/
│   │       └── local_repositories.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   └── app_entities.dart
│   │   └── repositories/
│   │       └── repositories.dart
│   └── features/
│       ├── auth/presentation/pages/
│       │   └── login_page.dart
│       ├── invoices/presentation/
│       │   ├── cubit/
│       │   │   └── invoice_detail_cubit.dart
│       │   └── pages/
│       │       └── invoice_detail_page.dart
│       ├── pos/presentation/
│       │   ├── cubit/
│       │   │   └── pos_cubit.dart
│       │   ├── pages/
│       │   │   └── pos_page.dart
│       │   └── widgets/
│       │       ├── cart_item_tile.dart
│       │       └── product_tile.dart
│       ├── products/presentation/
│       │   ├── cubit/
│       │   │   └── products_cubit.dart
│       │   └── pages/
│       │       └── products_page.dart
│       ├── reports/presentation/
│       │   ├── cubit/
│       │   │   └── reports_cubit.dart
│       │   └── pages/
│       │       └── reports_page.dart
│       ├── settings/presentation/pages/
│       │   └── settings_page.dart
│       ├── shared/widgets/
│       │   └── barcode_scanner_page.dart
│       └── shell/presentation/pages/
│           └── app_shell_page.dart
└── test/
    ├── widget_test.dart
    ├── core/utils/
    │   └── money_calculator_test.dart
    └── data/repositories/
        └── stock_logic_test.dart
```

---

## 2. Exhaustive Source File Catalog & Responsibilities

### Top-Level & App Infrastructure

| File Path | Size (Bytes) | Main Responsibility | Key Classes & Methods | Dependencies | Related Modules | Action |
|---|---|---|---|---|---|---|
| `lib/main.dart` | 281 | Application entry point; initializes Flutter bindings, asynchronous dependencies, and starts `MiniPosRoot`. | `main()` | `flutter/widgets.dart`, `app/app.dart`, `app/app_dependencies.dart` | Entire Application | **Modify** (rename app class, initialize logging/crash diagnostics) |
| `lib/app/app.dart` | 1,779 | Root widget configuring `MaterialApp.router`, global themes, localization delegates, and router binding. | `MiniPosRoot`, `_MiniPosRootState` | `flutter_bloc`, `flutter_localizations`, `app_router.dart`, `app_theme.dart` | Router, Theme, Localization | **Modify** (branding title, add Darvi theme tokens) |
| `lib/app/app_dependencies.dart` | 3,277 | Manual dependency injection container assembling database, repositories, services, and cubits. | `AppDependencies`, `create()`, `dispose()` | `drift`, `local_repositories.dart`, `stub_services.dart`, `receipt_pdf_service.dart` | Entire Application | **Extend** (register new Darvi services: Bluetooth printing, employee repo, ledger repo) |
| `lib/app/app_scope.dart` | 598 | `InheritedWidget` exposing `AppDependencies` down the widget tree. | `AppScope`, `of(BuildContext)` | `flutter/widgets.dart`, `app_dependencies.dart` | Entire Application | **Preserve** |
| `lib/app/router/app_router.dart` | 3,072 | GoRouter configuration with auth guards, refresh stream, ShellRoute bottom navigation, and invoice subroute. | `AppRouter`, `GoRouterRefreshStream` | `go_router`, `app_cubit.dart`, all feature pages | Navigation & Routing | **Extend** (register routes for Customers, Suppliers, Ledgers, Purchases, Staff, Printing) |
| `lib/app/theme/app_theme.dart` | 2,906 | Design system tokens for spacing, radii, typography, and Material 3 `ThemeData.light()`. | `AppSpacing`, `AppRadii`, `AppTheme` | `flutter/material.dart` | All UI Views | **Extend** (support Darvi brand palette: primary `#006B5E` / green accents, dark mode support) |

---

### Core Layer (`lib/core/`)

| File Path | Size (Bytes) | Main Responsibility | Key Classes & Methods | Dependencies | Related Modules | Action |
|---|---|---|---|---|---|---|
| `lib/core/errors/app_exception.dart` | 144 | Base application exception wrapper. | `AppException` | None | All Repositories & Cubits | **Extend** (typed exception hierarchy: `ValidationException`, `StockException`, `PrinterException`) |
| `lib/core/l10n/app_localizations.dart` | 5,124 | Static map-based localization for English (`en`) and Arabic (`ar`). | `AppLocalizations`, `_AppLocalizationsDelegate`, `tr()` | `flutter/material.dart` | All Presentation Views | **Extend** (add Kannada (`kn`), Hindi (`hi`), and Indian GST/ledger terms) |
| `lib/core/models/app_models.dart` | 11,119 | Core DTOs, enums, filter models, and metric models. | `UserRole`, `StockMovementType`, `PaymentMethod`, `SaleStatus`, `AppSettingsModel`, `ProductUpsertInput`, `StockMovementInput`, `ProductFilter`, `CategoryModel`, `CustomerModel`, `SupplierModel`, `InvoiceFilter`, `SaleSummary`, `ReturnItemInput`, `CartItem`, `DashboardMetrics`, `BestSellerMetric`, `SalesByProductMetric`, `SaleCheckoutInput` | `equatable` | Domain, Data, Features | **Extend** (add `GSTBreakup`, `EmployeeModel`, `IncentiveModel`, `AccountModel`, `PaymentTransactionInput`) |
| `lib/core/services/barcode_scanner_service_impl.dart` | 647 | Implementation of `BarcodeScannerService` pushing `BarcodeScannerPage`. | `RouteBarcodeScannerService.scanBarcode()` | `flutter/material.dart`, `barcode_scanner_page.dart` | POS, Products | **Preserve** |
| `lib/core/services/file_export_service.dart` | 1,655 | Exports sales and inventory lists to CSV using device documents directory and triggers sharing. | `FileExportService`, `exportSalesCsv()`, `exportInventoryCsv()`, `shareFile()` | `csv`, `path_provider`, `share_plus` | Reports | **Extend** (add ledger CSV export, GST summary export, PDF report generation) |
| `lib/core/services/receipt_pdf_service.dart` | 3,290 | Generates 80mm PDF receipts using `pdf` package and manages PDF printing/sharing. | `ReceiptPdfService`, `generateReceipt()`, `sharePdf()`, `printPdf()`, `printThroughStub()` | `pdf`, `printing`, `share_plus`, `path_provider` | POS, Invoices | **Modify** (support 58mm roll format, add Darvi business header & GST breakdown) |
| `lib/core/services/stub_services.dart` | 410 | Mock stubs for cloud sync and thermal printing. | `FakeSyncService.syncNow()`, `StubPrinterService.printReceiptPdfBytes()` | `domain/repositories.dart` | App Dependencies | **Replace** (`StubPrinterService` must be replaced by real Android ESC/POS Bluetooth engine) |
| `lib/core/state/app_cubit.dart` | 3,469 | Global application state management: session auth, settings cache, role checking. | `AppCubit`, `AppState`, `initialize()`, `loginCashier()`, `loginAdmin()`, `logout()`, `updateSettings()` | `flutter_bloc`, `equatable`, `app_models.dart`, `app_entities.dart` | Root App, Settings, Login | **Extend** (support multi-workspace state, dynamic employee session auth) |
| `lib/core/state/view_state.dart` | 55 | Generic enum representing async view execution states. | `ViewStatus { initial, loading, success, failure }` | None | Cubits | **Preserve** |
| `lib/core/utils/formatters.dart` | 376 | Utility helpers for currency formatting and short date formatting. | `AppFormatters.money()`, `AppFormatters.shortDate()` | `intl` | All Presentation Views | **Modify** (default currency to INR `₹`, support Indian number formatting lakhs/crores) |
| `lib/core/utils/money_calculator.dart` | 1,180 | Static utility functions calculating line totals, subtotals, tax, grand total, and line profit. | `MoneyCalculator`, `round2()`, `lineTotal()`, `subtotal()`, `tax()`, `orderTotal()`, `profitForLine()` | `dart:math` | Repositories, POS Cubit | **Modify & Extend** (support 3-tier Indian GST: CGST, SGST, IGST; fix subtotal discount ambiguity) |
| `lib/core/widgets/buttons.dart` | 1,925 | Reusable primary and danger button components. | `PrimaryButton`, `DangerButton` | `flutter/material.dart`, `app_theme.dart` | All Presentation Views | **Preserve** |
| `lib/core/widgets/cards.dart` | 2,312 | Metric card and status badge UI widgets. | `SummaryCard`, `StatusChip` | `flutter/material.dart`, `app_theme.dart` | Reports, Invoices, POS | **Preserve** |
| `lib/core/widgets/fields.dart` | 2,190 | Standardized text fields, currency amount fields, and dropdown form fields. | `AppTextField`, `AmountField`, `AppDropdown` | `flutter/material.dart`, `app_theme.dart` | POS, Products, Settings | **Preserve** |
| `lib/core/widgets/states.dart` | 1,864 | Empty state placeholder and animated loading skeleton list. | `EmptyState`, `LoadingSkeleton` | `flutter/material.dart`, `app_theme.dart` | POS, Products, Reports | **Preserve** |

---

### Data Layer (`lib/data/`)

| File Path | Size (Bytes) | Main Responsibility | Key Classes & Methods | Dependencies | Related Modules | Action |
|---|---|---|---|---|---|---|
| `lib/data/local/db/app_database.dart` | 5,617 | Drift SQLite schema definition, table definitions, database class, and migration strategy. | `Products`, `Categories`, `StockMovements`, `Customers`, `Suppliers`, `Purchases`, `Sales`, `SaleItems`, `AppSettings`, `AppDatabase` | `drift`, `drift/native.dart`, `path_provider` | Entire Data Layer | **Extend** (bump schema to v3; add tables for Workspaces, Ledger, Accounts, Employees, Incentives) |
| `lib/data/local/db/app_database.g.dart` | 261,581 | Generated Drift code containing data classes, companions, and SQL execution helpers. | `_$AppDatabase`, DAOs, companions | `drift` | Database | **Regenerate** (via `dart run build_runner build` after editing `app_database.dart`) |
| `lib/data/local/seed/seed_data.dart` | 10,906 | Seeds initial categories, products, Unsplash images, customers, suppliers, and default settings. | `SeedData`, `ensureSeeded()`, `_ensureSettings()`, `_seedCategoriesAndProducts()` | `drift`, `app_database.dart` | App Startup | **Modify** (seed Darvi Group Agri Tech business profile, INR settings, agricultural categories) |
| `lib/data/repositories/local_repositories.dart` | 29,175 | Concrete implementations of all domain repository contracts using Drift queries and transactions. | `LocalAuthRepository`, `LocalSettingsRepository`, `LocalProductRepository`, `LocalSalesRepository`, `LocalReportsRepository`, `LocalPartyRepository` | `drift`, `app_database.dart`, `app_models.dart`, `money_calculator.dart` | All Features | **Modify & Refactor** (split into dedicated feature files; fix POS state bugs, add SQL aggregation) |

---

### Domain Layer (`lib/domain/`)

| File Path | Size (Bytes) | Main Responsibility | Key Classes & Methods | Dependencies | Related Modules | Action |
|---|---|---|---|---|---|---|
| `lib/domain/entities/app_entities.dart` | 3,325 | Immutable domain entities decoupled from Drift generated classes. | `ProductView`, `SaleItemView`, `SaleView`, `SaleDetailView`, `AuthSession` | `equatable`, `app_models.dart` | Repositories, Cubits, Pages | **Extend** (add `CustomerLedgerEntry`, `EmployeeView`, `IncentiveReportView`) |
| `lib/domain/repositories/repositories.dart` | 3,614 | Abstract repository contracts and service interfaces. | `AuthRepository`, `SettingsRepository`, `ProductRepository`, `SalesRepository`, `ReportsRepository`, `PartyRepository`, `SyncService`, `PrinterService`, `BarcodeScannerService` | `app_models.dart`, `app_entities.dart` | All Features & Services | **Extend** (add `EmployeeRepository`, `LedgerRepository`, `PurchaseRepository`, `ThermalPrinterService`) |

---

### Features Layer (`lib/features/`)

| File Path | Size (Bytes) | Main Responsibility | Key Classes & Methods | Dependencies | Related Modules | Action |
|---|---|---|---|---|---|---|
| `lib/features/auth/presentation/pages/login_page.dart` | 4,278 | User login screen with Cashier PIN field and Admin password field. | `LoginPage`, `_LoginPageState` | `flutter_bloc`, `app_cubit.dart`, `fields.dart`, `buttons.dart` | Auth, Navigation | **Extend** (support employee selection dropdown, PIN verification against Employee database) |
| `lib/features/invoices/presentation/cubit/invoice_detail_cubit.dart` | 4,300 | State management for invoice detail and partial/full return submission. | `InvoiceDetailCubit`, `InvoiceDetailState`, `load()`, `setReturnQty()`, `submitReturn()` | `flutter_bloc`, `sales_repository` | Invoices | **Modify** (handle customer balance credit and return accounting on returns) |
| `lib/features/invoices/presentation/pages/invoice_detail_page.dart` | 9,249 | Detailed invoice view showing line items, pricing snapshots, return quantity selectors, and totals. | `InvoiceDetailPage`, `_InvoiceDetailView` | `flutter_bloc`, `invoice_detail_cubit.dart`, `cards.dart` | Invoices, Reports | **Modify** (display GST breakup, customer details, print thermal receipt action) |
| `lib/features/pos/presentation/cubit/pos_cubit.dart` | 12,753 | Comprehensive POS state machine: product filtering, cart management, line/order discount, checkout, receipt printing. | `PosCubit`, `PosState`, `load()`, `scanAndAdd()`, `addProductToCart()`, `updateItemQty()`, `checkout()`, `printLastReceipt()` | `flutter_bloc`, `product_repository`, `sales_repository`, `receipt_pdf_service.dart` | POS | **Modify** (fix `paid: state.total` bug, support customer selection, add thermal print trigger) |
| `lib/features/pos/presentation/pages/pos_page.dart` | 20,162 | Primary POS screen with responsive split layout (wide vs compact), category filter chips, search bar, and checkout modal sheet. | `PosPage`, `_PosView`, `_ProductsPane`, `_CartPane`, `_CheckoutBar` | `flutter_bloc`, `pos_cubit.dart`, `product_tile.dart`, `cart_item_tile.dart` | POS | **Modify** (support customer selection in checkout sheet, tax breakdown preview) |
| `lib/features/pos/presentation/widgets/cart_item_tile.dart` | 5,162 | Interactive cart item tile supporting swipe-to-delete, qty increment/decrement, discount dialog, and price edit dialog. | `CartItemTile`, `_QtyButton`, `_showAmountDialog` | `app_models.dart`, `formatters.dart`, `app_theme.dart` | POS | **Preserve** |
| `lib/features/pos/presentation/widgets/product_tile.dart` | 4,708 | Product card displaying thumbnail image, SKU, category, price, and stock badge. | `ProductTile`, `ProductImageWidget` | `app_entities.dart`, `formatters.dart`, `app_theme.dart` | POS, Products | **Preserve** |
| `lib/features/products/presentation/cubit/products_cubit.dart` | 3,899 | Manages product inventory state, search filters, category filtering, saving products, and recording stock movements. | `ProductsCubit`, `ProductsState`, `load()`, `applyFilter()`, `saveProduct()`, `applyStockMovement()` | `flutter_bloc`, `product_repository` | Products | **Modify** (ensure product editing records an audit trail in `StockMovements`) |
| `lib/features/products/presentation/pages/products_page.dart` | 24,065 | Product catalog view with search, filter chips, add/edit product bottom sheet (camera/gallery/URL image picker), and stock adjustment modal. | `ProductsPage`, `_ProductsView`, `_showProductEditor`, `_showStockActionSheet` | `flutter_bloc`, `image_picker`, `products_cubit.dart` | Products | **Modify** (add category management dialog, add HSN code field, tax rate selector) |
| `lib/features/reports/presentation/cubit/reports_cubit.dart` | 4,492 | Manages reports dashboard data, date range filtering, and CSV export triggers. | `ReportsCubit`, `ReportsState`, `load()`, `setRange()`, `exportSalesCsv()`, `exportInventoryCsv()` | `flutter_bloc`, `reports_repository`, `sales_repository`, `file_export_service.dart` | Reports | **Extend** (add GST GSTR-1 report generation, staff performance metrics) |
| `lib/features/reports/presentation/pages/reports_page.dart` | 13,656 | Dashboard view rendering summary metric cards, date range picker, export buttons, best seller list, sales by product bar chart, and invoice list. | `ReportsPage`, `_ReportsView`, `_RangeCard`, `_BestSellersCard`, `_SalesByProductCard`, `_LowStockCard`, `_InvoiceHistoryCard` | `flutter_bloc`, `reports_cubit.dart`, `cards.dart` | Reports | **Modify** (display genuine profit after tax, link to detailed invoice views) |
| `lib/features/settings/presentation/pages/settings_page.dart` | 11,083 | Settings screen managing store name, currency, tax toggle, tax rate, receipt header/footer, language, negative stock toggle, and credentials. | `SettingsPage`, `_SettingsPageState` | `flutter_bloc`, `app_cubit.dart`, `fields.dart`, `buttons.dart` | Settings | **Extend** (add Bluetooth printer configuration, business GSTIN & address fields, workspace switch) |
| `lib/features/shared/widgets/barcode_scanner_page.dart` | 999 | Full-screen camera view using `mobile_scanner` to scan 1D/2D barcodes. | `BarcodeScannerPage`, `_BarcodeScannerPageState` | `mobile_scanner` | Shared | **Preserve** |
| `lib/features/shell/presentation/pages/app_shell_page.dart` | 1,380 | Scaffold wrapping bottom navigation bar across 4 active tabs (`/pos`, `/products`, `/reports`, `/settings`). | `AppShellPage` | `go_router`, `app_localizations.dart` | Navigation Shell | **Extend** (expand navigation bar or drawer to include Purchases, Ledgers, Staff, Incentives) |

---

### Test Layer (`test/`)

| File Path | Size (Bytes) | Main Responsibility | Key Classes & Methods | Dependencies | Status / Evaluation |
|---|---|---|---|---|---|
| `test/widget_test.dart` | 376 | Default template test checking a dummy `MaterialApp`. | `main()` | `flutter_test` | **Deficient**: Does not test any application widget. |
| `test/core/utils/money_calculator_test.dart` | 1,446 | Unit tests for static calculation methods in `MoneyCalculator`. | Line total, subtotal, tax, order total, profit tests | `flutter_test`, `money_calculator.dart` | **Passing & Useful**: Accurately verifies money calculation logic. |
| `test/data/repositories/stock_logic_test.dart` | 2,467 | Unit tests verifying mathematical stock adjustments. | `applyStockMovementQty()`, `applySaleStockQty()` | `flutter_test` | **Isolated**: Tests local helper functions inside the test file; does not test Drift or repositories. |

