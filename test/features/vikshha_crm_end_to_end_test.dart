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
            businessName: 'Vikshha Agro-Forestry & Farmlands',
            gstin: const Value('29AAAAA0000A1Z5'),
          ),
        );

    // Bootstrap sales employee
    await db.into(db.employees).insert(
          EmployeesCompanion.insert(
            workspaceId: 1,
            employeeCode: 'EMP-DARVI-01',
            name: 'Mahesh Goudar',
            phone: '9845001122',
            role: 'sales',
            designation: 'Field Officer',
            loginPin: '1234',
          ),
        );

    // Bootstrap bank account
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            workspaceId: 1,
            name: 'Vikshha State Bank of India Current A/C',
            type: 'bank',
            currentBalance: const Value(2500000.0),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('VIKSHHA CRM COMPLETE 23-STEP END-TO-END WORKFLOW INTEGRATION TEST', () async {
    // -------------------------------------------------------------
    // Step 1: Create Farmland Development Project
    // -------------------------------------------------------------
    final projId = await plotRepo.saveProject(
      workspaceId: 1,
      name: 'Vikshha Sandalwood Sanctuary Phase 1',
      code: 'VSS-P1',
      location: 'Dharwad Bypass Highway',
      totalArea: 40.0,
      totalPlots: 10,
      description: 'Integrated sandalwood and organic agro-forestry farmland layout',
      amenities: '24/7 solar security, automated drip network, clubhouse',
      legalStatus: 'clear_title',
      address: 'Survey No 102/1B, Dharwad',
      gpsCoordinates: '15.4520° N, 75.0130° E',
    );
    expect(projId, isPositive);

    // -------------------------------------------------------------
    // Step 2: Upload Project Master Layout Blueprint
    // -------------------------------------------------------------
    final projDocId = await crmRepo.addDocument(
      workspaceId: 1,
      entityType: 'project',
      entityId: projId,
      documentType: 'blueprint',
      title: 'Approved Master Layout Plan',
      filePath: 'docs/projects/VSS-P1_layout.pdf',
      fileSize: 5242880,
    );
    expect(projDocId, isPositive);

    // -------------------------------------------------------------
    // Step 3: Register Farmland Plot Inventory
    // -------------------------------------------------------------
    final plotId = await plotRepo.savePlot(
      workspaceId: 1,
      projectId: projId,
      plotNumber: 'P-01',
      uniquePlotId: 'VSS-P1-01',
      dimensions: '40 x 60 ft',
      areaSqFt: 2400,
      facing: 'East',
      pricePerSqFt: 625,
      status: 'available',
      basePrice: 625,
      totalPrice: 1500000,
      cropType: 'Sandalwood & Mahogany',
      plantationDetails: '25 sandalwood saplings with fertigation connection',
    );
    expect(plotId, isPositive);

    // -------------------------------------------------------------
    // Step 4: Verify Project Dynamic Summary KPI
    // -------------------------------------------------------------
    final summary = await plotRepo.getProjectSummary(projId);
    expect(summary['totalPlots'], 1);
    expect(summary['availablePlots'], 1);
    expect(summary['totalValuation'], 1500000.0);

    // -------------------------------------------------------------
    // Step 5: Capture Inbound Investor Lead
    // -------------------------------------------------------------
    final leadId = await crmRepo.saveLead(
      workspaceId: 1,
      name: 'Naveen Deshpande',
      phone: '9844112233',
      alternatePhone: '9844112234',
      email: 'naveen.deshpande@example.com',
      city: 'Hubli',
      district: 'Dharwad',
      source: 'Digital Ads',
      priority: 'high',
      interestedProjectId: projId,
      interestedPlotSize: '2400 sq ft',
      budget: 1600000,
      requirements: 'East facing 2400 sq ft farmland plot with mature trees',
      stage: 'new',
      assignedEmployeeId: 1,
    );
    expect(leadId, isPositive);

    // -------------------------------------------------------------
    // Step 6: Verify Duplicate Phone Lead Validation
    // -------------------------------------------------------------
    final duplicate = await crmRepo.checkDuplicateLead(phone: '9844112233', workspaceId: 1);
    expect(duplicate, isNotNull);
    expect(duplicate.name, 'Naveen Deshpande');

    // -------------------------------------------------------------
    // Step 7: Log Telephonic Consultation & Progress Stage
    // -------------------------------------------------------------
    await crmRepo.logLeadActivity(
      workspaceId: 1,
      leadId: leadId,
      employeeId: 1,
      activityType: 'call',
      notes: 'Explained sandalwood crop sharing model and land titles',
    );
    await crmRepo.updateLeadStage(leadId, 'contacted');

    // -------------------------------------------------------------
    // Step 8: Schedule Lead Follow-up Call
    // -------------------------------------------------------------
    final followUpId = await crmRepo.createFollowUp(
      workspaceId: 1,
      leadId: leadId,
      employeeId: 1,
      scheduledDate: DateTime.now().add(const Duration(days: 1)),
      remarks: 'Follow up to confirm weekend site visit',
    );
    expect(followUpId, isPositive);

    // -------------------------------------------------------------
    // Step 9: Complete Follow-up Call
    // -------------------------------------------------------------
    await crmRepo.updateFollowUpStatus(followUpId, 'completed', remarks: 'Client agreed to site visit this Saturday');

    // -------------------------------------------------------------
    // Step 10: Schedule Site Visit to Farmland Plot
    // -------------------------------------------------------------
    final visitDate = DateTime.now().add(const Duration(days: 2));
    final visitId = await crmRepo.scheduleSiteVisit(
      workspaceId: 1,
      leadId: leadId,
      projectId: projId,
      plotId: plotId,
      scheduledDate: visitDate,
      conductedByEmployeeId: 1,
    );
    expect(visitId, isPositive);

    // Verify lead stage auto-progressed to site_visit
    var lead = await crmRepo.getLeadById(leadId);
    expect(lead?.stage, 'site_visit');

    // -------------------------------------------------------------
    // Step 11: Conduct & Complete Site Visit with Feedback
    // -------------------------------------------------------------
    await crmRepo.updateSiteVisitStatus(
      visitId,
      'completed',
      feedback: 'Client loved Plot P-01. Requested ₹50,000 festive discount on total price.',
      nextFollowUpDate: DateTime.now().add(const Duration(days: 1)),
    );

    // Verify stage auto-progressed to negotiation
    lead = await crmRepo.getLeadById(leadId);
    expect(lead?.stage, 'negotiation');

    // -------------------------------------------------------------
    // Step 12: Convert Lead to Darvi Billing Customer
    // -------------------------------------------------------------
    final customerId = await crmRepo.convertLeadToCustomer(leadId);
    expect(customerId, isPositive);

    lead = await crmRepo.getLeadById(leadId);
    expect(lead?.stage, 'converted');

    // -------------------------------------------------------------
    // Step 13: Temporary Plot Reservation (Token Hold)
    // -------------------------------------------------------------
    final resBookingId = await bookingRepo.reservePlot(
      workspaceId: 1,
      plotId: plotId,
      customerId: customerId,
      leadId: leadId,
      employeeId: 1,
      totalPlotValue: 1500000,
      reservationAmount: 50000,
      paymentAccountId: 1,
      expiryDays: 5,
      notes: 'Token reservation hold pending agreement draft',
    );
    expect(resBookingId, isPositive);

    var plot = await plotRepo.getPlotById(plotId);
    expect(plot?.status, 'reserved');

    // -------------------------------------------------------------
    // Step 14: Release / Cancel Reservation to proceed to Full Booking
    // -------------------------------------------------------------
    await bookingRepo.cancelBooking(
      bookingId: resBookingId,
      reason: 'Converting token reservation to full milestone booking',
      refundAmount: 0.0,
      refundAccountId: 1,
    );
    plot = await plotRepo.getPlotById(plotId);
    expect(plot?.status, 'available');

    // -------------------------------------------------------------
    // Step 15: Create Full Farmland Plot Booking with Milestones
    // -------------------------------------------------------------
    final now = DateTime.now();
    final bookingId = await bookingRepo.createBooking(
      workspaceId: 1,
      bookingNumber: 'BK-2026-VSS-001',
      plotId: plotId,
      customerId: customerId,
      leadId: leadId,
      employeeId: 1,
      totalPlotValue: 1500000,
      bookingAmount: 300000, // 20% advance
      discount: 50000,
      paymentAccountId: 1,
      paymentMode: 'bank_transfer',
      referenceNo: 'HDFC-IMPS-00918',
      notes: 'Festive offer discount ₹50,000 applied. Net plot value ₹1,450,000',
      installments: [
        {
          'installmentNumber': 1,
          'title': 'Booking Token & Advance',
          'dueDate': now,
          'amount': 300000.0,
        },
        {
          'installmentNumber': 2,
          'title': 'Agreement & Boundary Marking',
          'dueDate': now.add(const Duration(days: 30)),
          'amount': 600000.0,
        },
        {
          'installmentNumber': 3,
          'title': 'Registration & Plantation Handover',
          'dueDate': now.add(const Duration(days: 60)),
          'amount': 550000.0,
        },
      ],
    );
    expect(bookingId, isPositive);

    plot = await plotRepo.getPlotById(plotId);
    expect(plot?.status, 'booked');

    // -------------------------------------------------------------
    // Step 16: Verify Milestone 1 Advance Payment & Ledger Posting
    // -------------------------------------------------------------
    final installments = await bookingRepo.getInstallments(bookingId);
    expect(installments.length, 3);
    expect(installments[0].status, 'paid');
    expect(installments[0].paidAmount, 300000.0);
    expect(installments[1].status, 'pending');

    // -------------------------------------------------------------
    // Step 17: Upload Signed Sale Agreement Document
    // -------------------------------------------------------------
    final agreementDocId = await crmRepo.addDocument(
      workspaceId: 1,
      entityType: 'booking',
      entityId: bookingId,
      documentType: 'agreement',
      title: 'Registered Agreement for Sale',
      filePath: 'docs/agreements/BK-2026-VSS-001_agreement.pdf',
      fileSize: 3145728,
      uploadedBy: 1,
    );
    expect(agreementDocId, isPositive);

    await bookingRepo.updateAgreementStatus(bookingId, 'signed');

    // -------------------------------------------------------------
    // Step 18: Pay Milestone 2 Installment (₹600,000)
    // -------------------------------------------------------------
    final inst2 = installments[1];
    await bookingRepo.payInstallment(
      installmentId: inst2.id,
      amount: 600000.0,
      paymentAccountId: 1,
      paymentMode: 'bank_transfer',
      referenceNo: 'RTGS-VSS-7718',
    );

    // -------------------------------------------------------------
    // Step 19: Pay Milestone 3 Installment (₹550,000)
    // -------------------------------------------------------------
    final inst3 = installments[2];
    await bookingRepo.payInstallment(
      installmentId: inst3.id,
      amount: 550000.0,
      paymentAccountId: 1,
      paymentMode: 'bank_transfer',
      referenceNo: 'RTGS-VSS-9921',
    );

    // -------------------------------------------------------------
    // Step 20: Verify Complete Booking Financial Statement
    // -------------------------------------------------------------
    final statement = await bookingRepo.getBookingStatement(bookingId);
    expect(statement['totalValue'], 1500000.0);
    expect(statement['totalPaid'], 1450000.0); // 300k + 600k + 550k = 1,450k (with 50k discount)
    expect((statement['payments'] as List).length, 3);

    // -------------------------------------------------------------
    // Step 21: Verify Balanced Double-Entry System-Wide Ledger
    // -------------------------------------------------------------
    final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
    final totalDebit = recon['total_debit'] as double;
    final totalCredit = recon['total_credit'] as double;
    expect(totalDebit, closeTo(totalCredit, 0.001));
    expect(recon['is_trial_balanced'], isTrue);

    // -------------------------------------------------------------
    // Step 22: Calculate and Claim Sales Executive Commission
    // -------------------------------------------------------------
    final claimId = await bookingRepo.claimSalesCommission(
      workspaceId: 1,
      bookingId: bookingId,
      employeeId: 1,
      commissionRate: 2.0, // 2% of ₹1,500,000 = ₹30,000
    );
    expect(claimId, isPositive);

    final claim = await (db.select(db.incentiveClaims)..where((tbl) => tbl.id.equals(claimId))).getSingle();
    expect(claim.employeeId, 1);
    expect(claim.amount, 30000.0);
    expect(claim.status, 'pending');

    // -------------------------------------------------------------
    // Step 23: Verify Comprehensive Customer CRM Profile
    // -------------------------------------------------------------
    final crmProfile = await crmRepo.getCustomerCrmProfile(customerId);
    expect(crmProfile['totalBookings'], 1);
    expect(crmProfile['totalPlotValue'], 1500000.0);
    expect((crmProfile['bookings'] as List).length, 1);
  });
}

