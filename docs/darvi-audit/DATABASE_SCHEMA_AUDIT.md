# QuickStock POS Source Code Audit: Database Schema & Drift ORM

**Document ID:** `docs/darvi-audit/DATABASE_SCHEMA_AUDIT.md`  
**Audit Date:** November 2026  
**Auditor:** Senior Database Architect & Software Auditor  

---

## 1. Schema Overview

The database is built on **Drift ORM** (`drift: ^2.21.0`) with SQLite via `sqlite3_flutter_libs`.  
The definition is located in `lib/data/local/db/app_database.dart`.

- **Database Class:** `AppDatabase` extends `_$AppDatabase`
- **Schema Version:** `2`
- **Tables Registered (9):**
  1. `Products`
  2. `Categories`
  3. `StockMovements`
  4. `Customers`
  5. `Suppliers`
  6. `Purchases`
  7. `Sales`
  8. `SaleItems`
  9. `AppSettings`
- **Database File:** `mini_pos_inventory.sqlite` in application documents directory.

---

## 2. Table-by-Table Schema Specification

### 1. `Products`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Unique product identifier |
| `name` | `TextColumn` | `TEXT` | NO | | Product title |
| `sku` | `TextColumn` | `TEXT` | NO | `UNIQUE` | Stock Keeping Unit |
| `barcode` | `TextColumn` | `TEXT` | YES | `UNIQUE` | EAN/UPC barcode |
| `categoryId` | `IntColumn` | `INTEGER` | YES | `REFERENCES Categories(id) ON DELETE SET NULL` | Category foreign key |
| `cost` | `RealColumn` | `REAL` | NO | | Purchase/cost price |
| `price` | `RealColumn` | `REAL` | NO | | Selling price |
| `stockQty` | `IntColumn` | `INTEGER` | NO | | Current inventory count |
| `lowStockThreshold`| `IntColumn`| `INTEGER`| NO | `DEFAULT 5` | Alert trigger level |
| `unit` | `TextColumn` | `TEXT` | NO | `DEFAULT 'piece'` | Measurement unit |
| `notes` | `TextColumn` | `TEXT` | YES | | Optional remarks |
| `imagePath` | `TextColumn` | `TEXT` | YES | Added in schema v2 | Local path or HTTP URL |
| `createdAt` | `DateTimeColumn`| `INTEGER`| NO | `DEFAULT CURRENT_TIMESTAMP` | Creation timestamp |
| `updatedAt` | `DateTimeColumn`| `INTEGER`| NO | `DEFAULT CURRENT_TIMESTAMP` | Last updated timestamp |

---

### 2. `Categories`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Unique category ID |
| `name` | `TextColumn` | `TEXT` | NO | `UNIQUE` | Category name |

---

### 3. `StockMovements`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Movement record ID |
| `productId` | `IntColumn` | `INTEGER` | NO | `REFERENCES Products(id) ON DELETE CASCADE` | Product FK |
| `type` | `TextColumn` | `TEXT` | NO | Values: add, remove, adjust, purchase, sale, return | Movement classification |
| `qtyChange` | `IntColumn` | `INTEGER` | NO | Can be positive or negative | Net change in quantity |
| `reason` | `TextColumn` | `TEXT` | YES | | Audit note / reference |
| `createdAt` | `DateTimeColumn`| `INTEGER`| NO | `DEFAULT CURRENT_TIMESTAMP` | Movement timestamp |

---

### 4. `Customers`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Customer ID |
| `name` | `TextColumn` | `TEXT` | NO | | Customer full name |
| `phone` | `TextColumn` | `TEXT` | YES | | Contact number |
| `notes` | `TextColumn` | `TEXT` | YES | | Address / notes |
| `balance` | `RealColumn` | `REAL` | NO | `DEFAULT 0.0` | Accumulated outstanding balance |

---

### 5. `Suppliers`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Supplier ID |
| `name` | `TextColumn` | `TEXT` | NO | | Vendor company/person name |
| `phone` | `TextColumn` | `TEXT` | YES | | Contact number |

---

### 6. `Purchases`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Purchase ID |
| `supplierId` | `IntColumn` | `INTEGER` | YES | `REFERENCES Suppliers(id) ON DELETE SET NULL` | Supplier FK |
| `productId` | `IntColumn` | `INTEGER` | NO | `REFERENCES Products(id) ON DELETE CASCADE` | Purchased Product FK |
| `qty` | `IntColumn` | `INTEGER` | NO | | Purchased quantity |
| `unitCost` | `RealColumn` | `REAL` | NO | | Inward unit cost |
| `notes` | `TextColumn` | `TEXT` | YES | | Memo / purchase notes |
| `createdAt` | `DateTimeColumn`| `INTEGER`| NO | `DEFAULT CURRENT_TIMESTAMP` | Purchase timestamp |

---

