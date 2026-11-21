# Darvi Billing & Vikshha CRM

> **Enterprise POS Billing, Inventory, Accounting & Farmland Real Estate CRM**  
> Built with Flutter 3.x using **BLoC/Cubit**, **Feature-First Clean Architecture**, and **Drift (Offline-First SQLite)**.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Modules & Capabilities](#key-modules--capabilities)
   - [1. POS Billing & Printing](#1-pos-billing--printing)
   - [2. Inventory & Product Management](#2-inventory--product-management)
   - [3. Purchases & Supplier Management](#3-purchases--supplier-management)
   - [4. Double-Entry Accounting & Financials](#4-double-entry-accounting--financials)
   - [5. HR, Attendance, Payroll & Incentives](#5-hr-attendance-payroll--incentives)
   - [6. Vikshha CRM & Farmland Management](#6-vikshha-crm--farmland-management)
   - [7. Reports & Analytics](#7-reports--analytics)
   - [8. Access Control & Security](#8-access-control--security)
3. [Architecture & Technology Stack](#architecture--technology-stack)
4. [Project Structure](#project-structure)
5. [Getting Started](#getting-started)
   - [Prerequisites](#prerequisites)
   - [Setup & Run](#setup--run)
   - [Default Credentials](#default-credentials)
6. [Hardware & Thermal Printing](#hardware--thermal-printing)
7. [Testing & Quality Assurance](#testing--quality-assurance)
8. [Building for Production](#building-for-production)
9. [Documentation](#documentation)
10. [License](#license)

---

## Overview

**Darvi Billing & Vikshha CRM** is a production-grade, offline-first enterprise management suite designed for retail operations, wholesale distribution, agricultural supply, and farmland project management.

### Core Principles
- **Offline-First & Resilient**: Complete database operations execute locally via SQLite (Drift) with ACID transaction guarantees.
- **Enterprise Accounting**: Automated double-entry ledger bookings for every sale, purchase, payment, return, and expense.
- **Zomato-Style UX**: Rapid math steppers (`[-] qty [+]`), compact responsive UI, and persistent cross-module global navigation.
- **Universal Hardware Support**: Seamless ESC/POS thermal printing (58mm/80mm) via the Cleanter companion app and Android System Spooler with automated fallback.

---

## Key Modules & Capabilities

### 1. POS Billing & Printing
- **Fast Cart Manipulation**: Zomato-style math counter on products (`[-] 2 [+]` & `ADD +`), search by name, SKU, or barcode.
- **Split & Multi-Account Payments**: Cash, UPI, Card, Net Banking, and Customer Credit with credit limit exposure checks.
- **Bill Parking / Hold Bills**: Park active carts, switch transactions, and resume seamlessly.
- **Thermal Receipt Printing**: SSEZNIK2POS 58mm / 80mm thermal receipts with 32-column character formatting, business details, GSTIN, itemized taxes, and tear spacers.
- **A4 PDF Invoicing**: Instant GST Tax Invoices formatted for A4 printing and multi-channel PDF sharing.

### 2. Inventory & Product Management
- **Catalog Management**: Multi-category products, SKU, barcode, unit measurements, cost price, selling price, and reorder thresholds.
- **Batch & Expiry Tracking**: FEFO (First-Expired-First-Out) and FIFO rules, batch assignment during sales and purchase inwarding.
- **Stock Movements**: Audited stock movements across Purchases, Sales, Customer Returns, Supplier Returns, and Damaged Goods adjustments.

### 3. Purchases & Supplier Management
- **Supplier Inwarding**: Multi-item purchase invoices updating stock balance, average unit costs, and supplier payables ledger.
- **Purchase Returns**: Supplier debit notes with automatic inventory deduction and ledger reversal.
- **Outstanding Payables**: Real-time tracking of pending supplier dues with settlement workflows.

### 4. Double-Entry Accounting & Financials
- **Automated Bookkeeping**: System accounts for Cash Drawer, Bank/UPI Accounts, Sales Revenue, Inventory Asset, Accounts Receivable, Accounts Payable, and Taxes (CGST/SGST/IGST).
- **Core Financial Views**: General Ledger, Trial Balance, Cashbook, and Profit & Loss statement.

### 5. HR, Attendance, Payroll & Incentives
- **Staff Directory**: Role assignment, contact profiles, base salary, and commission tier configuration.
- **Daily Attendance**: Present / Absent / Half-day status tracking with monthly summaries.
- **Payroll**: Automated payslip generation computing basic pay, attendance deductions, and approved incentive bonuses.
- **Sales Incentives**: Automated incentive claim generation based on sales volume, with return-adjustment protection against overpayment.

### 6. Vikshha CRM & Farmland Management
- **Farmland Projects**: Project portfolio, acreages, survey numbers, boundary coordinates, and development stages.
- **Plot Inventory**: Detailed plot mapping (Area in sq ft / guntas, dimension, facing, unit pricing, total price).
- **Plot Status Lifecycle**: Available → Reserved → Booked → Registered/Sold.
- **Lead & Enquiry Pipeline**: Source tracking (Website, Referral, Walk-in, Social), pipeline stages, and priority tagging.
- **Follow-up Reminders**: Activity schedule, notes, and call-back tracking.
- **Site Visits**: Visit scheduling, driver/vehicle assignments, customer feedback, and conversion workflows.
- **Quotations & Payment Plans**: Custom project quotations, down payments, and installment schedule calculation.
- **Bookings & Agreements**: Formal booking generation, document registration tracking, and legal agreement history.

### 7. Reports & Analytics
- **Executive Dashboard**: KPI metrics for revenue, gross margin, purchases, net profit, cash flow, receivables, and payables.
- **Sales & Purchase Analytics**: Period-based breakdown, product-wise sales, category metrics, and cashier contributions.
- **Tax Reports**: GST GSTR-1 & GSTR-3B taxable value, CGST, SGST, and IGST breakdowns.
- **Export Formats**: PDF executive reports and CSV data exports.

### 8. Access Control & Security
- **Role-Based Access Control (RBAC)**: Fine-grained permissions for Admin, Manager, Cashier, and Accountant.
- **Authentication**: Local PIN authentication for fast cashier switching, and password authentication for administrators.
- **Data Isolation**: Workspaces and transactions guarded against concurrency and unauthorized mutation.

---

## Architecture & Technology Stack

```
lib/
├── app/                  # App initialization, routing, theme, dependencies, scope
│   ├── router/           # GoRouter route declarations & navigation shell
│   ├── theme/            # Material 3 design tokens, typography, radii, colors
│   └── app_scope.dart    # InheritedWidget dependency injection scope
├── core/                 # Shared domain models, utilities, errors, services
│   ├── errors/           # Custom AppExceptions & failure models
│   ├── models/           # Shared models (CartItem, GstBreakdown, etc.)
│   ├── services/         # ESC/POS generator, PDF generator, ThermalPrinterService
│   ├── utils/            # MoneyCalculator, formatters, sanitizers
│   └── widgets/          # GlobalAppHeader, AppButton, AppCard, AppModal, etc.
├── data/                 # Local persistence layer
│   └── local/
│       ├── db/           # Drift SQLite database, schema, queries, migrations
│       └── seed/         # Initial demo seed data & accounts
├── domain/               # Domain contracts
│   ├── entities/         # Immutable business entities
│   └── repositories/     # Repository interfaces
└── features/             # Feature-first presentation & business logic
    ├── auth/             # Login, PIN switch, session cubit
    ├── bookings/         # Farmland plot bookings & agreements
    ├── crm/              # Vikshha leads, follow-ups & site visits
    ├── dashboard/        # Executive analytics dashboard
    ├── deliveries/       # Order delivery dispatch & proof of delivery
    ├── employees/        # HR staff, attendance & payroll
    ├── financials/       # Accounts, cashbook, general ledger, P&L
    ├── invoices/         # Invoice history, search & credit notes
    ├── parties/          # Customers & suppliers management
    ├── plots/            # Project plots catalog & unit dimensions
    ├── pos/              # Billing workspace, cart, checkout & printing
    ├── products/         # Product catalog & stock adjustments
    ├── purchases/        # Purchase orders & vendor invoices
    ├── quotations/       # Project & plot quotation proposals
    ├── reports/          # Analytics reports generator
    ├── settings/         # Store preferences, printer setup & users
    └── shell/            # App shell with bottom navigation & drawer
```

| Component | Technology |
|:---|:---|
| **Framework** | Flutter 3.x (Dart 3.x, Material 3, sound null-safety) |
| **State Management** | `flutter_bloc` / `cubit` pattern |
| **Local Persistence** | `drift` ^2.21 + `sqlite3_flutter_libs` |
| **Routing** | `go_router` ^17 (ShellRoute + deep linking) |
| **Thermal Printing** | ESC/POS Binary Protocol + Cleanter HTTP REST Service |
| **PDF Generation** | `pdf` + `printing` |
| **Icons** | `tabler_icons_plus` |
| **Data Formatting** | `intl`, `csv` |

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.24.0` or higher
- Dart SDK `^3.5.0` or higher
- Android Studio / VS Code with Flutter extension
- Android SDK 34+ (for Android builds)

### Setup & Run
```bash
# 1. Clone the repository
git clone https://github.com/aimaniahub/darvi-app.git
cd darvi-app

# 2. Install dependencies
flutter pub get

# 3. Analyze code quality
dart analyze lib/

# 4. Run test suite
flutter test

# 5. Run the application
flutter run
```

### Default Credentials
| Role | User Identifier | Default Password / PIN |
|:---|:---|:---|
| **Admin** | `admin` | `admin123` |
| **Cashier PIN** | Quick switch | `1234` |

---

## Hardware & Thermal Printing

Darvi Billing supports dual-mode thermal printing:

1. **Cleanter Companion App Mode (Recommended)**:
   - Connects to the Cleanter (`Thermal Printer BT`) local server via `http://127.0.0.1:9100/print`.
   - Sends structured receipt JSON and direct ESC/POS byte buffers.
   - Automatically cuts paper and prints store header, items, tax breakdown, and footer.
2. **Android System Print Spooler Mode**:
   - Universal printing to any Wi-Fi, USB, Bluetooth, or Cloud printer registered in Android's Print Services.
   - Operates with zero configuration if Cleanter is not installed.

---

## Testing & Quality Assurance

Darvi features an automated test suite with **190 tests** verifying financial calculations, POS cart operations, inventory decrement rules, database backup/restore cycles, and farmland plot lifecycles.

```bash
# Execute all unit, cubit, and widget tests
flutter test
```

---

## Building for Production

### Android Release APK
```bash
flutter build apk --release
```
The compiled APK will be output to:
`build/app/outputs/flutter-apk/app-release.apk`

---

## Documentation

Full architectural audits, database schemas, and release acceptance reports are maintained in the [`docs/`](docs/) directory:
- [`docs/reports/`](docs/reports/): Complete sprint audit reports and integration validation history.
- [`docs/darvi-audit/`](docs/darvi-audit/): Architectural specifications and database relationship matrices.
- [`docs/darvi-final-audit/`](docs/darvi-final-audit/): Release readiness and hardware verification reports.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
