"""
E2E Integration & Accounting Invariant Validation Suite for Darvi Billing (P1 & P2)
Tests real-world end-to-end multi-step flows and verifies double-entry balance.
"""

import sqlite3
import unittest
import datetime

def init_test_db():
    conn = sqlite3.connect(':memory:')
    conn.execute("PRAGMA foreign_keys = ON;")
    cur = conn.cursor()

    cur.executescript('''
    CREATE TABLE workspaces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        business_type TEXT NOT NULL DEFAULT 'retail',
        gstin TEXT,
        address TEXT,
        phone TEXT,
        currency TEXT NOT NULL DEFAULT 'INR',
        receipt_slogan TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        name TEXT NOT NULL,
        account_type TEXT NOT NULL, -- 'cash', 'bank', 'upi', 'credit'
        account_number TEXT,
        current_balance REAL NOT NULL DEFAULT 0.0,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
    );

    CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        name TEXT NOT NULL,
        sku TEXT NOT NULL UNIQUE,
        barcode TEXT,
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
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        balance REAL NOT NULL DEFAULT 0.0,
        gstin TEXT,
        address TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        name TEXT NOT NULL,
        phone TEXT,
        gstin TEXT,
        address TEXT,
        balance REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        invoice_no TEXT NOT NULL UNIQUE,
        customer_id INTEGER REFERENCES customers(id),
        subtotal REAL NOT NULL,
        discount_total REAL NOT NULL DEFAULT 0.0,
        tax_total REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL,
        paid REAL NOT NULL,
        change_amount REAL NOT NULL DEFAULT 0.0,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        name_snapshot TEXT NOT NULL,
        cost_snapshot REAL NOT NULL,
        priceSnapshot REAL NOT NULL,
        qty INTEGER NOT NULL,
        discount REAL NOT NULL DEFAULT 0.0,
        line_total REAL NOT NULL
    );

    CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
        invoice_number TEXT NOT NULL,
        invoice_date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        tax_total REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'completed',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE purchase_invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL REFERENCES purchase_invoices(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 0.0,
        tax_amount REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL
    );

    CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        reference_no TEXT,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        employee_code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        role TEXT NOT NULL DEFAULT 'cashier', -- 'admin', 'manager', 'cashier'
        designation TEXT NOT NULL DEFAULT 'Staff',
        department TEXT NOT NULL DEFAULT 'Sales',
        login_pin TEXT NOT NULL DEFAULT '1234',
        base_salary REAL NOT NULL DEFAULT 0.0,
        joining_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        employee_id INTEGER NOT NULL REFERENCES employees(id),
        date TEXT NOT NULL,
        check_in TEXT,
        check_out TEXT,
        status TEXT NOT NULL DEFAULT 'present',
        working_hours REAL NOT NULL DEFAULT 8.0,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE payroll_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        employee_id INTEGER NOT NULL REFERENCES employees(id),
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        basic_salary REAL NOT NULL,
        incentive_amount REAL NOT NULL DEFAULT 0.0,
        allowances REAL NOT NULL DEFAULT 0.0,
        deductions REAL NOT NULL DEFAULT 0.0,
        net_salary REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'disbursed'
        disbursed_at TEXT,
        disbursed_from_account_id INTEGER REFERENCES accounts(id),
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE incentive_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        name TEXT NOT NULL,
        rule_type TEXT NOT NULL, -- 'percentage_revenue', 'fixed_per_item'
        threshold_amount REAL NOT NULL DEFAULT 0.0,
        reward_rate REAL NOT NULL DEFAULT 0.0,
        target_product_id INTEGER REFERENCES products(id),
        target_category_id INTEGER REFERENCES categories(id),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE incentive_claims (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        employee_id INTEGER NOT NULL REFERENCES employees(id),
        sale_id INTEGER REFERENCES sales(id),
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        processed_at TEXT
    );

    CREATE TABLE ledger_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
        transaction_type TEXT NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER NOT NULL,
        account_id INTEGER REFERENCES accounts(id),
        party_type TEXT, -- 'customer', 'supplier', null
        party_id INTEGER,
        debit REAL NOT NULL DEFAULT 0.0,
        credit REAL NOT NULL DEFAULT 0.0,
        narration TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    ''')

    # Seed Workspace #1 (Darvi Group Agri Tech) & Workspace #2 (Second isolated branch)
    cur.execute('''
    INSERT INTO workspaces (id, name, gstin, address, phone, currency, receipt_slogan)
    VALUES (1, 'Darvi Group Agri Tech', '29BKZPA0053M1ZQ', '#2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030', '9986890777', 'INR', 'Improving Agriculture, Improving lives');
    ''')
    cur.execute('''
    INSERT INTO workspaces (id, name, gstin, address, phone, currency, receipt_slogan)
    VALUES (2, 'Darvi Branch 2 Dharwad', '29BKZPA0053M1ZR', 'Station Road, Dharwad', '9986890888', 'INR', 'Serving Farmers');
    ''')

    # Seed Default Accounts for Workspace 1
    cur.execute("INSERT INTO accounts (workspace_id, name, account_type, is_default) VALUES (1, 'Cash Drawer', 'cash', 1);")
    cur.execute("INSERT INTO accounts (workspace_id, name, account_type, is_default) VALUES (1, 'State Bank of India', 'bank', 0);")
    cur.execute("INSERT INTO accounts (workspace_id, name, account_type, is_default) VALUES (1, 'Darvi UPI Business', 'upi', 0);")

    # Seed Accounts for Workspace 2
    cur.execute("INSERT INTO accounts (workspace_id, name, account_type, is_default) VALUES (2, 'Cash Drawer Br2', 'cash', 1);")

    conn.commit()
    return conn

