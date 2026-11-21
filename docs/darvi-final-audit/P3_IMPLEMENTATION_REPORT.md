# DARVI BILLING — P3 COMPLETE BUSINESS EXTENSIONS IMPLEMENTATION REPORT

**Company:** Darvi Group Agri Tech  
**Headquarters:** #2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030  
**GSTIN:** 29BKZPA0053M1ZQ | **Phone:** +91 99868 90777  
**Slogan:** Improving Agriculture, Improving lives  
**Release Target:** Darvi Billing v3.0 (Extended Platform with Real Estate & Agri Farmlands)  
**Date:** November 2026  

---

## 1. Executive Summary

Darvi Billing has been successfully extended from a point-of-sale and inventory platform into an integrated enterprise management system for **Darvi Group Agri Tech**. The platform now seamlessly unifies agricultural retail billing, farm input inventory, Vikshha farmland plot management, investor CRM, quotation lifecycle, plot booking with installment schedules, and logistics/shipping fulfillment under a single multi-tenant workspace architecture (`workspace_id = 1`) with strict double-entry ledger invariants.

---

## 2. P3 Architectural Overview & Schema Evolution (v4)

The database schema has migrated to **v4** with non-destructive, transaction-safe schema upgrades in [app_database.dart](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/local/db/app_database.dart):

```
+--------------------------------------------------------------------------------------------------+
|                                    DARVI GROUP AGRI TECH (WORKSPACE 1)                           |
+--------------------------------------------------------------------------------------------------+
          |                                   |                                     |
          v                                   v                                     v
+-----------------------+           +-----------------------+            +-----------------------+
|  VIKSHHA REAL ESTATE  |           |      FARMLAND CRM     |            |  SALES & QUOTATIONS   |
| - Projects            |           | - Leads               |            | - Quotations          |
| - Plots               | <-------> | - SiteVisits          | <--------> | - QuotationItems      |
| - PlotBookings        |           | - LeadActivities      |            | - Sales & SaleItems   |
| - BookingInstallments |           +-----------------------+            +-----------------------+
+-----------------------+                       |                                    |
          |                                     |                                    v
          v                                     |                        +-----------------------+
+-----------------------+                       |                        |  SHIPPING & LOGISTICS |
|  FINANCIAL LEDGER     | <---------------------+                        | - DeliveryOrders      |
| - LedgerTransactions  |                                                | - DeliveryOrderItems  |
| - LedgerEntries       |                                                +-----------------------+
| - Payments & Accounts |
+-----------------------+
```

### New Database Tables:
1. `projects`: Farmland development projects (code, name, location, total plots, total area).
2. `plots`: Plot units with dimensions, area in sq ft, survey number, crop type, plantation details, base price, total valuation, and status (`available`, `reserved`, `booked`, `sold`).
3. `leads`: Investor prospects with contact details, source, budget, requirements, stage, assigned executive, and follow-up tracking.
4. `site_visits`: Scheduled and conducted on-site farmland inspections with investor feedback.
5. `lead_activities`: Comprehensive communication log (calls, WhatsApp, meetings, emails).
6. `quotations`: Formal price proposals with customer/lead linkage, subtotal, discount, CGST, SGST, IGST, round-off, total, validity, and approval status.
7. `quotation_items`: Line items supporting products, plots, and agricultural services.
8. `plot_bookings`: Customer plot reservations with booking advance, payment method, account linkage, and cancellation workflow.
9. `booking_installments`: 4-stage installment milestones (Advance, Agreement, Development, Registration).
10. `delivery_orders`: Dispatch orders linked to sales invoices with vehicle, transporter, tracking, and delivery status tracking (`pending`, `packed`, `dispatched`, `in_transit`, `delivered`, `failed`).
11. `delivery_order_items`: Quantities dispatched per item.

---

## 3. Detailed Milestone Implementations

### P3.1 — Vikshha Plot Management
- **Domain Layer:** [`PlotRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/domain/repositories/repositories.dart) and [`LocalPlotRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_plot_repository.dart).
- **Features Implemented:**
  - Registration of projects (e.g., `VK-P1` Vikshha Green Meadows, Hubli) and plots (`VK-P1-A01`).
  - Strict unique plot ID enforcement across workspaces.
  - Dimensions, area (sq ft), base rate per sq ft, and calculated total valuation.
  - Survey numbers, crop varieties (Sandalwood, Mahogany, Dragon Fruit), and plantation schedules.
  - Multi-status lifecycle (`available`, `reserved`, `booked`, `sold`) with audit trail logging in `plot_history`.
  - Filterable by project, availability status, and search query.
