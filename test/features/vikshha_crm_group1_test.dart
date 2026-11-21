import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/repositories/local_crm_repository.dart';

void main() {
  late AppDatabase db;
  late LocalCrmRepository crmRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    crmRepo = LocalCrmRepository(db);

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

  group('Vikshha CRM Group 1 - Leads, Follow-ups & Activity Timeline', () {
    test('Lead registration with full details and duplicate validation check', () async {
      // 1. Create Lead
      final leadId1 = await crmRepo.saveLead(
        workspaceId: 1,
        name: 'Karthik Rao',
        phone: '9888877771',
        alternatePhone: '9888877772',
        email: 'karthik@example.com',
        city: 'Bangalore',
        district: 'Bangalore Urban',
        source: 'Walk-in',
        priority: 'high',
        budget: 2500000,
        requirements: 'East facing 2400 sq ft plot with Sandalwood trees',
        stage: 'new',
        nextFollowUpDate: DateTime.now().add(const Duration(days: 2)),
      );

      expect(leadId1, isPositive);

      // 2. Verify duplicate check returns existing lead
      final duplicate = await crmRepo.checkDuplicateLead(phone: '9888877771', workspaceId: 1);
      expect(duplicate, isNotNull);
      expect(duplicate.name, 'Karthik Rao');

      // 3. Exclude self check returns null
      final duplicateExcludeSelf = await crmRepo.checkDuplicateLead(phone: '9888877771', excludeId: leadId1, workspaceId: 1);
      expect(duplicateExcludeSelf, isNull);

      // 4. Different phone returns null
      final nonDuplicate = await crmRepo.checkDuplicateLead(phone: '9999900000', workspaceId: 1);
      expect(nonDuplicate, isNull);
    });

    test('Follow-up lifecycle: creation, query, reschedule, complete, overdue tracking', () async {
      final leadId = await crmRepo.saveLead(
        workspaceId: 1,
        name: 'Sunil Kumar',
        phone: '9888877773',
        stage: 'contacted',
      );

      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final futureDate = DateTime.now().add(const Duration(days: 3));

      // Create an overdue follow up
      final f1 = await crmRepo.createFollowUp(
        workspaceId: 1,
        leadId: leadId,
        scheduledDate: pastDate,
        remarks: 'Discuss layout masterplan',
      );
      expect(f1, isPositive);

      // Create a future follow up
      final f2 = await crmRepo.createFollowUp(
        workspaceId: 1,
        leadId: leadId,
        scheduledDate: futureDate,
        remarks: 'Send pricing PDF and agreement template',
      );
      expect(f2, isPositive);

      // Check overdue count
      final overdueCount = await crmRepo.getOverdueFollowUpsCount(workspaceId: 1);
      expect(overdueCount, 1);

      // Fetch all follow-ups
      final followUps = await crmRepo.getFollowUps(workspaceId: 1, leadId: leadId);
      expect(followUps.length, 2);

      // Mark the overdue one complete
      await crmRepo.updateFollowUpStatus(f1, 'completed', remarks: 'Customer attended call and confirmed layout visit');
      final updatedOverdueCount = await crmRepo.getOverdueFollowUpsCount(workspaceId: 1);
      expect(updatedOverdueCount, 0);

      // Reschedule future one
      final newSched = DateTime.now().add(const Duration(days: 5));
      await crmRepo.updateFollowUpStatus(f2, 'pending', rescheduleDate: newSched, remarks: 'Rescheduled on customer request');

      final refetched = await crmRepo.getFollowUps(workspaceId: 1, leadId: leadId);
      final refetchedF2 = refetched.firstWhere((item) => item['id'] == f2);
      expect(refetchedF2['scheduled_date'], newSched.millisecondsSinceEpoch);
    });

    test('Lead Stage progression, Activity timeline logging, and Lead Deletion', () async {
      final leadId = await crmRepo.saveLead(
        workspaceId: 1,
        name: 'Venkatesh Murthy',
        phone: '9888877774',
        stage: 'new',
      );

      // Log manual activities
      await crmRepo.logLeadActivity(
        workspaceId: 1,
        leadId: leadId,
        activityType: 'call',
        notes: 'Explaining Phase 2 farmland features',
      );
      await crmRepo.logLeadActivity(
        workspaceId: 1,
        leadId: leadId,
        activityType: 'whatsapp',
        notes: 'Shared brochure and video link',
      );

      // Update stage (which also auto-logs stage_change activity)
      await crmRepo.updateLeadStage(leadId, 'interested');

      final activities = await crmRepo.getLeadActivities(leadId);
      expect(activities.length, 3);
      expect(activities.any((a) => a.activityType == 'stage_change'), isTrue);

      // Verify stage updated
      final updatedLead = await crmRepo.getLeadById(leadId);
      expect(updatedLead?.stage, 'interested');

      // Test delete lead
      await crmRepo.deleteLead(leadId);
      final deletedLead = await crmRepo.getLeadById(leadId);
      expect(deletedLead, isNull);
    });
  });
}