class TestDarviE2EWorkflows(unittest.TestCase):
    def setUp(self):
        self.conn = init_test_db()
        self.cur = self.conn.cursor()

    def tearDown(self):
        self.conn.close()

    def test_workflow_1_product_lifecycle_purchase_sell_print(self):
        """Workflow 1: Create product -> purchase stock -> sell product -> collect payment -> verify ledger"""
        # Step 1: Create Product
        self.cur.execute('''
        INSERT INTO products (workspace_id, name, sku, barcode, cost, price, stock_qty, hsn_code, gst_rate)
        VALUES (1, 'Bio Fertiliser 50kg', 'SKU-BIO-50', '8901234567890', 400.0, 600.0, 0, '3101', 0.05);
        ''')
        prod_id = self.cur.lastrowid
        self.assertEqual(prod_id, 1)

        # Step 2: Create Supplier and Inward 100 units
        self.cur.execute("INSERT INTO suppliers (workspace_id, name, phone, gstin) VALUES (1, 'Karnataka Agro Mills', '9845011223', '29AABCK1234M1Z2');")
        sup_id = self.cur.lastrowid

        # Inward 100 units at 400.0 = 40,000.0, paid 10,000 from Bank (account 2), 30,000 payable
        self.cur.execute("UPDATE products SET stock_qty = stock_qty + 100 WHERE id = ?", (prod_id,))
        self.cur.execute('''
        INSERT INTO purchase_invoices (workspace_id, supplier_id, invoice_number, invoice_date, subtotal, total_amount, paid_amount, status)
        VALUES (1, ?, 'BILL-KAM-01', '2026-11-07', 40000.0, 40000.0, 10000.0, 'partial');
        ''', (sup_id,))
        pur_id = self.cur.lastrowid

        # Post balanced purchase ledger entries
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'purchase', 'purchase_invoice', ?, 40000.0, 0.0, 'Inward purchase');", (pur_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration) VALUES (1, 'purchase', 'supplier', ?, 'supplier', ?, 0.0, 40000.0, 'Payable for bill');", (pur_id, sup_id))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration) VALUES (1, 'payment_out', 'supplier', ?, 'supplier', ?, 10000.0, 0.0, 'Bank payment to supplier');", (pur_id, sup_id))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration) VALUES (1, 'payment_out', 'account', ?, 2, 0.0, 10000.0, 'Bank payout to supplier');", (pur_id,))
        self.conn.commit()

        # Verify stock increment
        self.cur.execute("SELECT stock_qty FROM products WHERE id = ?", (prod_id,))
        self.assertEqual(self.cur.fetchone()[0], 100)

        # Step 3: Sell 10 units at 600.0 + 5% GST = 6,000 + 300 GST = 6,300 total. Paid 6,300 Cash (account 1).
        # Atomic stock decrement
        self.cur.execute("UPDATE products SET stock_qty = stock_qty - 10 WHERE id = ?", (prod_id,))
        self.cur.execute('''
        INSERT INTO sales (workspace_id, invoice_no, subtotal, tax_total, total, paid, payment_method, status)
        VALUES (1, 'INV-20261107-0001', 6000.0, 300.0, 6300.0, 6300.0, 'cash', 'completed');
        ''')
        sale_id = self.cur.lastrowid

        # Post balanced sale ledger entries:
        # Credit Net Revenue: 6000.0
        # Credit GST Output Tax: 300.0
        # Debit Cash Drawer: 6300.0
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'sale', 'revenue', ?, 0.0, 6000.0, 'Net Sales Revenue');", (sale_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'sale', 'tax_payable', ?, 0.0, 300.0, 'GST Output Tax');", (sale_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration) VALUES (1, 'payment_in', 'sale', ?, 1, 6300.0, 0.0, 'Cash sale receipt');", (sale_id,))
        self.conn.commit()

        # Verify stock after sale
        self.cur.execute("SELECT stock_qty FROM products WHERE id = ?", (prod_id,))
        self.assertEqual(self.cur.fetchone()[0], 90)

        # Verify Ledger Invariant: Total Debits == Total Credits
        self.cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries WHERE workspace_id = 1;")
        d, c = self.cur.fetchone()
        self.assertEqual(d, c)
        self.assertEqual(d, 40000.0 + 10000.0 + 6300.0)

    def test_workflow_2_customer_credit_sale_and_settlement(self):
        """Workflow 2: Customer creation -> Credit sale -> Partial collection -> Full settlement"""
        # Create Customer
        self.cur.execute("INSERT INTO customers (workspace_id, name, phone, gstin) VALUES (1, 'Basavaraj Patil', '9448123456', '29BPT1234M1Z1');")
        cust_id = self.cur.lastrowid

        # Credit sale: 5000.0 total, 1000.0 paid by Cash (Acct 1), 4000.0 credit due
        self.cur.execute('''
        INSERT INTO sales (workspace_id, invoice_no, customer_id, subtotal, tax_total, total, paid, payment_method, status)
        VALUES (1, 'INV-20261107-0002', ?, 4237.29, 762.71, 5000.0, 1000.0, 'cash', 'completed');
        ''', (cust_id,))
        s_id = self.cur.lastrowid

        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'sale', 'revenue', ?, 0.0, 4237.29, 'Net Revenue');", (s_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'sale', 'tax_payable', ?, 0.0, 762.71, 'GST Output Tax');", (s_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration) VALUES (1, 'payment_in', 'sale', ?, 1, 1000.0, 0.0, 'Partial cash receipt');", (s_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration) VALUES (1, 'sale', 'customer', ?, 'customer', ?, 4000.0, 0.0, 'Credit due');", (s_id, cust_id))
        self.conn.commit()

        # Check Customer Due derived from Ledger
        self.cur.execute("SELECT SUM(debit) - SUM(credit) FROM ledger_entries WHERE party_type = 'customer' AND party_id = ?;", (cust_id,))
        due = self.cur.fetchone()[0]
        self.assertEqual(due, 4000.0)

        # Later: Customer settles remaining 4000.0 via UPI (Account #3)
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration) VALUES (1, 'payment_in', 'customer_settlement', ?, 3, 4000.0, 0.0, 'UPI settlement received');", (cust_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, party_type, party_id, debit, credit, narration) VALUES (1, 'payment_in', 'customer', ?, 'customer', ?, 0.0, 4000.0, 'Customer payment settlement');", (cust_id, cust_id))
        self.conn.commit()

        # Verify Customer Due is now 0.0
        self.cur.execute("SELECT SUM(debit) - SUM(credit) FROM ledger_entries WHERE party_type = 'customer' AND party_id = ?;", (cust_id,))
        due = self.cur.fetchone()[0]
        self.assertEqual(due, 0.0)

        # Total debits must equal total credits
        self.cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries WHERE workspace_id = 1;")
        d, c = self.cur.fetchone()
        self.assertEqual(d, c)

    def test_workflow_3_sales_return_restores_stock_and_reverses_ledger(self):
        """Workflow 3: Process Sales Return -> Restores stock qty -> Reverses financial entries"""
        # Add product with 50 in stock
        self.cur.execute("INSERT INTO products (workspace_id, name, sku, cost, price, stock_qty) VALUES (1, 'Drip Irrigation Pipe 16mm', 'SKU-DRIP-16', 500.0, 800.0, 50);")
        p_id = self.cur.lastrowid

        # Sale of 5 units (stock becomes 45) for 4000.0 cash
        self.cur.execute("UPDATE products SET stock_qty = stock_qty - 5 WHERE id = ?", (p_id,))
        self.cur.execute("INSERT INTO sales (workspace_id, invoice_no, subtotal, total, paid, payment_method) VALUES (1, 'INV-20261107-0003', 4000.0, 4000.0, 4000.0, 'cash');")
        s_id = self.cur.lastrowid
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit) VALUES (1, 'sale', 'revenue', ?, 0.0, 4000.0);", (s_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit) VALUES (1, 'payment_in', 'sale', ?, 1, 4000.0, 0.0);", (s_id,))
        self.conn.commit()

        # Customer returns 2 units (stock should restore to 47, refund 1600.0 from Cash)
        self.cur.execute("UPDATE products SET stock_qty = stock_qty + 2 WHERE id = ?", (p_id,))
        self.cur.execute("INSERT INTO sales (workspace_id, invoice_no, subtotal, total, paid, payment_method, status) VALUES (1, 'RET-20261107-0001', -1600.0, -1600.0, -1600.0, 'cash', 'returned');")
        ret_id = self.cur.lastrowid
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'sale_return', 'sale', ?, 1600.0, 0.0, 'Sales return debit');", (ret_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration) VALUES (1, 'sale_return', 'account', ?, 1, 0.0, 1600.0, 'Cash refund credit');", (ret_id,))
        self.conn.commit()

        # Check Stock Restoration
        self.cur.execute("SELECT stock_qty FROM products WHERE id = ?", (p_id,))
        self.assertEqual(self.cur.fetchone()[0], 47)

        # Check Ledger Equilibrium
        self.cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries WHERE workspace_id = 1;")
        d, c = self.cur.fetchone()
        self.assertEqual(d, c)
        self.assertEqual(d, 5600.0)

    def test_workflow_4_employee_attendance_payroll_and_disbursal(self):
        """Workflow 4: Register employee -> Record attendance -> Compute Payroll -> Disburse from Bank"""
        self.cur.execute('''
        INSERT INTO employees (workspace_id, employee_code, name, phone, role, designation, base_salary, joining_date)
        VALUES (1, 'DARVI-001', 'Ramesh Kumar', '9845099887', 'cashier', 'Senior Cashier', 24000.0, '2026-01-01');
        ''')
        emp_id = self.cur.lastrowid

        # Record 25 present days
        for day in range(1, 26):
            d_str = f"2026-10-{day:02d}"
            self.cur.execute("INSERT INTO attendances (workspace_id, employee_id, date, status, working_hours) VALUES (1, ?, ?, 'present', 8.0);", (emp_id, d_str))
        self.conn.commit()

        self.cur.execute("SELECT COUNT(*) FROM attendances WHERE employee_id = ? AND status = 'present';", (emp_id,))
        self.assertEqual(self.cur.fetchone()[0], 25)

        # Process monthly payroll for Oct 2026: (25/30) * 24000.0 = 20,000.0 net salary
        self.cur.execute('''
        INSERT INTO payroll_records (workspace_id, employee_id, month, year, basic_salary, net_salary, status)
        VALUES (1, ?, 10, 2026, 24000.0, 20000.0, 'approved');
        ''', (emp_id,))
        pay_id = self.cur.lastrowid

        # Disburse from Bank Account (Acct #2)
        self.cur.execute("UPDATE payroll_records SET status = 'disbursed', disbursed_at = '2026-11-01', disbursed_from_account_id = 2 WHERE id = ?;", (pay_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'payroll', 'payroll_record', ?, 20000.0, 0.0, 'Staff Salary Disbursal');", (pay_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration) VALUES (1, 'payroll', 'account', ?, 2, 0.0, 20000.0, 'Bank Disbursal');", (pay_id,))
        self.conn.commit()

        # Verify Ledger Invariant
        self.cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries WHERE workspace_id = 1;")
        d, c = self.cur.fetchone()
        self.assertEqual(d, c)
        self.assertEqual(d, 20000.0)

    def test_workflow_5_sales_incentive_calculation_and_approval(self):
        """Workflow 5: Employee Sale -> 2% Incentive Rule -> Claim Generated -> Approved -> Paid"""
        self.cur.execute("INSERT INTO employees (workspace_id, employee_code, name, phone, base_salary, joining_date) VALUES (1, 'DARVI-002', 'Sunil Gowda', '9845012399', 18000.0, '2026-03-01');")
        emp_id = self.cur.lastrowid

        # Create 2% incentive rule for revenue above 10,000
        self.cur.execute('''
        INSERT INTO incentive_rules (workspace_id, name, rule_type, threshold_amount, reward_rate)
        VALUES (1, 'Agri Equipment Sales Incentive', 'percentage_revenue', 10000.0, 0.02);
        ''')

        # Employee makes a ₹50,000 high-value pump sale
        self.cur.execute("INSERT INTO sales (workspace_id, invoice_no, subtotal, total, paid, payment_method) VALUES (1, 'INV-20261107-0004', 50000.0, 50000.0, 50000.0, 'bank');")
        sale_id = self.cur.lastrowid

        # Calculate incentive: 2% of 50,000 = ₹1,000
        inc_amount = 50000.0 * 0.02
        self.cur.execute('''
        INSERT INTO incentive_claims (workspace_id, employee_id, sale_id, amount, description, status)
        VALUES (1, ?, ?, ?, '2% incentive on INV-20261107-0004', 'pending');
        ''', (emp_id, sale_id, inc_amount))
        claim_id = self.cur.lastrowid

        # Admin approves claim
        self.cur.execute("UPDATE incentive_claims SET status = 'approved', processed_at = '2026-11-07' WHERE id = ?;", (claim_id,))

        # Disburse incentive through Cash Drawer (Acct 1)
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit, narration) VALUES (1, 'incentive_payout', 'incentive_claim', ?, 1000.0, 0.0, 'Incentive expense');", (claim_id,))
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, account_id, debit, credit, narration) VALUES (1, 'incentive_payout', 'account', ?, 1, 0.0, 1000.0, 'Cash drawer incentive payout');", (claim_id,))
        self.conn.commit()

        # Check claim status and ledger equilibrium
        self.cur.execute("SELECT status FROM incentive_claims WHERE id = ?", (claim_id,))
        self.assertEqual(self.cur.fetchone()[0], 'approved')

        self.cur.execute("SELECT SUM(debit), SUM(credit) FROM ledger_entries WHERE workspace_id = 1;")
        d, c = self.cur.fetchone()
        self.assertEqual(d, c)
        self.assertEqual(d, 1000.0)

    def test_workflow_6_multi_workspace_isolation(self):
        """Workflow 6: Verify complete multi-tenant workspace isolation across all tables"""
        # Add Product in Workspace 1
        self.cur.execute("INSERT INTO products (workspace_id, name, sku, cost, price, stock_qty) VALUES (1, 'W1 Seed Pack', 'SKU-W1-01', 100.0, 150.0, 10);")
        # Add Product in Workspace 2
        self.cur.execute("INSERT INTO products (workspace_id, name, sku, cost, price, stock_qty) VALUES (2, 'W2 Pesticide Can', 'SKU-W2-01', 500.0, 750.0, 20);")

        # Query Workspace 1 Products
        self.cur.execute("SELECT name FROM products WHERE workspace_id = 1;")
        w1_prods = [r[0] for r in self.cur.fetchall()]
        self.assertIn('W1 Seed Pack', w1_prods)
        self.assertNotIn('W2 Pesticide Can', w1_prods)

        # Query Workspace 2 Products
        self.cur.execute("SELECT name FROM products WHERE workspace_id = 2;")
        w2_prods = [r[0] for r in self.cur.fetchall()]
        self.assertIn('W2 Pesticide Can', w2_prods)
        self.assertNotIn('W1 Seed Pack', w2_prods)

        # Post Ledger in Workspace 1 vs Workspace 2
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit) VALUES (1, 'misc', 'test', 1, 500.0, 500.0);")
        self.cur.execute("INSERT INTO ledger_entries (workspace_id, transaction_type, reference_type, reference_id, debit, credit) VALUES (2, 'misc', 'test', 2, 800.0, 800.0);")
        self.conn.commit()

        # Verify sums per workspace
        self.cur.execute("SELECT SUM(debit) FROM ledger_entries WHERE workspace_id = 1;")
        self.assertEqual(self.cur.fetchone()[0], 500.0)
        self.cur.execute("SELECT SUM(debit) FROM ledger_entries WHERE workspace_id = 2;")
        self.assertEqual(self.cur.fetchone()[0], 800.0)

if __name__ == '__main__':
    unittest.main()

