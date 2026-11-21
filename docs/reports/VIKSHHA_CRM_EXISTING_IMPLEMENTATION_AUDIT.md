# VIKSHHA CRM & PLOT MANAGEMENT — EXISTING IMPLEMENTATION AUDIT

**Audit Date:** November 9, 2026  
**Auditor / Agent:** Antigravity System Architect  
**Scope:** Full codebase audit of Vikshha CRM, Farmland Projects, Plot Inventory, Site Visits, Bookings, Agreements, and Financial Integrations.

---

## 1. EXECUTIVE AUDIT SUMMARY

The Darvi Billing application contains preliminary UI scaffolding and basic Drift SQLite tables for Farmland Plot Management and CRM (`Leads`, `Plots`, `Projects`, `SiteVisits`, `PlotBookings`, `BookingInstallments`). However, critical enterprise features remain disconnected, partially implemented, or lack end-to-end business workflows.

### Screen & Feature Implementation Matrix

| Screen / Feature | Route / Component | Classification | Current Gaps & Missing Logic |
|---|---|---|---|
| **Leads & Enquiries Listing** | `/crm` (`CrmPage`) | **Partially implemented** | Missing follow-up reminders, overdue indicators, duplicate phone detection, employee and source filters, priority tagging. |
| **Lead Details & Activity Timeline** | `LeadDetailSheet` | **Partially implemented** | Logs stage changes and generic notes, but lacks dedicated follow-up completion/rescheduling, document attachments, and booking history. |
| **Follow-up Management** | Embedded in `/crm` | **UI implemented but business logic missing** | No dedicated follow-up list, no completion/missed markers, no overdue alerts. |
| **Farmland Projects** | `/plots` (`PlotsPage`, `ProjectEditorDialog`) | **Partially implemented** | Total plot counts are entered manually rather than calculated dynamically from plot inventory; no project document or image gallery. |
| **Plot Inventory & Grid** | `/plots` (`PlotsPage`, `PlotEditorDialog`) | **Partially implemented** | Basic plot CRUD exists; missing size/price filters, facing directions, and enquiry link views. |
| **Plot Details** | `PlotDetailSheet` | **Partially implemented** | Shows plot details and navigates to booking; missing historical reservations, payment progress, and linked enquiries. |
| **Site Visits** | `SiteVisitDialog` | **Partially implemented** | Can schedule visits; lacks completion outcome recording, rescheduling, and dedicated visit calendar/listing. |
| **Customer Conversion** | `CrmRepository.convertLeadToCustomer` | **Partially implemented** | Basic customer record creation; lacks employee reassignment and unified CRM customer profile with plot holdings. |
| **Customer CRM Profile** | `/parties` customer detail | **Not implemented** | Shows general billing/invoicing; does not display customer plot reservations, installment schedules, or land agreements. |
| **Plot Reservations** | `/bookings` | **Not implemented** | Only direct booking exists; no temporary reservation with token advance, expiry date, or auto-release on lapse. |
| **Plot Bookings** | `/bookings` (`BookingsPage`, `BookingEditorDialog`) | **Partially implemented** | Basic booking creation exists; lacks discount handling, agreement tracking, commission attribution, and cancellation refunds. |
| **Booking Details & History** | `BookingDetailSheet` | **Partially implemented** | Shows basic installment list; missing document uploads, agreement status, and payment receipt printout. |
| **Payments & Installments** | `BookingInstallments` in `BookingDetailSheet` | **Partially implemented** | Allows marking installment paid; missing double-entry ledger posting for subsequent installments and formal payment receipts. |
| **Agreements & Documents** | None | **Not implemented** | No table or UI for tracking agreement drafting, signing, legal status, or uploading KYC and land registry documents. |
| **Sales Employee Commission** | None | **Not implemented** | Farmland bookings do not automatically generate `IncentiveClaims` for assigned sales agents. |
| **CRM Dashboard & Analytics** | None | **Not implemented** | No dedicated CRM KPI overview (conversion rates, plot occupancy, pending collections, overdue installments). |

---

## 2. DATABASE SCHEMA AUDIT & DEFICIENCIES

