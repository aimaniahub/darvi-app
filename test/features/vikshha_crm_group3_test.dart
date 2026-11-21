import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/repositories/local_crm_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_plot_repository.dart';

void main() {
  late AppDatabase db;
  late LocalCrmRepository crmRepo;
  late LocalPlotRepository plotRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    crmRepo = LocalCrmRepository(db);
    plotRepo = LocalPlotRepository(db);

    // Bootstrap workspace
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            businessName: 'Vikshha Organic Agro Tech',
            gstin: const Value('29AAAAA0000A1Z5'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Vikshha CRM Group 3 - Site Visits, Customer Conversion & Customer CRM Profile', () {
    test('Site visit lifecycle: scheduling, status completion, activity log and auto-follow-up', () async {
      // 1. Create Lead and Project
      final leadId = await crmRepo.saveLead(
        workspaceId: 1,
        name: 'Prashanth Deshmukh',
        phone: '9888877788',
        stage: 'interested',
      );

      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Hills',
        code: 'VH',
        location: 'Dharwad',
      );

      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'D-05',
        uniquePlotId: 'VH-D05',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        basePrice: 550,
        totalPrice: 1320000,
      );

      // 2. Schedule Site Visit
      final visitDate = DateTime.now().add(const Duration(days: 1));
      final visitId = await crmRepo.scheduleSiteVisit(
        workspaceId: 1,
        leadId: leadId,
        projectId: projId,
        plotId: plotId,
        scheduledDate: visitDate,
      );
      expect(visitId, isPositive);

      // Verify Lead stage was automatically updated to site_visit
      var lead = await crmRepo.getLeadById(leadId);
      expect(lead?.stage, 'site_visit');

      // 3. Complete Site Visit with feedback and auto-scheduled follow up
      final nextFollowUp = DateTime.now().add(const Duration(days: 3));
      await crmRepo.updateSiteVisitStatus(
        visitId,
        'completed',
        feedback: 'Client very satisfied with plantation and soil quality. Wants discount on payment advance.',
        nextFollowUpDate: nextFollowUp,
      );

      // Verify stage progressed to negotiation
      lead = await crmRepo.getLeadById(leadId);
      expect(lead?.stage, 'negotiation');

      // Verify auto-created follow up
      final followUps = await crmRepo.getFollowUps(workspaceId: 1, leadId: leadId);
      expect(followUps.any((f) => (f['remarks'] as String).contains('Post-site visit follow-up')), isTrue);
    });

    test('Customer Conversion and Comprehensive CRM Profile View', () async {
      // 1. Register Lead
      final leadId = await crmRepo.saveLead(
        workspaceId: 1,
        name: 'Anand Kulkarni',
        phone: '9888877799',
        source: 'Agri Expo',
        stage: 'negotiation',
      );

      // 2. Convert Lead to Customer
      final custId = await crmRepo.convertLeadToCustomer(leadId);
      expect(custId, isPositive);

      // Verify lead stage updated to converted
      final convertedLead = await crmRepo.getLeadById(leadId);
      expect(convertedLead?.stage, 'converted');

      // Verify customer record created in customers table
      final cust = await (db.select(db.customers)..where((tbl) => tbl.id.equals(custId))).getSingle();
      expect(cust.name, 'Anand Kulkarni');
      expect(cust.phone, '9888877799');

      // 3. Add a plot booking for this converted customer
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Valley',
        code: 'VV',
        location: 'Hubli',
      );
      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'E-01',
        uniquePlotId: 'VV-E01',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        basePrice: 500,
        totalPrice: 1200000,
      );

      await db.into(db.plotBookings).insert(
            PlotBookingsCompanion.insert(
              workspaceId: 1,
              bookingNumber: 'BK-2026-TEST01',
              plotId: plotId,
              customerId: custId,
              totalPlotValue: 1200000,
              bookingAmount: 200000,
            ),
          );

      // 4. Fetch Customer CRM Profile
      final profile = await crmRepo.getCustomerCrmProfile(custId);
      expect(profile['totalBookings'], 1);
      expect(profile['totalPlotValue'], 1200000.0);
      expect((profile['bookings'] as List).length, 1);
    });
  });
}

