# QuickStock POS Source Code Audit: Business Logic & Calculations

**Document ID:** `docs/darvi-audit/BUSINESS_LOGIC_AUDIT.md`  
**Audit Date:** November 2026  
**Auditor:** Senior Flutter Architect & Software Auditor  

---

## 1. Billing and POS Business Logic Audit

### A. Calculation Pipeline (`MoneyCalculator`)
The core calculation rules are defined in `lib/core/utils/money_calculator.dart`:

```dart
static double round2(double value) => (value * 100).roundToDouble() / 100;

static double lineTotal({required double unitPrice, required int qty, required double itemDiscount}) {
  final raw = (unitPrice * qty) - itemDiscount;
  return round2(max(0, raw));
}

static double subtotal(List<double> lineTotals) {
  return round2(lineTotals.fold(0, (sum, line) => sum + line));
}

static double tax({required double taxableAmount, required bool taxEnabled, required double taxRate}) {
  if (!taxEnabled) return 0;
  return round2(max(0, taxableAmount) * taxRate);
}

static double orderTotal({required double subtotal, required double orderDiscount, required double tax}) {
  final raw = subtotal - orderDiscount + tax;
  return round2(max(0, raw));
}
```

### Critical Flaws in Financial Calculations

#### 1. The Subtotal & Discount Storage Inconsistency
- In `MoneyCalculator.lineTotal`, `itemDiscount` is subtracted *at the line level*.
- In `MoneyCalculator.subtotal`, it sums `lineTotals`. This means `subtotal` represents the **net sum after line discounts**, not the gross subtotal!
- Then in `LocalSalesRepository.checkout` (lines 359-385):
  ```dart
  final subtotal = MoneyCalculator.subtotal(lineTotals);
  final itemDiscountTotal = MoneyCalculator.round2(input.items.fold(0, (sum, item) => sum + item.discount));
  final discountTotal = MoneyCalculator.round2(itemDiscountTotal + input.orderDiscount);
  ```
- And it persists into the `Sales` table:
  - `subtotal: subtotal` (already discounted by item discounts)
  - `discountTotal: discountTotal` (`itemDiscountTotal + orderDiscount`)
  - `total: subtotal - orderDiscount + tax`
- **Resulting Accounting Error:** If an invoice has an item of ₹100 with a ₹10 item discount, and an order discount of ₹5:
  - `lineTotal` = ₹90
  - Stored `subtotal` = ₹90
  - Stored `discountTotal` = ₹15 (₹10 item + ₹5 order)
  - Stored `total` = ₹85
  - Any standard accounting check verifying `Gross Subtotal - Discount + Tax = Total` will fail because `90 - 15 = 75 != 85`! Line discounts are effectively subtracted twice in report reconciliation.
- **Darvi Fix:** Define:
  - `grossSubtotal` = `Sum(unitPrice * qty)`
  - `itemDiscountTotal` = `Sum(itemDiscount)`
  - `netSubtotal` = `grossSubtotal - itemDiscountTotal`
  - `taxableAmount` = `max(0, netSubtotal - orderDiscount)`
  - `grandTotal` = `taxableAmount + taxTotal`

#### 2. The `paid: state.total` Old-State Bug in `PosCubit`
In `lib/features/pos/presentation/cubit/pos_cubit.dart`:
```dart
void addProductToCart(ProductView product) {
  // ...
  emit(state.copyWith(cart: updated, paid: state.total, clearError: true, clearLastResult: true));
}
```
In Dart, when `state.copyWith(cart: updated, paid: state.total)` is evaluated, `state.total` is evaluated on the **current (old) state** before `updated` is applied!
- **Concrete Example:** 
  - Cart has 1 item worth ₹100. `state.total` is ₹100.
  - Cashier scans a second item worth ₹50.
  - When `addProductToCart` runs, `state.copyWith(...)` is called. `state.total` evaluates to ₹100 (old total).
  - The new state is emitted with `cart` containing ₹150 worth of goods, but `paid` is set to **₹100**!
  - If the cashier immediately taps "Checkout", the sale is recorded as a partial payment (Paid ₹100 on a ₹150 bill), and the remaining ₹50 is improperly added to customer debt!
  - The same bug occurs in `updateItemQty` (line 264) and `removeFromCart` (line 269).

#### 3. Duplicate Product ID Inventory Subtraction Flaw
In `LocalSalesRepository.checkout` (lines 339-426):
```dart
final productById = {for (final product in products) product.id: product};

for (var i = 0; i < input.items.length; i++) {
  final item = input.items[i];
  final product = productById[item.productId]!;
  // ...
  await (_db.update(_db.products)..where((tbl) => tbl.id.equals(product.id))).write(
    ProductsCompanion(
      stockQty: Value(product.stockQty - item.qty),
      updatedAt: Value(now),
    ),
  );
}
```
If the cart contains two lines with the *same* `productId` (for instance, with different batch numbers, serials, or line discounts):
- Item 1 subtracts from `product.stockQty` and writes to DB.
- Item 2 also reads from `product.stockQty` (which is still the static in-memory snapshot loaded before the loop) and overwrites the database with `product.stockQty - item2.qty`, **completely wiping out the stock reduction from Item 1!**

