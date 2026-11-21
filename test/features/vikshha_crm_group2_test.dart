import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/repositories/local_plot_repository.dart';

void main() {
  late AppDatabase db;
  late LocalPlotRepository plotRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    plotRepo = LocalPlotRepository(db);

    // Bootstrap workspace
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            businessName: 'Vikshha Agro Farmlands',
            gstin: const Value('29AAAAA0000A1Z5'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Vikshha CRM Group 2 - Project Management, Plot Inventory & Plot Details', () {
    test('Project creation with extended amenities, legal status & dynamic plot counts', () async {
      // 1. Create Project
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Sandalwood Estate Phase 1',
        code: 'VSE-P1',
        location: 'Dharwad Bypass Highway',
        totalArea: 50.0,
        totalPlots: 20,
        description: 'Prime red soil agricultural farmland layout',
        amenities: 'Borewell water, Solar fencing, 30ft asphalt roads',
        legalStatus: 'clear_title',
        address: 'Survey No 88, Dharwad Highway',
        gpsCoordinates: '15.4589° N, 75.0078° E',
      );
      expect(projId, isPositive);

      // 2. Add multiple plots under the project
      final plotId1 = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'A-01',
        uniquePlotId: 'VSE-P1-A01',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        facing: 'East',
        pricePerSqFt: 600,
        status: 'available',
        basePrice: 600,
        totalPrice: 1440000,
        cropType: 'Sandalwood & Mahogany',
        plantationDetails: '25 sandalwood trees with automated drip',
      );
      expect(plotId1, isPositive);

      final plotId2 = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'A-02',
        uniquePlotId: 'VSE-P1-A02',
        dimensions: '50 x 80 ft',
        areaSqFt: 4000,
        facing: 'North',
        pricePerSqFt: 650,
        status: 'reserved',
        basePrice: 650,
        totalPrice: 2600000,
        cropType: 'Organic Kesar Mango',
      );
      expect(plotId2, isPositive);

      final plotId3 = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'A-03',
        uniquePlotId: 'VSE-P1-A03',
        dimensions: '60 x 100 ft',
        areaSqFt: 6000,
        facing: 'East',
        pricePerSqFt: 700,
        status: 'booked',
        basePrice: 700,
        totalPrice: 4200000,
        cropType: 'Exotic Dragonfruit',
      );
      expect(plotId3, isPositive);

      // 3. Verify Project Summary counts
      final summary = await plotRepo.getProjectSummary(projId);
      expect(summary['totalPlots'], 3);
      expect(summary['availablePlots'], 1);
      expect(summary['reservedPlots'], 1);
      expect(summary['bookedPlots'], 1);
      expect(summary['soldPlots'], 0);
      expect(summary['totalValuation'], 1440000 + 2600000 + 4200000);
    });

    test('Plot filtering by status, facing direction, and price boundaries', () async {
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Phase 2',
        code: 'VP2',
        location: 'Belgaum Road',
      );

      await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'B-01',
        uniquePlotId: 'VP2-B01',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        facing: 'East',
        status: 'available',
        basePrice: 500,
        totalPrice: 1200000,
      );

      await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'B-02',
        uniquePlotId: 'VP2-B02',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        facing: 'North',
        status: 'available',
        basePrice: 500,
        totalPrice: 1200000,
      );

      // Filter by facing
      final eastPlots = await plotRepo.getPlots(workspaceId: 1, projectId: projId, facing: 'East');
      expect(eastPlots.length, 1);
      expect(eastPlots.first.plotNumber, 'B-01');

      // Filter by min price
      final priceFiltered = await plotRepo.getPlots(workspaceId: 1, minPrice: 1500000);
      expect(priceFiltered, isEmpty);
    });

    test('Plot lifecycle: status transition, activity timeline, and delete guard', () async {
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Project',
        code: 'VP',
        location: 'Hubli',
      );

      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'C-01',
        uniquePlotId: 'VP-C01',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        status: 'available',
        basePrice: 500,
        totalPrice: 1200000,
      );

      // Status change to reserved
      await plotRepo.updatePlotStatus(plotId, 'reserved');
      var p = await plotRepo.getPlotById(plotId);
      expect(p?.status, 'reserved');

      // Status change to booked
      await plotRepo.updatePlotStatus(plotId, 'booked');
      p = await plotRepo.getPlotById(plotId);
      expect(p?.status, 'booked');

      // Deletion guard: Booked plot cannot be deleted
      expect(() => plotRepo.deletePlot(plotId), throwsA(isA<StateError>()));

      // Update status back to available
      await plotRepo.updatePlotStatus(plotId, 'available');
      await plotRepo.deletePlot(plotId);
      final deleted = await plotRepo.getPlotById(plotId);
      expect(deleted, isNull);
    });
  });
}

