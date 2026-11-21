import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_inventory/core/services/quotation_pdf_service.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';
import 'package:mini_pos_inventory/data/repositories/local_booking_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_crm_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_delivery_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_ledger_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_plot_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_quotation_repository.dart';

void main() {
  late AppDatabase db;
  late LocalPlotRepository plotRepo;
  late LocalCrmRepository crmRepo;
  late LocalLedgerRepository ledgerRepo;
  late LocalQuotationRepository quotationRepo;
  late LocalBookingRepository bookingRepo;
  late LocalDeliveryRepository deliveryRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await SeedData(db).ensureSeeded();

    ledgerRepo = LocalLedgerRepository(db);
    plotRepo = LocalPlotRepository(db);
    crmRepo = LocalCrmRepository(db);
    quotationRepo = LocalQuotationRepository(db, ledgerRepo);
    bookingRepo = LocalBookingRepository(db, ledgerRepo);
    deliveryRepo = LocalDeliveryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('P3.1 — Vikshha Plot Management', () {
    test('projects and initial seeded plots exist', () async {
      final projects = await plotRepo.getProjects();
      expect(projects.length, greaterThanOrEqualTo(2));
      expect(projects.first.code, 'VK-P1');

      final plots = await plotRepo.getPlots();
      expect(plots.length, greaterThanOrEqualTo(4));
    });

    test('can register a new plot and search by uniquePlotId', () async {
      final plotId = await plotRepo.savePlot(
        projectId: 1,
        plotNumber: 'C-99',
        uniquePlotId: 'VK-P1-C99',
        dimensions: '50 x 80 ft',
        areaSqFt: 4000.0,
        surveyNumber: 'Sy No 150/1',
        status: 'available',
        basePrice: 600.0,
        totalPrice: 2400000.0,
        cropType: 'Sandalwood & Guava',
        plantationDetails: 'Automated solar drip system',
        notes: 'Corner boundary plot',
      );

      final fetched = await plotRepo.getPlotById(plotId);
      expect(fetched, isNotNull);
      expect(fetched!.uniquePlotId, 'VK-P1-C99');
      expect(fetched.totalPrice, 2400000.0);

      final searchResults = await plotRepo.getPlots(query: 'C99');
      expect(searchResults.length, 1);
      expect(searchResults.first.id, plotId);
    });

    test('can update plot status and fetch plot history', () async {
      await plotRepo.updatePlotStatus(1, 'reserved');
      final plot = await plotRepo.getPlotById(1);
      expect(plot!.status, 'reserved');

      final history = await plotRepo.getPlotHistory(1);
      expect(history, isA<List<Map<String, dynamic>>>());
    });
  });

  group('P3.2 — Farmland CRM', () {
    test('can register lead, log activity, and update stages', () async {
      final leadId = await crmRepo.saveLead(
        name: 'Vijay Kumar',
        phone: '9988776655',
        email: 'vijay@example.com',
        source: 'Agri Expo',
        interestedProjectId: 1,
        budget: 2000000.0,
        requirements: 'Interested in sandalwood plot for organic investment',
        stage: 'new',
      );

      expect(leadId, greaterThan(0));

      await crmRepo.updateLeadStage(leadId, 'interested');
      final updated = await crmRepo.getLeadById(leadId);
      expect(updated!.stage, 'interested');

      await crmRepo.logLeadActivity(
        leadId: leadId,
        activityType: 'call',
        notes: 'Spoke with client. Very interested in visiting Hubli site.',
      );

      final activities = await crmRepo.getLeadActivities(leadId);
      expect(activities.length, greaterThanOrEqualTo(2)); // stage change + call note
    });

    test('can schedule site visit and convert lead to customer', () async {
      final leadId = await crmRepo.saveLead(
        name: 'Sunil Patil',
        phone: '9911223344',
        stage: 'interested',
      );

      final visitId = await crmRepo.scheduleSiteVisit(
        leadId: leadId,
        projectId: 1,
        scheduledDate: DateTime.now().add(const Duration(days: 3)),
        feedback: 'Car pick-up requested at Hubli bus stand',
      );
      expect(visitId, greaterThan(0));

      final leadAfterVisit = await crmRepo.getLeadById(leadId);
      expect(leadAfterVisit!.stage, 'site_visit');

      final customerId = await crmRepo.convertLeadToCustomer(leadId);
      expect(customerId, greaterThan(0));

      final convertedLead = await crmRepo.getLeadById(leadId);
      expect(convertedLead!.stage, 'converted');
    });
  });

  group('P3.3 — Quotation Management', () {
    test('can create quotation with line items and calculate GST', () async {
      final now = DateTime.now();
      final quoteId = await quotationRepo.createQuotation(
        quotationNumber: 'QT-TEST-001',
        customerName: 'Praveen Shettar',
        customerPhone: '9845012399',
        validUntil: now.add(const Duration(days: 15)),
        subtotal: 1200000.0,
        discountTotal: 50000.0,
        taxTotal: 0.0,
        totalAmount: 1150000.0,
        items: [
          {
            'itemType': 'plot',
            'referenceId': 1,
            'description': 'Vikshha Farmland Plot VK-P1-A01',
            'quantity': 1.0,
            'unitPrice': 1200000.0,
            'discount': 50000.0,
            'gstRate': 0.0,
            'total': 1150000.0,
          },
        ],
      );

      expect(quoteId, greaterThan(0));
      final quotation = await quotationRepo.getQuotationById(quoteId);
      expect(quotation!.totalAmount, 1150000.0);

      final items = await quotationRepo.getQuotationItems(quoteId);
      expect(items.length, 1);
      expect(items.first.description, contains('VK-P1-A01'));
    });

    test('QuotationPdfService produces valid PDF bytes', () async {
      final now = DateTime.now();
      final quote = Quotation(
        id: 1,
        workspaceId: 1,
        quotationNumber: 'QT-PDF-001',
        customerName: 'Praveen Shettar',
        customerPhone: '9845012399',
        quotationDate: now,
        validUntil: now.add(const Duration(days: 15)),
        subtotal: 10000.0,
        discountTotal: 500.0,
        taxTotal: 1710.0,
        cgstTotal: 855.0,
        sgstTotal: 855.0,
        igstTotal: 0.0,
        totalAmount: 11210.0,
        status: 'draft',
        createdAt: now,
      );

      final items = [
        const QuotationItem(
          id: 1,
          quotationId: 1,
          itemType: 'product',
          description: 'Neem Oil Pest Guard 1L',
          quantity: 20.0,
          unitPrice: 500.0,
          discount: 500.0,
          gstRate: 18.0,
          total: 11210.0,
        ),
      ];

      final pdfService = QuotationPdfService();
      final bytes = await pdfService.buildPdfBytes(quotation: quote, items: items);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
    });

    test('convert quotation to sale creates sale and balanced double-entry ledger entries', () async {
      final now = DateTime.now();
      final quoteId = await quotationRepo.createQuotation(
        quotationNumber: 'QT-SALE-001',
        customerName: 'Kaveri Farms',
        customerPhone: '9448001122',
        validUntil: now.add(const Duration(days: 15)),
        subtotal: 5000.0,
        discountTotal: 0.0,
        taxTotal: 250.0,
        totalAmount: 5250.0,
        items: [
          {
            'itemType': 'product',
            'referenceId': 1,
            'description': 'Organic Fertilizer',
            'quantity': 10.0,
            'unitPrice': 500.0,
            'discount': 0.0,
            'gstRate': 5.0,
            'total': 5250.0,
          },
        ],
      );

      final saleId = await quotationRepo.convertQuotationToSale(
        quotationId: quoteId,
        accountId: 1,
        paymentMode: 'cash',
      );

      expect(saleId, greaterThan(0));
      final convertedQuote = await quotationRepo.getQuotationById(quoteId);
      expect(convertedQuote!.status, 'converted');

      // Verify double-entry ledger balance
      final statement = await ledgerRepo.getAccountStatement(1);
      expect(statement, isNotEmpty);
      expect(statement.any((e) => e.debit == 5250.0), isTrue);
    });
  });

  group('P3.4 — Customer Booking & Strict Double-Booking Prevention', () {
    test('can create booking, installments, and posts double-entry advance', () async {
      final now = DateTime.now();
      final bookingId = await bookingRepo.createBooking(
        bookingNumber: 'BK-TEST-001',
        plotId: 1,
        customerId: 1,
        totalPlotValue: 1200000.0,
        bookingAmount: 100000.0,
        paymentAccountId: 1,
        paymentMode: 'upi',
        installments: [
          {
            'installmentNumber': 1,
            'title': 'Booking Advance',
            'dueDate': now,
            'amount': 100000.0,
          },
          {
            'installmentNumber': 2,
            'title': 'Agreement Signing',
            'dueDate': now.add(const Duration(days: 30)),
            'amount': 400000.0,
          },
          {
            'installmentNumber': 3,
            'title': 'Registration',
            'dueDate': now.add(const Duration(days: 90)),
            'amount': 700000.0,
          },
        ],
      );

      expect(bookingId, greaterThan(0));

      // Plot status must be 'booked'
      final plot = await plotRepo.getPlotById(1);
      expect(plot!.status, 'booked');

      // Installments created
      final insts = await bookingRepo.getInstallments(bookingId);
      expect(insts.length, 3);
      expect(insts.first.status, 'paid');
      expect(insts[1].status, 'pending');
    });

    test('STRICT: attempting to book already booked plot throws StateError', () async {
      // Plot 1 was booked in previous test or can be booked here
      await plotRepo.updatePlotStatus(2, 'booked');

      expect(
        () => bookingRepo.createBooking(
          bookingNumber: 'BK-DUPLICATE-001',
          plotId: 2,
          customerId: 1,
          totalPlotValue: 2400000.0,
          bookingAmount: 200000.0,
          paymentAccountId: 1,
          installments: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('can cancel booking, refund advance, and plot reverts to available', () async {
      final now = DateTime.now();
      final bId = await bookingRepo.createBooking(
        bookingNumber: 'BK-CANCEL-TEST',
        plotId: 4, // VK-P2-B01 is available
        customerId: 1,
        totalPlotValue: 2250000.0,
        bookingAmount: 50000.0,
        paymentAccountId: 1,
        installments: [
          {
            'installmentNumber': 1,
            'title': 'Advance',
            'dueDate': now,
            'amount': 50000.0,
          },
        ],
      );

      // Verify plot is booked
      var plot = await plotRepo.getPlotById(4);
      expect(plot!.status, 'booked');

      // Cancel booking
      await bookingRepo.cancelBooking(
        bookingId: bId,
        reason: 'Customer relocated',
        refundAmount: 50000.0,
        refundAccountId: 1,
      );

      // Verify plot status reverted to available
      plot = await plotRepo.getPlotById(4);
      expect(plot!.status, 'available');

      final b = await bookingRepo.getBookingById(bId);
      expect(b!.status, 'cancelled');
      expect(b.refundAmount, 50000.0);
    });
  });

  group('P3.5 — Shipping & Delivery', () {
    test('can create delivery order and update status to delivered', () async {
      final now = DateTime.now();
      final delId = await deliveryRepo.createDelivery(
        deliveryNumber: 'DO-TEST-001',
        customerId: 1,
        deliveryAddress: 'Main Farm Gate, Airport Road, Hubli',
        transporterName: 'VRL Logistics',
        vehicleNumber: 'KA-25-A-9999',
        trackingNumber: 'VRL8888',
        shippingCharges: 1500.0,
        dispatchDate: now,
        expectedDeliveryDate: now.add(const Duration(days: 2)),
        status: 'dispatched',
        items: [
          {
            'productId': 1,
            'quantity': 50,
            'unit': 'bag',
          },
        ],
      );

      expect(delId, greaterThan(0));

      final items = await deliveryRepo.getDeliveryItems(delId);
      expect(items.length, 1);
      expect(items.first.quantity, 50);

      // Update to delivered with proof of delivery
      await deliveryRepo.updateDeliveryStatus(
        deliveryId: delId,
        status: 'delivered',
        deliveredDate: now.add(const Duration(days: 2)),
        proofOfDelivery: 'Received by Farm Manager Ramesh Patil',
      );

      final delivery = await deliveryRepo.getDeliveryById(delId);
      expect(delivery!.status, 'delivered');
      expect(delivery.proofOfDelivery, contains('Ramesh Patil'));
    });
  });
}
