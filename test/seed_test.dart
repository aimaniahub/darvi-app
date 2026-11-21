import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mini_pos_inventory/data/local/db/app_database.dart';
import 'package:mini_pos_inventory/data/local/seed/seed_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SeedData ensureSeeded runs without crashing', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final seeder = SeedData(db);
    await seeder.ensureSeeded();
    final workspaces = await db.select(db.workspaces).get();
    expect(workspaces.isNotEmpty, true);
    await db.close();
  });
}

