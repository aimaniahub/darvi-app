# QuickStock POS Source Code Audit: Database Relationships & Data Integrity

**Document ID:** `docs/darvi-audit/DATABASE_RELATIONSHIPS.md`  
**Audit Date:** November 2026  
**Auditor:** Senior Database Architect & Software Auditor  

---

## 1. Existing Entity Relationship Diagram

```mermaid
erDiagram
    CATEGORIES ||--o{ PRODUCTS : "categorizes (1:N, ON DELETE SET NULL)"
    PRODUCTS ||--o{ STOCK_MOVEMENTS : "tracks (1:N, ON DELETE CASCADE)"
    PRODUCTS ||--o{ PURCHASES : "purchased (1:N, ON DELETE CASCADE)"
    SUPPLIERS ||--o{ PURCHASES : "supplies (1:N, ON DELETE SET NULL)"
    CUSTOMERS ||--o{ SALES : "billed_to (1:N, ON DELETE SET NULL)"
    SALES ||--|{ SALE_ITEMS : "contains (1:N, ON DELETE CASCADE)"
    PRODUCTS ||--o{ SALE_ITEMS : "sold_in (1:N, ON DELETE RESTRICT)"
    APP_SETTINGS

    CATEGORIES {
        int id PK
        string name UK
    }

    PRODUCTS {
        int id PK
        string name
        string sku UK
        string barcode UK
        int categoryId FK
        real cost
        real price
        int stockQty
        int lowStockThreshold
        string unit
        string notes
        string imagePath
        datetime createdAt
        datetime updatedAt
    }

    STOCK_MOVEMENTS {
        int id PK
        int productId FK
        string type
        int qtyChange
        string reason
        datetime createdAt
    }

    CUSTOMERS {
        int id PK
        string name
        string phone
        string notes
        real balance
    }

    SUPPLIERS {
        int id PK
        string name
        string phone
    }

    PURCHASES {
        int id PK
        int supplierId FK
        int productId FK
        int qty
        real unitCost
        string notes
        datetime createdAt
    }

    SALES {
        int id PK
        string invoiceNo UK
        datetime createdAt
        int customerId FK
        real subtotal
        real discountTotal
        real taxTotal
        real total
        real paid
        real changeAmount
        string paymentMethod
        string status
    }

    SALE_ITEMS {
        int id PK
        int saleId FK
        int productId FK
        string nameSnapshot
        real costSnapshot
        real priceSnapshot
        int qty
        real discount
        real lineTotal
    }

    APP_SETTINGS {
        int id PK
        string storeName
        string currency
        bool taxEnabled
        real taxRate
        string receiptHeader
        string receiptFooter
        string language
        bool allowNegativeStock
        string cashierPin
        string adminPassword
    }
```

---

## 2. Answers to the 10 Data Integrity Questions

| # | Integrity Question | Status in Existing Code | Evidence & Analysis |
|---|---|---|---|
| **1** | **Can an invoice contain multiple products?** | **YES** | `SaleItems` table references `Sales(id)` with a `1:N` foreign key. An invoice can contain arbitrary lines. |
| **2** | **Can a customer have multiple invoices?** | **YES** | `Sales.customerId` references `Customers(id)` with a `1:N` foreign key (`ON DELETE SET NULL`). |
| **3** | **Can an invoice have multiple payment records?** | **NO** | There is no `Payments` table. Payment details are stored as flat columns on `Sales` (`paid`, `changeAmount`, `paymentMethod`). Split payments simply set `paymentMethod = 'split'` without tracking breakdown. |
| **4** | **Are payments connected to accounts?** | **NO** | There is no `Accounts` entity (no Cash Drawer, Bank Account, or UPI account). Money received is not allocated to any financial account. |
| **5** | **Are stock movements recorded separately?** | **PARTIAL** | Sales and manual adjustments insert into `StockMovements`. However, editing a product in `ProductsPage` directly overwrites `Products.stockQty` without inserting a movement record. |
| **6** | **Can purchases update inventory correctly?** | **PARTIAL** | `addStockMovement(type: purchase)` updates stock and inserts into `Purchases`. However, each purchase record accommodates only a single product. Multi-product supplier purchases are unsupported. |
| **7** | **Are returns represented correctly?** | **DEFICIENT** | Returns create a new `Sales` record with negative line items, but marking any item as returned marks the entire original invoice as `returned`. Customer balance and refunds are not adjusted. |
| **8** | **Are customer & supplier balances derived consistently?** | **NO** | Customer balance is modified in-place on the customer row. There is no ledger or transaction history to verify or audit how a balance was calculated. Suppliers have no balance column at all. |
| **9** | **Are database transactions used for multi-step operations?** | **YES** | Both `checkout` and `returnItems` are wrapped in `_db.transaction(() async { ... })`. |
| **10**| **Can multiple business workspaces be isolated?** | **NO** | Zero multi-workspace capability. All data belongs to a single global store. |

---

## 3. Critical Data Integrity Risks in Existing Codebase

1. **Race Condition in Invoice Number Generation:**
   In `LocalSalesRepository._nextInvoiceNo` (lines 636-646):
   ```dart
   final countExp = _db.sales.id.count();
   final query = _db.selectOnly(_db.sales)
     ..addColumns([countExp])
     ..where(_db.sales.invoiceNo.like('INV-$datePart-%'));
   final count = (await query.getSingleOrNull())?.read(countExp) ?? 0;
   final sequence = (count + 1).toString().padLeft(4, '0');
   ```
   If two devices checkout concurrently, or if an invoice is deleted, `count + 1` produces an identical sequence number, throwing a SQLite unique constraint violation and aborting the sale.
2. **Orphaned Debt:**
   Walk-in retail sales without a customer ID can be submitted with `paid < total`, causing debt to vanish.
3. **Double Stock Overwrite Flaw:**
   When multiple lines in the cart share the same product ID, inventory is subtracted from the pre-loop snapshot, causing previous deductions to be overwritten and lost.

---

## 4. Minimum Database Changes Required for Darvi Billing

To support Darvi Billing safely, the database must be upgraded to **Schema Version 3** with the following structural additions:

1. **`Workspaces` Table:**
   - Multi-tenant boundary (`id`, `businessName`, `gstin`, `address`, `phone`, `logoPath`, `isDefault`).
   - Add `workspaceId` foreign key to `Products`, `Sales`, `Purchases`, `Customers`, `Suppliers`, `AppSettings`.
2. **`LedgerEntries` Table:**
   - Replacing flat balance columns with a double-entry / audit ledger (`id`, `workspaceId`, `partyType`, `partyId`, `date`, `entryType`, `debit`, `credit`, `balanceAfter`, `referenceType`, `referenceId`, `notes`).
3. **`Accounts` & `Payments` Tables:**
   - Financial accounts (`Cash`, `Bank`, `UPI`) and payment transactions linked to invoices and bills.
4. **`PurchaseInvoices` & `PurchaseInvoiceItems` Tables:**
   - True multi-item purchase bills matching supplier invoices.
5. **`Employees`, `Attendance`, `Payroll`, and `Incentives` Tables:**
   - Enterprise workforce and commission management.

