import 'package:sqflite/sqflite.dart';

import '../../data/local/local_data_source.dart';
import '../../data/remote/remote_data_source.dart';
import '../network/connectivity_service.dart';
import '../storage/session_storage.dart';
import '../utils/uuid.dart';
import 'conflict_repository.dart';
import 'sync_models.dart';
import 'sync_queue_repository.dart';

class SyncCoordinator {
  SyncCoordinator({
    required Database database,
    required SessionStorage sessionStorage,
    required ConnectivityService connectivityService,
    required RemoteDataSource remoteDataSource,
    required SyncQueueRepository queueRepository,
    required ConflictRepository conflictRepository,
    required LocalDataSource localDataSource,
  })  : _db = database,
        _sessionStorage = sessionStorage,
        _connectivityService = connectivityService,
        _remoteDataSource = remoteDataSource,
        _queueRepository = queueRepository,
        _conflictRepository = conflictRepository,
        _localDataSource = localDataSource;

  final Database _db;
  final SessionStorage _sessionStorage;
  final ConnectivityService _connectivityService;
  final RemoteDataSource _remoteDataSource;
  final SyncQueueRepository _queueRepository;
  final ConflictRepository _conflictRepository;
  final LocalDataSource _localDataSource;

  bool _running = false;

  bool get isRunning => _running;

  Future<SyncSummary> summary() => _queueRepository.summary();

  Future<void> syncNow() async {
    final mode = await _sessionStorage.readUsageMode();
    if (mode != AppUsageMode.onlineAccount) {
      throw Exception('Hãy đăng nhập trước khi đồng bộ dữ liệu khách ngoại tuyến.');
    }
    if (_running) return;
    final networkStatus = await _connectivityService.status();
    if (networkStatus == NetworkStatus.offline) {
      await _writeSyncState(lastError: 'Không có kết nối mạng');
      throw Exception('Không có kết nối mạng. Thay đổi vẫn được lưu trong hàng đợi cục bộ.');
    }

    _running = true;
    try {
      await _queueRepository.compact();
      await _pushPending();
      await _pullRemote();
      await _writeSyncState(
        lastSyncedAt: DateTime.now(),
        lastPushAt: DateTime.now(),
        lastPullAt: DateTime.now(),
        lastError: null,
      );
    } catch (ex) {
      await _writeSyncState(lastError: ex.toString());
      rethrow;
    } finally {
      _running = false;
    }
  }

  Future<void> _pushPending() async {
    final pending = await _queueRepository.pending();
    if (pending.isEmpty) return;
    final response = await _remoteDataSource.push(
      deviceId: await _deviceId(),
      clientBatchId: generateUuid(),
      operations: pending.map((operation) => operation.toPushPayload()).toList(),
    );
    final byId = {for (final operation in pending) operation.id: operation};
    for (final result in response.results) {
      final operation = byId[result.operationId];
      if (operation == null) continue;
      final table = _tableFor(operation.entityType);
      switch (result.status) {
        case 'APPLIED':
          await _queueRepository.markApplied(operation.id);
          if (table != null) {
            await _localDataSource.markSyncedByLocalUuid(
              table: table,
              localUuid: operation.entityId,
              serverVersion: result.serverVersion,
            );
          }
        case 'CONFLICT':
          if (table != null) {
            await _localDataSource.markConflictByLocalUuid(
              table: table,
              localUuid: operation.entityId,
              error: 'Phát hiện xung đột trên đám mây',
            );
          }
          await _conflictRepository.create(
            accountId: operation.accountId,
            projectId: int.tryParse(operation.projectId ?? ''),
            entityType: operation.entityType,
            entityId: operation.entityId,
            localPayload: operation.payload,
            remotePayload: result.remotePayload ?? const {},
            conflictingFields: result.conflictingFields,
          );
        case 'VALIDATION_ERROR':
        case 'UNAUTHORIZED':
        case 'DEPENDENCY_ERROR':
        case 'REJECTED':
          final error = result.error ?? result.status;
          await _queueRepository.markFailed(operation.id, error);
          if (table != null) {
            await _localDataSource.markSyncFailedByLocalUuid(
              table: table,
              localUuid: operation.entityId,
              error: error,
            );
          }
        default:
          await _queueRepository.markFailed(
            operation.id,
            result.error ?? 'Trạng thái đồng bộ không xác định: ${result.status}',
          );
      }
    }
  }

  Future<void> _pullRemote() async {
    var cursor = await _readCursor();
    var hasMore = true;
    while (hasMore) {
      final response = await _remoteDataSource.pull(cursor: cursor);
      for (final change in response.changes) {
        await _applyPullChange(change);
      }
      cursor = response.nextCursor ?? cursor;
      hasMore = response.hasMore;
      await _writeSyncState(pullCursor: cursor);
    }
  }

