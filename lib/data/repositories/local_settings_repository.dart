import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../local/db/app_database.dart';
import '../../domain/repositories/repositories.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<AppSettingsModel> getSettings() async {
    final row = await (_db.select(_db.appSettings)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (row == null) {
      return AppSettingsModel.fallback;
    }

    return AppSettingsModel(
      storeName: row.storeName,
      currency: row.currency,
      taxEnabled: row.taxEnabled,
      taxRate: row.taxRate,
      receiptHeader: row.receiptHeader,
      receiptFooter: row.receiptFooter,
      language: row.language,
      allowNegativeStock: row.allowNegativeStock,
      cashierPin: row.cashierPin,
      adminPassword: row.adminPassword,
    );
  }

  @override
  Future<void> updateSettings(AppSettingsModel settings) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            storeName: Value(settings.storeName),
            currency: Value(settings.currency),
            taxEnabled: Value(settings.taxEnabled),
            taxRate: Value(settings.taxRate),
            receiptHeader: Value(settings.receiptHeader),
            receiptFooter: Value(settings.receiptFooter),
            language: Value(settings.language),
            allowNegativeStock: Value(settings.allowNegativeStock),
            cashierPin: Value(settings.cashierPin),
            adminPassword: Value(settings.adminPassword),
          ),
        );
  }

  @override
  Future<BusinessProfileModel> getBusinessProfile({int workspaceId = 1}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM workspaces WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(workspaceId)],
    ).get();

    if (rows.isEmpty) {
      return BusinessProfileModel.defaultDarvi;
    }

    final d = rows.first.data;
    return BusinessProfileModel(
      workspaceId: d['id'] as int? ?? 1,
      businessName: d['business_name'] as String? ?? BusinessProfileModel.defaultDarvi.businessName,
      logoPath: d['logo_path'] as String? ?? BusinessProfileModel.defaultDarvi.logoPath,
      address: d['address'] as String? ?? BusinessProfileModel.defaultDarvi.address,
      phone: d['phone'] as String? ?? BusinessProfileModel.defaultDarvi.phone,
      email: d['email'] as String? ?? BusinessProfileModel.defaultDarvi.email,
      gstin: d['gstin'] as String? ?? BusinessProfileModel.defaultDarvi.gstin,
      state: d['state'] as String? ?? BusinessProfileModel.defaultDarvi.state,
      stateCode: d['state_code'] as String? ?? BusinessProfileModel.defaultDarvi.stateCode,
      invoiceFooter: d['receipt_terms'] as String? ?? BusinessProfileModel.defaultDarvi.invoiceFooter,
      businessSlogan: d['receipt_slogan'] as String? ?? BusinessProfileModel.defaultDarvi.businessSlogan,
      currency: d['currency'] as String? ?? BusinessProfileModel.defaultDarvi.currency,
      invoicePrefix: d['invoice_prefix'] as String? ?? 'DARVI-',
      invoiceSuffix: d['invoice_suffix'] as String? ?? '',
      nextInvoiceNumber: d['next_invoice_number'] as int? ?? 1001,
      paymentTerms: d['payment_terms'] as String? ?? 'Immediate',
      roundOffMode: d['round_off_mode'] as String? ?? 'nearest',
      printerName: d['printer_name'] as String? ?? 'SSEZNIK2POS',
      printerMac: d['printer_mac'] as String?,
      paperWidthMm: d['paper_width_mm'] as int? ?? 58,
      reprintCount: d['reprint_count'] as int? ?? 1,
    );
  }

  @override
  Future<void> updateBusinessProfile(BusinessProfileModel profile) async {
    await _db.customStatement('''
      UPDATE workspaces 
      SET business_name = ?, address = ?, phone = ?, email = ?, gstin = ?,
          state = ?, state_code = ?, receipt_terms = ?, receipt_slogan = ?, currency = ?,
          invoice_prefix = ?, invoice_suffix = ?, next_invoice_number = ?, payment_terms = ?,
          round_off_mode = ?, printer_name = ?, printer_mac = ?, paper_width_mm = ?,
          reprint_count = ?, logo_path = ?
      WHERE id = ?
    ''', [
      profile.businessName.trim(),
      profile.address.trim(),
      profile.phone.trim(),
      profile.email.trim(),
      profile.gstin.trim(),
      profile.state.trim(),
      profile.stateCode.trim(),
      profile.invoiceFooter.trim(),
      profile.businessSlogan.trim(),
      profile.currency.trim(),
      profile.invoicePrefix.trim(),
      profile.invoiceSuffix.trim(),
      profile.nextInvoiceNumber,
      profile.paymentTerms.trim(),
      profile.roundOffMode.trim(),
      profile.printerName.trim(),
      profile.printerMac,
      profile.paperWidthMm,
      profile.reprintCount,
      profile.logoPath.trim(),
      profile.workspaceId,
    ]);

    // Also sync storeName and receiptHeader in app_settings table
    try {
      final current = await getSettings();
      await updateSettings(current.copyWith(
        storeName: profile.businessName,
        currency: profile.currency,
        receiptHeader: '${profile.businessName}\n${profile.address}\nGSTIN: ${profile.gstin} | Ph: ${profile.phone}',
        receiptFooter: '${profile.businessSlogan}\n${profile.invoiceFooter}',
      ));
    } catch (_) {}
  }

  @override
  Future<BackupRecord> createBackup({int workspaceId = 1}) async {
    // 1. Checkpoint SQLite Write-Ahead Log (WAL) to ensure complete data consistency
    try {
      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {
      // Ignore in environments where WAL is not active (e.g., pure in-memory)
    }

    // 2. Collect comprehensive JSON dump of all operational tables
    const tablesToDump = [
      'workspaces',
      'accounts',
      'categories',
      'products',
      'product_batches',
      'stock_movements',
      'customers',
      'suppliers',
      'purchases',
      'purchase_invoices',
      'purchase_invoice_items',
      'sales',
      'sale_items',
      'payments',
      'ledger_entries',
      'expenses',
      'employees',
      'attendances',
      'leave_requests',
      'payroll_records',
      'incentive_rules',
      'sales_targets',
      'incentive_claims',
      'projects',
      'plots',
      'leads',
      'site_visits',
      'lead_activities',
      'quotations',
      'quotation_items',
      'plot_bookings',
      'booking_installments',
      'delivery_orders',
      'delivery_order_items',
      'users',
      'app_settings',
    ];

    final Map<String, dynamic> backupData = {
      'app': 'Darvi Billing',
      'version': '1.0.0',
      'workspace_id': workspaceId,
      'created_at': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    int totalRecords = 0;
    for (final table in tablesToDump) {
      try {
        final rows = await _db.customSelect('SELECT * FROM "$table"').get();
        backupData['tables'][table] = rows.map((r) => r.data).toList();
        totalRecords += rows.length;
      } catch (_) {}
    }

    final jsonString = jsonEncode(backupData);
    final checksum = sha256.convert(utf8.encode(jsonString)).toString();

    // Determine backup directory
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = Directory.systemTemp;
    }

    final backupDir = Directory(p.join(dir.path, 'darvi_backups'));
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }

    final timestampStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final filename = 'darvi_backup_$timestampStr.json';
    final filePath = p.join(backupDir.path, filename);
    final file = File(filePath);
    await file.writeAsString(jsonString, flush: true);

    final fileSize = file.lengthSync();
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final id = await _db.customInsert(
      '''
      INSERT INTO backup_records (workspace_id, filename, file_path, file_size, record_count, checksum, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 'valid', ?)
      ''',
      variables: [
        Variable.withInt(workspaceId),
        Variable.withString(filename),
        Variable.withString(filePath),
        Variable.withInt(fileSize),
        Variable.withInt(totalRecords),
        Variable.withString(checksum),
        Variable.withInt(nowSeconds),
      ],
    );

    return BackupRecord(
      id: id,
      workspaceId: workspaceId,
      filename: filename,
      filePath: filePath,
      fileSize: fileSize,
      recordCount: totalRecords,
      checksum: checksum,
      status: 'valid',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<BackupRecord>> getBackupHistory({int workspaceId = 1}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM backup_records WHERE workspace_id = ? ORDER BY created_at DESC',
      variables: [Variable.withInt(workspaceId)],
    ).get();

    return rows.map((r) {
      final d = r.data;
      return BackupRecord(
        id: d['id'] as int,
        workspaceId: d['workspace_id'] as int? ?? 1,
        filename: d['filename'] as String? ?? 'backup.json',
        filePath: d['file_path'] as String? ?? '',
        fileSize: d['file_size'] as int? ?? 0,
        recordCount: d['record_count'] as int? ?? 0,
        checksum: d['checksum'] as String? ?? '',
        status: d['status'] as String? ?? 'valid',
        createdAt: DateTime.fromMillisecondsSinceEpoch(((d['created_at'] as int?) ?? 0) * 1000),
      );
    }).toList();
  }

  @override
  Future<bool> validateBackup(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    try {
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      if (data['app'] != 'Darvi Billing' || !data.containsKey('tables')) {
        return false;
      }

      final tables = data['tables'] as Map<String, dynamic>?;
      if (tables == null || tables.isEmpty) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> restoreBackup(String filePath, {int workspaceId = 1}) async {
    final isValid = await validateBackup(filePath);
    if (!isValid) {
      throw AppException('Backup file validation failed. Invalid format or corrupted archive.');
    }

    final file = File(filePath);
    final content = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);
    final tables = data['tables'] as Map<String, dynamic>;

    const tablesToRestore = [
      'workspaces',
      'accounts',
      'categories',
      'products',
      'product_batches',
      'stock_movements',
      'customers',
      'suppliers',
      'purchases',
      'purchase_invoices',
      'purchase_invoice_items',
      'sales',
      'sale_items',
      'payments',
      'ledger_entries',
      'expenses',
      'employees',
      'attendances',
      'leave_requests',
      'payroll_records',
      'incentive_rules',
      'sales_targets',
      'incentive_claims',
      'projects',
      'plots',
      'leads',
      'site_visits',
      'lead_activities',
      'quotations',
      'quotation_items',
      'plot_bookings',
      'booking_installments',
      'delivery_orders',
      'delivery_order_items',
      'users',
      'app_settings',
    ];

    await _db.transaction(() async {
      // 1. Temporarily disable foreign keys for clean restoration
      await _db.customStatement('PRAGMA foreign_keys = OFF;');

      try {
        for (final table in tablesToRestore) {
          if (!tables.containsKey(table)) continue;
          final List rows = tables[table] as List? ?? [];

          // Delete existing rows for this table
          await _db.customStatement('DELETE FROM "$table";');

          // Insert rows
          for (final rawRow in rows) {
            final row = Map<String, dynamic>.from(rawRow as Map);
            if (row.isEmpty) continue;

            final columns = row.keys.map((c) => '"$c"').join(', ');
            final placeholders = List.filled(row.length, '?').join(', ');
            final values = row.values.map((v) {
              if (v is bool) return v ? 1 : 0;
              return v;
            }).toList();

            await _db.customStatement(
              'INSERT INTO "$table" ($columns) VALUES ($placeholders);',
              values,
            );
          }
        }
      } finally {
        await _db.customStatement('PRAGMA foreign_keys = ON;');
      }

      // 2. Perform database integrity check
      final integrityCheck = await _db.customSelect('PRAGMA integrity_check;').get();
      final integrityStr = integrityCheck.isNotEmpty ? integrityCheck.first.data.values.first.toString() : '';
      if (integrityStr.toLowerCase() != 'ok') {
        throw AppException('Database integrity check failed after restore: $integrityStr');
      }

      // 3. Perform foreign key consistency check
      final fkCheck = await _db.customSelect('PRAGMA foreign_key_check;').get();
      if (fkCheck.isNotEmpty) {
        throw AppException('Foreign key validation failed: ${fkCheck.length} violations found after restore');
      }
    });

    return true;
  }
}

