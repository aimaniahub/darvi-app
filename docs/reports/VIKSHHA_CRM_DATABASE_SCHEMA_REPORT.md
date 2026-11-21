# VIKSHHA CRM & PLOT MANAGEMENT — DATABASE SCHEMA REPORT

**Application:** Darvi Billing Flutter Application  
**Database Engine:** SQLite (via Drift ORM & Native SQLite Drivers)  
**Schema Version:** 4 (Extended with Non-Destructive Migrations)  

---

## 1. NEW DEDICATED TABLES CREATED

### A. Table: `crm_follow_ups`
Tracks all scheduled, completed, and overdue follow-up interactions across leads and customers.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Unique Follow-up identifier |
| `workspace_id` | `INTEGER` | `NOT NULL DEFAULT 1` | Workspace tenant isolation |
| `lead_id` | `INTEGER` | `REFERENCES leads(id) ON DELETE CASCADE` | Associated CRM Lead |
| `customer_id` | `INTEGER` | `REFERENCES customers(id) ON DELETE SET NULL` | Associated Customer |
| `employee_id` | `INTEGER` | `REFERENCES employees(id) ON DELETE SET NULL` | Assigned Sales Executive |
| `scheduled_date`| `INTEGER` | `NOT NULL` | Scheduled timestamp in Unix milliseconds |
| `status` | `TEXT` | `NOT NULL DEFAULT 'pending'` | Status (`pending`, `completed`, `missed`, `rescheduled`) |
| `remarks` | `TEXT` | `NULLABLE` | Follow-up discussion notes or purpose |
| `created_at` | `INTEGER` | `NOT NULL` | Record creation timestamp |
| `completed_at` | `INTEGER` | `NULLABLE` | Completion timestamp |

### B. Table: `crm_documents`
Polymorphic document repository storing agreements, title deeds, layout maps, and customer KYC proofs.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Unique Document identifier |
| `workspace_id` | `INTEGER` | `NOT NULL DEFAULT 1` | Workspace tenant isolation |
| `entity_type` | `TEXT` | `NOT NULL` | Target entity (`project`, `plot`, `lead`, `customer`, `booking`) |
| `entity_id` | `INTEGER` | `NOT NULL` | Associated entity primary key ID |
| `document_type` | `TEXT` | `NOT NULL` | Type (`blueprint`, `agreement`, `kyc`, `tax_receipt`, `other`) |
| `title` | `TEXT` | `NOT NULL` | Document title |
| `file_path` | `TEXT` | `NOT NULL` | Local storage file path |
| `file_size` | `INTEGER` | `NOT NULL DEFAULT 0` | File size in bytes |
| `status` | `TEXT` | `NOT NULL DEFAULT 'active'` | Document lifecycle status |
| `uploaded_by` | `INTEGER` | `REFERENCES employees(id) ON DELETE SET NULL` | Uploading employee ID |
| `created_at` | `INTEGER` | `NOT NULL` | Upload timestamp |

---

## 2. NON-DESTRUCTIVE COLUMN EXPANSIONS

The following columns were expanded into existing database tables safely via `ensureVikshhaCrmSchemaTables()`:

### A. Table: `leads`
- `alternate_phone TEXT`: Secondary contact number for investor.
- `address TEXT`: Full street / residential address.
- `city TEXT`: City name.
- `district TEXT`: District / state information.
- `priority TEXT NOT NULL DEFAULT 'medium'`: Lead priority (`low`, `medium`, `high`, `urgent`).
- `interested_plot_size TEXT`: Preferred plot size (e.g., `2400 sq ft`, `0.5 acre`).

### B. Table: `projects`
- `amenities TEXT`: Layout amenities (solar fencing, drip irrigation, asphalt roads, clubhouse).
- `legal_status TEXT DEFAULT 'clear_title'`: Title classification (`clear_title`, `under_process`, `na_converted`).
- `address TEXT`: Physical site location and survey numbers.
- `gpsCoordinates TEXT`: GPS coordinates for site navigation.

### C. Table: `plots`
- `facing TEXT DEFAULT 'East'`: Vastu / plot facing orientation (`East`, `North`, `West`, `South`, `North-East`).
- `price_per_sq_ft REAL DEFAULT 0.0`: Normalized unit rate per square foot.

### D. Table: `plot_bookings`
- `reservation_amount REAL DEFAULT 0.0`: Advance token amount for temporary reservation.
- `reservation_expiry INTEGER`: Timestamp when temporary reservation expires.
- `discount REAL DEFAULT 0.0`: Commercial discount applied to booking.
- `agreement_status TEXT DEFAULT 'draft'`: Agreement status (`draft`, `signed`, `registered`).

---

## 3. DATA INTEGRITY & MIGRATION SAFETY
1. **Foreign Key Enforcement:** `PRAGMA foreign_keys = ON;` is enforced on every database connection.
2. **Backward Compatibility:** All new tables use `CREATE TABLE IF NOT EXISTS`, and column additions catch schema collision exceptions gracefully.
3. **Data Type Normalization:** Dates and timestamps use standard Unix millisecond integers to avoid string parse exceptions across mobile, desktop, and test runners.

