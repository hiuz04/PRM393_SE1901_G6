import 'package:sqflite/sqflite.dart';

import '../../core/sync/sync_models.dart';
import '../../core/utils/uuid.dart';

class LocalDataSource {
  LocalDataSource(this._db);

  final Database _db;

  Future<String> ensureLocalUuid(
    DatabaseExecutor executor,
    String table,
    int id,
  ) async {
    final rows = await executor.query(
      table,
      columns: ['local_uuid'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Không tìm thấy dòng $id trong bảng $table để ghi metadata đồng bộ.');
    }
    final existing = rows.single['local_uuid'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final localUuid = generateUuid();
    await executor.update(
      table,
      {'local_uuid': localUuid},
      where: 'id = ?',
      whereArgs: [id],
    );
    return localUuid;
  }

  Future<String> markCreated(
    DatabaseExecutor executor, {
    required String table,
    required int id,
    required AppUsageMode mode,
    String? accountId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final localUuid = await ensureLocalUuid(executor, table, id);
    await executor.update(
      table,
      {
        'workspace_type':
            mode == AppUsageMode.offlineGuest ? 'LOCAL_GUEST' : 'CLOUD_ACCOUNT',
        'owner_account_id': mode == AppUsageMode.offlineGuest ? null : accountId,
        'sync_status': mode == AppUsageMode.offlineGuest
            ? EntitySyncStatus.localOnly.dbValue
            : EntitySyncStatus.pendingCreate.dbValue,
        'local_version': 1,
        'sync_error': null,
        if (await hasColumn(executor, table, 'created_at')) 'created_at': now,
        if (await hasColumn(executor, table, 'updated_at')) 'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return localUuid;
  }

  Future<String> markUpdated(
    DatabaseExecutor executor, {
    required String table,
    required int id,
    required AppUsageMode mode,
    String? accountId,
  }) async {
    final localUuid = await ensureLocalUuid(executor, table, id);
    if (mode == AppUsageMode.offlineGuest) {
      await _bumpLocalVersion(
        executor,
        table,
        id,
        EntitySyncStatus.localOnly,
      );
      return localUuid;
    }
    final rows = await executor.query(
      table,
      columns: ['sync_status'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final current = EntitySyncStatusCodec.fromDb(
      rows.isEmpty ? null : rows.single['sync_status'] as String?,
    );
    final nextStatus = current == EntitySyncStatus.pendingCreate
        ? EntitySyncStatus.pendingCreate
        : EntitySyncStatus.pendingUpdate;
    await _bumpLocalVersion(
      executor,
      table,
      id,
      nextStatus,
      accountId: accountId,
    );
    return localUuid;
  }

  Future<String> markDeleted(
    DatabaseExecutor executor, {
    required String table,
    required int id,
    required AppUsageMode mode,
    String? accountId,
  }) async {
    final localUuid = await ensureLocalUuid(executor, table, id);
    if (mode == AppUsageMode.offlineGuest) return localUuid;
    await _bumpLocalVersion(
      executor,
      table,
      id,
      EntitySyncStatus.pendingDelete,
      accountId: accountId,
      deletedAt: DateTime.now(),
    );
    return localUuid;
  }

  Future<Map<String, Object?>> payloadFor(
    String table,
    int id, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _db;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return const {};
    return Map<String, Object?>.from(rows.single);
  }

  Future<void> markSyncedByLocalUuid({
    required String table,
    required String localUuid,
    int? serverVersion,
  }) async {
    await _db.update(
      table,
      {
        'sync_status': EntitySyncStatus.synced.dbValue,
        'server_version': serverVersion,
        'last_synced_at': DateTime.now().toIso8601String(),
        'sync_error': null,
      },
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }

  Future<void> markSyncFailedByLocalUuid({
    required String table,
    required String localUuid,
    required String error,
  }) async {
    await _db.update(
      table,
      {
        'sync_status': EntitySyncStatus.syncFailed.dbValue,
        'sync_error': error,
      },
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }

  Future<void> markConflictByLocalUuid({
    required String table,
    required String localUuid,
    required String error,
  }) async {
    await _db.update(
      table,
      {
        'sync_status': EntitySyncStatus.conflict.dbValue,
        'sync_error': error,
      },
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }

  Future<bool> hasColumn(
    DatabaseExecutor executor,
    String table,
    String column,
  ) async {
    final rows = await executor.rawQuery('PRAGMA table_info($table)');
    return rows.any((row) => row['name'] == column);
  }

  Future<void> _bumpLocalVersion(
    DatabaseExecutor executor,
    String table,
    int id,
    EntitySyncStatus status, {
    String? accountId,
    DateTime? deletedAt,
  }) async {
    final rows = await executor.query(
      table,
      columns: ['local_version'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final currentVersion =
        rows.isEmpty ? 0 : rows.single['local_version'] as int? ?? 0;
    final values = <String, Object?>{
      'local_version': currentVersion + 1,
      'sync_status': status.dbValue,
      if (accountId != null) 'owner_account_id': accountId,
      if (deletedAt != null) 'deleted_at': deletedAt.toIso8601String(),
      'sync_error': null,
    };
    if (await hasColumn(executor, table, 'updated_at')) {
      values['updated_at'] = DateTime.now().toIso8601String();
    }
    await executor.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
