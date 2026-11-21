import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';

void main() {
  test('AppDatabase automatically heals ISO 8601 strings in DateTime columns', () async {
    final db = AppDatabase(NativeDatabase.memory());

    final res = await db.customSelect("SELECT strftime('%s', '2026-11-07T15:47:05.064481') as s;").getSingle();
    print('STRFTIME RESULT: ${res.data['s']} (type: ${res.data['s'].runtimeType})');

    // Insert corrupted rows in various tables where dates are raw ISO strings
    await db.customStatement('''
      INSERT INTO products (
        name, sku, cost, price, stock_qty, created_at, updated_at
      ) VALUES (
        'Corrupted Date Product', 'CORRUPT001', 50.0, 100.0, 10, '2026-11-07T15:47:05.064481', '2026-11-07T15:47:05.064481'
      );
    ''');

    await db.customStatement('''
      INSERT INTO workspaces (
        id, business_name, gstin, address, phone, is_default, created_at
      ) VALUES (
        1, 'Darvi Group Agri Tech', '29BKZPA0053M1ZQ', 'Hubli', '9986890777', 1, '2026-11-07T15:47:05.064481'
      );
    ''');

    await db.customStatement('''
      INSERT INTO accounts (
        id, workspace_id, name, type, is_default, created_at
      ) VALUES (
        1, 1, 'Cash', 'cash', 1, '2026-11-07T15:47:05.064481'
      );
    ''');

    await db.customStatement('''
      INSERT INTO payments (
        id, workspace_id, account_id, payment_type, reference_type, amount, payment_mode, created_at
      ) VALUES (
        1, 1, 1, 'customer_receipt', 'sale', 500.0, 'cash', '2026-11-07T15:47:05.064481'
      );
    ''');

    await db.customStatement('''
      INSERT INTO ledger_entries (
        workspace_id, transaction_type, reference_type, debit, credit, created_at
      ) VALUES (
        1, 'sale', 'revenue', 500.0, 0.0, '2026-11-07T15:47:05.064481'
      );
    ''');

    // Run sanitizeDateTimeColumns
    await db.sanitizeDateTimeColumns();

    // Now query every single table: none must throw FormatException
    final prods = await db.select(db.products).get();
    expect(prods.length, 1);
    expect(prods.first.name, 'Corrupted Date Product');
    expect(prods.first.createdAt.year, 2026);
    expect(prods.first.updatedAt.year, 2026);

    final pays = await db.select(db.payments).get();
    expect(pays.length, 1);
    expect(pays.first.createdAt.year, 2026);

    final ledgers = await db.select(db.ledgerEntries).get();
    expect(ledgers.length, 1);
    expect(ledgers.first.createdAt.year, 2026);

    // Run SeedData.ensureSeeded to verify full startup flow succeeds cleanly!
    final seeder = SeedData(db);
    await seeder.ensureSeeded();

    await db.close();
  });
}
