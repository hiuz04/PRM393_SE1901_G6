import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../utils/uuid.dart';
import 'sync_models.dart';

class SyncQueueOperation {
  const SyncQueueOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.idempotencyKey,
    this.accountId,
    this.projectId,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String? accountId;
  final String? projectId;
  final String entityType;
  final String entityId;
  final SyncOperationType operation;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final int retryCount;
  final String? lastError;

  factory SyncQueueOperation.fromMap(Map<String, Object?> map) {
    return SyncQueueOperation(
      id: map['id'] as String,
      accountId: map['account_id'] as String?,
      projectId: map['project_id'] as String?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: SyncOperationTypeCodec.fromDb(map['operation'] as String),
      payload: jsonDecode(map['payload_json'] as String? ?? '{}')
          as Map<String, dynamic>,
      idempotencyKey: map['idempotency_key'] as String,
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  Map<String, dynamic> toPushPayload() {
    return {
      'operationId': id,
      'idempotencyKey': idempotencyKey,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation.dbValue,
      'baseVersion': payload['serverVersion'],
      'payload': payload,
    };
  }
}

class SyncQueueRepository {
  SyncQueueRepository(this._db);

  final Database _db;

  static const dependencyOrder = [
    'PROJECT',
    'PROJECT_MEMBER',
    'ACT',
    'CHARACTER',
    'STORY_LOCATION',
    'SHOOTING_LOCATION',
    'FILM_RESOURCE',
    'SCENE',
    'SCENE_CHARACTER',
    'SCENE_RESOURCE',
    'SHOOTING_DAY',
    'SHOOTING_DAY_SCENE',
    'FILE_ASSET',
  ];

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperationType operation,
    required Map<String, Object?> payload,
    String? accountId,
    int? projectId,
    String? dependencyGroup,
  }) {
    return enqueueWithExecutor(
      _db,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      accountId: accountId,
      projectId: projectId,
      dependencyGroup: dependencyGroup,
    );
  }

  Future<void> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required SyncOperationType operation,
    required Map<String, Object?> payload,
    String? accountId,
    int? projectId,
    String? dependencyGroup,
  }) async {
    final existing = await executor.query(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'created_at ASC',
    );
    final now = DateTime.now().toIso8601String();
    if (operation == SyncOperationType.update) {
      final create = _firstWhereOrNull(
        existing,
        (row) => row['operation'] == SyncOperationType.create.dbValue,
      );
      if (create != null) {
        await _updateExisting(executor, create['id'] as String, payload, now);
        return;
      }
      final update = _firstWhereOrNull(
        existing,
        (row) => row['operation'] == SyncOperationType.update.dbValue,
      );
      if (update != null) {
        await _updateExisting(executor, update['id'] as String, payload, now);
        return;
      }
      if (existing.any((row) => row['operation'] == 'DELETE')) return;
    }

    if (operation == SyncOperationType.delete) {
      final create = _firstWhereOrNull(
        existing,
        (row) => row['operation'] == SyncOperationType.create.dbValue,
      );
      if (create != null) {
        await executor.delete(
          'sync_queue',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: [entityType, entityId],
        );
        return;
      }
      await executor.delete(
        'sync_queue',
        where:
            'entity_type = ? AND entity_id = ? AND operation IN (?, ?)',
        whereArgs: [
          entityType,
          entityId,
          SyncOperationType.update.dbValue,
          SyncOperationType.delete.dbValue,
        ],
      );
    }

    if (operation == SyncOperationType.create) {
      await executor.delete(
        'sync_queue',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );
    }

    await executor.insert('sync_queue', {
      'id': generateUuid(),
      'account_id': accountId,
      'project_id': projectId?.toString(),
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation.dbValue,
      'payload_json': jsonEncode(payload),
      'idempotency_key': generateUuid(),
      'dependency_group': dependencyGroup,
      'retry_count': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
      'next_retry_at': null,
    });
  }

  Future<void> compact() async {
    final rows = await _db.query(
      'sync_queue',
      orderBy: 'entity_type ASC, entity_id ASC, created_at ASC',
    );
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent('${row['entity_type']}:${row['entity_id']}', () => [])
          .add(row);
    }
    await _db.transaction((txn) async {
      for (final group in grouped.values) {
        if (group.length <= 1) continue;
        final latest = group.last;
        await txn.delete(
          'sync_queue',
          where: 'entity_type = ? AND entity_id = ? AND id <> ?',
          whereArgs: [
            latest['entity_type'],
            latest['entity_id'],
            latest['id'],
          ],
        );
      }
    });
  }

  Future<List<SyncQueueOperation>> pending({int limit = 50}) async {
    final rows = await _db.query('sync_queue', orderBy: 'created_at ASC');
    rows.sort((a, b) {
      final entityCompare = _entityRank(a['entity_type'] as String)
          .compareTo(_entityRank(b['entity_type'] as String));
      if (entityCompare != 0) return entityCompare;
      return (a['created_at'] as String).compareTo(b['created_at'] as String);
    });
    return rows.take(limit).map(SyncQueueOperation.fromMap).toList();
  }

  Future<void> markApplied(String operationId) async {
    await _db.delete('sync_queue', where: 'id = ?', whereArgs: [operationId]);
  }

  Future<void> markFailed(String operationId, String error) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawUpdate(
      '''
      UPDATE sync_queue
      SET retry_count = retry_count + 1,
          last_error = ?,
          updated_at = ?,
          next_retry_at = ?
      WHERE id = ?
      ''',
      [error, now, now, operationId],
    );
  }

  Future<SyncSummary> summary() async {
    final counts = await _db.rawQuery('''
      SELECT operation, COUNT(*) AS count
      FROM sync_queue
      GROUP BY operation
    ''');
    int count(String operation) {
      final row = _firstWhereOrNull(
        counts,
        (item) => item['operation'] == operation,
      );
      return row == null ? 0 : row['count'] as int? ?? 0;
    }

    final failed = await _db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM sync_queue
      WHERE last_error IS NOT NULL AND last_error <> ''
    ''');
    final conflicts = await _db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM sync_conflicts
      WHERE resolution IS NULL
    ''');
    final syncState = await _db.query(
      'sync_state',
      columns: ['last_synced_at', 'last_error'],
      orderBy: 'last_synced_at DESC',
      limit: 1,
    );
    return SyncSummary(
      pendingCreates: count(SyncOperationType.create.dbValue),
      pendingUpdates: count(SyncOperationType.update.dbValue),
      pendingDeletes: count(SyncOperationType.delete.dbValue),
      pendingUploads: count(SyncOperationType.uploadFile.dbValue),
      failed: failed.single['count'] as int? ?? 0,
      conflicts: conflicts.single['count'] as int? ?? 0,
      lastSyncedAt: _dateTimeOrNull(
        syncState.isEmpty ? null : syncState.single['last_synced_at'],
      ),
      lastError: syncState.isEmpty
          ? null
          : syncState.single['last_error'] as String?,
    );
  }

  Future<void> _updateExisting(
    DatabaseExecutor executor,
    String id,
    Map<String, Object?> payload,
    String now,
  ) {
    return executor.update(
      'sync_queue',
      {
        'payload_json': jsonEncode(payload),
        'retry_count': 0,
        'last_error': null,
        'updated_at': now,
        'next_retry_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  int _entityRank(String entityType) {
    final index = dependencyOrder.indexOf(entityType);
    return index == -1 ? dependencyOrder.length : index;
  }

  DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
