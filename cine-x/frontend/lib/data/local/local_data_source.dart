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
    bool syncToServer = true,
  }) async {
    final now = DateTime.now().toIso8601String();
    final localUuid = await ensureLocalUuid(executor, table, id);
    final shouldSync = mode == AppUsageMode.onlineAccount && syncToServer;
    await executor.update(
      table,
      {
        'workspace_type':
            mode == AppUsageMode.offlineGuest ? 'LOCAL_GUEST' : 'CLOUD_ACCOUNT',
        'owner_account_id': mode == AppUsageMode.offlineGuest ? null : accountId,
        'sync_status': shouldSync
            ? EntitySyncStatus.pendingCreate.dbValue
            : EntitySyncStatus.localOnly.dbValue,
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
    bool syncToServer = true,
  }) async {
    final localUuid = await ensureLocalUuid(executor, table, id);
    if (mode == AppUsageMode.offlineGuest || !syncToServer) {
      await _bumpLocalVersion(
        executor,
        table,
        id,
        EntitySyncStatus.localOnly,
        accountId: mode == AppUsageMode.onlineAccount ? accountId : null,
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
    bool syncToServer = true,
  }) async {
    final localUuid = await ensureLocalUuid(executor, table, id);
    if (mode == AppUsageMode.offlineGuest) return localUuid;
    if (!syncToServer) {
      await _bumpLocalVersion(
        executor,
        table,
        id,
        EntitySyncStatus.localOnly,
        accountId: accountId,
        deletedAt: DateTime.now(),
      );
      return localUuid;
    }
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
    final payload = Map<String, Object?>.from(rows.single);
    await _enrichSyncPayload(db, table, payload);
    return payload;
  }

  Future<void> markSyncedByLocalUuid({
    required String table,
    required String localUuid,
    int? serverVersion,
    String? remoteId,
  }) async {
    await _db.update(
      table,
      {
        'sync_status': EntitySyncStatus.synced.dbValue,
        if (remoteId != null) 'remote_id': remoteId,
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

  Future<void> _enrichSyncPayload(
    DatabaseExecutor executor,
    String table,
    Map<String, Object?> payload,
  ) async {
    final projectId = payload['project_id'] as int?;
    if (projectId != null) {
      payload['project_client_uuid'] =
          await _localUuidFor(executor, 'projects', projectId);
    }
    switch (table) {
      case 'scenes':
        final actId = payload['act_id'] as int?;
        final storyLocationId = payload['story_location_id'] as int?;
        final shootingLocationId = payload['planned_shooting_location_id'] as int?;
        if (actId != null) {
          payload['act_client_uuid'] =
              await _localUuidFor(executor, 'acts', actId);
        }
        if (storyLocationId != null) {
          payload['story_location_client_uuid'] =
              await _localUuidFor(executor, 'story_locations', storyLocationId);
        }
        if (shootingLocationId != null) {
          payload['shooting_location_client_uuid'] =
              await _localUuidFor(executor, 'shooting_locations', shootingLocationId);
        }
        final characterRows = await executor.rawQuery(
          '''
          SELECT c.local_uuid
          FROM scene_characters sc
          JOIN characters c ON c.id = sc.character_id
          WHERE sc.scene_id = ?
          ORDER BY c.name COLLATE NOCASE ASC
          ''',
          [payload['id']],
        );
        payload['character_client_uuids'] = characterRows
            .map((row) => row['local_uuid'])
            .whereType<String>()
            .toList();
        break;
      case 'project_members':
        final memberProjectId = payload['project_id'] as int?;
        if (memberProjectId != null) {
          payload['project_client_uuid'] =
              await _localUuidFor(executor, 'projects', memberProjectId);
        }
        break;
    }
  }

  Future<String?> _localUuidFor(
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
    return rows.isEmpty ? null : rows.single['local_uuid'] as String?;
  }
}