  Future<void> _applyPullChange(PullChange change) async {
    final table = _tableFor(change.entityType);
    if (table == null) return;
    final rows = await _db.query(
      table,
      where: 'local_uuid = ? OR remote_id = ?',
      whereArgs: [change.entityId, change.entityId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final row = rows.single;
      final status = EntitySyncStatusCodec.fromDb(row['sync_status'] as String?);
      if (status.hasPendingChange) {
        await _conflictRepository.create(
          accountId: await _sessionStorage.readCurrentAccountId(),
          projectId: row['project_id'] as int?,
          entityType: change.entityType,
          entityId: change.entityId,
          localPayload: row,
          remotePayload: change.payload,
          conflictingFields: _changedFields(row, change.payload),
          localUpdatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
          remoteUpdatedAt: change.updatedAt,
        );
        await _localDataSource.markConflictByLocalUuid(
          table: table,
          localUuid: row['local_uuid'] as String,
          error: 'Dữ liệu từ xa đã thay đổi khi chỉnh sửa cục bộ còn đang chờ',
        );
        return;
      }
      await _updateExistingFromRemote(table, row['id'] as int, change);
      return;
    }
    if (change.entityType == 'PROJECT' && change.operation != 'DELETE') {
      await _insertProjectFromRemote(change);
    }
  }

  Future<void> _updateExistingFromRemote(
    String table,
    int id,
    PullChange change,
  ) async {
    final payload = Map<String, Object?>.from(change.payload);
    payload
      ..remove('id')
      ..remove('remoteId')
      ..remove('localUuid');
    await _db.update(
      table,
      {
        ...payload,
        'remote_id': change.entityId,
        'server_version': change.serverVersion,
        'sync_status': EntitySyncStatus.synced.dbValue,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': change.updatedAt.toIso8601String(),
        'sync_error': null,
        if (change.operation == 'DELETE')
          'deleted_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _insertProjectFromRemote(PullChange change) async {
    final accountId = await _sessionStorage.readCurrentUserId();
    if (accountId == null) return;
    final now = DateTime.now().toIso8601String();
    final title = change.payload['title']?.toString();
    if (title == null || title.trim().isEmpty) return;
    final projectId = await _db.insert('projects', {
      'owner_user_id': accountId,
      'title': title.trim(),
      'genre': change.payload['genre'],
      'description': change.payload['description'],
      'start_date': change.payload['startDate'],
      'end_date': change.payload['endDate'],
      'max_shooting_minutes_per_day':
          change.payload['maxShootingMinutesPerDay'] ?? 480,
      'poster_url': change.payload['posterUrl'],
      'created_at': change.payload['createdAt'] ?? now,
      'updated_at': change.updatedAt.toIso8601String(),
      'local_uuid': change.entityId,
      'remote_id': change.entityId,
      'workspace_type': 'CLOUD_ACCOUNT',
      'owner_account_id': '$accountId',
      'sync_status': EntitySyncStatus.synced.dbValue,
      'local_version': 0,
      'server_version': change.serverVersion,
      'last_synced_at': now,
    });
    await _db.insert(
      'project_members',
      {
        'project_id': projectId,
        'user_id': accountId,
        'role': 'OWNER',
        'local_uuid': generateUuid(),
        'remote_id': null,
        'workspace_type': 'CLOUD_ACCOUNT',
        'owner_account_id': '$accountId',
        'sync_status': EntitySyncStatus.synced.dbValue,
        'local_version': 0,
        'server_version': change.serverVersion,
        'last_synced_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<String?> _readCursor() async {
    final accountId = await _sessionStorage.readCurrentAccountId();
    final rows = await _db.query(
      'sync_state',
      columns: ['pull_cursor'],
      where: 'account_id = ? AND project_id IS NULL',
      whereArgs: [accountId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['pull_cursor'] as String?;
  }

  Future<void> _writeSyncState({
    String? pullCursor,
    DateTime? lastSyncedAt,
    DateTime? lastPushAt,
    DateTime? lastPullAt,
    String? lastError,
  }) async {
    final accountId = await _sessionStorage.readCurrentAccountId();
    if (accountId == null) return;
    final existing = await _db.query(
      'sync_state',
      where: 'account_id = ? AND project_id IS NULL',
      whereArgs: [accountId],
      limit: 1,
    );
    final values = {
      'account_id': accountId,
      'project_id': null,
      if (pullCursor != null) 'pull_cursor': pullCursor,
      if (lastSyncedAt != null)
        'last_synced_at': lastSyncedAt.toIso8601String(),
      if (lastPushAt != null) 'last_push_at': lastPushAt.toIso8601String(),
      if (lastPullAt != null) 'last_pull_at': lastPullAt.toIso8601String(),
      'last_error': lastError,
    };
    if (existing.isEmpty) {
      await _db.insert('sync_state', values);
    } else {
      await _db.update(
        'sync_state',
        values,
        where: 'account_id = ? AND project_id IS NULL',
        whereArgs: [accountId],
      );
    }
  }

  Future<String> _deviceId() async {
    final rows = await _db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['device_id'],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.single['value'] as String;
    final id = generateUuid();
    await _db.insert('app_metadata', {'key': 'device_id', 'value': id});
    return id;
  }

  String? _tableFor(String entityType) {
    return switch (entityType) {
      'PROJECT' => 'projects',
      'PROJECT_MEMBER' => 'project_members',
      'ACT' => 'acts',
      'CHARACTER' => 'characters',
      'STORY_LOCATION' => 'story_locations',
      'SHOOTING_LOCATION' => 'shooting_locations',
      'FILM_RESOURCE' => 'film_resources',
      'SCENE' => 'scenes',
      'SHOOTING_DAY' => 'shooting_days',
      'FILE_ASSET' => 'file_assets',
      _ => null,
    };
  }

  List<String> _changedFields(
    Map<String, Object?> local,
    Map<String, dynamic> remote,
  ) {
    final result = <String>[];
    for (final entry in remote.entries) {
      final localValue = local[entry.key];
      if (localValue != null && localValue.toString() != entry.value?.toString()) {
        result.add(entry.key);
      }
    }
    return result;
  }
}
