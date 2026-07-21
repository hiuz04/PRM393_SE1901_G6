import 'package:cine_x/core/network/backend_connection_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('BackendConnectionProvider marks online from SQLite', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final provider = BackendConnectionProvider.local(db);

    await provider.check();

    expect(provider.status, BackendConnectionStatus.online);
    expect(provider.error, isNull);
    await db.close();
  });

  test('BackendConnectionProvider marks offline on database failure', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.close();
    final provider = BackendConnectionProvider.local(db);

    await provider.check();

    expect(provider.status, BackendConnectionStatus.offline);
    expect(provider.error, 'Không thể mở cơ sở dữ liệu SQLite cục bộ');
  });
}