### 7. `Sales`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Sale ID |
| `invoiceNo` | `TextColumn` | `TEXT` | NO | `UNIQUE` | E.g., `INV-20261107-0001` |
| `createdAt` | `DateTimeColumn`| `INTEGER`| NO | `DEFAULT CURRENT_TIMESTAMP` | Sale completion time |
| `customerId` | `IntColumn` | `INTEGER` | YES | `REFERENCES Customers(id) ON DELETE SET NULL` | Optional Customer FK |
| `subtotal` | `RealColumn` | `REAL` | NO | | Net of item discounts |
| `discountTotal`| `RealColumn`| `REAL` | NO | | Item discount + Order discount |
| `taxTotal` | `RealColumn` | `REAL` | NO | | Tax amount charged |
| `total` | `RealColumn` | `REAL` | NO | | Final invoice total payable |
| `paid` | `RealColumn` | `REAL` | NO | | Amount tendered |
| `changeAmount` | `RealColumn`| `REAL` | NO | | Change returned to customer |
| `paymentMethod`| `TextColumn`| `TEXT` | NO | `cash`, `card`, `split` | Payment classification |
| `status` | `TextColumn` | `TEXT` | NO | `completed`, `returned` | Invoice lifecycle state |

---

### 8. `SaleItems`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY AUTOINCREMENT` | Line item ID |
| `saleId` | `IntColumn` | `INTEGER` | NO | `REFERENCES Sales(id) ON DELETE CASCADE` | Invoice parent FK |
| `productId` | `IntColumn` | `INTEGER` | NO | `REFERENCES Products(id) ON DELETE RESTRICT` | Product sold FK |
| `nameSnapshot`| `TextColumn`| `TEXT` | NO | | Immutable name at sale time |
| `costSnapshot`| `RealColumn`| `REAL` | NO | | Immutable cost at sale time |
| `priceSnapshot`| `RealColumn`| `REAL`| NO | | Immutable price at sale time |
| `qty` | `IntColumn` | `INTEGER` | NO | Negative for returns | Units sold |
| `discount` | `RealColumn` | `REAL` | NO | `DEFAULT 0.0` | Line item discount |
| `lineTotal` | `RealColumn` | `REAL` | NO | | Final line total |

---

### 9. `AppSettings`
| Column | Drift Type | SQL Type | Nullable | Constraints & Defaults | Description |
|---|---|---|---|---|---|
| `id` | `IntColumn` | `INTEGER` | NO | `PRIMARY KEY` (Always 1) | Single record constraint |
| `storeName` | `TextColumn` | `TEXT` | NO | `DEFAULT 'Mini Store'` | Store brand name |
| `currency` | `TextColumn` | `TEXT` | NO | `DEFAULT 'EGP'` | Store currency code |
| `taxEnabled` | `BoolColumn` | `INTEGER` | NO | `DEFAULT 0` | Tax calculation toggle |
| `taxRate` | `RealColumn` | `REAL` | NO | `DEFAULT 0.14` | Default tax percentage |
| `receiptHeader`| `TextColumn`| `TEXT` | NO | `DEFAULT 'Thank you!'` | Printed receipt header |
| `receiptFooter`| `TextColumn`| `TEXT` | NO | `DEFAULT 'Visit us again'`| Printed receipt footer |
| `language` | `TextColumn` | `TEXT` | NO | `DEFAULT 'en'` | Default UI language |
| `allowNegativeStock`| `BoolColumn`| `INTEGER`| NO | `DEFAULT 0` | Negative stock flag |
| `cashierPin` | `TextColumn` | `TEXT` | NO | `DEFAULT '1234'` | Cashier authentication PIN |
| `adminPassword`| `TextColumn`| `TEXT` | NO | `DEFAULT 'admin123'` | Admin password |

---

## 3. Migration Strategy Analysis

The existing migration implementation in `AppDatabase` (lines 196-203):
```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(products, products.imagePath);
    }
  },
);
```

### Critical Findings for Schema Migration:
1. **Clean Upgrade Pattern:** The existing `onUpgrade` hook is clean and functional. Bumping to `schemaVersion => 3` can execute incremental schema migrations without data loss.
2. **Use of Floating-Point (`RealColumn`):** Currency amounts are stored as SQLite `REAL` (floating-point IEEE 754). While `MoneyCalculator.round2()` mitigates rounding errors in the UI, storing currency as floating-point can accumulate rounding errors in financial ledgers. For Darvi Billing, monetary values should be stored in paise (integer cents) or strictly rounded `REAL` with check constraints.
3. **Absence of Indexes:**
   - No custom indexes exist. As the database grows, querying `sales.createdAt`, `sales.customerId`, `stockMovements.productId`, and `products.barcode` will trigger full table scans.
   - *Recommendation:* Add indexes on `sales.createdAt`, `sales.invoiceNo`, `products.barcode`, and `stockMovements.productId`.