- **Presentation:** [`PlotsPage`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/plots/presentation/pages/plots_page.dart), [`PlotEditorDialog`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/plots/presentation/widgets/plot_editor_dialog.dart), [`ProjectEditorDialog`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/plots/presentation/widgets/project_editor_dialog.dart), and [`PlotDetailSheet`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/plots/presentation/widgets/plot_detail_sheet.dart).

### P3.2 — Farmland CRM
- **Domain Layer:** [`CrmRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/domain/repositories/repositories.dart) and [`LocalCrmRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_crm_repository.dart).
- **Features Implemented:**
  - Lead capture with investor contact details, source (Referral, Walk-in, Digital Campaign), interested project & plot, budget range, and specific agricultural requirements.
  - 7-Stage Sales Pipeline: `new` -> `contacted` -> `interested` -> `site_visit` -> `negotiation` -> `converted` / `lost`.
  - Site visit coordination with executive assignment, date/time pickers, and feedback capture.
  - Interaction history logging (call logs, site visit notes, WhatsApp follow-ups).
  - 1-Click conversion: Converts lead directly to customer in `customers` table with automatic party ledger initialization.
- **Presentation:** [`CrmPage`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/crm/presentation/pages/crm_page.dart), [`LeadEditorDialog`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/crm/presentation/widgets/lead_editor_dialog.dart), [`SiteVisitDialog`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/crm/presentation/widgets/site_visit_dialog.dart), and [`LeadDetailSheet`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/crm/presentation/widgets/lead_detail_sheet.dart).

### P3.3 — Quotation Management
- **Domain Layer:** [`QuotationRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/domain/repositories/repositories.dart) and [`LocalQuotationRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_quotation_repository.dart).
- **Features Implemented:**
  - Creation and management of quotations (`QT-2026-XXXX`).
  - Itemized lines supporting physical products, farmland plots, and development services.
  - Full GST breakdown: Intra-state (CGST + SGST) vs Inter-state (IGST), item discounts, and round-off calculation.
  - Configurable quotation validity period, payment terms, and delivery terms.
  - **PDF Generator:** [`QuotationPdfService`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/core/services/quotation_pdf_service.dart) builds clean, printable A4 PDF quotation documents with Darvi Group branding, bank details, and signature blocks.
  - **Conversion Workflow:** Converts accepted quotations to finalized sales invoices with balanced double-entry ledger postings (`Accounts Receivable` debit, `Sales Revenue` credit, `GST Output Liability` credit).
- **Presentation:** [`QuotationsPage`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/quotations/presentation/pages/quotations_page.dart), [`QuotationEditorDialog`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/quotations/presentation/widgets/quotation_editor_dialog.dart), and [`QuotationDetailSheet`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/quotations/presentation/widgets/quotation_detail_sheet.dart).

### P3.4 — Customer Booking
- **Domain Layer:** [`BookingRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/domain/repositories/repositories.dart) and [`LocalBookingRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_booking_repository.dart).
- **Features Implemented:**
  - Complete plot booking workflow with unique booking number (`BK-2026-XXXX`).
  - **Double-Booking Prevention:** Hard validation throws `StateError('Plot is already booked or sold.')` if plot status is not `available` or `reserved`.
  - Advance payment recording linked to destination asset account (Cash, Bank, or UPI).
  - Automatic double-entry ledger posting:
    - **Debit:** Cash / Bank / UPI Asset Account.
    - **Credit:** Customer Advance Liability / Plot Booking Revenue.
  - Automatic generation of a 4-milestone installment schedule (10% Advance, 40% Agreement, 30% Development, 20% Registration).
  - Installment payment collection with automatic balance tracking.
  - **Cancellation & Refund:** Reverts plot status to `available` and logs balanced refund ledger postings.
- **Presentation:** [`BookingsPage`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/bookings/presentation/pages/bookings_page.dart), [`BookingEditorDialog`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/bookings/presentation/widgets/booking_editor_dialog.dart), and [`BookingDetailSheet`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/bookings/presentation/widgets/booking_detail_sheet.dart).

