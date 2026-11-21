import 'package:drift/drift.dart';

import '../../domain/repositories/repositories.dart';
import '../local/db/app_database.dart';

class LocalPlotRepository implements PlotRepository {
  const LocalPlotRepository(this.db);

  final AppDatabase db;

  @override
  Future<List<Project>> getProjects({int workspaceId = 1}) async {
    final query = db.select(db.projects)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.get();
  }

  @override
  Future<Map<String, dynamic>> getProjectSummary(int projectId) async {
    final plots = await (db.select(db.plots)..where((tbl) => tbl.projectId.equals(projectId))).get();
    final totalPlots = plots.length;
    final available = plots.where((p) => p.status == 'available').length;
    final reserved = plots.where((p) => p.status == 'reserved').length;
    final booked = plots.where((p) => p.status == 'booked').length;
    final sold = plots.where((p) => p.status == 'sold').length;
    final totalValuation = plots.fold<double>(0.0, (acc, p) => acc + p.totalPrice);

    return {
      'totalPlots': totalPlots,
      'availablePlots': available,
      'reservedPlots': reserved,
      'bookedPlots': booked,
      'soldPlots': sold,
      'totalValuation': totalValuation,
    };
  }

  @override
  Future<int> saveProject({
    int? id,
    int workspaceId = 1,
    required String name,
    required String code,
    required String location,
    double totalArea = 0.0,
    int totalPlots = 0,
    String? description,
    String? amenities,
    String? legalStatus,
    String? address,
    String? gpsCoordinates,
    String status = 'active',
  }) async {
    int projId;
    if (id != null && id > 0) {
      await (db.update(db.projects)..where((tbl) => tbl.id.equals(id))).write(
        ProjectsCompanion(
          name: Value(name),
          code: Value(code),
          location: Value(location),
          totalArea: Value(totalArea),
          totalPlots: Value(totalPlots),
          description: Value(description),
          status: Value(status),
        ),
      );
      projId = id;
    } else {
      projId = await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              workspaceId: workspaceId,
              name: name,
              code: code,
              location: location,
              totalArea: Value(totalArea),
              totalPlots: Value(totalPlots),
              description: Value(description),
              status: Value(status),
            ),
          );
    }

    try {
      await db.customStatement(
        'UPDATE projects SET amenities = ?, legal_status = ?, address = ?, gps_coordinates = ? WHERE id = ?;',
        [amenities, legalStatus, address, gpsCoordinates, projId],
      );
    } catch (_) {}

    return projId;
  }

  @override
  Future<List<Plot>> getPlots({
    int workspaceId = 1,
    int? projectId,
    String? status,
    String? facing,
    double? minPrice,
    double? maxPrice,
    String? query,
  }) async {
    final q = db.select(db.plots)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId));

    if (projectId != null && projectId > 0) {
      q.where((tbl) => tbl.projectId.equals(projectId));
    }

    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      q.where((tbl) => tbl.status.equals(status.toLowerCase()));
    }

    var rows = await q.get();

    if (facing != null && facing.isNotEmpty && facing.toLowerCase() != 'all') {
      try {
        final facingRows = await db.customSelect(
          'SELECT id FROM plots WHERE workspace_id = ? AND LOWER(facing) = ?;',
          variables: [Variable.withInt(workspaceId), Variable.withString(facing.toLowerCase())],
        ).get();
        final facingIds = facingRows.map((r) => r.data['id'] as int).toSet();
        rows = rows.where((p) => facingIds.contains(p.id)).toList();
      } catch (_) {}
    }

    if (minPrice != null && minPrice > 0) {
      rows = rows.where((p) => p.totalPrice >= minPrice).toList();
    }
    if (maxPrice != null && maxPrice > 0) {
      rows = rows.where((p) => p.totalPrice <= maxPrice).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final clean = query.trim().toLowerCase();
      return rows.where((plot) {
        final matchesNumber = plot.plotNumber.toLowerCase().contains(clean);
        final matchesUniqueId = plot.uniquePlotId.toLowerCase().contains(clean);
        final matchesSurvey = plot.surveyNumber?.toLowerCase().contains(clean) ?? false;
        final matchesCrop = plot.cropType?.toLowerCase().contains(clean) ?? false;
        return matchesNumber || matchesUniqueId || matchesSurvey || matchesCrop;
      }).toList();
    }

    return rows;
  }

  @override
  Future<Plot?> getPlotById(int plotId) async {
    final query = db.select(db.plots)..where((tbl) => tbl.id.equals(plotId));
    return query.getSingleOrNull();
  }

  @override
  Future<int> savePlot({
    int? id,
    int workspaceId = 1,
    required int projectId,
    required String plotNumber,
    required String uniquePlotId,
    required String dimensions,
    required double areaSqFt,
    String? surveyNumber,
    String? facing,
    double pricePerSqFt = 0.0,
    String status = 'available',
    required double basePrice,
    required double totalPrice,
    String? cropType,
    String? plantationDetails,
    String? imagePath,
    String? documentPath,
    String? notes,
  }) async {
    final now = DateTime.now();
    int plotId;
    if (id != null && id > 0) {
      await (db.update(db.plots)..where((tbl) => tbl.id.equals(id))).write(
        PlotsCompanion(
          projectId: Value(projectId),
          plotNumber: Value(plotNumber),
          uniquePlotId: Value(uniquePlotId),
          dimensions: Value(dimensions),
          areaSqFt: Value(areaSqFt),
          surveyNumber: Value(surveyNumber),
          status: Value(status),
          basePrice: Value(basePrice),
          totalPrice: Value(totalPrice),
          cropType: Value(cropType),
          plantationDetails: Value(plantationDetails),
          imagePath: Value(imagePath),
          documentPath: Value(documentPath),
          notes: Value(notes),
          updatedAt: Value(now),
        ),
      );
      plotId = id;
    } else {
      plotId = await db.into(db.plots).insert(
            PlotsCompanion.insert(
              workspaceId: workspaceId,
              projectId: projectId,
              plotNumber: plotNumber,
              uniquePlotId: uniquePlotId,
              dimensions: dimensions,
              areaSqFt: areaSqFt,
              surveyNumber: Value(surveyNumber),
              status: Value(status),
              basePrice: basePrice,
              totalPrice: totalPrice,
              cropType: Value(cropType),
              plantationDetails: Value(plantationDetails),
              imagePath: Value(imagePath),
              documentPath: Value(documentPath),
              notes: Value(notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }

    try {
      await db.customStatement(
        'UPDATE plots SET facing = ?, price_per_sq_ft = ? WHERE id = ?;',
        [facing ?? 'East', pricePerSqFt, plotId],
      );
    } catch (_) {}

    return plotId;
  }

  @override
  Future<void> updatePlotStatus(int plotId, String status) async {
    await (db.update(db.plots)..where((tbl) => tbl.id.equals(plotId))).write(
      PlotsCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deletePlot(int plotId) async {
    // Prevent deletion if plot is booked or sold
    final plot = await getPlotById(plotId);
    if (plot == null) return;
    if (plot.status == 'booked' || plot.status == 'sold') {
      throw StateError('Cannot delete plot in "${plot.status}" status.');
    }
    await (db.delete(db.plots)..where((tbl) => tbl.id.equals(plotId))).go();
  }

  @override
  Future<List<Map<String, dynamic>>> getPlotHistory(int plotId) async {
    final history = <Map<String, dynamic>>[];

    // 1. Plot bookings
    final bookings = await (db.select(db.plotBookings)
          ..where((tbl) => tbl.plotId.equals(plotId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.bookingDate)]))
        .get();

    for (final b in bookings) {
      history.add({
        'type': 'booking',
        'title': 'Booking ${b.bookingNumber}',
        'date': b.bookingDate,
        'status': b.status,
        'amount': b.totalPlotValue,
        'details': 'Advance: ₹${b.bookingAmount} | Status: ${b.status}',
      });
    }

    // 2. Site visits
    final visits = await (db.select(db.siteVisits)
          ..where((tbl) => tbl.plotId.equals(plotId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDate)]))
        .get();

    for (final v in visits) {
      history.add({
        'type': 'site_visit',
        'title': 'Site Visit',
        'date': v.scheduledDate,
        'status': v.status,
        'amount': 0.0,
        'details': v.feedback ?? 'Site inspection scheduled/completed',
      });
    }

    return history;
  }
}

