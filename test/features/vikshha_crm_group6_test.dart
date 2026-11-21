import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/repositories/local_booking_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_crm_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_ledger_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_plot_repository.dart';

void main() {
  late AppDatabase db;
  late LocalLedgerRepository ledgerRepo;
  late LocalBookingRepository bookingRepo;
  late LocalPlotRepository plotRepo;
  late LocalCrmRepository crmRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledgerRepo = LocalLedgerRepository(db);
    bookingRepo = LocalBookingRepository(db, ledgerRepo);
    plotRepo = LocalPlotRepository(db);
    crmRepo = LocalCrmRepository(db);

    // Bootstrap workspace
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            businessName: 'Vikshha Organic Agro Tech',
            gstin: const Value('29AAAAA0000A1Z5'),
          ),
        );

    // Bootstrap sales employee
    await db.into(db.employees).insert(
          EmployeesCompanion.insert(
            workspaceId: 1,
            employeeCode: 'EMP-101',
            name: 'Vijay Kumar',
            phone: '9988776655',
            role: 'sales',
            designation: 'Senior Sales Executive',
            loginPin: '1234',
          ),
        );

    // Bootstrap bank account
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            workspaceId: 1,
            name: 'Vikshha Escrow Bank A/C',
            type: 'bank',
            currentBalance: const Value(1000000.0),
          ),
        );

    // Bootstrap customer
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            workspaceId: const Value(1),
            name: 'Suresh Hegde',
            phone: const Value('9988001122'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Vikshha CRM Group 6 - Agreements, Documents, Commission & CRM Dashboard', () {
    test('Agreement lifecycle and multi-entity CRM document management', () async {
      // 1. Create Project and Plot
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Palm Meadows',
        code: 'VPM',
        location: 'Hubli',
      );
      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'P-12',
        uniquePlotId: 'VPM-P12',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        status: 'available',
        basePrice: 500,
        totalPrice: 1200000,
      );

      // Attach layout blueprint document to Project
      final doc1 = await crmRepo.addDocument(
        workspaceId: 1,
        entityType: 'project',
        entityId: projId,
        documentType: 'blueprint',
        title: 'Master Layout Plan Phase 1',
        filePath: 'documents/projects/vpm_masterplan.pdf',
        fileSize: 4194304,
      );
      expect(doc1, isPositive);

      final projDocs = await crmRepo.getDocuments(workspaceId: 1, entityType: 'project', entityId: projId);
      expect(projDocs.length, 1);
      expect(projDocs.first['title'], 'Master Layout Plan Phase 1');

      // 2. Book Plot with Agreement status tracking
      final bookingId = await bookingRepo.createBooking(
        workspaceId: 1,
        bookingNumber: 'BK-2026-VPM-P12',
        plotId: plotId,
        customerId: 1,
        employeeId: 1,
        totalPlotValue: 1200000,
        bookingAmount: 200000,
        paymentAccountId: 1,
        installments: [
          {'installmentNumber': 1, 'title': 'Advance', 'dueDate': DateTime.now(), 'amount': 200000.0},
        ],
      );

      // Transition Agreement status through: draft -> signed -> registered
      await bookingRepo.updateAgreementStatus(bookingId, 'signed');
      var b = await bookingRepo.getBookingById(bookingId);
      expect(b, isNotNull);

      // Attach signed Agreement document
      final doc2 = await crmRepo.addDocument(
        workspaceId: 1,
        entityType: 'booking',
        entityId: bookingId,
        documentType: 'agreement',
        title: 'Sale Agreement Signed Copy',
        filePath: 'documents/agreements/BK-2026-VPM-P12_signed.pdf',
        fileSize: 2097152,
        uploadedBy: 1,
      );
      expect(doc2, isPositive);

      final bookingDocs = await crmRepo.getDocuments(workspaceId: 1, entityType: 'booking', entityId: bookingId);
      expect(bookingDocs.length, 1);
      expect(bookingDocs.first['document_type'], 'agreement');

      // Test delete document
      await crmRepo.deleteDocument(doc2);
      final refetchedBookingDocs = await crmRepo.getDocuments(workspaceId: 1, entityType: 'booking', entityId: bookingId);
      expect(refetchedBookingDocs, isEmpty);
    });

    test('Sales Employee Attribution and Commission Claim Calculation', () async {
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Agro Farmlands',
        code: 'VAF',
        location: 'Dharwad',
      );
      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'K-05',
        uniquePlotId: 'VAF-K05',
        dimensions: '50 x 80 ft',
        areaSqFt: 4000,
        status: 'available',
        basePrice: 500,
        totalPrice: 2000000,
      );

      final bookingId = await bookingRepo.createBooking(
        workspaceId: 1,
        bookingNumber: 'BK-2026-VAF-K05',
        plotId: plotId,
        customerId: 1,
        employeeId: 1, // Vijay Kumar
        totalPlotValue: 2000000,
        bookingAmount: 400000,
        paymentAccountId: 1,
        installments: [
          {'installmentNumber': 1, 'title': 'Advance', 'dueDate': DateTime.now(), 'amount': 400000.0},
        ],
      );

      // Claim 2.5% sales commission on ₹2,000,000 plot = ₹50,000
      final claimId = await bookingRepo.claimSalesCommission(
        workspaceId: 1,
        bookingId: bookingId,
        employeeId: 1,
        commissionRate: 2.5,
        remarks: '2.5% Farmland deal commission',
      );
      expect(claimId, isPositive);

      // Verify claim recorded in incentive_claims table
      final claim = await (db.select(db.incentiveClaims)..where((tbl) => tbl.id.equals(claimId))).getSingle();
      expect(claim.employeeId, 1);
      expect(claim.amount, 50000.0);
      expect(claim.status, 'pending');

      // Duplicate claim call returns existing claim
      final duplicateClaimId = await bookingRepo.claimSalesCommission(
        workspaceId: 1,
        bookingId: bookingId,
        employeeId: 1,
        commissionRate: 2.5,
      );
      expect(duplicateClaimId, claimId);
    });
  });
}