#### 4. Anonymous Customer Partial Payments
In `checkout` (lines 429-438):
```dart
if (input.customerId != null && paid < total) {
  final customer = await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(input.customerId!))).getSingleOrNull();
  if (customer != null) {
    await (_db.update(_db.customers)..where((tbl) => tbl.id.equals(customer.id))).write(
      CustomersCompanion(balance: Value(customer.balance + (total - paid))),
    );
  }
}
```
If `input.customerId == null` (walk-in retail customer) and `paid < total`, the transaction completes without error! The unpaid debt is never assigned to anyone and vanishes from the financial records.

---

## 2. Inventory Business Logic Audit

### A. Stock Movement Integrity
`StockMovements` supports 6 movement types: `add`, `remove`, `adjust`, `purchase`, `sale`, `returnSale`.
- When `addStockMovement` runs:
  - If `type == StockMovementType.adjust`, `newQty = qtyChange`.
  - Otherwise, `newQty = product.stockQty + qtyChange`.
  - Checked against `newQty < 0`.
  - Written inside a `_db.transaction`.
- **Flaw: Direct Stock Editing in Product Editor:**
  When a user edits a product in `ProductsPage` and changes the "Stock" field, `LocalProductRepository.upsertProduct` directly overwrites `stockQty` on the `Products` table. **No record is inserted into `StockMovements`.** This breaks inventory audit trails.

### B. "Popular Products" Implementation Flaw
In `LocalProductRepository.getPopularProducts` (lines 221-224):
```dart
Future<List<ProductView>> getPopularProducts() async {
  final rows = await (_db.select(_db.products)
        ..orderBy([(t) => OrderingTerm.desc(t.stockQty)])
        ..limit(8))
      .get();
  // ...
}
```
The method orders products by **highest in-stock quantity**, NOT by sales volume! Products with large unsold quantities are presented as "popular" on the POS screen.

---

## 3. Customers & Suppliers Business Logic Audit

1. **In-Place Balance Modification (No Ledger):**
   - Customer balance is stored as a single `real` column on the `Customers` table.
   - When a partial payment occurs, it updates `customer.balance = customer.balance + (total - paid)`.
   - There is no transaction history, no credit/debit entries, and no record of which invoices contributed to the balance.
2. **Missing Supplier Balances:**
   - The `Suppliers` table has columns `(id, name, phone)`.
   - It has no `balance` column and no ledger.
3. **No Payment-In / Payment-Out Operations:**
   - If a customer visits the store to pay off ₹500 of their outstanding balance, there is **no method or screen** to accept a payment on account.

---

## 4. Purchases Business Logic Audit

In `LocalProductRepository.addStockMovement`:
```dart
if (input.type == StockMovementType.purchase && input.unitCost != null) {
  await _db.into(_db.purchases).insert(
    PurchasesCompanion.insert(
      supplierId: Value(input.supplierId),
      productId: input.productId,
      qty: max(0, input.qtyChange),
      unitCost: input.unitCost!,
      notes: Value(input.reason),
    ),
  );
}
```
1. **Single-Item Purchase Table:**
   - Each purchase record corresponds to exactly one product.
   - It is impossible to enter a supplier invoice containing 10 different items with a bill total, freight charges, and tax breakup.
2. **No Purchase Invoices / Bills:**
   - There is no purchase invoice number, purchase date, invoice attachment, or supplier bill reference.
3. **No Purchase Returns:**
   - There is no workflow to return defective stock to a supplier.

---

## 5. Reports & Analytics Performance Audit

In `LocalReportsRepository.getDashboardMetrics` (lines 669-670):
```dart
final sales = await _db.select(_db.sales).get();
final items = await _db.select(_db.saleItems).get();
```
- **Severe Performance Bottleneck:** To compute today's sales and month's sales, the repository executes a `SELECT *` across all sales and all sale items in database history and filters them in Dart memory using `date.year == now.year && ...`.
- **Scaling Limit:** In a live store generating 100 invoices/day, after 6 months the app will load ~18,000 sales and ~70,000 items into memory on every dashboard view, leading to memory pressure and UI stutter.
- **Darvi Fix:** Replace with SQL aggregation queries:
  ```sql
  SELECT SUM(total) as revenue, COUNT(*) as count 
  FROM sales 
  WHERE created_at >= :startOfDay AND created_at <= :endOfDay;
  ```

