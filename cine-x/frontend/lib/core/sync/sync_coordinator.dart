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
  static const _projectUploadEntityTypes = {
    'PROJECT',
    'PROJECT_MEMBER',
    'ACT',
    'CHARACTER',
    'STORY_LOCATION',
    'SCENE',
  };

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

  Future<List<SyncProjectOption>> localProjects() async {
    final rows = await _db.rawQuery('''
      SELECT
        p.id,
        p.title,
        p.genre,
        p.updated_at,
        p.remote_id,
        p.server_version,
        (
          SELECT COUNT(*)
          FROM sync_queue q
          WHERE q.project_id = CAST(p.id AS TEXT)
        ) AS pending_count,
        (
          SELECT COUNT(*)
          FROM sync_queue q
          WHERE q.project_id = CAST(p.id AS TEXT)
            AND q.last_error IS NOT NULL
            AND q.last_error <> ''
        ) AS failed_count,
        1
          + (SELECT COUNT(*) FROM project_members pm WHERE pm.project_id = p.id AND pm.deleted_at IS NULL)
          + (SELECT COUNT(*) FROM acts a WHERE a.project_id = p.id AND a.deleted_at IS NULL)
          + (SELECT COUNT(*) FROM characters c WHERE c.project_id = p.id AND c.deleted_at IS NULL)
          + (SELECT COUNT(*) FROM story_locations l WHERE l.project_id = p.id AND l.deleted_at IS NULL)
          + (SELECT COUNT(*) FROM scenes s WHERE s.project_id = p.id AND s.deleted_at IS NULL)
          AS supported_item_count
      FROM projects p
      WHERE p.deleted_at IS NULL
      ORDER BY p.updated_at DESC
    ''');
    return rows
        .map(
          (row) => SyncProjectOption(
            id: row['id'] as int,
            title: row['title'] as String,
            genre: row['genre'] as String?,
            updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
            supportedItemCount: row['supported_item_count'] as int? ?? 1,
            pendingCount: row['pending_count'] as int? ?? 0,
            failedCount: row['failed_count'] as int? ?? 0,
            uploaded:
                (row['remote_id']?.toString().trim().isNotEmpty ?? false) ||
                    ((_intOrNull(row['server_version']) ?? 0) > 0),
          ),
        )
        .toList();
  }

  Future<List<SyncDetailItem>> details(SyncDetailKind kind) async {
    if (kind == SyncDetailKind.conflicts) {
      final conflicts = await _conflictRepository.unresolved();
      return conflicts
          .map(
            (conflict) => SyncDetailItem(
              entityType: conflict.entityType,
              entityId: conflict.entityId,
              operation: 'CONFLICT',
              title: _detailTitle(
                conflict.entityType,
                conflict.remotePayload.isEmpty
                    ? conflict.localPayload
                    : conflict.remotePayload,
              ),
              projectId: conflict.projectId,
              error: conflict.conflictingFields.isEmpty
                  ? 'Dữ liệu cục bộ và server đều đã thay đổi.'
                  : 'Trường xung đột: ${conflict.conflictingFields.join(', ')}',
              conflictingFields: conflict.conflictingFields,
              createdAt: conflict.createdAt,
              updatedAt: conflict.remoteUpdatedAt ?? conflict.localUpdatedAt,
            ),
          )
          .toList();
    }
    final operations = await _queueRepository.details(kind);
    return operations
        .map(
          (operation) => SyncDetailItem(
            entityType: operation.entityType,
            entityId: operation.entityId,
            operation: operation.operation.dbValue,
            title: _detailTitle(operation.entityType, operation.payload),
            projectId: operation.projectId,
            error: operation.lastError,
            retryCount: operation.retryCount,
            createdAt: operation.createdAt,
            updatedAt: operation.updatedAt,
          ),
        )
        .toList();
  }

  Future<void> syncNow() async {
    throw Exception('Hãy chọn một project local để đồng bộ lên server.');
  }

  Future<void> syncProjectToServer(int projectId) async {
    final mode = await _sessionStorage.readUsageMode();
    if (mode != AppUsageMode.onlineAccount) {
      throw Exception(
          'Hãy đăng nhập trước khi đồng bộ project local lên server.');
    }
    if (_running) return;
    final networkStatus = await _connectivityService.status();
    if (networkStatus == NetworkStatus.offline) {
      await _writeSyncState(lastError: 'Không có kết nối mạng');
      throw Exception(
          'Không có kết nối mạng. Thay đổi vẫn được lưu trong hàng đợi cục bộ.');
    }

    _running = true;
    try {
      await _prepareProjectUploadQueue(projectId);
      await _queueRepository.compact();
      final failedCount = await _pushPending(
        projectId: projectId,
        entityTypes: _projectUploadEntityTypes,
      );
      if (failedCount > 0) {
        throw Exception(
          'Có $failedCount mục của project chưa đồng bộ được. Bấm ô Thất bại để xem lý do.',
        );
      }
      await _writeSyncState(
        lastSyncedAt: DateTime.now(),
        lastPushAt: DateTime.now(),
        lastError: null,
      );
    } catch (ex) {
      await _writeSyncState(lastError: ex.toString());
      rethrow;
    } finally {
      _running = false;
    }
  }

  Future<int> _pushPending({
    int? projectId,
    Set<String>? entityTypes,
  }) async {
    final pending = await _queueRepository.pending(
      limit: 500,
      projectId: projectId,
      entityTypes: entityTypes,
    );
    if (pending.isEmpty) return 0;
    final response = await _remoteDataSource.push(
      deviceId: await _deviceId(),
      clientBatchId: generateUuid(),
      operations:
          pending.map((operation) => operation.toPushPayload()).toList(),
    );
    final byId = {for (final operation in pending) operation.id: operation};
    var failedCount = 0;
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
              remoteId: result.remoteId,
              serverVersion: result.serverVersion,
            );
          }
        case 'CONFLICT':
          failedCount++;
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
          failedCount++;
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
          failedCount++;
          await _queueRepository.markFailed(
            operation.id,
            result.error ??
                'Trạng thái đồng bộ không xác định: ${result.status}',
          );
      }
    }
    return failedCount;
  }

  Future<void> _prepareProjectUploadQueue(int projectId) async {
    final accountId = await _sessionStorage.readCurrentAccountId();
    if (accountId == null || accountId.isEmpty) {
      throw Exception('Không tìm thấy tài khoản đang đăng nhập.');
    }
    await _db.transaction((txn) async {
      await _claimProjectForCurrentUser(txn, projectId, accountId);
      await _enqueueSyncableRows(
        txn,
        table: 'projects',
        entityType: 'PROJECT',
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [projectId],
        projectId: projectId,
      );
      await _enqueueProjectMembers(txn, projectId, accountId);
      await _enqueueSyncableRows(
        txn,
        table: 'acts',
        entityType: 'ACT',
        where: "project_id = ? AND (deleted_at IS NULL OR sync_status = ?)",
        whereArgs: [projectId, EntitySyncStatus.pendingDelete.dbValue],
        projectId: projectId,
        orderBy: 'sequence_order ASC, id ASC',
      );
      await _enqueueSyncableRows(
        txn,
        table: 'characters',
        entityType: 'CHARACTER',
        where: "project_id = ? AND (deleted_at IS NULL OR sync_status = ?)",
        whereArgs: [projectId, EntitySyncStatus.pendingDelete.dbValue],
        projectId: projectId,
        orderBy: 'name COLLATE NOCASE ASC, id ASC',
      );
      await _enqueueSyncableRows(
        txn,
        table: 'story_locations',
        entityType: 'STORY_LOCATION',
        where: "project_id = ? AND (deleted_at IS NULL OR sync_status = ?)",
        whereArgs: [projectId, EntitySyncStatus.pendingDelete.dbValue],
        projectId: projectId,
        orderBy: 'name COLLATE NOCASE ASC, id ASC',
      );
      await _enqueueSyncableRows(
        txn,
        table: 'scenes',
        entityType: 'SCENE',
        where: "project_id = ? AND (deleted_at IS NULL OR sync_status = ?)",
        whereArgs: [projectId, EntitySyncStatus.pendingDelete.dbValue],
        projectId: projectId,
        orderBy: 'scene_number ASC, id ASC',
      );
    });
  }

  Future<void> _claimProjectForCurrentUser(
    Transaction txn,
    int projectId,
    String accountId,
  ) async {
    final userId = await _sessionStorage.readCurrentUserId();
    if (userId == null) throw Exception('Vui lòng đăng nhập lại.');
    final projectRows = await txn.query(
      'projects',
      columns: ['owner_user_id'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [projectId],
      limit: 1,
    );
    if (projectRows.isEmpty) {
      throw Exception('Không tìm thấy project local để đồng bộ.');
    }
    final ownerUserId = projectRows.single['owner_user_id'] as int;
    final now = DateTime.now().toIso8601String();
    if (ownerUserId != userId) {
      final currentMember = await txn.query(
        'project_members',
        columns: ['user_id'],
        where: 'project_id = ? AND user_id = ?',
        whereArgs: [projectId, userId],
        limit: 1,
      );
      if (currentMember.isEmpty) {
        final ownerMember = await txn.query(
          'project_members',
          columns: ['user_id'],
          where: 'project_id = ? AND user_id = ?',
          whereArgs: [projectId, ownerUserId],
          limit: 1,
        );
        if (ownerMember.isEmpty) {
          await txn.insert('project_members', {
            'project_id': projectId,
            'user_id': userId,
            'role': 'OWNER',
            'local_uuid': generateUuid(),
            'workspace_type': 'CLOUD_ACCOUNT',
            'owner_account_id': accountId,
            'sync_status': EntitySyncStatus.pendingCreate.dbValue,
            'local_version': 1,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          await txn.update(
            'project_members',
            {
              'user_id': userId,
              'role': 'OWNER',
              'workspace_type': 'CLOUD_ACCOUNT',
              'owner_account_id': accountId,
              'sync_status': EntitySyncStatus.pendingCreate.dbValue,
              'sync_error': null,
              'updated_at': now,
            },
            where: 'project_id = ? AND user_id = ?',
            whereArgs: [projectId, ownerUserId],
          );
        }
      } else {
        await txn.update(
          'project_members',
          {
            'role': 'OWNER',
            'workspace_type': 'CLOUD_ACCOUNT',
            'owner_account_id': accountId,
            'sync_error': null,
            'updated_at': now,
          },
          where: 'project_id = ? AND user_id = ?',
          whereArgs: [projectId, userId],
        );
        await txn.delete(
          'project_members',
          where: 'project_id = ? AND user_id = ?',
          whereArgs: [projectId, ownerUserId],
        );
      }
      await txn.update(
        'projects',
        {
          'owner_user_id': userId,
          'workspace_type': 'CLOUD_ACCOUNT',
          'owner_account_id': accountId,
          'sync_error': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [projectId],
      );
    }
  }

  Future<void> _enqueueSyncableRows(
    Transaction txn, {
    required String table,
    required String entityType,
    required String where,
    required List<Object?> whereArgs,
    required int projectId,
    String? orderBy,
  }) async {
    final accountId = await _sessionStorage.readCurrentAccountId();
    final rows = await txn.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    for (final row in rows) {
      final operation = _operationForUpload(row);
      if (operation == null) continue;
      final id = row['id'] as int;
      final localUuid = await _markRowQueued(
        txn,
        table: table,
        id: id,
        operation: operation,
        accountId: accountId,
      );
      await _queueRepository.enqueueWithExecutor(
        txn,
        entityType: entityType,
        entityId: localUuid,
        operation: operation,
        payload: await _localDataSource.payloadFor(
          table,
          id,
          executor: txn,
        ),
        accountId: accountId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    }
  }

  Future<void> _enqueueProjectMembers(
    Transaction txn,
    int projectId,
    String accountId,
  ) async {
    final rows = await txn.query(
      'project_members',
      where: "project_id = ? AND (deleted_at IS NULL OR sync_status = ?)",
      whereArgs: [projectId, EntitySyncStatus.pendingDelete.dbValue],
      orderBy: '''
        CASE role
          WHEN 'OWNER' THEN 0
          WHEN 'SCREENWRITER' THEN 1
          WHEN 'PRODUCER' THEN 2
          WHEN 'ASSISTANT_DIRECTOR' THEN 3
          WHEN 'CREW' THEN 4
          ELSE 5
        END,
        user_id ASC
      ''',
    );
    for (final row in rows) {
      final operation = _operationForUpload(row);
      if (operation == null) continue;
      final userId = row['user_id'] as int;
      final localUuid = await _markProjectMemberQueued(
        txn,
        projectId: projectId,
        userId: userId,
        operation: operation,
        accountId: accountId,
      );
      await _queueRepository.enqueueWithExecutor(
        txn,
        entityType: 'PROJECT_MEMBER',
        entityId: localUuid,
        operation: operation,
        payload: await _projectMemberPayload(
          txn,
          projectId: projectId,
          userId: userId,
        ),
        accountId: accountId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    }
  }

  Future<String> _markRowQueued(
    Transaction txn, {
    required String table,
    required int id,
    required SyncOperationType operation,
    required String? accountId,
  }) async {
    final localUuid = await _localDataSource.ensureLocalUuid(txn, table, id);
    final rows = await txn.query(
      table,
      columns: ['local_version'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final localVersion =
        rows.isEmpty ? 0 : rows.single['local_version'] as int? ?? 0;
    final values = <String, Object?>{
      'workspace_type': 'CLOUD_ACCOUNT',
      'owner_account_id': accountId,
      'sync_status': _pendingStatusFor(operation).dbValue,
      'local_version': localVersion + 1,
      'sync_error': null,
    };
    if (await _localDataSource.hasColumn(txn, table, 'updated_at')) {
      values['updated_at'] = DateTime.now().toIso8601String();
    }
    await txn.update(table, values, where: 'id = ?', whereArgs: [id]);
    return localUuid;
  }

  Future<String> _markProjectMemberQueued(
    Transaction txn, {
    required int projectId,
    required int userId,
    required SyncOperationType operation,
    required String accountId,
  }) async {
    final rows = await txn.query(
      'project_members',
      columns: ['local_uuid', 'local_version'],
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Không tìm thấy thành viên local để đồng bộ.');
    }
    final localUuid =
        rows.single['local_uuid']?.toString().trim().isNotEmpty == true
            ? rows.single['local_uuid'] as String
            : generateUuid();
    final localVersion = rows.single['local_version'] as int? ?? 0;
    await txn.update(
      'project_members',
      {
        'local_uuid': localUuid,
        'workspace_type': 'CLOUD_ACCOUNT',
        'owner_account_id': accountId,
        'sync_status': _pendingStatusFor(operation).dbValue,
        'local_version': localVersion + 1,
        'sync_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
    );
    return localUuid;
  }

  Future<Map<String, Object?>> _projectMemberPayload(
    Transaction txn, {
    required int projectId,
    required int userId,
  }) async {
    final rows = await txn.rawQuery('''
      SELECT pm.*, p.local_uuid AS project_client_uuid, u.full_name, u.email
      FROM project_members pm
      JOIN projects p ON p.id = pm.project_id
      JOIN users u ON u.id = pm.user_id
      WHERE pm.project_id = ? AND pm.user_id = ?
      LIMIT 1
    ''', [projectId, userId]);
    if (rows.isEmpty) return const {};
    return Map<String, Object?>.from(rows.single);
  }

  SyncOperationType? _operationForUpload(Map<String, Object?> row) {
    final status = EntitySyncStatusCodec.fromDb(row['sync_status'] as String?);
    final serverVersion = _intOrNull(row['server_version']) ?? 0;
    final deleted = row['deleted_at']?.toString().trim().isNotEmpty == true ||
        status == EntitySyncStatus.pendingDelete;
    if (deleted) {
      return serverVersion <= 0 ? null : SyncOperationType.delete;
    }
    final remoteId = row['remote_id']?.toString().trim();
    if (status == EntitySyncStatus.pendingCreate ||
        status == EntitySyncStatus.localOnly ||
        serverVersion <= 0 ||
        remoteId == null ||
        remoteId.isEmpty) {
      return SyncOperationType.create;
    }
    return SyncOperationType.update;
  }

  EntitySyncStatus _pendingStatusFor(SyncOperationType operation) {
    return switch (operation) {
      SyncOperationType.create => EntitySyncStatus.pendingCreate,
      SyncOperationType.update => EntitySyncStatus.pendingUpdate,
      SyncOperationType.delete => EntitySyncStatus.pendingDelete,
      SyncOperationType.uploadFile => EntitySyncStatus.pendingUpdate,
    };
  }

  Future<void> pullRemoteFromServer() async {
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
    final rows = await _rowsBySyncId(table, change.entityId);
    if (rows.isNotEmpty) {
      final row = rows.single;
      final status =
          EntitySyncStatusCodec.fromDb(row['sync_status'] as String?);
      if (status.hasPendingChange) {
        await _conflictRepository.create(
          accountId: await _sessionStorage.readCurrentAccountId(),
          projectId: row['project_id'] as int?,
          entityType: change.entityType,
          entityId: change.entityId,
          localPayload: row,
          remotePayload: change.payload,
          conflictingFields: _changedFields(row, change.payload),
          localUpdatedAt:
              DateTime.tryParse(row['updated_at']?.toString() ?? ''),
          remoteUpdatedAt: change.updatedAt,
        );
        await _localDataSource.markConflictByLocalUuid(
          table: table,
          localUuid: row['local_uuid'] as String,
          error: 'Dữ liệu từ xa đã thay đổi khi chỉnh sửa cục bộ còn đang chờ',
        );
        return;
      }
      await _updateExistingFromRemote(table, row, change);
      return;
    }
    if (change.operation != 'DELETE') {
      await _insertFromRemote(table, change);
    }
  }

  Future<void> _updateExistingFromRemote(
    String table,
    Map<String, Object?> row,
    PullChange change,
  ) async {
    final payload = await _localValuesForRemote(table, change);
    if (change.operation == 'DELETE') {
      payload['deleted_at'] = DateTime.now().toIso8601String();
    }
    payload
      ..remove('id')
      ..remove('remoteId')
      ..remove('localUuid')
      ..remove('local_uuid');
    await _db.update(
      table,
      await _filterValuesForTable(table, {
        ...payload,
        'remote_id': change.payload['remote_id']?.toString() ?? change.entityId,
        'server_version': change.serverVersion,
        'sync_status': EntitySyncStatus.synced.dbValue,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': change.updatedAt.toIso8601String(),
        'sync_error': null,
      }),
      where: table == 'project_members'
          ? 'project_id = ? AND user_id = ?'
          : 'id = ?',
      whereArgs: table == 'project_members'
          ? [row['project_id'], row['user_id']]
          : [row['id']],
    );
  }

  Future<void> _insertFromRemote(String table, PullChange change) async {
    switch (table) {
      case 'projects':
        await _insertProjectFromRemote(change);
        break;
      case 'project_members':
        await _insertProjectMemberFromRemote(change);
        break;
      default:
        await _insertSyncableRowFromRemote(table, change);
    }
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
      'start_date': change.payload['start_date'] ?? change.payload['startDate'],
      'end_date': change.payload['end_date'] ?? change.payload['endDate'],
      'max_shooting_minutes_per_day':
          change.payload['max_shooting_minutes_per_day'] ??
              change.payload['maxShootingMinutesPerDay'] ??
              480,
      'poster_url': change.payload['poster_url'] ?? change.payload['posterUrl'],
      'created_at':
          change.payload['created_at'] ?? change.payload['createdAt'] ?? now,
      'updated_at': change.updatedAt.toIso8601String(),
      'local_uuid': change.entityId,
      'remote_id': change.payload['remote_id']?.toString() ?? change.entityId,
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

  Future<void> _insertProjectMemberFromRemote(PullChange change) async {
    final projectId = await _localIdForRemote(
      'projects',
      change.payload['project_client_uuid']?.toString(),
    );
    final userId = _intOrNull(change.payload['user_id']);
    if (projectId == null || userId == null) return;
    await _upsertRemoteUser(change.payload);
    final now = DateTime.now().toIso8601String();
    await _db.insert(
      'project_members',
      await _filterValuesForTable('project_members', {
        'project_id': projectId,
        'user_id': userId,
        'role': change.payload['role']?.toString() ?? 'VIEWER',
        'local_uuid': change.entityId,
        'remote_id': change.payload['remote_id']?.toString() ?? change.entityId,
        'workspace_type': 'CLOUD_ACCOUNT',
        'owner_account_id': await _sessionStorage.readCurrentAccountId(),
        'sync_status': EntitySyncStatus.synced.dbValue,
        'local_version': 0,
        'server_version': change.serverVersion,
        'last_synced_at': now,
        'created_at': change.payload['joined_at']?.toString() ?? now,
        'updated_at': change.updatedAt.toIso8601String(),
        'sync_error': null,
      }),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> _rowsBySyncId(
    String table,
    String syncId,
  ) {
    return _db.query(
      table,
      where: 'local_uuid = ? OR remote_id = ?',
      whereArgs: [syncId, syncId],
      limit: 1,
    );
  }

  Future<Map<String, Object?>> _localValuesForRemote(
    String table,
    PullChange change,
  ) async {
    final payload = change.payload;
    switch (table) {
      case 'projects':
        final userId = await _sessionStorage.readCurrentUserId();
        return {
          if (userId != null) 'owner_user_id': userId,
          if (payload.containsKey('title')) 'title': payload['title'],
          if (payload.containsKey('genre')) 'genre': payload['genre'],
          if (payload.containsKey('description'))
            'description': payload['description'],
          if (payload.containsKey('start_date'))
            'start_date': payload['start_date'],
          if (payload.containsKey('end_date')) 'end_date': payload['end_date'],
          if (payload.containsKey('max_shooting_minutes_per_day'))
            'max_shooting_minutes_per_day':
                _intOrNull(payload['max_shooting_minutes_per_day']),
          if (payload.containsKey('poster_url'))
            'poster_url': payload['poster_url'],
        };
      case 'acts':
        final projectId = await _localIdForRemote(
          'projects',
          payload['project_client_uuid']?.toString(),
        );
        if (projectId == null) return const {};
        return {
          'project_id': projectId,
          'title': payload['title'],
          'description': payload['description'],
          'sequence_order': _intOrNull(
                  payload['sequence_order'] ?? payload['sequenceOrder']) ??
              1,
        };
      case 'project_members':
        final projectId = await _localIdForRemote(
          'projects',
          payload['project_client_uuid']?.toString(),
        );
        final userId = _intOrNull(payload['user_id']);
        if (projectId == null || userId == null) return const {};
        await _upsertRemoteUser(payload);
        return {
          'project_id': projectId,
          'user_id': userId,
          'role': payload['role'] ?? 'VIEWER',
          'created_at': payload['joined_at'],
        };
      case 'characters':
        final projectId = await _localIdForRemote(
          'projects',
          payload['project_client_uuid']?.toString(),
        );
        if (projectId == null) return const {};
        return {
          'project_id': projectId,
          'name': payload['name'],
          'role_type': payload['role_type'] ?? payload['roleType'] ?? 'SUPPORT',
          'psychological_description':
              payload['psychological_description'] ?? payload['description'],
          'appearance_description': payload['appearance_description'],
          'image_path': payload['image_path'] ?? payload['imageUrl'],
          'is_archived': _boolToInt(payload['is_archived']),
        };
      case 'story_locations':
        final projectId = await _localIdForRemote(
          'projects',
          payload['project_client_uuid']?.toString(),
        );
        if (projectId == null) return const {};
        return {
          'project_id': projectId,
          'name': payload['name'],
          'description': payload['description'],
          'notes': payload['notes'],
          'is_archived': _boolToInt(payload['is_archived']),
        };
      case 'scenes':
        final projectId = await _localIdForRemote(
          'projects',
          payload['project_client_uuid']?.toString(),
        );
        final actId = await _localIdForRemote(
          'acts',
          payload['act_client_uuid']?.toString(),
        );
        final storyLocationId = await _localIdForRemote(
          'story_locations',
          payload['story_location_client_uuid']?.toString(),
        );
        if (projectId == null || actId == null || storyLocationId == null) {
          return const {};
        }
        return {
          'project_id': projectId,
          'act_id': actId,
          'story_location_id': storyLocationId,
          'scene_number':
              _intOrNull(payload['scene_number'] ?? payload['sceneNumber']) ??
                  1,
          'title': payload['title'],
          'summary': payload['summary'] ?? '',
          'setting_type':
              payload['setting_type'] ?? payload['settingType'] ?? 'INT',
          'time_of_day':
              payload['time_of_day'] ?? payload['timeOfDay'] ?? 'DAY',
          'estimated_duration_minutes': _intOrNull(
                  payload['estimated_duration_minutes'] ??
                      payload['estimatedMinutes']) ??
              1,
          'priority': _intOrNull(payload['priority']) ?? 3,
          'writing_status':
              payload['writing_status'] ?? payload['status'] ?? 'TODO',
          'production_status': payload['production_status'] ?? 'NOT_READY',
        };
      default:
        return const {};
    }
  }

  Future<Map<String, Object?>> _filterValuesForTable(
    String table,
    Map<String, Object?> values,
  ) async {
    final columns = await _columnsForTable(table);
    return Map<String, Object?>.fromEntries(
      values.entries.where((entry) => columns.contains(entry.key)),
    );
  }

  Future<Set<String>> _columnsForTable(String table) async {
    final rows = await _db.rawQuery('PRAGMA table_info($table)');
    return rows.map((row) => row['name'] as String).toSet();
  }

  Future<int?> _localIdForRemote(String table, String? syncId) async {
    if (syncId == null || syncId.trim().isEmpty) return null;
    final rows = await _rowsBySyncId(table, syncId);
    return rows.isEmpty ? null : rows.single['id'] as int?;
  }

  Future<void> _upsertRemoteUser(Map<String, dynamic> payload) async {
    final userId = _intOrNull(payload['user_id']);
    final email = payload['email']?.toString();
    if (userId == null || email == null || email.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final values = {
      'id': userId,
      'full_name': payload['full_name']?.toString() ?? email,
      'email': email.trim().toLowerCase(),
      'password_hash': 'remote-member',
      'is_active': 1,
      'created_at': now,
    };
    await _db.insert(
      'users',
      values,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _db.update(
      'users',
      {
        'full_name': values['full_name'],
        'email': values['email'],
        'is_active': 1,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> _insertSyncableRowFromRemote(
    String table,
    PullChange change,
  ) async {
    final values = await _localValuesForRemote(table, change);
    if (values.isEmpty) return;
    await _db.insert(
      table,
      await _filterValuesForTable(table, {
        ...values,
        'local_uuid': change.entityId,
        'remote_id': change.payload['remote_id']?.toString() ?? change.entityId,
        'workspace_type': 'CLOUD_ACCOUNT',
        'owner_account_id': await _sessionStorage.readCurrentAccountId(),
        'sync_status': EntitySyncStatus.synced.dbValue,
        'local_version': 0,
        'server_version': change.serverVersion,
        'last_synced_at': DateTime.now().toIso8601String(),
        'created_at': change.payload['created_at']?.toString() ??
            change.updatedAt.toIso8601String(),
        'updated_at': change.updatedAt.toIso8601String(),
        'sync_error': null,
      }),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int _boolToInt(Object? value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value == 0 ? 0 : 1;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1' ? 1 : 0;
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
      if (localValue != null &&
          localValue.toString() != entry.value?.toString()) {
        result.add(entry.key);
      }
    }
    return result;
  }

  String _detailTitle(String entityType, Map<String, dynamic> payload) {
    for (final key in [
      'title',
      'name',
      'email',
      'full_name',
      'summary',
      'local_path',
    ]) {
      final value = payload[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '${_entityLabel(entityType)} ${payload['id'] ?? ''}'.trim();
  }

  String _entityLabel(String entityType) {
    return switch (entityType) {
      'PROJECT' => 'Dự án',
      'PROJECT_MEMBER' => 'Thành viên',
      'ACT' => 'Hồi',
      'CHARACTER' => 'Nhân vật',
      'STORY_LOCATION' => 'Bối cảnh',
      'SHOOTING_LOCATION' => 'Địa điểm quay',
      'FILM_RESOURCE' => 'Tài nguyên',
      'SCENE' => 'Cảnh',
      'SHOOTING_DAY' => 'Ngày quay',
      'FILE_ASSET' => 'Tệp',
      _ => entityType,
    };
  }
}
