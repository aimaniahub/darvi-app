import 'package:drift/drift.dart';

import '../../../core/models/app_models.dart';
import '../../local/db/app_database.dart';

/// Corporate identity constants for Darvi Group Agri Tech
class DarviCorporateInfo {
  static const int primaryWorkspaceId = 1;
  static const String businessName = 'Darvi Group Agri Tech';
  static const String gstin = '29BKZPA0053M1ZQ';
  static const String address = '#2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030';
  static const String phone = '9986890777';
  static const String stateCode = '29';
  static const String currency = 'INR';
  static const String receiptSlogan = 'Improving Agriculture, Improving lives.';
  static const String receiptTerms = 'Goods once sold will not be taken back or exchanged.\nNo cash payments accepted.';
}

/// Product SKU to image map
const _productImageUrls = <String, String>{
  'BEV001': 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=300&h=300&fit=crop',
  'BEV002': 'https://images.unsplash.com/photo-1567103472471-e7e7da177e22?w=300&h=300&fit=crop',
  'BEV003': 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=300&h=300&fit=crop',
  'BEV004': 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=300&h=300&fit=crop',
  'BEV005': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=300&h=300&fit=crop',
  'SNK001': 'https://images.unsplash.com/photo-1576675784201-0e142b423952?w=300&h=300&fit=crop',
  'SNK002': 'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=300&h=300&fit=crop',
  'SNK003': 'https://images.unsplash.com/photo-1574570069012-f013e2fbc0af?w=300&h=300&fit=crop',
  'SNK004': 'https://images.unsplash.com/photo-1505686994434-e3cc5abf1330?w=300&h=300&fit=crop',
  'SNK005': 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=300&h=300&fit=crop',
  'DAR001': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300&h=300&fit=crop',
  'DAR002': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=300&h=300&fit=crop',
  'DAR003': 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=300&h=300&fit=crop',
  'DAR004': 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=300&h=300&fit=crop',
  'DAR005': 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=300&h=300&fit=crop',
  'HSH001': 'https://images.unsplash.com/photo-1585512458118-c22fa20dfe17?w=300&h=300&fit=crop',
  'HSH002': 'https://images.unsplash.com/photo-1610557892470-55d9e80c0bce?w=300&h=300&fit=crop',
  'HSH003': 'https://images.unsplash.com/photo-1584464491033-06628f3a6b7b?w=300&h=300&fit=crop',
  'PRS001': 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=300&h=300&fit=crop',
  'PRS002': 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=300&h=300&fit=crop',
};

class SeedData {
  const SeedData(this.db);

  final AppDatabase db;

  Future<void> ensureSeeded() async {
    // 0. Ensure schema tables and auto-heal any legacy text date values before reading tables
    await db.ensureGroup1SchemaTables();
    await db.ensureGroup2SchemaTables();
    await db.ensureGroup3SchemaTables();
    await db.ensureGroup4SchemaTables();
    await db.ensurePhase4_4SchemaTables();
    await db.sanitizeDateTimeColumns();

    // 1. Ensure primary Darvi workspace exists
    await _ensurePrimaryWorkspace();

    // 2. Ensure Darvi default financial accounts exist (Cash, Bank, UPI)
    await _ensureDefaultAccounts();

    // 3. Ensure Darvi corporate app settings
    await _ensureSettings();

    // 4. Ensure default staff
    await _ensureDefaultEmployees();

    // 5. Ensure default users for access control
    await _ensureDefaultUsers();

    // 5. Ensure products and party data
    final productCount = await db.select(db.products).get().then((rows) => rows.length);
    if (productCount > 0) {
      await _ensureProductImages();
      await _ensureVikshhaProjectsAndPlots();
      return;
    }

    await _seedCategoriesAndProducts();
    await _seedCustomersSuppliers();
    await _ensureVikshhaProjectsAndPlots();
  }