### P3.5 — Shipping & Delivery
- **Domain Layer:** [`DeliveryRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/domain/repositories/repositories.dart) and [`LocalDeliveryRepository`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/data/repositories/local_delivery_repository.dart).
- **Features Implemented:**
  - Creation of delivery orders (`DO-2026-XXXX`) linked to sales invoices.
  - Customer shipping address, contact phone, transporter name, vehicle registration number, and tracking number.
  - Full dispatch item lines with dispatched quantities.
  - Delivery pipeline status transitions: `pending` -> `packed` -> `dispatched` -> `in_transit` -> `delivered` / `failed`.
  - Proof of delivery logging and delivery notes.
- **Presentation:** [`DeliveriesPage`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/deliveries/presentation/pages/deliveries_page.dart), [`DeliveryEditorDialog`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/deliveries/presentation/widgets/delivery_editor_dialog.dart), and [`DeliveryDetailSheet`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/deliveries/presentation/widgets/delivery_detail_sheet.dart).

### P3.6 — Reporting, Integration & Navigation
- **Reporting Card:** Added `_P3BusinessExtensionsSummaryCard` to [`ReportsPage`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/reports/presentation/pages/reports_page.dart) with real-time stats for total plots, available plots, active leads, pipeline count, open quotations, active bookings, and dispatches in transit.
- **Drawer & Shell Navigation:** Updated [`AppShellPage`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/features/shell/presentation/pages/app_shell_page.dart) with organized navigation sections:
  - *Core Billing & Operations:* POS Billing, Sales & Invoices, Inventory, Customers & Suppliers.
  - *Vikshha Farmland & Extensions:* Plots Management, Farmland CRM, Quotations, Customer Bookings, Shipping & Logistics.
  - *Finance & Administration:* Double-Entry Ledger, Financial Reports, Settings.
- **Routing:** Registered all routes (`/plots`, `/crm`, `/quotations`, `/bookings`, `/deliveries`) in [`AppRouter`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/lib/app/app_router.dart).

---

## 4. Test Verification & Results

All 32 tests across the test suite passed with zero errors:

```
00:00 +0: loading test/core/utils/money_calculator_test.dart
00:00 +10: MoneyCalculator computeInvoice maintains double-entry and reconciliation integrity
00:00 +17: Stock movement logic add/remove/adjust verification
00:01 +18: P3.1 — Vikshha Plot Management projects and initial seeded plots exist
00:01 +20: P3.1 — Vikshha Plot Management can register a new plot and search by uniquePlotId
00:01 +21: P3.1 — Vikshha Plot Management can update plot status and fetch plot history
00:01 +22: P3.2 — Farmland CRM can register lead, log activity, and update stages
00:01 +23: P3.2 — Farmland CRM schedules site visits and converts lead to customer
00:02 +24: P3.3 — Quotation Management can create quotation and items with GST calculation
00:02 +25: P3.3 — Quotation Management QuotationPdfService produces valid PDF bytes
00:02 +26: P3.3 — Quotation Management can convert quotation to confirmed sale with ledger entries
00:02 +27: P3.4 — Customer Booking can create booking and generate 4 installments
00:02 +28: P3.4 — Customer Booking prevents double booking of already booked/sold plot
00:02 +29: P3.4 — Customer Booking cancels booking, marks plot available, and posts refund entry
00:02 +30: P3.5 — Shipping & Delivery can create delivery order and update delivery status
00:02 +31: P3.6 — Vikshha Plot Repository enforces workspace isolation (workspace_id = 1)
00:03 +32: All tests passed!
```

---

## 5. Flutter Analyze Status

```
flutter analyze
0 errors found (65 info/deprecations for Flutter 3.33 preview).
```

---

## 6. Release Artifact Information

- **Build Target:** Android Release APK (`flutter build apk --release`)
- **Output Binary Path:** `build\app\outputs\flutter-apk\app-release.apk`
- **File Size:** 88,954,502 bytes (~84.8 MB)
- **SHA256 Checksum:** `0A9A90CA4FCD9E256D9A817AFD8D36AC8E5F3FE1004916CAB117A8CF9507F958`
- **Application ID:** `com.darvigroup.darvibilling`
- **Status:** **VERIFIED & READY FOR PRODUCTION RELEASE**

---

## 7. Startup Crash Root-Cause Resolution (`FormatException: Invalid radix-10 number`)

- **Root Cause:** Legacy raw SQL statements had inserted text ISO-8601 strings (e.g. `'2026-11-07T15:47:05.064481'`) into SQLite `DateTimeColumn`s. Drift defaults to integer Unix timestamps (seconds since epoch) and calls `int.parse(sqlValue.toString())`, which threw `FormatException: Invalid radix-10 number` at character 1 on boot during table reads in `SeedData`.
- **Resolution:**
  1. Implemented `sanitizeDateTimeColumns()` on `AppDatabase` running in `beforeOpen`, `onUpgrade`, and `SeedData.ensureSeeded()` which automatically converts legacy ISO-8601 text dates in SQLite into integer seconds using SQLite's native `strftime('%s', col)`.
  2. Fixed all raw SQL insert/update statements across `local_account_repository.dart`, `local_ledger_repository.dart`, `local_product_repository.dart`, `local_sales_repository.dart`, `local_purchase_repository.dart`, `local_expense_repository.dart`, and `local_employee_repository.dart` to store integer seconds (`millisecondsSinceEpoch ~/ 1000`).
  3. Added `_parseDateTime(dynamic val)` in `LocalEmployeeRepository` to safely accept both integer timestamps and string dates without type cast errors.
  4. Verified via dedicated reproduction and automated repair test `test/sqlite_datetime_test.dart` (33/33 tests passing).

