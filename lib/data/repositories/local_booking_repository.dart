import 'package:drift/drift.dart';

import '../../core/models/app_models.dart';
import '../../domain/repositories/repositories.dart';
import '../local/db/app_database.dart';

class LocalBookingRepository implements BookingRepository {
  const LocalBookingRepository(this.db, this.ledgerRepository);

  final AppDatabase db;
  final LedgerRepository ledgerRepository;

  @override
  Future<List<PlotBooking>> getBookings({
    int workspaceId = 1,
    String? status,
    String? query,
  }) async {
    final q = db.select(db.plotBookings)
      ..where((tbl) => tbl.workspaceId.equals(workspaceId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.bookingDate)]);

    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      q.where((tbl) => tbl.status.equals(status.toLowerCase()));
    }

    final rows = await q.get();

    if (query != null && query.trim().isNotEmpty) {
      final clean = query.trim().toLowerCase();
      return rows.where((b) {
        final matchesNumber = b.bookingNumber.toLowerCase().contains(clean);
        return matchesNumber;
      }).toList();
    }

    return rows;
  }

  @override
  Future<PlotBooking?> getBookingById(int bookingId) async {
    final query = db.select(db.plotBookings)..where((tbl) => tbl.id.equals(bookingId));
    return query.getSingleOrNull();
  }

  @override
  Future<List<BookingInstallment>> getInstallments(int bookingId) async {
    final query = db.select(db.bookingInstallments)
      ..where((tbl) => tbl.bookingId.equals(bookingId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.installmentNumber)]);
    return query.get();
  }

  @override
  Future<int> reservePlot({
    int workspaceId = 1,
    required int plotId,
    required int customerId,
    int? leadId,
    int? employeeId,
    required double totalPlotValue,
    required double reservationAmount,
    required int paymentAccountId,
    String paymentMode = 'upi',
    int expiryDays = 7,
    String? notes,
  }) async {
    return db.transaction(() async {
      final plot = await (db.select(db.plots)..where((tbl) => tbl.id.equals(plotId))).getSingleOrNull();
      if (plot == null) throw StateError('Plot not found.');
      if (plot.status != 'available') {
        throw StateError('Cannot reserve plot ${plot.uniquePlotId} with status "${plot.status}".');
      }

      final now = DateTime.now();
      final expiry = now.add(Duration(days: expiryDays));
      final bookingNumber = 'RES-${now.millisecondsSinceEpoch.toString().substring(7)}';

      // Mark plot as reserved
      await (db.update(db.plots)..where((tbl) => tbl.id.equals(plotId))).write(
        PlotsCompanion(status: const Value('reserved'), updatedAt: Value(now)),
      );

      final bookingId = await db.into(db.plotBookings).insert(
            PlotBookingsCompanion.insert(
              workspaceId: workspaceId,
              bookingNumber: bookingNumber,
              plotId: plotId,
              customerId: customerId,
              leadId: Value(leadId),
              employeeId: Value(employeeId),
              bookingDate: Value(now),
              totalPlotValue: totalPlotValue,
              bookingAmount: reservationAmount,
              paymentAccountId: Value(paymentAccountId),
              paymentMode: Value(paymentMode),
              status: const Value('reserved'),
              notes: Value(notes ?? 'Plot reservation for $expiryDays days'),
              createdAt: Value(now),
            ),
          );

      try {
        await db.customStatement(
          'UPDATE plot_bookings SET reservation_amount = ?, reservation_expiry = ? WHERE id = ?;',
          [reservationAmount, expiry.millisecondsSinceEpoch, bookingId],
        );
      } catch (_) {}

      // Ledger posting for reservation token advance
      if (reservationAmount > 0) {
        await ledgerRepository.postTransaction(
          workspaceId: workspaceId,
          entries: [
            LedgerPostingItem(
              transactionType: 'payment_in',
              referenceType: 'account',
              referenceId: paymentAccountId,
              accountId: paymentAccountId,
              partyType: 'customer',
              partyId: customerId,
              debit: reservationAmount,
              credit: 0.0,
              narration: 'Plot reservation token for ${plot.uniquePlotId}',
            ),
            LedgerPostingItem(
              transactionType: 'payment_in',
              referenceType: 'customer',
              referenceId: customerId,
              accountId: paymentAccountId,
              partyType: 'customer',
              partyId: customerId,
              debit: 0.0,
              credit: reservationAmount,
              narration: 'Plot reservation token advance credit',
            ),
          ],
        );
      }

      return bookingId;
    });
  }

  @override
  Future<void> releaseExpiredReservations({int workspaceId = 1}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredRows = await db.customSelect(
      '''
      SELECT id, plot_id FROM plot_bookings
      WHERE workspace_id = ? AND status = 'reserved' AND reservation_expiry IS NOT NULL AND reservation_expiry < ?;
      ''',
      variables: [Variable.withInt(workspaceId), Variable.withInt(now)],
    ).get();

    for (final row in expiredRows) {
      final bId = row.data['id'] as int;
      final plotId = row.data['plot_id'] as int;

      await (db.update(db.plotBookings)..where((tbl) => tbl.id.equals(bId))).write(
        const PlotBookingsCompanion(
          status: Value('cancelled'),
          cancellationReason: Value('Reservation expired automatically'),
        ),
      );

      await (db.update(db.plots)..where((tbl) => tbl.id.equals(plotId))).write(
        PlotsCompanion(status: const Value('available'), updatedAt: Value(DateTime.now())),
      );
    }
  }

  @override
  Future<int> createBooking({
    int workspaceId = 1,
    required String bookingNumber,
    required int plotId,
    required int customerId,
    int? leadId,
    int? employeeId,
    required double totalPlotValue,
    required double bookingAmount,
    double discount = 0.0,
    required int paymentAccountId,
    String paymentMode = 'upi',
    String? referenceNo,
    String? notes,
    required List<Map<String, dynamic>> installments,
  }) async {
    return db.transaction(() async {
      // 1. Strict validation: Ensure plot is NOT already booked or sold!
      final plot = await (db.select(db.plots)..where((tbl) => tbl.id.equals(plotId))).getSingleOrNull();
      if (plot == null) {
        throw StateError('Plot not found.');
      }
      if (plot.status == 'booked' || plot.status == 'sold') {
        throw StateError('Plot ${plot.uniquePlotId} is already ${plot.status}. Double-booking is strictly prohibited.');
      }

      final now = DateTime.now();

      // 2. Insert booking record
      final bookingId = await db.into(db.plotBookings).insert(
            PlotBookingsCompanion.insert(
              workspaceId: workspaceId,
              bookingNumber: bookingNumber,
              plotId: plotId,
              customerId: customerId,
              leadId: Value(leadId),
              employeeId: Value(employeeId),
              bookingDate: Value(now),
              totalPlotValue: totalPlotValue,
              bookingAmount: bookingAmount,
              paymentAccountId: Value(paymentAccountId),
              paymentMode: Value(paymentMode),
              referenceNo: Value(referenceNo),
              status: const Value('booked'),
              notes: Value(notes),
              createdAt: Value(now),
            ),
          );

      try {
        await db.customStatement(
          'UPDATE plot_bookings SET discount = ?, agreement_status = "draft" WHERE id = ?;',
          [discount, bookingId],
        );
      } catch (_) {}

      // 3. Mark plot status as 'booked'
      await (db.update(db.plots)..where((tbl) => tbl.id.equals(plotId))).write(
        PlotsCompanion(
          status: const Value('booked'),
          updatedAt: Value(now),
        ),
      );

      // 4. Insert installment schedule
      for (final inst in installments) {
        final isAdvance = (inst['installmentNumber'] as int) == 1;
        await db.into(db.bookingInstallments).insert(
              BookingInstallmentsCompanion.insert(
                bookingId: bookingId,
                installmentNumber: inst['installmentNumber'] as int,
                title: inst['title'] as String? ?? 'Installment',
                dueDate: inst['dueDate'] as DateTime? ?? now,
                amount: (inst['amount'] as num).toDouble(),
                paidAmount: Value(isAdvance ? bookingAmount : 0.0),
                paidDate: Value(isAdvance ? now : null),
                status: Value(isAdvance ? 'paid' : 'pending'),
                paymentAccountId: Value(isAdvance ? paymentAccountId : null),
              ),
            );
      }

      // 5. Post double-entry financial ledger entries for the booking advance
      if (bookingAmount > 0) {
        await ledgerRepository.postTransaction(
          workspaceId: workspaceId,
          entries: [
            // DR Cash/Bank Account (Asset increases)
            LedgerPostingItem(
              transactionType: 'payment_in',
              referenceType: 'account',
              referenceId: paymentAccountId,
              accountId: paymentAccountId,
              partyType: 'customer',
              partyId: customerId,
              debit: bookingAmount,
              credit: 0.0,
              narration: 'Booking advance for Plot ${plot.uniquePlotId} ($bookingNumber)',
            ),
            // CR Customer Account / Plot Advance Liability
            LedgerPostingItem(
              transactionType: 'payment_in',
              referenceType: 'customer',
              referenceId: customerId,
              accountId: paymentAccountId,
              partyType: 'customer',
              partyId: customerId,
              debit: 0.0,
              credit: bookingAmount,
              narration: 'Plot booking advance credit ($bookingNumber)',
            ),
          ],
        );

        // Record Payment transaction
        await db.into(db.payments).insert(
              PaymentsCompanion.insert(
                workspaceId: workspaceId,
                accountId: paymentAccountId,
                paymentType: 'customer_receipt',
                referenceType: 'booking',
                referenceId: Value(bookingId),
                amount: bookingAmount,
                paymentMode: paymentMode,
                referenceNo: Value(referenceNo ?? bookingNumber),
                narration: Value('Booking advance for Plot ${plot.uniquePlotId}'),
                createdAt: Value(now),
              ),
            );
      }

      return bookingId;
    });
  }

  @override
  Future<void> payInstallment({
    required int installmentId,
    required double amount,
    required int paymentAccountId,
    String paymentMode = 'upi',
    String? referenceNo,
  }) async {
    return db.transaction(() async {
      final inst = await (db.select(db.bookingInstallments)..where((tbl) => tbl.id.equals(installmentId))).getSingleOrNull();
      if (inst == null) throw StateError('Installment not found.');

      final booking = await getBookingById(inst.bookingId);
      if (booking == null) throw StateError('Booking not found.');

      final now = DateTime.now();
      final newPaid = inst.paidAmount + amount;
      final newStatus = newPaid >= inst.amount ? 'paid' : 'partial';

      await (db.update(db.bookingInstallments)..where((tbl) => tbl.id.equals(installmentId))).write(
        BookingInstallmentsCompanion(
          paidAmount: Value(newPaid),
          paidDate: Value(now),
          status: Value(newStatus),
          paymentAccountId: Value(paymentAccountId),
        ),
      );

      // Post balanced double-entry ledger entry
      await ledgerRepository.postTransaction(
        workspaceId: booking.workspaceId,
        entries: [
          LedgerPostingItem(
            transactionType: 'payment_in',
            referenceType: 'account',
            referenceId: paymentAccountId,
            accountId: paymentAccountId,
            partyType: 'customer',
            partyId: booking.customerId,
            debit: amount,
            credit: 0.0,
            narration: 'Installment payment #${inst.installmentNumber} for Booking ${booking.bookingNumber}',
          ),
          LedgerPostingItem(
            transactionType: 'payment_in',
            referenceType: 'customer',
            referenceId: booking.customerId,
            accountId: paymentAccountId,
            partyType: 'customer',
            partyId: booking.customerId,
            debit: 0.0,
            credit: amount,
            narration: 'Installment #${inst.installmentNumber} credit for Booking ${booking.bookingNumber}',
          ),
        ],
      );

      // Record payment
      await db.into(db.payments).insert(
            PaymentsCompanion.insert(
              workspaceId: booking.workspaceId,
              accountId: paymentAccountId,
              paymentType: 'customer_receipt',
              referenceType: 'booking',
              referenceId: Value(booking.id),
              amount: amount,
              paymentMode: paymentMode,
              referenceNo: Value(referenceNo ?? booking.bookingNumber),
              narration: Value('Installment #${inst.installmentNumber} payment for ${booking.bookingNumber}'),
              createdAt: Value(now),
            ),
          );
    });
  }

  @override
  Future<void> cancelBooking({
    required int bookingId,
    required String reason,
    required double refundAmount,
    required int refundAccountId,
  }) async {
    return db.transaction(() async {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw StateError('Booking not found.');
      if (booking.status == 'cancelled') throw StateError('Booking is already cancelled.');

      final now = DateTime.now();

      // 1. Mark booking as cancelled
      await (db.update(db.plotBookings)..where((tbl) => tbl.id.equals(bookingId))).write(
        PlotBookingsCompanion(
          status: const Value('cancelled'),
          cancellationReason: Value(reason),
          refundAmount: Value(refundAmount),
          refundAccountId: Value(refundAccountId),
          refundDate: Value(now),
        ),
      );

      // 2. Revert plot status to 'available'
      await (db.update(db.plots)..where((tbl) => tbl.id.equals(booking.plotId))).write(
        PlotsCompanion(
          status: const Value('available'),
          updatedAt: Value(now),
        ),
      );

      // 3. Post double-entry refund ledger entries if refund is paid
      if (refundAmount > 0) {
        await ledgerRepository.postTransaction(
          workspaceId: booking.workspaceId,
          entries: [
            // DR Customer / Booking Refund
            LedgerPostingItem(
              transactionType: 'payment_out',
              referenceType: 'customer',
              referenceId: booking.customerId,
              accountId: refundAccountId,
              partyType: 'customer',
              partyId: booking.customerId,
              debit: refundAmount,
              credit: 0.0,
              narration: 'Refund debit for cancelled booking ${booking.bookingNumber}',
            ),
            // CR Cash/Bank Account (Asset decreases)
            LedgerPostingItem(
              transactionType: 'payment_out',
              referenceType: 'account',
              referenceId: refundAccountId,
              accountId: refundAccountId,
              partyType: 'customer',
              partyId: booking.customerId,
              debit: 0.0,
              credit: refundAmount,
              narration: 'Refund payment for cancelled booking ${booking.bookingNumber}',
            ),
          ],
        );

        // Record Payment transaction
        await db.into(db.payments).insert(
              PaymentsCompanion.insert(
                workspaceId: booking.workspaceId,
                accountId: refundAccountId,
                paymentType: 'customer_refund',
                referenceType: 'booking',
                referenceId: Value(booking.id),
                amount: refundAmount,
                paymentMode: 'bank_transfer',
                referenceNo: Value('REFUND-${booking.bookingNumber}'),
                narration: Value('Refund for cancelled booking: $reason'),
                createdAt: Value(now),
              ),
            );
      }
    });
  }

  @override
  Future<Map<String, dynamic>> getBookingStatement(int bookingId) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw StateError('Booking #$bookingId not found.');

    final plot = await (db.select(db.plots)..where((tbl) => tbl.id.equals(booking.plotId))).getSingle();
    final customer = await (db.select(db.customers)..where((tbl) => tbl.id.equals(booking.customerId))).getSingle();
    final installments = await getInstallments(bookingId);

    final totalValue = booking.totalPlotValue;
    final totalPaid = installments.fold<double>(0.0, (acc, inst) => acc + inst.paidAmount);
    final balanceOutstanding = (totalValue - totalPaid).clamp(0.0, double.infinity);

    // Payments linked to this booking
    final payments = await (db.select(db.payments)
          ..where((tbl) => tbl.referenceType.equals('booking'))
          ..where((tbl) => tbl.referenceId.equals(bookingId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();

    return {
      'booking': booking,
      'plot': plot,
      'customer': customer,
      'installments': installments,
      'totalValue': totalValue,
      'totalPaid': totalPaid,
      'balanceOutstanding': balanceOutstanding,
      'payments': payments,
    };
  }

  @override
  Future<void> updateAgreementStatus(int bookingId, String agreementStatus) async {
    await db.customStatement(
      'UPDATE plot_bookings SET agreement_status = ? WHERE id = ?;',
      [agreementStatus.toLowerCase(), bookingId],
    );
  }

  @override
  Future<int> claimSalesCommission({
    int workspaceId = 1,
    required int bookingId,
    required int employeeId,
    required double commissionRate,
    String? remarks,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw StateError('Booking #$bookingId not found.');

    final commissionAmount = (booking.totalPlotValue * (commissionRate / 100)).roundToDouble();
    final bookingRefTag = '[BK#$bookingId:${booking.bookingNumber}]';
    final desc = '${remarks ?? "Sales commission for Farmland Booking ${booking.bookingNumber} ($commissionRate%)"} $bookingRefTag';

    // Check if claim already exists for employee and this booking
    final allClaims = await (db.select(db.incentiveClaims)
          ..where((tbl) => tbl.employeeId.equals(employeeId)))
        .get();

    final existing = allClaims.where((c) => c.description.contains(bookingRefTag)).firstOrNull;

    if (existing != null) {
      return existing.id;
    }

    final claimId = await db.into(db.incentiveClaims).insert(
          IncentiveClaimsCompanion.insert(
            workspaceId: workspaceId,
            employeeId: employeeId,
            amount: commissionAmount,
            description: desc,
            status: const Value('pending'),
            createdAt: Value(DateTime.now()),
          ),
        );

    return claimId;
  }
}
