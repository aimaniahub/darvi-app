import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/repositories/local_booking_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_ledger_repository.dart';
import 'package:mini_pos_inventory/data/repositories/local_plot_repository.dart';

void main() {
  late AppDatabase db;
  late LocalLedgerRepository ledgerRepo;
  late LocalBookingRepository bookingRepo;
  late LocalPlotRepository plotRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledgerRepo = LocalLedgerRepository(db);
    bookingRepo = LocalBookingRepository(db, ledgerRepo);
    plotRepo = LocalPlotRepository(db);

    // Bootstrap workspace
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            businessName: 'Vikshha Agro Farmlands',
            gstin: const Value('29AAAAA0000A1Z5'),
          ),
        );

    // Bootstrap payment account (Bank Account)
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            workspaceId: 1,
            name: 'Company ICICI Bank A/C',
            type: 'bank',
            currentBalance: const Value(500000.0),
          ),
        );

    // Bootstrap customer
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            workspaceId: const Value(1),
            name: 'Ramesh Patil',
            phone: const Value('9900011223'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Vikshha CRM Group 4 - Plot Reservations, Booking Management & Details', () {
    test('Plot Reservation lifecycle: temporary hold with expiry and auto-release', () async {
      // 1. Create Project and Plot
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha River View',
        code: 'VRV',
        location: 'Dharwad',
      );
      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'F-01',
        uniquePlotId: 'VRV-F01',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        status: 'available',
        basePrice: 600,
        totalPrice: 1440000,
      );

      // 2. Reserve plot for 3 days with token advance ₹25,000
      final resId = await bookingRepo.reservePlot(
        workspaceId: 1,
        plotId: plotId,
        customerId: 1,
        totalPlotValue: 1440000,
        reservationAmount: 25000,
        paymentAccountId: 1,
        expiryDays: 3,
        notes: 'Hold for bank loan pre-approval',
      );
      expect(resId, isPositive);

      // Verify Plot status transitioned to 'reserved'
      var plot = await plotRepo.getPlotById(plotId);
      expect(plot?.status, 'reserved');

      // Verify Booking status is 'reserved'
      final booking = await bookingRepo.getBookingById(resId);
      expect(booking?.status, 'reserved');
      expect(booking?.bookingAmount, 25000.0);

      // 3. Double-reservation guard: Cannot reserve or book an already reserved plot
      expect(
        () => bookingRepo.reservePlot(
          workspaceId: 1,
          plotId: plotId,
          customerId: 1,
          totalPlotValue: 1440000,
          reservationAmount: 25000,
          paymentAccountId: 1,
        ),
        throwsA(isA<StateError>()),
      );

      // 4. Test release expired reservations: simulate past expiry
      final pastExpiry = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      await db.customStatement(
        'UPDATE plot_bookings SET reservation_expiry = ? WHERE id = ?;',
        [pastExpiry, resId],
      );

      await bookingRepo.releaseExpiredReservations(workspaceId: 1);

      // Verify plot is now unlocked back to 'available'
      plot = await plotRepo.getPlotById(plotId);
      expect(plot?.status, 'available');

      final expiredBooking = await bookingRepo.getBookingById(resId);
      expect(expiredBooking?.status, 'cancelled');
    });

    test('Booking Creation with discount, installment milestone schedule, and cancellation refund', () async {
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Woods',
        code: 'VW',
        location: 'Hubli',
      );
      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'G-10',
        uniquePlotId: 'VW-G10',
        dimensions: '50 x 80 ft',
        areaSqFt: 4000,
        status: 'available',
        basePrice: 500,
        totalPrice: 2000000,
      );

      // Create Booking with 3 milestone installments
      final now = DateTime.now();
      final bookingId = await bookingRepo.createBooking(
        workspaceId: 1,
        bookingNumber: 'BK-2026-VW-G10',
        plotId: plotId,
        customerId: 1,
        totalPlotValue: 2000000,
        bookingAmount: 400000, // 20% advance
        discount: 50000,
        paymentAccountId: 1,
        paymentMode: 'bank_transfer',
        installments: [
          {
            'installmentNumber': 1,
            'title': 'Booking Token Advance',
            'dueDate': now,
            'amount': 400000.0,
          },
          {
            'installmentNumber': 2,
            'title': 'Sale Agreement Signing',
            'dueDate': now.add(const Duration(days: 30)),
            'amount': 600000.0,
          },
          {
            'installmentNumber': 3,
            'title': 'Registration & Possession',
            'dueDate': now.add(const Duration(days: 90)),
            'amount': 950000.0,
          },
        ],
      );

      expect(bookingId, isPositive);

      // Verify plot is marked 'booked'
      final plot = await plotRepo.getPlotById(plotId);
      expect(plot?.status, 'booked');

      // Verify installments
      final installments = await bookingRepo.getInstallments(bookingId);
      expect(installments.length, 3);
      expect(installments[0].status, 'paid');
      expect(installments[0].paidAmount, 400000.0);
      expect(installments[1].status, 'pending');

      // Cancel booking with ₹350,000 refund (₹50,000 retention penalty)
      await bookingRepo.cancelBooking(
        bookingId: bookingId,
        reason: 'Client requested cancellation due to family relocation',
        refundAmount: 350000,
        refundAccountId: 1,
      );

      // Verify booking cancelled and plot restored to 'available'
      final cancelledBooking = await bookingRepo.getBookingById(bookingId);
      expect(cancelledBooking?.status, 'cancelled');
      expect(cancelledBooking?.refundAmount, 350000.0);

      final restoredPlot = await plotRepo.getPlotById(plotId);
      expect(restoredPlot?.status, 'available');
    });
  });
}