  Future<void> _ensureVikshhaProjectsAndPlots() async {
    final existingProjects = await db.select(db.projects).get();
    if (existingProjects.isEmpty) {
      await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: const Value(1),
              workspaceId: DarviCorporateInfo.primaryWorkspaceId,
              name: 'Vikshha Agro Farmland - Phase 1',
              code: 'VK-P1',
              location: 'Gokul Road, Near Airport Bypass, Hubli, Karnataka',
              totalArea: const Value(25.5), // 25.5 acres
              totalPlots: const Value(45),
              description: const Value('Managed agro-forestry plots featuring Sandalwood, Mahogany and automated drip irrigation.'),
              status: const Value('active'),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: const Value(2),
              workspaceId: DarviCorporateInfo.primaryWorkspaceId,
              name: 'Vikshha Organic Orchards - Phase 2',
              code: 'VK-P2',
              location: 'Dharwad High-Tech Agri Corridor, Karnataka',
              totalArea: const Value(18.0),
              totalPlots: const Value(30),
              description: const Value('High-density Kesar Mango and Malabar Neem plantation estate with resort amenities.'),
              status: const Value('active'),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    final existingPlots = await db.select(db.plots).get();
    if (existingPlots.isEmpty) {
      final now = DateTime.now();
      await db.batch((batch) {
        batch.insertAll(db.plots, [
          PlotsCompanion.insert(
            id: const Value(1),
            workspaceId: DarviCorporateInfo.primaryWorkspaceId,
            projectId: 1,
            plotNumber: 'A-01',
            uniquePlotId: 'VK-P1-A01',
            dimensions: '40 x 60 ft',
            areaSqFt: 2400.0,
            surveyNumber: const Value('Sy No 142/2A'),
            status: const Value('available'),
            basePrice: 500.0, // Rs 500 per sq ft
            totalPrice: 1200000.0, // Rs 12 Lakhs
            cropType: const Value('Sandalwood & Mahogany'),
            plantationDetails: const Value('25 Sandalwood saplings with automated Netafim drip system'),
            notes: const Value('East-facing premium corner plot'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          PlotsCompanion.insert(
            id: const Value(2),
            workspaceId: DarviCorporateInfo.primaryWorkspaceId,
            projectId: 1,
            plotNumber: 'A-02',
            uniquePlotId: 'VK-P1-A02',
            dimensions: '60 x 80 ft',
            areaSqFt: 4800.0,
            surveyNumber: const Value('Sy No 142/2B'),
            status: const Value('available'),
            basePrice: 500.0,
            totalPrice: 2400000.0, // Rs 24 Lakhs
            cropType: const Value('Teakwood & Fruit Trees'),
            plantationDetails: const Value('50 Red Teakwood and Guava trees with organic mulching'),
            notes: const Value('Adjacent to main 30-ft internal avenue road'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          PlotsCompanion.insert(
            id: const Value(3),
            workspaceId: DarviCorporateInfo.primaryWorkspaceId,
            projectId: 1,
            plotNumber: 'A-03',
            uniquePlotId: 'VK-P1-A03',
            dimensions: '40 x 60 ft',
            areaSqFt: 2400.0,
            surveyNumber: const Value('Sy No 142/3'),
            status: const Value('reserved'),
            basePrice: 500.0,
            totalPrice: 1200000.0,
            cropType: const Value('Sandalwood'),
            plantationDetails: const Value('25 Sandalwood trees planted 2025'),
            notes: const Value('Token advance received, token hold for 7 days'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          PlotsCompanion.insert(
            id: const Value(4),
            workspaceId: DarviCorporateInfo.primaryWorkspaceId,
            projectId: 2,
            plotNumber: 'B-01',
            uniquePlotId: 'VK-P2-B01',
            dimensions: '50 x 100 ft',
            areaSqFt: 5000.0,
            surveyNumber: const Value('Sy No 89/1'),
            status: const Value('available'),
            basePrice: 450.0,
            totalPrice: 2250000.0,
            cropType: const Value('Organic Kesar Mango & Neem'),
            plantationDetails: const Value('40 Grafted Kesar Mango trees with solar sensor drip'),
            notes: const Value('Panoramic hill view, club house access'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        ], mode: InsertMode.insertOrIgnore);
      });
    }

    // Ensure sample Farmland CRM leads
    final existingLeads = await db.select(db.leads).get();
    if (existingLeads.isEmpty) {
      final now = DateTime.now();
      await db.batch((batch) {
        batch.insertAll(db.leads, [
          LeadsCompanion.insert(
            id: const Value(1),
            workspaceId: DarviCorporateInfo.primaryWorkspaceId,
            name: 'Ramesh Kulkarni',
            phone: '9845112233',
            email: const Value('ramesh.kulkarni@example.com'),
            source: const Value('Agri Expo'),
            interestedProjectId: const Value(1),
            budget: const Value(1500000.0),
            requirements: const Value('Looking for 2400 sq ft plot with Sandalwood plantation for retirement.'),
            stage: const Value('site_visit'),
            assignedEmployeeId: const Value(1),
            nextFollowUpDate: Value(now.add(const Duration(days: 2))),
            notes: const Value('Site visit scheduled for coming Sunday morning 10 AM.'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          LeadsCompanion.insert(
            id: const Value(2),
            workspaceId: DarviCorporateInfo.primaryWorkspaceId,
            name: 'Ananya Patil',
            phone: '9448223344',
            email: const Value('ananya.patil@example.com'),
            source: const Value('Digital Ads'),
            interestedProjectId: const Value(2),
            budget: const Value(2500000.0),
            requirements: const Value('Interested in 5000 sq ft Mango orchard for weekend farming.'),
            stage: const Value('interested'),
            assignedEmployeeId: const Value(2),
            nextFollowUpDate: Value(now.add(const Duration(days: 1))),
            notes: const Value('Sent Vikshha Phase 2 brochure over WhatsApp.'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        ], mode: InsertMode.insertOrIgnore);
      });
    }

    // Ensure sample site visits
    try {
      final existingVisits = await db.select(db.siteVisits).get();
      if (existingVisits.isEmpty) {
        final now = DateTime.now();
        await db.into(db.siteVisits).insert(
              SiteVisitsCompanion.insert(
                id: const Value(1),
                workspaceId: DarviCorporateInfo.primaryWorkspaceId,
                leadId: 1,
                projectId: const Value(1),
                plotId: const Value(1),
                scheduledDate: now.add(const Duration(days: 2)),
                conductedByEmployeeId: const Value(1),
                feedback: const Value('Customer interested in soil health report and boundary fencing.'),
                status: const Value('scheduled'),
                createdAt: Value(now),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    } catch (_) {}

    // Ensure sample CRM follow-ups
    try {
      final existingFollowUps = await db.customSelect('SELECT id FROM crm_follow_ups;').get();
      if (existingFollowUps.isEmpty) {
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final dueTomorrowSeconds = nowSeconds + 86400;
        await db.customStatement('''
          INSERT OR IGNORE INTO crm_follow_ups (
            id, workspace_id, lead_id, employee_id, scheduled_date, status, remarks, created_at
          ) VALUES (
            1, 1, 1, 1, ?, 'pending', 'Confirm weekend site visit logistics and vehicle pickup', ?
          );
        ''', [dueTomorrowSeconds, nowSeconds]);
      }
    } catch (_) {}

    // Ensure sample Quotation
    try {
      final existingQuotes = await db.select(db.quotations).get();
      if (existingQuotes.isEmpty) {
        final now = DateTime.now();
        await db.into(db.quotations).insert(
              QuotationsCompanion.insert(
                id: const Value(1),
                workspaceId: DarviCorporateInfo.primaryWorkspaceId,
                quotationNumber: 'QT-2026-0001',
                customerName: 'Ramesh Kulkarni',
                customerPhone: '9845112233',
                leadId: const Value(1),
                quotationDate: Value(now),
                validUntil: now.add(const Duration(days: 15)),
                subtotal: 1200000.0,
                totalAmount: 1200000.0,
                status: const Value('sent'),
                terms: const Value('Valid for 15 days. Payment schedule as per agreement milestone.'),
                notes: const Value('Quotation for Farmland Plot VK-P1-A01 (2400 sq ft) with Sandalwood plantation.'),
                createdAt: Value(now),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await db.into(db.quotationItems).insert(
              QuotationItemsCompanion.insert(
                quotationId: 1,
                itemType: const Value('plot'),
                referenceId: const Value(1),
                description: 'Plot VK-P1-A01 (2400 sq ft Sandalwood Estate)',
                quantity: const Value(1.0),
                unitPrice: 1200000.0,
                total: 1200000.0,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    } catch (_) {}

    // Ensure sample Plot Booking
    try {
      final existingBookings = await db.select(db.plotBookings).get();
      if (existingBookings.isEmpty) {
        final now = DateTime.now();
        await db.into(db.plotBookings).insert(
              PlotBookingsCompanion.insert(
                id: const Value(1),
                workspaceId: DarviCorporateInfo.primaryWorkspaceId,
                bookingNumber: 'BK-2026-0001',
                plotId: 3, // Plot A-03
                customerId: 1,
                employeeId: const Value(1),
                bookingDate: Value(now),
                totalPlotValue: 1200000.0,
                bookingAmount: 100000.0,
                paymentAccountId: const Value(1),
                paymentMode: const Value('upi'),
                referenceNo: const Value('UPI/2026/99812'),
                status: const Value('booked'),
                notes: const Value('Token advance paid. Balance in 3 milestone installments.'),
                createdAt: Value(now),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await db.into(db.bookingInstallments).insert(
              BookingInstallmentsCompanion.insert(
                bookingId: 1,
                installmentNumber: 1,
                title: 'Token Advance',
                dueDate: now,
                amount: 100000.0,
                paidAmount: const Value(100000.0),
                paidDate: Value(now),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await db.into(db.bookingInstallments).insert(
              BookingInstallmentsCompanion.insert(
                bookingId: 1,
                installmentNumber: 2,
                title: 'Agreement Milestone (40%)',
                dueDate: now.add(const Duration(days: 30)),
                amount: 480000.0,
                paidAmount: const Value(0.0),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    } catch (_) {}
  }

  Future<void> _ensurePrimaryWorkspace() async {
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            id: const Value(1),
            businessName: DarviCorporateInfo.businessName,
            gstin: const Value(DarviCorporateInfo.gstin),
            address: const Value(DarviCorporateInfo.address),
            phone: const Value(DarviCorporateInfo.phone),
            receiptSlogan: const Value(DarviCorporateInfo.receiptSlogan),
            receiptTerms: const Value(DarviCorporateInfo.receiptTerms),
            currency: const Value(DarviCorporateInfo.currency),
            isDefault: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.workspaces).insert(
          const WorkspacesCompanion(
            id: Value(2),
            businessName: Value('Darvi Agro Dharwad Branch'),
            gstin: Value('29AABBD1234F1Z9'),
            address: Value('PB Road, Dharwad, Karnataka 580001'),
            phone: Value('+91 836 244 5566'),
            currency: Value('INR'),
            isDefault: Value(false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _ensureDefaultAccounts() async {
    await db.into(db.accounts).insert(
          const AccountsCompanion(
            id: Value(1),
            workspaceId: Value(1),
            name: Value('Store Cash Drawer'),
            type: Value('cash'),
            isDefault: Value(false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.accounts).insert(
          const AccountsCompanion(
            id: Value(2),
            workspaceId: Value(1),
            name: Value('Company Bank Account'),
            type: Value('bank'),
            isDefault: Value(false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.accounts).insert(
          const AccountsCompanion(
            id: Value(3),
            workspaceId: Value(1),
            name: Value('Store UPI Account'),
            type: Value('upi'),
            isDefault: Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );

    // Workspace 2 Accounts
    await db.into(db.accounts).insert(
          const AccountsCompanion(
            id: Value(4),
            workspaceId: Value(2),
            name: Value('Dharwad Branch Cash Drawer'),
            type: Value('cash'),
            isDefault: Value(false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.accounts).insert(
          const AccountsCompanion(
            id: Value(5),
            workspaceId: Value(2),
            name: Value('Dharwad Branch Bank Account'),
            type: Value('bank'),
            isDefault: Value(false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _ensureDefaultEmployees() async {
    await db.into(db.employees).insert(
          const EmployeesCompanion(
            id: Value(1),
            workspaceId: Value(1),
            employeeCode: Value('EMP001'),
            name: Value('Suresh Totad'),
            phone: Value('9986890777'),
            role: Value('admin'),
            designation: Value('Managing Director'),
            department: Value('Management'),
            loginPin: Value('9988'),
            baseSalary: Value(50000.0),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.employees).insert(
          const EmployeesCompanion(
            id: Value(2),
            workspaceId: Value(1),
            employeeCode: Value('EMP002'),
            name: Value('Manjunath Patil'),
            phone: Value('9845012345'),
            role: Value('manager'),
            designation: Value('Store Manager'),
            department: Value('Operations'),
            loginPin: Value('5544'),
            baseSalary: Value(30000.0),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.employees).insert(
          const EmployeesCompanion(
            id: Value(3),
            workspaceId: Value(1),
            employeeCode: Value('EMP003'),
            name: Value('Priya Sharma'),
            phone: Value('9988001122'),
            role: Value('cashier'),
            designation: Value('Frontline Cashier'),
            department: Value('Sales'),
            loginPin: Value('1122'),
            baseSalary: Value(20000.0),
          ),
          mode: InsertMode.insertOrIgnore,
        );

    // Ensure Default Shifts
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final existingShifts = await db.customSelect('SELECT COUNT(*) as count FROM shifts').getSingle();
    if ((existingShifts.data['count'] as num) == 0) {
      await db.customStatement('''
        INSERT INTO shifts (id, workspace_id, name, start_time, end_time, break_minutes, grace_minutes, is_overnight, is_active, created_at)
        VALUES (1, 1, 'General Day Shift', '09:00', '18:00', 30, 15, 0, 1, ?)
      ''', [nowSeconds]);
      await db.customStatement('''
        INSERT INTO shifts (id, workspace_id, name, start_time, end_time, break_minutes, grace_minutes, is_overnight, is_active, created_at)
        VALUES (2, 1, 'Morning Shift', '07:00', '15:30', 30, 15, 0, 1, ?)
      ''', [nowSeconds]);
      await db.customStatement('''
        INSERT INTO shifts (id, workspace_id, name, start_time, end_time, break_minutes, grace_minutes, is_overnight, is_active, created_at)
        VALUES (3, 1, 'Evening Shift', '14:00', '22:30', 30, 15, 0, 1, ?)
      ''', [nowSeconds]);
    }

    // Ensure Default Incentive Rules
    final existingRules = await db.customSelect('SELECT COUNT(*) as count FROM incentive_rules').getSingle();
    if ((existingRules.data['count'] as num) == 0) {
      await db.customStatement('''
        INSERT INTO incentive_rules (id, workspace_id, name, rule_type, threshold_amount, reward_rate, is_active, created_at)
        VALUES (1, 1, '5% Retail Sales Incentive', 'percentage_revenue', 25000.0, 5.0, 1, ?)
      ''', [nowSeconds]);
      await db.customStatement('''
        INSERT INTO incentive_rules (id, workspace_id, name, rule_type, threshold_amount, reward_rate, is_active, created_at)
        VALUES (2, 1, 'Super Performer Monthly Bonus', 'fixed_bonus', 100000.0, 5000.0, 1, ?)
      ''', [nowSeconds]);
    }

    // Ensure Default Sales Targets
    final existingTargets = await db.customSelect('SELECT COUNT(*) as count FROM sales_targets').getSingle();
    if ((existingTargets.data['count'] as num) == 0) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59).millisecondsSinceEpoch ~/ 1000;
      await db.customStatement('''
        INSERT INTO sales_targets (id, workspace_id, employee_id, month, year, target_revenue, target_type, target_amount, current_amount, start_date, end_date, status, created_at)
        VALUES (1, 1, 3, ?, ?, 150000.0, 'revenue', 150000.0, 48500.0, ?, ?, 'in_progress', ?)
      ''', [now.month, now.year, start, end, nowSeconds]);
    }
  }

  Future<void> _ensureDefaultUsers() async {
    final existingUsers = await db.customSelect('SELECT COUNT(*) as count FROM users').getSingle();
    if ((existingUsers.data['count'] as num) == 0) {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 1. Admin: username 'admin', pin '1234', password 'admin123'
      const adminSalt = 'darvi_salt_admin';
      final adminPasswordHash = HashHelper.hashCredential('admin123', adminSalt);
      final adminPinHash = HashHelper.hashCredential('1234', adminSalt);
      await db.customStatement('''
        INSERT INTO users (id, workspace_id, name, username, email, phone, role, is_active, password_hash, pin_hash, salt, created_at)
        VALUES (1, 1, 'Darvi Administrator', 'admin', 'admin@darvigroups.com', '9986890777', 'admin', 1, ?, ?, ?, ?)
      ''', [adminPasswordHash, adminPinHash, adminSalt, nowSeconds]);

      // 2. Manager: username 'manager', pin '2222', password 'manager123'
      const mgrSalt = 'darvi_salt_manager';
      final mgrPasswordHash = HashHelper.hashCredential('manager123', mgrSalt);
      final mgrPinHash = HashHelper.hashCredential('2222', mgrSalt);
      await db.customStatement('''
        INSERT INTO users (id, workspace_id, name, username, email, phone, role, is_active, password_hash, pin_hash, salt, created_at)
        VALUES (2, 1, 'Ramesh Kumar (Store Manager)', 'manager', 'ramesh@darvigroups.com', '9845112233', 'manager', 1, ?, ?, ?, ?)
      ''', [mgrPasswordHash, mgrPinHash, mgrSalt, nowSeconds]);

      // 3. Cashier: username 'cashier', pin '1111'
      const cashierSalt = 'darvi_salt_cashier';
      final cashierPinHash = HashHelper.hashCredential('1111', cashierSalt);
      await db.customStatement('''
        INSERT INTO users (id, workspace_id, name, username, email, phone, role, is_active, pin_hash, salt, created_at)
        VALUES (3, 1, 'Sunil Patil (Senior Cashier)', 'cashier', 'sunil@darvigroups.com', '9845223344', 'cashier', 1, ?, ?, ?)
      ''', [cashierPinHash, cashierSalt, nowSeconds]);

      // 4. Field Officer: username 'field_officer', pin '3333'
      const foSalt = 'darvi_salt_fo';
      final foPinHash = HashHelper.hashCredential('3333', foSalt);
      await db.customStatement('''
        INSERT INTO users (id, workspace_id, name, username, email, phone, role, is_active, pin_hash, salt, created_at)
        VALUES (4, 1, 'Anand Deshmukh (Field Officer)', 'field_officer', 'anand@darvigroups.com', '9845334455', 'field_officer', 1, ?, ?, ?)
      ''', [foPinHash, foSalt, nowSeconds]);

      // 5. Agronomist: username 'agronomist', pin '4444'
      const agroSalt = 'darvi_salt_agro';
      final agroPinHash = HashHelper.hashCredential('4444', agroSalt);
      await db.customStatement('''
        INSERT INTO users (id, workspace_id, name, username, email, phone, role, is_active, pin_hash, salt, created_at)
        VALUES (5, 1, 'Dr. Priya Kulkarni (Agronomist)', 'agronomist', 'priya@darvigroups.com', '9845445566', 'agronomist', 1, ?, ?, ?)
      ''', [agroPinHash, agroSalt, nowSeconds]);

      // Seed initial activity log
      await db.customStatement('''
        INSERT INTO user_activity_logs (workspace_id, user_id, username, module, action, details, created_at)
        VALUES (1, 1, 'admin', 'system', 'seed', 'Initial system seeding with role-based access control users', ?)
      ''', [nowSeconds]);
    }
  }

  Future<void> _ensureSettings() async {
    final existing = await (db.select(db.appSettings)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (existing == null) {
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(
              id: const Value(1),
              storeName: const Value(DarviCorporateInfo.businessName),
              currency: const Value(DarviCorporateInfo.currency),
              taxEnabled: const Value(true),
              taxRate: const Value(0.18),
              receiptHeader: const Value(
                '${DarviCorporateInfo.businessName}\n${DarviCorporateInfo.address}\nGSTIN: ${DarviCorporateInfo.gstin} | Ph: ${DarviCorporateInfo.phone}',
              ),
              receiptFooter: const Value(
                '${DarviCorporateInfo.receiptSlogan}\n${DarviCorporateInfo.receiptTerms}',
              ),
              language: const Value('en'),
              allowNegativeStock: const Value(false),
              cashierPin: const Value('1234'),
              adminPassword: const Value('admin123'),
            ),
          );
    } else {
      await (db.update(db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
            AppSettingsCompanion(
              storeName: const Value(DarviCorporateInfo.businessName),
              currency: const Value(DarviCorporateInfo.currency),
              taxEnabled: const Value(true),
              taxRate: const Value(0.18),
              receiptHeader: const Value(
                '${DarviCorporateInfo.businessName}\n${DarviCorporateInfo.address}\nGSTIN: ${DarviCorporateInfo.gstin} | Ph: ${DarviCorporateInfo.phone}',
              ),
              receiptFooter: const Value(
                '${DarviCorporateInfo.receiptSlogan}\n${DarviCorporateInfo.receiptTerms}',
              ),
            ),
          );
    }
  }

  Future<void> _ensureProductImages() async {
    for (final entry in _productImageUrls.entries) {
      final rows = await (db.select(db.products)..where((t) => t.sku.equals(entry.key))).get();
      for (final row in rows) {
        if (row.imagePath == null) {
          await (db.update(db.products)..where((t) => t.id.equals(row.id))).write(
            ProductsCompanion(imagePath: Value(entry.value)),
          );
        }
      }
    }
  }

  Future<void> _seedCategoriesAndProducts() async {
    final categories = ['Beverages', 'Snacks', 'Dairy', 'Household', 'Personal Care'];
    final categoryIds = <String, int>{};

    for (final name in categories) {
      final id = await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: name), mode: InsertMode.insertOrIgnore);
      if (id > 0) {
        categoryIds[name] = id;
      }
    }

    final existing = await db.select(db.categories).get();
    for (final category in existing) {
      categoryIds[category.name] = category.id;
    }

    final now = DateTime.now();
    final products = <ProductsCompanion>[
      // Beverages (HSN 2202, 12% GST)
      _product(name: 'Coca Cola 330ml',     sku: 'BEV001', barcode: '622300136001', categoryId: categoryIds['Beverages'],    cost: 8,   price: 12,  stockQty: 50, lowStockThreshold: 10, hsnCode: '2202', gstRate: 12.0),
      _product(name: 'Pepsi 330ml',         sku: 'BEV002', barcode: '622300136002', categoryId: categoryIds['Beverages'],    cost: 8,   price: 12,  stockQty: 42, lowStockThreshold: 10, hsnCode: '2202', gstRate: 12.0),
      _product(name: 'Orange Juice 1L',     sku: 'BEV003', barcode: '622300136003', categoryId: categoryIds['Beverages'],    cost: 18,  price: 25,  stockQty: 15, lowStockThreshold: 5,  hsnCode: '2202', gstRate: 12.0),
      _product(name: 'Mineral Water 600ml', sku: 'BEV004', barcode: '622300136004', categoryId: categoryIds['Beverages'],    cost: 4,   price: 6,   stockQty: 100, lowStockThreshold: 20, hsnCode: '2201', gstRate: 18.0),
      _product(name: 'Energy Drink',        sku: 'BEV005', barcode: '622300136005', categoryId: categoryIds['Beverages'],    cost: 22,  price: 30,  stockQty: 12, lowStockThreshold: 5,  hsnCode: '2202', gstRate: 28.0),
      // Snacks (HSN 1905 / 2008, 12% GST)
      _product(name: 'Potato Chips Large',  sku: 'SNK001', barcode: '622300236001', categoryId: categoryIds['Snacks'],       cost: 9,   price: 15,  stockQty: 35, lowStockThreshold: 8,  hsnCode: '2008', gstRate: 12.0),
      _product(name: 'Chocolate Bar',       sku: 'SNK002', barcode: '622300236002', categoryId: categoryIds['Snacks'],       cost: 7,   price: 10,  stockQty: 60, lowStockThreshold: 12, hsnCode: '1806', gstRate: 18.0),
      _product(name: 'Mixed Nuts 200g',     sku: 'SNK003', barcode: '622300236003', categoryId: categoryIds['Snacks'],       cost: 28,  price: 40,  stockQty: 9,  lowStockThreshold: 6,  hsnCode: '2008', gstRate: 12.0),
      _product(name: 'Popcorn Salted',      sku: 'SNK004', barcode: '622300236004', categoryId: categoryIds['Snacks'],       cost: 11,  price: 18,  stockQty: 20, lowStockThreshold: 6,  hsnCode: '1905', gstRate: 12.0),
      _product(name: 'Cookies Pack',        sku: 'SNK005', barcode: '622300236005', categoryId: categoryIds['Snacks'],       cost: 14,  price: 22,  stockQty: 28, lowStockThreshold: 7,  hsnCode: '1905', gstRate: 18.0),
      // Dairy (HSN 0401 / 0402, 5% GST)
      _product(name: 'Full Cream Milk 1L',  sku: 'DAR001', barcode: '622300336001', categoryId: categoryIds['Dairy'],        cost: 24,  price: 32,  stockQty: 18, lowStockThreshold: 6,  hsnCode: '0401', gstRate: 5.0),
      _product(name: 'Yogurt Cup',          sku: 'DAR002', barcode: '622300336002', categoryId: categoryIds['Dairy'],        cost: 6,   price: 9,   stockQty: 40, lowStockThreshold: 10, hsnCode: '0403', gstRate: 5.0),
      _product(name: 'Cheddar Cheese 250g', sku: 'DAR003', barcode: '622300336003', categoryId: categoryIds['Dairy'],        cost: 45,  price: 62,  stockQty: 7,  lowStockThreshold: 4,  hsnCode: '0406', gstRate: 12.0),
      _product(name: 'Butter 200g',         sku: 'DAR004', barcode: '622300336004', categoryId: categoryIds['Dairy'],        cost: 36,  price: 50,  stockQty: 10, lowStockThreshold: 4,  hsnCode: '0405', gstRate: 12.0),
      _product(name: 'Eggs Tray 30',        sku: 'DAR005', barcode: '622300336005', categoryId: categoryIds['Dairy'],        cost: 120, price: 145, stockQty: 11, lowStockThreshold: 3,  hsnCode: '0407', gstRate: 0.0, unit: 'tray'),
      // Household (HSN 3402, 18% GST)
      _product(name: 'Dish Soap 750ml',     sku: 'HSH001', barcode: '622300436001', categoryId: categoryIds['Household'],    cost: 22,  price: 32,  stockQty: 16, lowStockThreshold: 5,  hsnCode: '3402', gstRate: 18.0),
      _product(name: 'Laundry Powder 1kg',  sku: 'HSH002', barcode: '622300436002', categoryId: categoryIds['Household'],    cost: 48,  price: 63,  stockQty: 14, lowStockThreshold: 5,  hsnCode: '3402', gstRate: 18.0),
      _product(name: 'Paper Towels 2 Rolls',sku: 'HSH003', barcode: '622300436003', categoryId: categoryIds['Household'],    cost: 26,  price: 39,  stockQty: 8,  lowStockThreshold: 4,  hsnCode: '4818', gstRate: 18.0),
      // Personal Care (HSN 3306, 18% GST)
      _product(name: 'Toothpaste 125ml',    sku: 'PRS001', barcode: '622300536001', categoryId: categoryIds['Personal Care'],cost: 19,  price: 28,  stockQty: 25, lowStockThreshold: 6,  hsnCode: '3306', gstRate: 18.0),
      _product(name: 'Shampoo 400ml',       sku: 'PRS002', barcode: '622300536002', categoryId: categoryIds['Personal Care'],cost: 42,  price: 58,  stockQty: 13, lowStockThreshold: 4,  hsnCode: '3305', gstRate: 18.0),
    ];

    await db.batch((batch) {
      for (final product in products) {
        batch.insert(db.products, product, mode: InsertMode.insertOrIgnore);
      }
    });

    await _ensureProductImages();

    final allProducts = await db.select(db.products).get();
    await db.batch((batch) {
      for (final product in allProducts) {
        batch.insert(
          db.stockMovements,
          StockMovementsCompanion.insert(
            productId: product.id,
            type: 'add',
            qtyChange: product.stockQty,
            reason: const Value('Initial stock seed'),
            createdAt: Value(now),
          ),
        );
      }
    });
  }

  Future<void> _seedCustomersSuppliers() async {
    await db.batch((batch) {
      batch.insertAll(db.customers, [
        CustomersCompanion.insert(
          workspaceId: const Value(1),
          name: 'Walk-in Customer',
          phone: const Value('9988000000'),
          notes: const Value('Default customer'),
          balance: const Value(0),
        ),
        CustomersCompanion.insert(
          workspaceId: const Value(1),
          name: 'Karnataka Agro Agency',
          phone: const Value('9845012345'),
          notes: const Value('Wholesale buyer'),
          balance: const Value(0),
        ),
        CustomersCompanion.insert(
          workspaceId: const Value(1),
          name: 'Hubli Farmers Association',
          phone: const Value('9448098765'),
          notes: const Value('Cooperative society'),
          balance: const Value(500),
        ),
      ], mode: InsertMode.insertOrIgnore);

      batch.insertAll(db.suppliers, [
        SuppliersCompanion.insert(
          workspaceId: const Value(1),
          name: 'Hubli Agri Inputs Wholesale',
          phone: const Value('08362255441'),
        ),
        SuppliersCompanion.insert(
          workspaceId: const Value(1),
          name: 'Dharwad Seed Distributors',
          phone: const Value('08362441122'),
        ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  ProductsCompanion _product({
    required String name,
    required String sku,
    required String barcode,
    required int? categoryId,
    required double cost,
    required double price,
    required int stockQty,
    required int lowStockThreshold,
    String unit = 'piece',
    String? hsnCode,
    double gstRate = 0.0,
  }) {
    final now = DateTime.now();
    return ProductsCompanion.insert(
      name: name,
      sku: sku,
      barcode: Value(barcode),
      categoryId: Value(categoryId),
      cost: cost,
      price: price,
      stockQty: stockQty,
      lowStockThreshold: Value(lowStockThreshold),
      unit: Value(unit),
      imagePath: Value(_productImageUrls[sku]),
      createdAt: Value(now),
      updatedAt: Value(now),
      workspaceId: const Value(DarviCorporateInfo.primaryWorkspaceId),
      hsnCode: Value(hsnCode),
      gstRate: Value(gstRate),
    );
  }
}
