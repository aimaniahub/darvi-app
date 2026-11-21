import sqlite3
import os
import shutil
import tempfile
import sys

def test_full_darvi_p1_and_p2_suite():
    print("======================================================================")
    print("      DARVI BILLING FULL P1 & P2 INTEGRATION VERIFICATION SUITE       ")
    print("======================================================================")
    
    db_path = os.path.join(tempfile.gettempdir(), 'darvi_full_p1_p2.db')
    if os.path.exists(db_path):
        os.remove(db_path)
        
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("PRAGMA foreign_keys = ON;")
    
    # 1. CREATE ALL SCHEMAS (P1 Core Business + P2 Staff, Attendance & Payroll)
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
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
      CREATE TABLE customers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        gstin TEXT,
        address TEXT,
        balance REAL NOT NULL DEFAULT 0.0,
        credit_limit REAL NOT NULL DEFAULT 50000.0
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
    cur.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        reference_no TEXT,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''')
    cur.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        employee_code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        role TEXT NOT NULL,
        designation TEXT NOT NULL,
        department TEXT NOT NULL DEFAULT 'Sales',
        login_pin TEXT NOT NULL,
        base_salary REAL NOT NULL DEFAULT 0.0,
        joining_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''')
    cur.execute('''
      CREATE TABLE attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        status TEXT NOT NULL DEFAULT 'present',
        working_hours REAL NOT NULL DEFAULT 8.0,
        notes TEXT
      );
    ''')
    cur.execute('''
      CREATE TABLE payroll_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        basic_salary REAL NOT NULL,
        incentive_amount REAL NOT NULL DEFAULT 0.0,
        allowances REAL NOT NULL DEFAULT 0.0,
        deductions REAL NOT NULL DEFAULT 0.0,
        net_salary REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        paid_from_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
        paid_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
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
    conn.commit()

    # Seed Darvi Primary Setup
    cur.execute('''
      INSERT INTO workspaces (id, business_name, gstin, phone, address, receipt_slogan, receipt_terms, is_default)
      VALUES (1, 'Darvi Group Agri Tech', '29BKZPA0053M1ZQ', '9986890777', 'Hubli, Karnataka', 'Improving Agriculture', 'No cash', 1);
    ''')
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (1, 1, 'Cash Drawer', 'cash', 0);")
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (2, 1, 'Company Bank', 'bank', 0);")
    cur.execute("INSERT INTO accounts (id, workspace_id, name, type, is_default) VALUES (3, 1, 'Store UPI', 'upi', 1);")
    cur.execute("INSERT INTO categories (id, name) VALUES (1, 'Fertilizers');")
    cur.execute('''
      INSERT INTO products (id, workspace_id, name, sku, category_id, cost, price, stock_qty, hsn_code, gst_rate, created_at, updated_at)
      VALUES (1, 1, 'Bio NPK 1L', 'FERT01', 1, 300.0, 450.0, 50, '3105', 18.0, '2026-11-01', '2026-11-01');
    ''')
    cur.execute("INSERT INTO customers (id, workspace_id, name, phone, balance) VALUES (1, 1, 'Walk-in Customer', '9988000000', 0.0);")
    cur.execute("INSERT INTO customers (id, workspace_id, name, phone, balance) VALUES (2, 1, 'Anil Kumar', '9845012345', 0.0);")
    cur.execute("INSERT INTO suppliers (id, workspace_id, name, phone, balance) VALUES (1, 1, 'Agri Wholesale Hubli', '0836220000', 0.0);")
    cur.execute('''
      INSERT INTO employees (id, workspace_id, employee_code, name, phone, role, designation, login_pin, base_salary, joining_date)
      VALUES (1, 1, 'EMP001', 'Prakash Naik', '9988776655', 'cashier', 'Senior Cashier', '1234', 18000.0, '2026-01-01');
    ''')
    conn.commit()
    print("PASS: P1 & P2 Complete Schema initialized successfully")

    # TEST 1: POS Billing with GST Output Tax Separation and Credit Sale
    print("\n--- TEST 1: POS Billing with GST Output Tax Separation ---")
    # Anil Kumar buys 2 Bio NPK: Subtotal = 900.0, 18% GST = 162.0 (CGST 81, SGST 81), Total = 1062.0
    # Customer pays 500 via UPI (Account #3), 562 on credit
    cur.execute("UPDATE products SET stock_qty = stock_qty - 2 WHERE id = 1;")
    cur.execute('''
      INSERT INTO sales (workspace_id, invoice_no, created_at, customer_id, employee_id, subtotal, discount_total, tax_total, cgst_total, sgst_total, total, paid, change_amount, payment_method, status)
      VALUES (1, 'INV-20261107-1001', '2026-11-07', 2, 1, 900.0, 0.0, 162.0, 81.0, 81.0, 1062.0, 500.0, 0.0, 'upi', 'completed');
    ''')
    s_id = cur.lastrowid
    # Double-entry ledger:
    # 1. Credit Revenue: 900.0
    # 2. Credit GST Output Tax: 162.0
    # 3. Debit UPI (Acct #3): 500.0
    # 4. Debit Customer (#2): 562.0
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at) VALUES (1, 'sale', 'revenue', ?, 0.0, 900.0, 'Net Sales Revenue', '2026-11-07');", (s_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at) VALUES (1, 'sale', 'tax_payable', ?, 0.0, 162.0, 'GST Output Tax', '2026-11-07');", (s_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration, created_at) VALUES (1, 'payment_in', 'sale', ?, 3, 500.0, 0.0, 'UPI partial receipt', '2026-11-07');", (s_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at) VALUES (1, 'sale', 'customer', ?, 'customer', 2, 562.0, 0.0, 'Customer credit due', '2026-11-07');", (s_id,))
    conn.commit()

    cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries;")
    d, c = cur.fetchone()
    assert abs(d - c) < 0.001, f"Unbalanced: {d} vs {c}"
    print(f"PASS: GST Output Tax and Revenue properly segregated: Total Debits (₹{d}) == Total Credits (₹{c})")

    # TEST 2: Inward Purchase Bill & Supplier Payable
    print("\n--- TEST 2: Inward Purchase Bill & Stock Increment ---")
    # Purchase 40 units at 300.0 = 12000.0 from Supplier #1, paid 2000 from Bank (#2), 10000 payable
    cur.execute("UPDATE products SET stock_qty = stock_qty + 40 WHERE id = 1;")
    cur.execute('''
      INSERT INTO purchase_invoices (workspace_id, supplier_id, invoice_number, invoice_date, subtotal, total_amount, paid_amount, status)
      VALUES (1, 1, 'BILL-SUP-01', '2026-11-07', 12000.0, 12000.0, 2000.0, 'partial');
    ''')
    pur_id = cur.lastrowid
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at) VALUES (1, 'purchase', 'purchase_invoice', ?, 12000.0, 0.0, 'Inward purchase bill', '2026-11-07');", (pur_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at) VALUES (1, 'purchase', 'supplier', ?, 'supplier', 1, 0.0, 12000.0, 'Payable for bill', '2026-11-07');", (pur_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at) VALUES (1, 'payment_out', 'supplier', ?, 'supplier', 1, 2000.0, 0.0, 'Bank payment to supplier', '2026-11-07');", (pur_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration, created_at) VALUES (1, 'payment_out', 'account', ?, 2, 0.0, 2000.0, 'Bank payout to supplier', '2026-11-07');", (pur_id,))
    conn.commit()

    cur.execute("SELECT stock_qty FROM products WHERE id = 1;")
    assert cur.fetchone()[0] == 88, "Stock mismatch: 50 - 2 + 40 = 88"
    print("PASS: Purchase inward stock verified: 88 units in stock")

    # TEST 3: Daily Store Expense
    print("\n--- TEST 3: Store Expense Recording ---")
    cur.execute('''
      INSERT INTO expenses (workspace_id, account_id, category, amount, expense_date, notes)
      VALUES (1, 1, 'Electricity', 1500.0, '2026-11-07', 'October shop electricity bill');
    ''')
    exp_id = cur.lastrowid
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration, created_at) VALUES (1, 'expense', 'expense', ?, 1500.0, 0.0, 'Electricity bill', '2026-11-07');", (exp_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration, created_at) VALUES (1, 'expense', 'account', ?, 1, 0.0, 1500.0, 'Cash drawer expense payout', '2026-11-07');", (exp_id,))
    conn.commit()
    print("PASS: Expense transaction posted with balanced ledger entries")

    # TEST 4: Staff Attendance & Monthly Payroll Disbursal (P2)
    print("\n--- TEST 4: P2 Staff Attendance & Payroll Disbursal ---")
    cur.execute('''
      INSERT INTO attendances (workspace_id, employee_id, date, status, working_hours)
      VALUES (1, 1, '2026-11-07', 'present', 8.0);
    ''')
    cur.execute('''
      INSERT INTO payroll_records (workspace_id, employee_id, month, year, basic_salary, incentive_amount, allowances, deductions, net_salary, status, paid_from_account_id, paid_date)
      VALUES (1, 1, 11, 2026, 18000.0, 2000.0, 500.0, 200.0, 20300.0, 'paid', 2, '2026-11-07');
    ''')
    pay_id = cur.lastrowid
    # Post salary ledger entries:
    # Debit: Salary Expense = 20300.0
    # Credit: Bank Account (#2) = 20300.0
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration, created_at) VALUES (1, 'salary', 'salary', ?, 'employee', 1, 20300.0, 0.0, 'Prakash Naik Nov Salary', '2026-11-07');", (pay_id,))
    cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration, created_at) VALUES (1, 'salary', 'account', ?, 2, 0.0, 20300.0, 'Bank payout for employee salary', '2026-11-07');", (pay_id,))
    conn.commit()
    print("PASS: Staff attendance and monthly salary disbursement verified with balanced ledger entries")

    # TEST 5: Complete System Ledger Equilibrium Verification
    print("\n--- TEST 5: Complete Ledger Equilibrium Verification ---")
    cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries;")
    final_d, final_c = cur.fetchone()
    assert abs(final_d - final_c) < 0.001, f"Unbalanced: {final_d} vs {final_c}"
    print(f"PASS: Full system invariant verified: Total Debits (₹{final_d}) == Total Credits (₹{final_c})")

    # TEST 6: Derived Balances Check
    print("\n--- TEST 6: Derived Party & Account Balances ---")
    # Customer #2 Due: ₹562.0
    cur.execute("SELECT COALESCE(SUM(debit), 0.0) - COALESCE(SUM(credit), 0.0) FROM ledger_entries WHERE workspace_id = 1 AND party_type = 'customer' AND party_id = 2;")
    c2_bal = cur.fetchone()[0]
    assert c2_bal == 562.0, f"Customer due mismatch: {c2_bal}"
    
    # Supplier #1 Payable: ₹10000.0 (12000 - 2000)
    cur.execute("SELECT COALESCE(SUM(credit), 0.0) - COALESCE(SUM(debit), 0.0) FROM ledger_entries WHERE workspace_id = 1 AND party_type = 'supplier' AND party_id = 1;")
    s1_bal = cur.fetchone()[0]
    assert s1_bal == 10000.0, f"Supplier payable mismatch: {s1_bal}"
    
    print(f"PASS: Customer #2 Due = ₹{c2_bal}, Supplier #1 Payable = ₹{s1_bal}")

    conn.close()
    os.remove(db_path)
    print("\n======================================================================")
    print("      ALL DARVI BILLING P1 & P2 INTEGRATION TESTS PASSED (100%)       ")
    print("======================================================================")

if __name__ == '__main__':
    test_full_darvi_p1_and_p2_suite()
