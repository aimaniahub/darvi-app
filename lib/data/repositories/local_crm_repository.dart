import 'package:drift/drift.dart';

import '../../domain/repositories/repositories.dart';
import '../local/db/app_database.dart';

class LocalCrmRepository implements CrmRepository {
  const LocalCrmRepository(this.db);

  final AppDatabase db;

  @override
  Future<List<Lead>> getLeads({
    int workspaceId = 1,
    String? stage,
    int? employeeId,
    String? source,
    String? priority,
    String? query,
  }) async {
    final q = db.select(db.leads)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

    if (stage != null && stage.isNotEmpty && stage.toLowerCase() != 'all') {
      q.where((tbl) => tbl.stage.equals(stage.toLowerCase()));
    }

    if (employeeId != null && employeeId > 0) {
      q.where((tbl) => tbl.assignedEmployeeId.equals(employeeId));
    }

    if (source != null && source.isNotEmpty && source.toLowerCase() != 'all') {
      q.where((tbl) => tbl.source.equals(source));
    }

    final rows = await q.get();

    // Priority filtering if table column or in-memory
    var filtered = rows;
    if (priority != null && priority.isNotEmpty && priority.toLowerCase() != 'all') {
      // In SQLite, priority column is present in table schema
      try {
        final prioRows = await db.customSelect(
          'SELECT id FROM leads WHERE workspace_id = ? AND LOWER(priority) = ?',
          variables: [Variable.withInt(workspaceId), Variable.withString(priority.toLowerCase())],
        ).get();
        final prioIds = prioRows.map((r) => r.data['id'] as int).toSet();
        filtered = filtered.where((l) => prioIds.contains(l.id)).toList();
      } catch (_) {}
    }

    if (query != null && query.trim().isNotEmpty) {
      final clean = query.trim().toLowerCase();
      return filtered.where((l) {
        final matchesName = l.name.toLowerCase().contains(clean);
        final matchesPhone = l.phone.toLowerCase().contains(clean);
        final matchesEmail = l.email?.toLowerCase().contains(clean) ?? false;
        final matchesReq = l.requirements?.toLowerCase().contains(clean) ?? false;
        return matchesName || matchesPhone || matchesEmail || matchesReq;
      }).toList();
    }

    return filtered;
  }

  @override
  Future<Lead?> getLeadById(int leadId) async {
    final query = db.select(db.leads)..where((tbl) => tbl.id.equals(leadId));
    return query.getSingleOrNull();
  }

