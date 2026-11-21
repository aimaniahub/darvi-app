# DARVI BILLING — PRODUCTION DEPLOYMENT & OPERATIONS MANUAL

**Target Entity:** Darvi Group Agri Tech  
**Registered Office:** #2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030  
**Contact Phone:** 9986890777  
**GSTIN:** 29BKZPA0053M1ZQ  
**Application:** Darvi Billing v1.0.0 (Production Candidate)  
**Release Artifact:** `build\app\outputs\flutter-apk\app-release.apk` (SHA-256: `9EE319DC45F6696E0F47078D6BA20C5FDB874C7875209F59EBF1E7990E79BC78`)  
**Deployment Date:** 2026-11-07  

---

## 1. System Requirements & Hardware Prerequisites

### 1.1 Target POS Device
- **Operating System:** Android 8.0 (Oreo / API Level 26) through Android 14 (API Level 34)
- **Form Factor:** Android Tablet (10-inch recommended for counter POS) or Smartphone (minimum 5.5-inch)
- **RAM:** 3 GB minimum (4 GB+ recommended)
- **Storage:** Minimum 500 MB free internal flash storage for SQLite database and invoice PDF caching
- **Connectivity:** Bluetooth 4.0+ (for SSEZNIK2POS thermal receipt printer) and Wi-Fi / Cellular data (optional, for cloud backup)

### 1.2 Thermal Printer
- **Model:** SSEZNIK2POS (or compatible 58mm ESC/POS Bluetooth thermal printer)
- **Paper Roll:** 58mm × 40mm / 50mm thermal paper roll

---

## 2. Installation & Initial Setup Instructions

### 2.1 Installing the Production APK

#### Option A: Direct Installation via Android USB Cable (Recommended for Store IT)
1. Enable **Developer Options** and **USB Debugging** on the target Android tablet.
2. Connect the Android tablet to the computer via USB.
3. Open terminal and run:
   ```powershell
   adb install -r "D:\Mini-POS-Inventory-Flutter-main\Mini-POS-Inventory-Flutter-main\build\app\outputs\flutter-apk\app-release.apk"
   ```
4. Verify application icon **Darvi Billing** appears on the tablet home screen.

#### Option B: Direct Side-loading via USB Flash Drive / SD Card
1. Copy `app-release.apk` to a USB drive or microSD card.
2. Insert drive into Android tablet via OTG adapter.
3. Open Android **Files** app, tap `app-release.apk`, allow **Install Unknown Apps**, and tap **Install**.

---

## 3. First-Launch Configuration & Seed Data Verification

When the application launches for the first time, it automatically initializes the SQLite database (Schema Version 3) and executes `SeedData.initializeDarviDefaults`:

### 3.1 Primary Business Identity
- **Business Name:** `Darvi Group Agri Tech`
- **GSTIN:** `29BKZPA0053M1ZQ`
- **Address:** `#2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030`
- **Phone:** `9986890777`
- **Currency:** `INR (₹)`
- **Receipt Slogan:** `Improving Agriculture, Improving lives.`
- **Receipt Footer:** `Goods once sold will not be taken back or exchanged.\nNo cash payments accepted.`

### 3.2 Pre-seeded Financial Accounts
- **Account 1:** `Store Cash Drawer` (Type: `cash`)
- **Account 2:** `Company Bank Account` (Type: `bank`)
- **Account 3:** `Store UPI Account` (Type: `upi`, Default POS Account)

### 3.3 Default Staff Accounts & Login Credentials
| Employee Name | Employee Code | Designation | Role Tier | Default Login PIN |
|---|---|---|---|:---:|
| **Suresh Totad** | `EMP001` | Managing Director | `admin` | `9988` |
| **Manjunath Patil** | `EMP002` | Store Manager | `manager` | `5544` |
| **Priya Sharma** | `EMP003` | Frontline Cashier | `cashier` | `1122` |

> [!IMPORTANT]
> Immediately upon first login, the Managing Director should navigate to **Settings -> Team Profiles** and update all employee login PINs.

---

## 4. SSEZNIK2POS Bluetooth Printer Setup

1. Turn on the SSEZNIK2POS printer.
2. On the Android tablet, go to **Settings -> Connected Devices -> Pair New Device**.
3. Select **SSEZNIK2POS** (or `POS-58`). Enter pairing PIN `0000` or `1234` if prompted.
4. Open **Darvi Billing**, log in, and tap the settings or printer icon on the POS checkout screen.
5. Select the paired printer from the list. The app will maintain connection via the native RFCOMM socket bridge.

---

## 5. Daily Store Operational Workflows

### 5.1 Morning Opening Routine
1. The Store Manager logs in (`EMP002`).
2. Navigate to **Team -> Attendance** and clock in staff members.
3. Navigate to **Financials -> Cashbook** to verify opening cash drawer balance.

### 5.2 Billing & Point of Sale (POS)
1. Cashier logs in (`EMP003`).
2. Search products by typing name, selecting category, or scanning barcode with the tablet camera or handheld laser scanner.
3. Tap items to add to cart.
4. Select customer from directory (or leave blank for Walk-in Retail).
5. Tap **Charge**, select payment mode (**Store UPI Account** is default), enter collected amount, and confirm payment.
6. Tap **Print Thermal Receipt** to generate the 58mm thermal receipt on the SSEZNIK2POS printer.

### 5.3 Inward Shipments (Stock Inward)
1. Store Manager navigates to **Purchases**.
2. Tap **+ Inward Bill**.
3. Select Supplier (or create new supplier with GSTIN).
4. Enter supplier invoice number and add line items with batch number, expiry date, purchase cost, and GST rate.
5. Save bill. Inventory and supplier ledger balances update atomically.

### 5.4 Evening Store Closing Routine
1. Store Manager navigates to **Financials -> Cashbook**.
2. Compare physical cash in drawer against the Cashbook report.
3. Run Day-End Reconciliation and export daily report.
4. Back up database: Tap **Settings -> Backup Database** and save the encrypted SQLite file to Google Drive or external USB drive.

---

## 6. Database Backup & Disaster Recovery

### 6.1 Automated Backup File Location
The live SQLite database is stored at:
`/data/data/com.example.mini_pos/databases/darvi_billing.db`

### 6.2 Manual Backup Procedure
- Tap **Settings -> Backup Database**.
- The system generates a timestamped snapshot: `darvi_backup_YYYYMMDD_HHMMSS.db`.
- Share or copy this snapshot to secondary off-device storage.

### 6.3 Disaster Recovery / Tablet Replacement
1. Install `app-release.apk` on replacement tablet.
2. Before launching, copy `darvi_backup_*.db` into `/data/data/com.example.mini_pos/databases/darvi_billing.db`.
3. Launch app. All customers, products, ledger entries, and historical invoices will be restored intact.