### 2.1 Existing Tables
- `projects`: Basic columns (`name`, `code`, `location`, `total_area`, `total_plots`, `description`, `status`). Missing: amenities, legal status, address, GPS coordinates.
- `plots`: Basic columns (`project_id`, `plot_number`, `unique_plot_id`, `dimensions`, `area_sq_ft`, `survey_number`, `status`, `base_price`, `total_price`, `crop_type`, `plantation_details`). Missing: `facing`, `price_per_unit`.
- `leads`: Basic columns (`name`, `phone`, `email`, `source`, `interested_project_id`, `budget`, `stage`, `assigned_employee_id`, `next_follow_up_date`, `notes`). Missing: `alternate_phone`, `address`, `city`, `priority`.
- `site_visits`: Scheduled visits with feedback and basic status. Missing: `meeting_location`, `outcome_notes`.
- `lead_activities`: Basic activity logging (`activity_type`, `notes`).
- `plot_bookings`: Booking records. Missing: `reservation_expiry`, `discount`, `agreement_status`.
- `booking_installments`: Installment schedule with paid amount.

### 2.2 Missing Tables Needed for Full Enterprise Capabilities
1. `crm_follow_ups`: First-class follow-up tracking with scheduled dates, status (`pending`, `completed`, `missed`, `rescheduled`), remarks, and reminders.
2. `crm_documents`: Document tracking for KYC, land deeds, plot agreements, and payment slips associated with projects, plots, leads, or bookings.
3. `plot_reservations`: Dedicated pre-booking reservation records with token deposit, expiry threshold, and conversion lifecycle.

---

## 3. WORKFLOW INTEGRATION GAPS

1. **Lead $\to$ Customer $\to$ Booking Continuity:**
   When a lead is converted, the customer record is created, but subsequent plot bookings do not consistently propagate employee attribution back to the incentive commission engine.
2. **Double-Entry Financial Accounting:**
   The initial booking advance posts a ledger entry, but subsequent installment collections do not invoke `LedgerRepository.postTransaction`, creating an accounting discrepancy between booking payments and cash/bank balances.
3. **Inventory Source of Truth:**
   Project cards currently show static numbers from `projects.total_plots` rather than dynamically aggregating `available`, `reserved`, `booked`, and `sold` counts directly from `plots`.
4. **Workspace Partitioning:**
   While `workspace_id` is present on existing tables, certain joins and dropdown queries omit strict `workspace_id` filtering.

---

## 4. PHASED IMPLEMENTATION PLAN (3 MODULES PER GROUP)

In strict adherence to instructions, implementation will proceed in 6 controlled groups:

- **Group 1:**
  1. Leads & Enquiries (CRUD, filters, priority, duplicate prevention).
  2. Follow-ups (first-class follow-up tracking, reminders, overdue indicators).
  3. Lead Details & Activity Timeline (comprehensive profile, history, action shortcuts).
- **Group 2:**
  1. Project Management (rich details, dynamic inventory stats, legal status).
  2. Plot Inventory (facing, pricing per unit, size/price filters).
  3. Plot Details (enquiries, reservations, payment history).
- **Group 3:**
  1. Site Visits (scheduling, calendar, outcome recording, follow-up generation).
  2. Customer Conversion (seamless conversion, phone dedup, employee assignment).
  3. Customer CRM Profile (unified customer view of plots, bookings, installments).
- **Group 4:**
  1. Plot Reservations (token advance, expiry date, cancel/release).
  2. Booking Management (discount, unique number, atomic plot state change).
  3. Booking Details & History (milestones, installment timeline, audit log).
- **Group 5:**
  1. Payments (advance, down payment, settlement, reversal).
  2. Installments (due dates, partial payments, overdue status).
  3. Receipts & Payment Statements (PDF/print receipt, customer statement).
- **Group 6:**
  1. Agreements & Documents (document repository, agreement statuses).
  2. Sales Employee Assignment & Commission (booking attribution, incentive claim integration).
  3. CRM Dashboard & Reports (KPI metrics, funnel conversion, plot inventory reports).