  @override
  Future<dynamic> checkDuplicateLead({required String phone, int? excludeId, int workspaceId = 1}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleanPhone.isEmpty) return null;
    final q = db.select(db.leads)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId))
      ..where((tbl) => tbl.phone.equals(cleanPhone));
    if (excludeId != null) {
      q.where((tbl) => tbl.id.equals(excludeId).not());
    }
    return q.getSingleOrNull();
  }

  @override
  Future<int> saveLead({
    int? id,
    int workspaceId = 1,
    required String name,
    required String phone,
    String? alternatePhone,
    String? email,
    String? address,
    String? city,
    String? district,
    String source = 'Walk-in',
    String priority = 'medium',
    int? interestedProjectId,
    int? interestedPlotId,
    String? interestedPlotSize,
    double budget = 0.0,
    String? requirements,
    String stage = 'new',
    int? assignedEmployeeId,
    DateTime? nextFollowUpDate,
    String? notes,
  }) async {
    final now = DateTime.now();
    int leadId;
    if (id != null && id > 0) {
      await (db.update(db.leads)..where((tbl) => tbl.id.equals(id))).write(
        LeadsCompanion(
          name: Value(name),
          phone: Value(phone),
          email: Value(email),
          source: Value(source),
          interestedProjectId: Value(interestedProjectId),
          interestedPlotId: Value(interestedPlotId),
          budget: Value(budget),
          requirements: Value(requirements),
          stage: Value(stage),
          assignedEmployeeId: Value(assignedEmployeeId),
          nextFollowUpDate: Value(nextFollowUpDate),
          notes: Value(notes),
          updatedAt: Value(now),
        ),
      );
      leadId = id;
    } else {
      leadId = await db.into(db.leads).insert(
            LeadsCompanion.insert(
              workspaceId: workspaceId,
              name: name,
              phone: phone,
              email: Value(email),
              source: Value(source),
              interestedProjectId: Value(interestedProjectId),
              interestedPlotId: Value(interestedPlotId),
              budget: Value(budget),
              requirements: Value(requirements),
              stage: Value(stage),
              assignedEmployeeId: Value(assignedEmployeeId),
              nextFollowUpDate: Value(nextFollowUpDate),
              notes: Value(notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }

    // Persist extended fields (alternate_phone, address, city, district, priority, interested_plot_size)
    try {
      await db.customStatement(
        'UPDATE leads SET alternate_phone = ?, address = ?, city = ?, district = ?, priority = ?, interested_plot_size = ? WHERE id = ?',
        [alternatePhone, address, city, district, priority.toLowerCase(), interestedPlotSize, leadId],
      );
    } catch (_) {}

    // Auto-create initial follow-up task if nextFollowUpDate is scheduled
    if (nextFollowUpDate != null) {
      try {
        final existingFollowUps = await getFollowUps(leadId: leadId, status: 'pending');
        if (existingFollowUps.isEmpty) {
          await createFollowUp(
            workspaceId: workspaceId,
            leadId: leadId,
            employeeId: assignedEmployeeId,
            scheduledDate: nextFollowUpDate,
            remarks: 'Scheduled follow up for $name ($stage)',
          );
        }
      } catch (_) {}
    }

    return leadId;
  }

  @override
  Future<void> deleteLead(int leadId) async {
    await (db.delete(db.leads)..where((tbl) => tbl.id.equals(leadId))).go();
  }

  @override
  Future<void> updateLeadStage(int leadId, String stage) async {
    await (db.update(db.leads)..where((tbl) => tbl.id.equals(leadId))).write(
      LeadsCompanion(
        stage: Value(stage),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Auto-log activity
    await logLeadActivity(
      leadId: leadId,
      activityType: 'stage_change',
      notes: 'Lead progressed to stage: $stage',
    );
  }

  @override
  Future<void> logLeadActivity({
    int workspaceId = 1,
    required int leadId,
    int? employeeId,
    required String activityType,
    required String notes,
  }) async {
    await db.into(db.leadActivities).insert(
          LeadActivitiesCompanion.insert(
            workspaceId: workspaceId,
            leadId: leadId,
            employeeId: Value(employeeId),
            activityType: activityType,
            notes: notes,
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<List<LeadActivity>> getLeadActivities(int leadId) async {
    final query = db.select(db.leadActivities)
      ..where((tbl) => tbl.leadId.equals(leadId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.get();
  }

  @override
  Future<int> scheduleSiteVisit({
    int workspaceId = 1,
    required int leadId,
    int? projectId,
    int? plotId,
    required DateTime scheduledDate,
    int? conductedByEmployeeId,
    String? feedback,
    String status = 'scheduled',
  }) async {
    final id = await db.into(db.siteVisits).insert(
          SiteVisitsCompanion.insert(
            workspaceId: workspaceId,
            leadId: leadId,
            projectId: Value(projectId),
            plotId: Value(plotId),
            scheduledDate: scheduledDate,
            conductedByEmployeeId: Value(conductedByEmployeeId),
            feedback: Value(feedback),
            status: Value(status),
            createdAt: Value(DateTime.now()),
          ),
        );

    // Update lead stage to site_visit if earlier
    final lead = await getLeadById(leadId);
    if (lead != null && (lead.stage == 'new' || lead.stage == 'contacted' || lead.stage == 'interested')) {
      await updateLeadStage(leadId, 'site_visit');
    }

    await logLeadActivity(
      leadId: leadId,
      activityType: 'site_visit',
      notes: 'Site visit scheduled for ${scheduledDate.toLocal()}',
    );

    return id;
  }

  @override
  Future<List<SiteVisit>> getSiteVisits({
    int workspaceId = 1,
    int? leadId,
    int? employeeId,
    String? status,
  }) async {
    final q = db.select(db.siteVisits)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDate)]);

    if (leadId != null && leadId > 0) {
      q.where((tbl) => tbl.leadId.equals(leadId));
    }

    if (employeeId != null && employeeId > 0) {
      q.where((tbl) => tbl.conductedByEmployeeId.equals(employeeId));
    }

    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      q.where((tbl) => tbl.status.equals(status.toLowerCase()));
    }

    return q.get();
  }

  @override
  Future<void> updateSiteVisitStatus(int visitId, String status, {String? feedback, DateTime? nextFollowUpDate}) async {
    await (db.update(db.siteVisits)..where((tbl) => tbl.id.equals(visitId))).write(
      SiteVisitsCompanion(
        status: Value(status),
        feedback: feedback != null ? Value(feedback) : const Value.absent(),
      ),
    );

    // Fetch visit to auto-update lead and log follow-up
    final visit = await (db.select(db.siteVisits)..where((tbl) => tbl.id.equals(visitId))).getSingleOrNull();
    if (visit != null) {
      await logLeadActivity(
        workspaceId: visit.workspaceId,
        leadId: visit.leadId,
        employeeId: visit.conductedByEmployeeId,
        activityType: 'site_visit_update',
        notes: 'Site visit #$visitId status changed to "$status". Feedback: ${feedback ?? "None"}',
      );

      if (status.toLowerCase() == 'completed') {
        final lead = await getLeadById(visit.leadId);
        if (lead != null && lead.stage == 'site_visit') {
          await updateLeadStage(visit.leadId, 'negotiation');
        }
      }

      if (nextFollowUpDate != null) {
        await createFollowUp(
          workspaceId: visit.workspaceId,
          leadId: visit.leadId,
          employeeId: visit.conductedByEmployeeId,
          scheduledDate: nextFollowUpDate,
          remarks: 'Post-site visit follow-up: ${feedback ?? ""}',
        );
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getCustomerCrmProfile(int customerId) async {
    final cust = await (db.select(db.customers)..where((tbl) => tbl.id.equals(customerId))).getSingleOrNull();
    if (cust == null) throw StateError('Customer #$customerId not found.');

    final bookings = await (db.select(db.plotBookings)
          ..where((tbl) => tbl.customerId.equals(customerId))
          ..where((tbl) => tbl.status.equals('cancelled').not()))
        .get();
    final totalBookings = bookings.length;
    final totalPlotValue = bookings.fold<double>(0.0, (acc, b) => acc + b.totalPlotValue);

    final followUps = await getFollowUps(customerId: customerId);
    final sales = await (db.select(db.sales)..where((tbl) => tbl.customerId.equals(customerId))).get();

    return {
      'customer': cust,
      'totalBookings': totalBookings,
      'totalPlotValue': totalPlotValue,
      'bookings': bookings,
      'followUps': followUps,
      'sales': sales,
    };
  }

  @override
  Future<int> convertLeadToCustomer(int leadId) async {
    return db.transaction(() async {
      final lead = await getLeadById(leadId);
      if (lead == null) {
        throw StateError('Lead not found.');
      }

      // Check if customer with same phone already exists
      final existingCust = await (db.select(db.customers)
            ..where((tbl) => tbl.phone.equals(lead.phone)))
          .getSingleOrNull();

      int customerId;
      if (existingCust != null) {
        customerId = existingCust.id;
      } else {
        customerId = await db.into(db.customers).insert(
              CustomersCompanion.insert(
                workspaceId: const Value(1),
                name: lead.name,
                phone: Value(lead.phone),
                notes: Value('Converted from Farmland CRM (Lead #${lead.id}, Source: ${lead.source})'),
                balance: const Value(0.0),
              ),
            );
      }

      // Update lead stage
      await (db.update(db.leads)..where((tbl) => tbl.id.equals(leadId))).write(
        LeadsCompanion(
          stage: const Value('converted'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await logLeadActivity(
        leadId: leadId,
        activityType: 'conversion',
        notes: 'Converted lead to Customer #$customerId (${lead.name})',
      );

      return customerId;
    });
  }

  // -------------------------------------------------------------
  // VIKSHHA FOLLOW-UPS IMPLEMENTATION
  // -------------------------------------------------------------

  @override
  Future<int> createFollowUp({
    int workspaceId = 1,
    int? leadId,
    int? customerId,
    int? employeeId,
    required DateTime scheduledDate,
    String status = 'pending',
    String? remarks,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sched = scheduledDate.millisecondsSinceEpoch;

    final cols = ['workspace_id', 'scheduled_date', 'status', 'remarks', 'created_at'];
    final placeholders = ['?', '?', '?', '?', '?'];
    final vars = <Variable>[
      Variable.withInt(workspaceId),
      Variable.withInt(sched),
      Variable.withString(status),
      Variable.withString(remarks ?? ''),
      Variable.withInt(now),
    ];

    if (leadId != null && leadId > 0) {
      cols.add('lead_id');
      placeholders.add('?');
      vars.add(Variable.withInt(leadId));
    }
    if (customerId != null && customerId > 0) {
      cols.add('customer_id');
      placeholders.add('?');
      vars.add(Variable.withInt(customerId));
    }
    if (employeeId != null && employeeId > 0) {
      cols.add('employee_id');
      placeholders.add('?');
      vars.add(Variable.withInt(employeeId));
    }

    final sql = '''
      INSERT INTO crm_follow_ups (${cols.join(', ')})
      VALUES (${placeholders.join(', ')})
      RETURNING id;
    ''';

    final res = await db.customSelect(sql, variables: vars).getSingle();
    final followUpId = res.data['id'] as int;

    if (leadId != null && leadId > 0) {
      await logLeadActivity(
        workspaceId: workspaceId,
        leadId: leadId,
        employeeId: employeeId,
        activityType: 'follow_up_scheduled',
        notes: 'Follow-up scheduled for ${scheduledDate.toLocal()}: ${remarks ?? ""}',
      );
    }

    return followUpId;
  }

  @override
  Future<List<Map<String, dynamic>>> getFollowUps({
    int workspaceId = 1,
    int? leadId,
    int? customerId,
    int? employeeId,
    String? status,
  }) async {
    final queryBuffer = StringBuffer(
      '''
      SELECT f.id, f.workspace_id, f.lead_id, f.customer_id, f.employee_id,
             f.scheduled_date, f.status, f.remarks, f.created_at, f.completed_at,
             l.name as lead_name, l.phone as lead_phone, l.stage as lead_stage,
             e.name as employee_name
      FROM crm_follow_ups f
      LEFT JOIN leads l ON l.id = f.lead_id
      LEFT JOIN employees e ON e.id = f.employee_id
      WHERE f.workspace_id = ?
      ''',
    );
    final vars = <Variable>[Variable.withInt(workspaceId)];

    if (leadId != null && leadId > 0) {
      queryBuffer.write(' AND f.lead_id = ?');
      vars.add(Variable.withInt(leadId));
    }
    if (customerId != null && customerId > 0) {
      queryBuffer.write(' AND f.customer_id = ?');
      vars.add(Variable.withInt(customerId));
    }
    if (employeeId != null && employeeId > 0) {
      queryBuffer.write(' AND f.employee_id = ?');
      vars.add(Variable.withInt(employeeId));
    }
    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      queryBuffer.write(' AND LOWER(f.status) = ?');
      vars.add(Variable.withString(status.toLowerCase()));
    }

    queryBuffer.write(' ORDER BY f.scheduled_date ASC;');

    final rows = await db.customSelect(queryBuffer.toString(), variables: vars).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  @override
  Future<void> updateFollowUpStatus(
    int followUpId,
    String status, {
    String? remarks,
    DateTime? rescheduleDate,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (status.toLowerCase() == 'completed') {
      await db.customStatement(
        'UPDATE crm_follow_ups SET status = ?, completed_at = ?, remarks = COALESCE(?, remarks) WHERE id = ?;',
        [status.toLowerCase(), now, remarks, followUpId],
      );
    } else if (rescheduleDate != null) {
      final newSched = rescheduleDate.millisecondsSinceEpoch;
      await db.customStatement(
        'UPDATE crm_follow_ups SET status = ?, scheduled_date = ?, remarks = COALESCE(?, remarks) WHERE id = ?;',
        [status.toLowerCase(), newSched, remarks, followUpId],
      );
    } else {
      await db.customStatement(
        'UPDATE crm_follow_ups SET status = ?, remarks = COALESCE(?, remarks) WHERE id = ?;',
        [status.toLowerCase(), remarks, followUpId],
      );
    }
  }

  @override
  Future<int> getOverdueFollowUpsCount({int workspaceId = 1}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) as cnt FROM crm_follow_ups
      WHERE workspace_id = ? AND status = 'pending' AND scheduled_date < ?;
      ''',
      variables: [Variable.withInt(workspaceId), Variable.withInt(now)],
    ).getSingle();
    return (row.data['cnt'] as num?)?.toInt() ?? 0;
  }

  // -------------------------------------------------------------
  // VIKSHHA CRM DOCUMENTS IMPLEMENTATION
  // -------------------------------------------------------------

  @override
  Future<int> addDocument({
    int workspaceId = 1,
    required String entityType,
    required int entityId,
    required String documentType,
    required String title,
    required String filePath,
    int fileSize = 0,
    int? uploadedBy,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cols = ['workspace_id', 'entity_type', 'entity_id', 'document_type', 'title', 'file_path', 'file_size', 'status', 'created_at'];
    final placeholders = ['?', '?', '?', '?', '?', '?', '?', "'active'", '?'];
    final vars = <Variable>[
      Variable.withInt(workspaceId),
      Variable.withString(entityType),
      Variable.withInt(entityId),
      Variable.withString(documentType),
      Variable.withString(title),
      Variable.withString(filePath),
      Variable.withInt(fileSize),
      Variable.withInt(now),
    ];

    if (uploadedBy != null && uploadedBy > 0) {
      cols.add('uploaded_by');
      placeholders.add('?');
      vars.add(Variable.withInt(uploadedBy));
    }

    final sql = '''
      INSERT INTO crm_documents (${cols.join(', ')})
      VALUES (${placeholders.join(', ')})
      RETURNING id;
    ''';

    final res = await db.customSelect(sql, variables: vars).getSingle();
    return res.data['id'] as int;
  }

  @override
  Future<List<Map<String, dynamic>>> getDocuments({
    int workspaceId = 1,
    required String entityType,
    required int entityId,
  }) async {
    final rows = await db.customSelect(
      '''
      SELECT id, workspace_id, entity_type, entity_id, document_type, title, file_path, file_size, status, uploaded_by, created_at
      FROM crm_documents
      WHERE workspace_id = ? AND entity_type = ? AND entity_id = ?
      ORDER BY created_at DESC;
      ''',
      variables: [
        Variable.withInt(workspaceId),
        Variable.withString(entityType),
        Variable.withInt(entityId),
      ],
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  @override
  Future<void> deleteDocument(int documentId) async {
    await db.customStatement('DELETE FROM crm_documents WHERE id = ?;', [documentId]);
  }
}

