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
            businessName: 'Vikshha Organic Agro Tech',
            gstin: const Value('29AAAAA0000A1Z5'),
          ),
        );

    // Bootstrap bank account
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            workspaceId: 1,
            name: 'Company HDFC Current A/C',
            type: 'bank',
            currentBalance: const Value(1000000.0),
          ),
        );

    // Bootstrap customer
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            workspaceId: const Value(1),
            name: 'Prakash Rao',
            phone: const Value('9844012345'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Vikshha CRM Group 5 - Payments, Installments & Booking Statements', () {
    test('Installment partial payments, balanced double-entry ledger & status transitions', () async {
      // 1. Create Project, Plot and Booking
      final projId = await plotRepo.saveProject(
        workspaceId: 1,
        name: 'Vikshha Green Acres',
        code: 'VGA',
        location: 'Dharwad',
      );
      final plotId = await plotRepo.savePlot(
        workspaceId: 1,
        projectId: projId,
        plotNumber: 'H-01',
        uniquePlotId: 'VGA-H01',
        dimensions: '40 x 60 ft',
        areaSqFt: 2400,
        status: 'available',
        basePrice: 500,
        totalPrice: 1200000,
      );

      final now = DateTime.now();
      final bookingId = await bookingRepo.createBooking(
        workspaceId: 1,
        bookingNumber: 'BK-2026-VGA-H01',
        plotId: plotId,
        customerId: 1,
        totalPlotValue: 1200000,
        bookingAmount: 200000,
        paymentAccountId: 1,
        paymentMode: 'bank_transfer',
        installments: [
          {
            'installmentNumber': 1,
            'title': 'Token Advance',
            'dueDate': now,
            'amount': 200000.0,
          },
          {
            'installmentNumber': 2,
            'title': 'Milestone 2 - Layout Development',
            'dueDate': now.add(const Duration(days: 30)),
            'amount': 500000.0,
          },
          {
            'installmentNumber': 3,
            'title': 'Milestone 3 - Registration',
            'dueDate': now.add(const Duration(days: 60)),
            'amount': 500000.0,
          },
        ],
      );

      // Verify initial advance payment posted
      var statement = await bookingRepo.getBookingStatement(bookingId);
      expect(statement['totalValue'], 1200000.0);
      expect(statement['totalPaid'], 200000.0);
      expect(statement['balanceOutstanding'], 1000000.0);
      expect((statement['payments'] as List).length, 1);

      // 2. Pay Partial Installment for Milestone 2 (Pay ₹250,000 of ₹500,000)
      final installments = await bookingRepo.getInstallments(bookingId);
      final inst2 = installments.firstWhere((i) => i.installmentNumber == 2);

      await bookingRepo.payInstallment(
        installmentId: inst2.id,
        amount: 250000.0,
        paymentAccountId: 1,
        paymentMode: 'upi',
        referenceNo: 'UPI-PARTIAL-001',
      );

      // Verify Milestone 2 is in 'partial' status
      var refetchedInsts = await bookingRepo.getInstallments(bookingId);
      var updatedInst2 = refetchedInsts.firstWhere((i) => i.installmentNumber == 2);
      expect(updatedInst2.status, 'partial');
      expect(updatedInst2.paidAmount, 250000.0);

      // 3. Pay Remaining for Milestone 2 (Pay ₹250,000)
      await bookingRepo.payInstallment(
        installmentId: inst2.id,
        amount: 250000.0,
        paymentAccountId: 1,
        paymentMode: 'bank_transfer',
        referenceNo: 'NEFT-FULL-002',
      );

      refetchedInsts = await bookingRepo.getInstallments(bookingId);
      updatedInst2 = refetchedInsts.firstWhere((i) => i.installmentNumber == 2);
      expect(updatedInst2.status, 'paid');
      expect(updatedInst2.paidAmount, 500000.0);

      // 4. Verify Final Statement
      statement = await bookingRepo.getBookingStatement(bookingId);
      expect(statement['totalPaid'], 700000.0);
      expect(statement['balanceOutstanding'], 500000.0);
      expect((statement['payments'] as List).length, 3);

      // 5. Verify system-wide double-entry ledger balance
      final recon = await ledgerRepo.reconcileBalances(workspaceId: 1);
      final totalDebit = recon['total_debit'] as double;
      final totalCredit = recon['total_credit'] as double;
      expect(totalDebit, closeTo(totalCredit, 0.001));
      expect(recon['is_trial_balanced'], isTrue);
    });
  });
}
