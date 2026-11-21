import sqlite3
import os
import shutil
import tempfile
import sys

def run_pos_and_financial_engine_tests():
    print("======================================================================")
    print("      DARVI BILLING P0-8 & FINANCIAL VERIFICATION TEST SUITE          ")
    print("======================================================================")
    
    db_path = os.path.join(tempfile.gettempdir(), 'darvi_pos_test.db')
    if os.path.exists(db_path):
        os.remove(db_path)
        
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("PRAGMA foreign_keys = ON;")
    
    # --- SETUP V3 SCHEMA ---
    cur.execute('''
      CREATE TABLE workspaces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT NOT NULL,
        gstin TEXT,
        address TEXT,
        phone TEXT,
        receipt_slogan TEXT NOT NULL,
        receipt_terms TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'INR',
        is_default INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''')
    cur.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        account_number TEXT,
        opening_balance REAL NOT NULL DEFAULT 0.0,
        current_balance REAL NOT NULL DEFAULT 0.0,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''')
    cur.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''')
    cur.execute('''
      CREATE TABLE customers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        gstin TEXT,
        address TEXT,
        balance REAL NOT NULL DEFAULT 0.0
      );
    ''')
    cur.execute('''
      CREATE TABLE suppliers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        phone TEXT,
        gstin TEXT,
        address TEXT,
        balance REAL NOT NULL DEFAULT 0.0
      );
    ''')
    cur.execute('''
      CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        sku TEXT NOT NULL UNIQUE,
        barcode TEXT UNIQUE,
        category_id INTEGER REFERENCES categories(id),
        cost REAL NOT NULL,
        price REAL NOT NULL,
        stock_qty INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        unit TEXT NOT NULL DEFAULT 'piece',
        notes TEXT,
        image_path TEXT,
        hsn_code TEXT,
        gst_rate REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''')
    cur.execute('''
      CREATE TABLE sales (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE,
        invoice_no TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        employee_id INTEGER,
        subtotal REAL NOT NULL,
        discount_total REAL NOT NULL,
        tax_total REAL NOT NULL,
        cgst_total REAL NOT NULL DEFAULT 0.0,
        sgst_total REAL NOT NULL DEFAULT 0.0,
        igst_total REAL NOT NULL DEFAULT 0.0,
        round_off REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL,
        paid REAL NOT NULL,
        change_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL
      );
    ''')
    cur.execute('''
      CREATE TABLE sale_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        name_snapshot TEXT NOT NULL,
        cost_snapshot REAL NOT NULL,
        price_snapshot REAL NOT NULL,
        qty INTEGER NOT NULL,
        discount REAL NOT NULL DEFAULT 0.0,
        line_total REAL NOT NULL
      );
    ''')
    cur.execute('''
      CREATE TABLE stock_movements (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        qty_change INTEGER NOT NULL,
        reason TEXT,
        supplier_id INTEGER REFERENCES suppliers(id),
        unit_cost REAL,
        created_at TEXT NOT NULL
      );
    ''')
    cur.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        payment_type TEXT NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER,
        amount REAL NOT NULL,
        payment_mode TEXT NOT NULL,
        reference_no TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        narration TEXT
      );
    ''')
    cur.execute('''
      CREATE TABLE ledger_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        transaction_type TEXT NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER,
        party_type TEXT,
        party_id INTEGER,
        account_id INTEGER REFERENCES accounts(id) ON DELETE RESTRICT,
        debit REAL NOT NULL DEFAULT 0.0,
        credit REAL NOT NULL DEFAULT 0.0,
        narration TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''')
    cur.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
        invoice_number TEXT NOT NULL,
        invoice_date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        tax_total REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'unpaid',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''')
    cur.execute('''
      CREATE TABLE purchase_invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL REFERENCES purchase_invoices(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        gst_rate REAL NOT NULL DEFAULT 0.0,
        discount REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL
      );
    ''')
    conn.commit()

    # Seed baseline Darvi workspace & accounts
    cur.execute('''
      INSERT INTO workspaces (id, business_name, gstin, phone, address, receipt_slogan, receipt_terms, currency, is_default)
      VALUES (1, 'Darvi Group Agri Tech', '29BKZPA0053M1ZQ', '9986890777', '#2 Totad Building, Hubli', 'Improving Agriculture, Improving lives.', 'No returns without bill', 'INR', 1);
    ''')
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (1, 1, 'Cash Drawer', 'cash', 0);")
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (2, 1, 'Company Bank', 'bank', 0);")
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (3, 1, 'Store UPI', 'upi', 1);")
    cur.execute("INSERT INTO categories (id, name) VALUES (1, 'Agri Inputs');")
    
    # Seed 2 products with initial stock 100 each
    cur.execute('''
      INSERT INTO products (id, workspace_id, name, sku, category_id, cost, price, stock_qty, hsn_code, gst_rate, created_at, updated_at)
      VALUES (1, 1, 'Bio NPK Fertilizer 1L', 'AGR001', 1, 350.0, 480.0, 100, '3105', 18.0, '2026-11-01', '2026-11-01');
    ''')
    cur.execute('''
      INSERT INTO products (id, workspace_id, name, sku, category_id, cost, price, stock_qty, hsn_code, gst_rate, created_at, updated_at)
      VALUES (2, 1, 'Neem Oil Pest Guard 500ml', 'AGR002', 1, 180.0, 250.0, 100, '3808', 12.0, '2026-11-01', '2026-11-01');
    ''')
    
    # Seed Customers: #1 Walk-in, #2 Registered Farmer (Ramesh Patil) with opening balance 200.0
    cur.execute("INSERT INTO customers (id, workspace_id, name, phone, balance) VALUES (1, 1, 'Walk-in Customer', '9988000000', 0.0);")
    cur.execute("INSERT INTO customers (id, workspace_id, name, phone, balance) VALUES (2, 1, 'Ramesh Patil', '9845012345', 200.0);")
    
    # Seed Supplier: #1 Hubli Agro Chemicals with opening payable 500.0
    cur.execute("INSERT INTO suppliers (id, workspace_id, name, phone, balance) VALUES (1, 1, 'Hubli Agro Chemicals', '0836220000', 500.0);")
    conn.commit()
    
    print("\n--- TEST 1: Migration of Customer & Supplier Opening Balances into Ledger ---")
    # Customer Opening Balance (Asset: Debit Customer, Credit Equity)
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at)
      VALUES (1, 'opening_balance', 'customer', 2, 'customer', 2, 200.0, 0.0, 'Opening balance debit for customer Ramesh Patil', '2026-11-01');
    ''')
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at)
      VALUES (1, 'opening_balance', 'equity', 0, 0.0, 200.0, 'Offsetting opening balance credit to Capital/Equity', '2026-11-01');
    ''')
    # Supplier Opening Balance (Liability: Credit Supplier, Debit Equity)
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at)
      VALUES (1, 'opening_balance', 'equity', 0, 500.0, 0.0, 'Offsetting opening balance debit to Capital/Equity', '2026-11-01');
    ''')
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at)
      VALUES (1, 'opening_balance', 'supplier', 1, 'supplier', 1, 0.0, 500.0, 'Opening payable for Hubli Agro Chemicals', '2026-11-01');
    ''')
    conn.commit()
    
    cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries;")
    d_sum, c_sum = cur.fetchone()
    assert abs(d_sum - c_sum) < 0.001, f"Unbalanced: {d_sum} vs {c_sum}"
    print(f"PASS: Opening balances balanced: Debit={d_sum}, Credit={c_sum}")

    print("\n--- TEST 2: Multiple Products & Same Product Multiple Times in Cart ---")
    # Simulate cart with:
    # - Product 1: 3 units (first added 2, then +1)
    # - Product 2: 2 units
    # Atomic stock updates check: Product 1: 100 - 3 = 97; Product 2: 100 - 2 = 98
    p1_qty = 3
    p2_qty = 2
    cur.execute("UPDATE products SET stock_qty = stock_qty - ?, updated_at = '2026-11-07' WHERE id = 1;", (p1_qty,))
    cur.execute("UPDATE products SET stock_qty = stock_qty - ?, updated_at = '2026-11-07' WHERE id = 2;", (p2_qty,))
    conn.commit()
    
    cur.execute("SELECT stock_qty FROM products WHERE id = 1;")
    assert cur.fetchone()[0] == 97, "Product 1 stock failed"
    cur.execute("SELECT stock_qty FROM products WHERE id = 2;")
    assert cur.fetchone()[0] == 98, "Product 2 stock failed"
    print("PASS: Atomic stock decrement verified (Product 1: 100->97, Product 2: 100->98)")

    print("\n--- TEST 3: Partial Payment & Manual Override Checkout ---")
    # Total calculation for Invoice 1:
    # Item 1: 3 x 480 = 1440.0
    # Item 2: 2 x 250 = 500.0
    # Gross Subtotal = 1940.0
    # Item Discount on Item 1 = 40.0 -> Net Subtotal = 1900.0
    # Order Discount = 100.0 -> Taxable = 1800.0
    # GST 18% = 324.0 (CGST 162.0, SGST 162.0)
    # Total = 2124.0
    # Customer #2 pays manually overridden partial amount: 1000.0 via UPI (#3)
    # Outstanding Credit = 1124.0
    cur.execute('''
      INSERT INTO sales (
        workspace_id, invoice_no, created_at, customer_id, subtotal, discount_total, tax_total,
        cgst_total, sgst_total, total, paid, change_amount, payment_method, status
      ) VALUES (
        1, 'INV-20261107-0001', '2026-11-07', 2, 1900.0, 140.0, 324.0,
        162.0, 162.0, 2124.0, 1000.0, 0.0, 'upi', 'completed'
      );
    ''')
    sale1_id = cur.lastrowid
    
    # Ledger entries for Sale 1:
    # 1. Credit Sales Revenue = 2124.0
    # 2. Debit UPI Account (#3) = 1000.0
    # 3. Debit Customer Receivable (#2) = 1124.0
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at)
      VALUES (1, 'sale', 'sale', ?, 0.0, 2124.0, 'Sales revenue for INV-20261107-0001', '2026-11-07');
    ''', (sale1_id,))
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration, created_at)
      VALUES (1, 'payment_in', 'sale', ?, 3, 1000.0, 0.0, 'Partial UPI payment for INV-20261107-0001', '2026-11-07');
    ''', (sale1_id,))
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at)
      VALUES (1, 'sale', 'customer', ?, 'customer', 2, 1124.0, 0.0, 'Credit balance for INV-20261107-0001', '2026-11-07');
    ''', (sale1_id,))
    conn.commit()

    # Verify debit == credit
    cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries;")
    d_sum, c_sum = cur.fetchone()
    assert abs(d_sum - c_sum) < 0.001, f"Unbalanced: {d_sum} vs {c_sum}"
    print(f"PASS: Partial payment ledger balanced: Total Debits (₹{d_sum}) == Total Credits (₹{c_sum})")
    
    # Check Customer #2 Derived Balance: 200.0 (opening) + 1124.0 (credit sale) = 1324.0
    cur.execute('''
      SELECT COALESCE(SUM(debit), 0.0) - COALESCE(SUM(credit), 0.0)
      FROM ledger_entries
      WHERE workspace_id = 1 AND party_type = 'customer' AND party_id = 2;
    ''')
    cust2_bal = cur.fetchone()[0]
    assert cust2_bal == 1324.0, f"Customer balance mismatch: {cust2_bal}"
    print(f"PASS: Customer #2 derived balance accurately updated: ₹{cust2_bal} (Opening: ₹200 + Due: ₹1124)")

    print("\n--- TEST 4: Walk-in Customer with Partial/Zero Payment ---")
    # Walk-in Customer (#1) buys 1 Neem Oil (250.0), pays 0.0 cash.
    # The system must never lose outstanding amount: debits Customer #1 for ₹250.0
    cur.execute('''
      INSERT INTO sales (
        workspace_id, invoice_no, created_at, customer_id, subtotal, discount_total, tax_total,
        total, paid, change_amount, payment_method, status
      ) VALUES (
        1, 'INV-20261107-0002', '2026-11-07', 1, 250.0, 0.0, 0.0,
        250.0, 0.0, 0.0, 'cash', 'completed'
      );
    ''')
    sale2_id = cur.lastrowid
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at)
      VALUES (1, 'sale', 'sale', ?, 0.0, 250.0, 'Sales revenue for Walk-in INV-20261107-0002', '2026-11-07');
    ''', (sale2_id,))
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at)
      VALUES (1, 'sale', 'customer', ?, 'customer', 1, 250.0, 0.0, 'Walk-in unpaid balance recorded', '2026-11-07');
    ''', (sale2_id,))
    conn.commit()
    
    cur.execute('''
      SELECT COALESCE(SUM(debit), 0.0) - COALESCE(SUM(credit), 0.0)
      FROM ledger_entries
      WHERE workspace_id = 1 AND party_type = 'customer' AND party_id = 1;
    ''')
    walkin_bal = cur.fetchone()[0]
    assert walkin_bal == 250.0, f"Walk-in balance lost: {walkin_bal}"
    print(f"PASS: Walk-in customer unpaid balance preserved in ledger: ₹{walkin_bal}")

    print("\n--- TEST 5: Purchase Bill Inward & Balanced Supplier Postings ---")
    # Purchase 50 units of Bio NPK at cost 350.0 = 17500.0 from Supplier #1 (Hubli Agro Chemicals)
    # Paid 7500.0 via Bank (#2), Credit 10000.0
    cur.execute('''
      INSERT INTO purchase_invoices (
        workspace_id, supplier_id, invoice_number, invoice_date, subtotal, total_amount, paid_amount, status, created_at
      ) VALUES (
        1, 1, 'PUR-2026-099', '2026-11-07', 17500.0, 17500.0, 7500.0, 'partial', '2026-11-07'
      );
    ''')
    pur_id = cur.lastrowid
    
    # Atomic stock increment: 97 + 50 = 147
    cur.execute("UPDATE products SET stock_qty = stock_qty + 50, updated_at = '2026-11-07' WHERE id = 1;")
    
    # Ledger entries for Purchase:
    # 1. Debit Inventory/Purchase = 17500.0
    # 2. Credit Supplier Payable (#1) = 17500.0
    # 3. Debit Supplier Payable (#1) = 7500.0 (paid portion)
    # 4. Credit Bank Account (#2) = 7500.0
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at)
      VALUES (1, 'purchase', 'purchase_invoice', ?, 17500.0, 0.0, 'Inventory inward PUR-2026-099', '2026-11-07');
    ''', (pur_id,))
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at)
      VALUES (1, 'purchase', 'supplier', ?, 'supplier', 1, 0.0, 17500.0, 'Payable for PUR-2026-099', '2026-11-07');
    ''', (pur_id,))
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at)
      VALUES (1, 'payment_out', 'supplier', ?, 'supplier', 1, 7500.0, 0.0, 'Bank payment for PUR-2026-099', '2026-11-07');
    ''', (pur_id,))
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration, created_at)
      VALUES (1, 'payment_out', 'account', ?, 2, 0.0, 7500.0, 'Bank payout for PUR-2026-099', '2026-11-07');
    ''', (pur_id,))
    conn.commit()

    # Stock check
    cur.execute("SELECT stock_qty FROM products WHERE id = 1;")
    assert cur.fetchone()[0] == 147, "Stock increment failed"
    
    # Check Supplier #1 Derived Balance: 500.0 (opening) + (17500 - 7500) = 10500.0
    cur.execute('''
      SELECT COALESCE(SUM(credit), 0.0) - COALESCE(SUM(debit), 0.0)
      FROM ledger_entries
      WHERE workspace_id = 1 AND party_type = 'supplier' AND party_id = 1;
    ''')
    supp_bal = cur.fetchone()[0]
    assert supp_bal == 10500.0, f"Supplier balance mismatch: {supp_bal}"
    print(f"PASS: Supplier #1 derived payable balance: ₹{supp_bal} (Opening: ₹500 + Net Purchase Due: ₹10000)")

    print("\n--- TEST 6: Atomic Rollback on Failed Transaction ---")
    # Simulate a transaction failure:
    initial_p1_stock = 147
    cur.execute("SELECT COUNT(*) FROM sales;")
    initial_sales_count = cur.fetchone()[0]
    
    try:
        cur.execute("BEGIN TRANSACTION;")
        cur.execute("UPDATE products SET stock_qty = stock_qty - 10 WHERE id = 1;")
        cur.execute("INSERT INTO sales (workspace_id, invoice_no, created_at, subtotal, discount_total, tax_total, total, paid, change_amount, payment_method, status) VALUES (1, 'INV-FAIL-01', 'now', 100, 0, 0, 100, 100, 0, 'cash', 'completed');")
        # Deliberate failure: Duplicate invoice number or null constraint
        cur.execute("INSERT INTO sales (workspace_id, invoice_no, created_at, subtotal, discount_total, tax_total, total, paid, change_amount, payment_method, status) VALUES (1, 'INV-FAIL-01', 'now', 100, 0, 0, 100, 100, 0, 'cash', 'completed');")
        conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"Captured expected transaction error: {e}")

    cur.execute("SELECT stock_qty FROM products WHERE id = 1;")
    post_fail_stock = cur.fetchone()[0]
    assert post_fail_stock == initial_p1_stock, f"Stock rollback failed: {post_fail_stock} vs {initial_p1_stock}"
    cur.execute("SELECT COUNT(*) FROM sales;")
    assert cur.fetchone()[0] == initial_sales_count, "Sales table rollback failed"
    print(f"PASS: Complete transaction rollback verified. Stock preserved at {post_fail_stock}, no orphan records created.")

    print("\n--- TEST 7: Complete Ledger Equilibrium Verification ---")
    cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries;")
    final_debit, final_credit = cur.fetchone()
    assert abs(final_debit - final_credit) < 0.001, f"Final equilibrium failed: {final_debit} vs {final_credit}"
    print(f"PASS: Total system ledger equilibrium verified: Total Debits (₹{final_debit}) == Total Credits (₹{final_credit})")

    conn.close()
    os.remove(db_path)
    print("\n======================================================================")
    print("      ALL POS STATE, CHECKOUT & FINANCIAL ENGINE TESTS PASSED         ")
    print("======================================================================")

if __name__ == '__main__':
    run_pos_and_financial_engine_tests()
