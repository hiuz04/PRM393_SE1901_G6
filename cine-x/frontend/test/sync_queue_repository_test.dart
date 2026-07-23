import 'package:cine_x/core/sync/sync_models.dart';
import 'package:cine_x/core/sync/sync_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('CREATE followed by UPDATE keeps one CREATE with latest payload',
      () async {
    final db = await _openDb();
    final queue = SyncQueueRepository(db);

    await queue.enqueue(
      entityType: 'CHARACTER',
      entityId: 'character-1',
      operation: SyncOperationType.create,
      payload: {'name': 'A'},
    );
    await queue.enqueue(
      entityType: 'CHARACTER',
      entityId: 'character-1',
      operation: SyncOperationType.update,
      payload: {'name': 'B'},
    );

    final pending = await queue.pending();

    expect(pending, hasLength(1));
    expect(pending.single.operation, SyncOperationType.create);
    expect(pending.single.payload['name'], 'B');
    await db.close();
  });

  test('CREATE followed by DELETE removes the queued operation', () async {
    final db = await _openDb();
    final queue = SyncQueueRepository(db);

    await queue.enqueue(
      entityType: 'SCENE',
      entityId: 'scene-1',
      operation: SyncOperationType.create,
      payload: {'sceneNumber': 1},
    );
    await queue.enqueue(
      entityType: 'SCENE',
      entityId: 'scene-1',
      operation: SyncOperationType.delete,
      payload: {'sceneNumber': 1},
    );

    expect(await queue.pending(), isEmpty);
    await db.close();
  });
}

Future<Database> _openDb() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE sync_queue (
      id TEXT PRIMARY KEY,
      account_id TEXT,
      project_id TEXT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      idempotency_key TEXT NOT NULL UNIQUE,
      dependency_group TEXT,
      retry_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      next_retry_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE sync_conflicts (
      id TEXT PRIMARY KEY,
      resolution TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE sync_state (
      account_id TEXT NOT NULL,
      project_id TEXT,
      last_synced_at TEXT,
      last_error TEXT
    )
  ''');
  return db;
}
