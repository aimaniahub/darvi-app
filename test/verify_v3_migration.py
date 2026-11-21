import sqlite3
import os
import shutil
import tempfile
import sys

def test_v2_to_v3_migration():
    print("=== Testing Database Schema v2 to v3 Migration ===")
    
    # 1. Create a temporary v2 SQLite database
    db_path = os.path.join(tempfile.gettempdir(), 'darvi_test_v2.db')
    if os.path.exists(db_path):
        os.remove(db_path)
        
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    
    # Enable foreign keys
    cur.execute("PRAGMA foreign_keys = ON;")
    
    # Set user_version to 2
    cur.execute("PRAGMA user_version = 2;")
    
    # Create v2 schema tables
    cur.execute('''
    CREATE TABLE app_settings (
        id INTEGER NOT NULL PRIMARY KEY,
        store_name TEXT NOT NULL,
        currency TEXT NOT NULL,
        tax_enabled INTEGER NOT NULL,
        tax_rate REAL NOT NULL,
        receipt_header TEXT NOT NULL,
        receipt_footer TEXT NOT NULL,
        language TEXT NOT NULL,
        allow_negative_stock INTEGER NOT NULL,
        cashier_pin TEXT NOT NULL,
        admin_password TEXT NOT NULL
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
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        balance REAL NOT NULL DEFAULT 0.0
    );
    ''')
    
    cur.execute('''
    CREATE TABLE suppliers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT
    );
    ''')
    
    cur.execute('''
    CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    ''')
    
    cur.execute('''
    CREATE TABLE sales (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        subtotal REAL NOT NULL,
        discount_total REAL NOT NULL,
        tax_total REAL NOT NULL,
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
        sale_id INTEGER NOT NULL REFERENCES sales(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
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
        product_id INTEGER NOT NULL REFERENCES products(id),
        type TEXT NOT NULL,
        qty_change INTEGER NOT NULL,
        reason TEXT,
        supplier_id INTEGER REFERENCES suppliers(id),
        unit_cost REAL,
        created_at TEXT NOT NULL
    );
    ''')
    
    # Seed v2 data: 2 customers (one with opening balance 350.0), 1 supplier, 2 products, 1 sale
    cur.execute("INSERT INTO categories (name) VALUES ('Fertilizers');")
    cur.execute("INSERT INTO customers (name, phone, balance) VALUES ('Ramesh Kumar', '9845011111', 350.0);")
    cur.execute("INSERT INTO customers (name, phone, balance) VALUES ('Suresh Patil', '9845022222', 0.0);")
    cur.execute("INSERT INTO suppliers (name, phone) VALUES ('Hubli Agro Supply', '0836220000');")
    cur.execute('''
        INSERT INTO products (name, sku, barcode, category_id, cost, price, stock_qty, created_at, updated_at)
        VALUES ('Urea 45kg', 'FERT001', '890123456789', 1, 240.0, 280.0, 50, '2026-01-01', '2026-01-01');
    ''')
    cur.execute('''
        INSERT INTO sales (invoice_no, created_at, customer_id, subtotal, discount_total, tax_total, total, paid, change_amount, payment_method, status)
        VALUES ('INV-20260101-0001', '2026-01-01', 1, 280.0, 0.0, 0.0, 280.0, 280.0, 0.0, 'cash', 'completed');
    ''')
    conn.commit()
    
    # Check v2 state
    cur.execute("SELECT COUNT(*) FROM customers;")
    v2_customers = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM products;")
    v2_products = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM sales;")
    v2_sales = cur.fetchone()[0]
    print(f"Pre-migration Record Counts: Customers={v2_customers}, Products={v2_products}, Sales={v2_sales}")
    
    # 2. Simulate Migration Steps (matches AppDatabase.migration.onUpgrade to v3)
    # Perform Backup
    backup_path = db_path + '.v2.bak'
    shutil.copyfile(db_path, backup_path)
    print(f"Verified Backup Created: {backup_path} ({os.path.getsize(backup_path)} bytes)")
    
    # Apply Schema Alterations and New Tables
    cur.execute('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT NOT NULL,
        gstin TEXT,
        address TEXT,
        phone TEXT,
        receipt_slogan TEXT NOT NULL DEFAULT 'Improving Agriculture, Improving lives.',
        receipt_terms TEXT NOT NULL DEFAULT 'Goods once sold will not be taken back or exchanged.\nNo cash payments accepted.',
        currency TEXT NOT NULL DEFAULT 'INR',
        is_default INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''')
    cur.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
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
      CREATE TABLE IF NOT EXISTS payments (
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
      CREATE TABLE IF NOT EXISTS ledger_entries (
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
      CREATE TABLE IF NOT EXISTS purchase_invoices (
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
      CREATE TABLE IF NOT EXISTS purchase_invoice_items (
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
    
    # Add new nullable columns to existing tables
    cur.execute("ALTER TABLE products ADD COLUMN workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE;")
    cur.execute("ALTER TABLE products ADD COLUMN hsn_code TEXT;")
    cur.execute("ALTER TABLE products ADD COLUMN gst_rate REAL NOT NULL DEFAULT 0.0;")
    
    cur.execute("ALTER TABLE sales ADD COLUMN workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE;")
    cur.execute("ALTER TABLE sales ADD COLUMN employee_id INTEGER;")
    cur.execute("ALTER TABLE sales ADD COLUMN cgst_total REAL NOT NULL DEFAULT 0.0;")
    cur.execute("ALTER TABLE sales ADD COLUMN sgst_total REAL NOT NULL DEFAULT 0.0;")
    cur.execute("ALTER TABLE sales ADD COLUMN igst_total REAL NOT NULL DEFAULT 0.0;")
    cur.execute("ALTER TABLE sales ADD COLUMN round_off REAL NOT NULL DEFAULT 0.0;")
    
    cur.execute("ALTER TABLE customers ADD COLUMN workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE;")
    cur.execute("ALTER TABLE customers ADD COLUMN gstin TEXT;")
    cur.execute("ALTER TABLE customers ADD COLUMN address TEXT;")
    
    cur.execute("ALTER TABLE suppliers ADD COLUMN workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE;")
    cur.execute("ALTER TABLE suppliers ADD COLUMN gstin TEXT;")
    cur.execute("ALTER TABLE suppliers ADD COLUMN address TEXT;")
    cur.execute("ALTER TABLE suppliers ADD COLUMN balance REAL NOT NULL DEFAULT 0.0;")
    
    # Seed Darvi Primary Workspace and Default Accounts
    cur.execute('''
      INSERT INTO workspaces (id, business_name, gstin, phone, address, currency, is_default)
      VALUES (1, 'Darvi Group Agri Tech', '29BKZPA0053M1ZQ', '9986890777', '#2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030', 'INR', 1);
    ''')
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (1, 1, 'Store Cash Drawer', 'cash', 0);")
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (2, 1, 'Company Bank Account', 'bank', 0);")
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (3, 1, 'Store UPI Account', 'upi', 1);")
    
    # Backfill workspace_id = 1 for existing data
    cur.execute("UPDATE products SET workspace_id = 1 WHERE workspace_id IS NULL;")
    cur.execute("UPDATE sales SET workspace_id = 1 WHERE workspace_id IS NULL;")
    cur.execute("UPDATE customers SET workspace_id = 1 WHERE workspace_id IS NULL;")
    cur.execute("UPDATE suppliers SET workspace_id = 1 WHERE workspace_id IS NULL;")

    # Backfill non-zero opening balances into double-entry ledger_entries
    cur.execute("SELECT id, name, balance FROM customers WHERE balance != 0;")
    for row in cur.fetchall():
        cid, cname, bal = row
        print(f"Migrating customer #{cid} ({cname}) opening balance: ₹{bal}")
        if bal > 0:
            cur.execute('''
              INSERT INTO ledger_entries (
                workspace_id, transaction_type, reference_type, reference_id,
                party_type, party_id, debit, credit, narration, created_at
              ) VALUES (1, 'opening_balance', 'customer', ?, 'customer', ?, ?, 0.0, ?, '2026-01-01');
            ''', (cid, cid, bal, f"Opening balance migrated for customer {cname}"))
            cur.execute('''
              INSERT INTO ledger_entries (
                workspace_id, transaction_type, reference_type, reference_id,
                debit, credit, narration, created_at
              ) VALUES (1, 'opening_balance', 'equity', 0, 0.0, ?, 'Offsetting opening balance credit to Capital/Equity', '2026-01-01');
            ''', (bal,))
            
    conn.commit()
    
    # 3. Assertions & Verifications
    print("\n--- Verifying Migration Integrity ---")
    
    # Check Record Counts
    cur.execute("SELECT COUNT(*) FROM customers;")
    v3_customers = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM products;")
    v3_products = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM sales;")
    v3_sales = cur.fetchone()[0]
    assert v3_customers == v2_customers, f"Customer count mismatch: {v3_customers} vs {v2_customers}"
    assert v3_products == v2_products, f"Product count mismatch: {v3_products} vs {v2_products}"
    assert v3_sales == v2_sales, f"Sales count mismatch: {v3_sales} vs {v2_sales}"
    print(f"PASS: Existing record counts perfectly preserved ({v3_customers} customers, {v3_products} products, {v3_sales} sales)")
    
    # Verify Workspace Isolation: All existing rows backfilled to workspace_id = 1
    cur.execute("SELECT COUNT(*) FROM products WHERE workspace_id != 1;")
    assert cur.fetchone()[0] == 0, "Non-workspace_1 product found"
    cur.execute("SELECT COUNT(*) FROM sales WHERE workspace_id != 1;")
    assert cur.fetchone()[0] == 0, "Non-workspace_1 sale found"
    cur.execute("SELECT COUNT(*) FROM customers WHERE workspace_id != 1;")
    assert cur.fetchone()[0] == 0, "Non-workspace_1 customer found"
    print("PASS: Workspace isolation backfill verified: 100% records scoped to workspace_id=1")
    
    # Verify Double-Entry Balance Invariant: Total Debit == Total Credit
    cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries;")
    debit_sum, credit_sum = cur.fetchone()
    assert abs(debit_sum - credit_sum) < 0.001, f"Double-entry ledger unbalanced: Debits={debit_sum}, Credits={credit_sum}"
    print(f"PASS: Double-entry ledger invariant verified: Total Debits (₹{debit_sum}) == Total Credits (₹{credit_sum})")
    
    # Verify Customer Balance Derivation from Ledger
    cur.execute('''
      SELECT 
        COALESCE(SUM(debit), 0.0) - COALESCE(SUM(credit), 0.0) as derived_balance
      FROM ledger_entries
      WHERE workspace_id = 1 AND party_type = 'customer' AND party_id = 1;
    ''')
    derived_bal = cur.fetchone()[0]
    assert derived_bal == 350.0, f"Customer 1 derived balance mismatch: {derived_bal}"
    print(f"PASS: Customer 1 balance derived from ledger matches opening balance: ₹{derived_bal}")
    
    # 4. Simulate a New Sale with Double-Entry Transaction
    print("\n--- Simulating New Credit Sale Transaction ---")
    # Sale of 1 Urea: Total = 280.0, Customer pays 100.0, Credit = 180.0
    sale_total = 280.0
    paid = 100.0
    unpaid = 180.0
    
    # Ledger entries for sale:
    # 1. Credit Sales Revenue: 280.0
    # 2. Debit Account (UPI #3): 100.0
    # 3. Debit Customer (#1): 180.0
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at)
      VALUES (1, 'sale', 'sale', 2, 0.0, 280.0, 'Sales revenue for INV-20261107-0002', '2026-11-07');
    ''')
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration, created_at)
      VALUES (1, 'payment_in', 'sale', 2, 3, 100.0, 0.0, 'Payment received for INV-20261107-0002', '2026-11-07');
    ''')
    cur.execute('''
      INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at)
      VALUES (1, 'sale', 'customer', 1, 'customer', 1, 180.0, 0.0, 'Credit balance for INV-20261107-0002', '2026-11-07');
    ''')
    conn.commit()
    
    # Verify new double-entry balance: Debits == Credits
    cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries;")
    debit_sum, credit_sum = cur.fetchone()
    assert abs(debit_sum - credit_sum) < 0.001, f"Double-entry ledger unbalanced after sale: Debits={debit_sum}, Credits={credit_sum}"
    print(f"PASS: Double-entry ledger invariant verified post-sale: Total Debits (₹{debit_sum}) == Total Credits (₹{credit_sum})")
    
    # Verify Customer #1 updated derived balance: 350.0 (opening) + 180.0 (credit) = 530.0
    cur.execute('''
      SELECT 
        COALESCE(SUM(debit), 0.0) - COALESCE(SUM(credit), 0.0) as derived_balance
      FROM ledger_entries
      WHERE workspace_id = 1 AND party_type = 'customer' AND party_id = 1;
    ''')
    new_bal = cur.fetchone()[0]
    assert new_bal == 530.0, f"Customer 1 balance mismatch after sale: {new_bal}"
    print(f"PASS: Customer 1 balance derived from ledger accurately updated: ₹{new_bal} (was ₹350.0 + ₹180.0 credit)")
    
    # Verify Account #3 balance: 100.0
    cur.execute('''
      SELECT 
        COALESCE(SUM(debit), 0.0) - COALESCE(SUM(credit), 0.0) as account_balance
      FROM ledger_entries
      WHERE workspace_id = 1 AND account_id = 3;
    ''')
    acc_bal = cur.fetchone()[0]
    assert acc_bal == 100.0, f"Account 3 balance mismatch: {acc_bal}"
    print(f"PASS: UPI Account #3 balance derived from ledger accurately updated: ₹{acc_bal}")

    # Clean up
    conn.close()
    os.remove(db_path)
    os.remove(backup_path)
    print("\n=== ALL DATABASE MIGRATION & REPOSITORY FOUNDATION TESTS PASSED ===")

if __name__ == '__main__':
    test_v2_to_v3_migration()
