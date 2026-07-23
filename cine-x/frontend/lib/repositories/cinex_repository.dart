import 'dart:typed_data';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../core/permissions/permission_service.dart';
import '../core/storage/session_storage.dart';
import '../core/sync/sync_models.dart';
import '../core/sync/sync_queue_repository.dart';
import '../core/utils/uuid.dart';
import '../core/validators/form_validators.dart';
import '../data/local/local_data_source.dart';
import '../models/cinex_models.dart';
import '../services/image_storage_service.dart';
import '../services/pdf_export_service.dart';
import '../services/production_schedule_optimizer.dart';
import '../services/schedule_conflict_service.dart';

class CineXRepository {
  static const _serverSyncEntityTypes = {
    'PROJECT',
    'PROJECT_MEMBER',
    'ACT',
    'CHARACTER',
    'STORY_LOCATION',
    'SCENE',
  };

  CineXRepository(
    Database db,
    SessionStorage sessionStorage,
    PermissionService permissionService, {
    ImageStorageService imageStorageService = const ImageStorageService(),
    PdfExportService pdfExportService = const PdfExportService(),
    ProductionScheduleOptimizer optimizer = const ProductionScheduleOptimizer(),
    ScheduleConflictService conflictService = const ScheduleConflictService(),
    LocalDataSource? localDataSource,
    SyncQueueRepository? syncQueueRepository,
  })  : _db = db,
        _sessionStorage = sessionStorage,
        _permissionService = permissionService,
        _imageStorageService = imageStorageService,
        _pdfExportService = pdfExportService,
        _optimizer = optimizer,
        _conflictService = conflictService,
        _localDataSource = localDataSource ?? LocalDataSource(db),
        _syncQueueRepository = syncQueueRepository ?? SyncQueueRepository(db);

  final Database _db;
  final SessionStorage _sessionStorage;
  final PermissionService _permissionService;
  final ImageStorageService _imageStorageService;
  final PdfExportService _pdfExportService;
  final ProductionScheduleOptimizer _optimizer;
  final ScheduleConflictService _conflictService;
  final LocalDataSource _localDataSource;
  final SyncQueueRepository _syncQueueRepository;

  Future<int> _currentUserId() async {
    final userId = await _sessionStorage.readCurrentUserId();
    if (userId == null) throw Exception('Vui lòng đăng nhập lại.');
    return userId;
  }

  Future<void> _require(int projectId, ProjectPermission permission) async {
    await _permissionService.require(
      projectId,
      await _currentUserId(),
      permission,
    );
  }

  Future<AppUsageMode> _usageMode() => _sessionStorage.readUsageMode();

  Future<String?> _accountId() => _sessionStorage.readCurrentAccountId();

  Future<bool> _isOnlineAccount() async {
    return await _usageMode() == AppUsageMode.onlineAccount;
  }

  Future<void> _recordCreate(
    DatabaseExecutor executor, {
    required String table,
    required String entityType,
    required int id,
    int? projectId,
    String? dependencyGroup,
  }) async {
    final mode = await _usageMode();
    final accountId = await _accountId();
    final syncToServer = _serverSyncEntityTypes.contains(entityType);
    final localUuid = await _localDataSource.markCreated(
      executor,
      table: table,
      id: id,
      mode: mode,
      accountId: accountId,
      syncToServer: syncToServer,
    );
    if (mode == AppUsageMode.offlineGuest || !syncToServer) return;
    await _syncQueueRepository.enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: localUuid,
      operation: SyncOperationType.create,
      payload: await _localDataSource.payloadFor(
        table,
        id,
        executor: executor,
      ),
      accountId: accountId,
      projectId: projectId,
      dependencyGroup: dependencyGroup,
    );
  }

  Future<void> _recordUpdate(
    DatabaseExecutor executor, {
    required String table,
    required String entityType,
    required int id,
    int? projectId,
    String? dependencyGroup,
  }) async {
    final mode = await _usageMode();
    final accountId = await _accountId();
    final syncToServer = _serverSyncEntityTypes.contains(entityType);
    final localUuid = await _localDataSource.markUpdated(
      executor,
      table: table,
      id: id,
      mode: mode,
      accountId: accountId,
      syncToServer: syncToServer,
    );
    if (mode == AppUsageMode.offlineGuest || !syncToServer) return;
    await _syncQueueRepository.enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: localUuid,
      operation: SyncOperationType.update,
      payload: await _localDataSource.payloadFor(
        table,
        id,
        executor: executor,
      ),
      accountId: accountId,
      projectId: projectId,
      dependencyGroup: dependencyGroup,
    );
  }

  Future<void> _recordDelete(
    DatabaseExecutor executor, {
    required String table,
    required String entityType,
    required int id,
    int? projectId,
    String? dependencyGroup,
  }) async {
    final mode = await _usageMode();
    final accountId = await _accountId();
    final syncToServer = _serverSyncEntityTypes.contains(entityType);
    final localUuid = await _localDataSource.markDeleted(
      executor,
      table: table,
      id: id,
      mode: mode,
      accountId: accountId,
      syncToServer: syncToServer,
    );
    if (mode == AppUsageMode.offlineGuest || !syncToServer) return;
    await _syncQueueRepository.enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: localUuid,
      operation: SyncOperationType.delete,
      payload: await _localDataSource.payloadFor(
        table,
        id,
        executor: executor,
      ),
      accountId: accountId,
      projectId: projectId,
      dependencyGroup: dependencyGroup,
    );
  }

  Future<void> _recordFileUpload(
    DatabaseExecutor executor, {
    required int projectId,
    required String entityTable,
    required int entityId,
    required String localPath,
  }) async {
    final mode = await _usageMode();
    final accountId = await _accountId();
    final now = DateTime.now().toIso8601String();
    final localUuid = generateUuid();
    final file = File(localPath);
    final fileSize = await file.exists() ? await file.length() : null;
    await executor.insert('file_assets', {
      'project_id': projectId,
      'entity_table': entityTable,
      'entity_id': entityId,
      'local_path': localPath,
      'remote_url': null,
      'checksum': null,
      'upload_status': EntitySyncStatus.localOnly.dbValue,
      'mime_type': null,
      'file_size': fileSize,
      'created_at': now,
      'updated_at': now,
      'local_uuid': localUuid,
      'workspace_type':
          mode == AppUsageMode.offlineGuest ? 'LOCAL_GUEST' : 'CLOUD_ACCOUNT',
      'owner_account_id': mode == AppUsageMode.offlineGuest ? null : accountId,
      'sync_status': EntitySyncStatus.localOnly.dbValue,
      'local_version': 1,
    });
  }

  Future<Set<ProjectPermission>> permissions(int projectId) async {
    return _permissionService.permissionsForUser(
      projectId,
      await _currentUserId(),
    );
  }

  Future<List<ProjectMember>> members(int projectId) async {
    final userId = await _currentUserId();
    if (await _count(
          'project_members',
          'project_id = ? AND user_id = ? AND deleted_at IS NULL',
          [projectId, userId],
        ) ==
        0) {
      throw Exception('Bạn không thuộc dự án này.');
    }
    final rows = await _db.rawQuery('''
      SELECT pm.*, u.full_name, u.email
      FROM project_members pm
      JOIN users u ON u.id = pm.user_id
      WHERE pm.project_id = ? AND pm.deleted_at IS NULL
      ORDER BY
        CASE pm.role
          WHEN 'OWNER' THEN 0
          WHEN 'SCREENWRITER' THEN 1
          WHEN 'PRODUCER' THEN 2
          WHEN 'ASSISTANT_DIRECTOR' THEN 3
          WHEN 'CREW' THEN 4
          ELSE 5
        END,
        u.full_name COLLATE NOCASE ASC
    ''', [projectId]);
    return rows.map(ProjectMember.fromMap).toList();
  }

  Future<ProjectMember> addMember(
    int projectId, {
    required String email,
    required String role,
    String? fullName,
  }) async {
    await _require(projectId, ProjectPermission.manageMembers);
    final normalizedEmail = _normalizeEmail(email);
    final normalizedRole = _normalizeMemberRole(role, creating: true);
    late final int userId;
    await _db.transaction((txn) async {
      userId = await _ensureLocalUser(
        txn,
        email: normalizedEmail,
        fullName: _emptyToNull(fullName) ?? normalizedEmail,
      );
      final existing = await txn.query(
        'project_members',
        columns: ['user_id', 'deleted_at'],
        where: 'project_id = ? AND user_id = ?',
        whereArgs: [projectId, userId],
        limit: 1,
      );
      final now = DateTime.now().toIso8601String();
      final localUuid = existing.isEmpty
          ? generateUuid()
          : await _ensureMemberLocalUuid(txn, projectId, userId);
      if (existing.isEmpty) {
        await txn.insert('project_members', {
          'project_id': projectId,
          'user_id': userId,
          'role': normalizedRole,
          'local_uuid': localUuid,
          'created_at': now,
          'updated_at': now,
        });
      } else if (existing.single['deleted_at'] == null) {
        throw Exception('Người dùng đã là thành viên dự án.');
      } else {
        await txn.update(
          'project_members',
          {
            'role': normalizedRole,
            'deleted_at': null,
            'updated_at': now,
          },
          where: 'project_id = ? AND user_id = ?',
          whereArgs: [projectId, userId],
        );
      }
      await _markMemberChanged(
        txn,
        projectId: projectId,
        userId: userId,
        operation: SyncOperationType.create,
      );
    });
    return _memberByUser(projectId, userId);
  }

  Future<ProjectMember> updateMemberRole(
    int projectId,
    int userId,
    String role,
  ) async {
    await _require(projectId, ProjectPermission.manageMembers);
    final normalizedRole = _normalizeMemberRole(role);
    final current = await _memberByUser(projectId, userId);
    if (current.role == 'OWNER' &&
        normalizedRole != 'OWNER' &&
        await _ownerCount(projectId) <= 1) {
      throw Exception('Không thể hạ quyền OWNER cuối cùng.');
    }
    await _db.transaction((txn) async {
      await txn.update(
        'project_members',
        {
          'role': normalizedRole,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'project_id = ? AND user_id = ?',
        whereArgs: [projectId, userId],
      );
      await _markMemberChanged(
        txn,
        projectId: projectId,
        userId: userId,
        operation: SyncOperationType.update,
      );
    });
    return _memberByUser(projectId, userId);
  }

  Future<void> deleteMember(int projectId, int userId) async {
    await _require(projectId, ProjectPermission.manageMembers);
    final current = await _memberByUser(projectId, userId);
    if (current.role == 'OWNER' && await _ownerCount(projectId) <= 1) {
      throw Exception('Không thể xóa OWNER cuối cùng.');
    }
    if (await _isOnlineAccount()) {
      await _db.transaction((txn) async {
        await txn.update(
          'project_members',
          {
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'project_id = ? AND user_id = ?',
          whereArgs: [projectId, userId],
        );
        await _markMemberChanged(
          txn,
          projectId: projectId,
          userId: userId,
          operation: SyncOperationType.delete,
        );
      });
      return;
    }
    await _db.delete(
      'project_members',
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
    );
  }

  Future<List<Project>> projects({String? search}) async {
    final userId = await _currentUserId();
    final args = <Object?>[userId];
    var where = 'pm.user_id = ? AND p.deleted_at IS NULL';
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      where +=
          ' AND (p.title LIKE ? OR p.genre LIKE ? OR p.description LIKE ?)';
      args.addAll(['%$term%', '%$term%', '%$term%']);
    }
    final rows = await _db.rawQuery('''
      SELECT p.*
      FROM projects p
      JOIN project_members pm ON pm.project_id = p.id
      WHERE $where
      ORDER BY p.updated_at DESC
    ''', args);
    final result = <Project>[];
    for (final row in rows) {
      result.add(
        Project.fromMap(
          row,
          progressPercent: await _projectProgress(row['id'] as int),
        ),
      );
    }
    return result;
  }

  Future<Project> createProject(Map<String, dynamic> body) async {
    final userId = await _currentUserId();
    final titleError = ProjectValidators.title(body['title']?.toString());
    if (titleError != null) throw Exception(titleError);
    final start = _dateOrNull(body['startDate']);
    final end = _dateOrNull(body['endDate']);
    final dateError = ProjectValidators.dateRange(start, end);
    if (dateError != null) throw Exception(dateError);
    final maxMinutes = _intOrNull(body['maxShootingMinutesPerDay']) ?? 480;
    final maxError = ProjectValidators.maxMinutes('$maxMinutes');
    if (maxError != null) throw Exception(maxError);
    final now = DateTime.now().toIso8601String();
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('projects', {
        'owner_user_id': userId,
        'title': body['title'].toString().trim(),
        'genre': _emptyToNull(body['genre']),
        'description': _emptyToNull(body['description']),
        'start_date': start?.toIso8601String(),
        'end_date': end?.toIso8601String(),
        'max_shooting_minutes_per_day': maxMinutes,
        'poster_url': _emptyToNull(body['posterUrl']),
        'created_at': now,
        'updated_at': now,
      });
      await _recordCreate(
        txn,
        table: 'projects',
        entityType: 'PROJECT',
        id: id,
        projectId: id,
      );
      final mode = await _usageMode();
      final accountId = await _accountId();
      final memberUuid = generateUuid();
      await txn.insert('project_members', {
        'project_id': id,
        'user_id': userId,
        'role': 'OWNER',
        'local_uuid': memberUuid,
        'workspace_type':
            mode == AppUsageMode.offlineGuest ? 'LOCAL_GUEST' : 'CLOUD_ACCOUNT',
        'owner_account_id':
            mode == AppUsageMode.offlineGuest ? null : accountId,
        'sync_status': mode == AppUsageMode.offlineGuest
            ? EntitySyncStatus.localOnly.dbValue
            : EntitySyncStatus.pendingCreate.dbValue,
        'local_version': 1,
        'created_at': now,
        'updated_at': now,
      });
      if (mode == AppUsageMode.onlineAccount) {
        await _syncQueueRepository.enqueueWithExecutor(
          txn,
          entityType: 'PROJECT_MEMBER',
          entityId: memberUuid,
          operation: SyncOperationType.create,
          payload: {
            'projectId': id,
            'userId': userId,
            'role': 'OWNER',
            'localUuid': memberUuid,
          },
          accountId: accountId,
          projectId: id,
          dependencyGroup: 'project:$id',
        );
      }
    });
    return projectById(id);
  }

  Future<Project> updateProject(
      int projectId, Map<String, dynamic> body) async {
    await _require(projectId, ProjectPermission.manageProject);
    final title = body['title']?.toString().trim();
    if (title != null) {
      final titleError = ProjectValidators.title(title);
      if (titleError != null) throw Exception(titleError);
    }
    final start = _dateOrNull(body['startDate']);
    final end = _dateOrNull(body['endDate']);
    final dateError = ProjectValidators.dateRange(start, end);
    if (dateError != null) throw Exception(dateError);
    final maxMinutes = _intOrNull(body['maxShootingMinutesPerDay']);
    if (maxMinutes != null) {
      final maxError = ProjectValidators.maxMinutes('$maxMinutes');
      if (maxError != null) throw Exception(maxError);
    }
    await _db.transaction((txn) async {
      await txn.update(
        'projects',
        {
          if (title != null) 'title': title,
          'genre': _emptyToNull(body['genre']),
          'description': _emptyToNull(body['description']),
          'start_date': start?.toIso8601String(),
          'end_date': end?.toIso8601String(),
          if (maxMinutes != null) 'max_shooting_minutes_per_day': maxMinutes,
          'poster_url': _emptyToNull(body['posterUrl']),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [projectId],
      );
      await _recordUpdate(
        txn,
        table: 'projects',
        entityType: 'PROJECT',
        id: projectId,
        projectId: projectId,
      );
    });
    return projectById(projectId);
  }

  Future<void> deleteProject(int projectId) async {
    await _require(projectId, ProjectPermission.deleteProject);
    if (await _isOnlineAccount()) {
      await _db.transaction((txn) async {
        await txn.update(
          'projects',
          {
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [projectId],
        );
        await _recordDelete(
          txn,
          table: 'projects',
          entityType: 'PROJECT',
          id: projectId,
          projectId: projectId,
        );
      });
      return;
    }
    await _db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
  }

  Future<Project> projectById(int projectId) async {
    final rows = await _db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (rows.isEmpty || rows.single['deleted_at'] != null) {
      throw Exception('Không tìm thấy dự án.');
    }
    return Project.fromMap(
      rows.single,
      progressPercent: await _projectProgress(projectId),
    );
  }

  Future<Dashboard> dashboard(int projectId) async {
    final totalActs = await _count(
      'acts',
      'project_id = ? AND deleted_at IS NULL',
      [projectId],
    );
    final totalCharacters = await _count(
      'characters',
      'project_id = ? AND is_archived = 0 AND deleted_at IS NULL',
      [projectId],
    );
    final storyLocations = await _count(
      'story_locations',
      'project_id = ? AND is_archived = 0 AND deleted_at IS NULL',
      [projectId],
    );
    final shootingLocations = await _count(
      'shooting_locations',
      'project_id = ? AND is_active = 1 AND deleted_at IS NULL',
      [projectId],
    );
    final totalScenes = await _count(
      'scenes',
      'project_id = ? AND deleted_at IS NULL',
      [projectId],
    );
    final todo = await _count(
      'scenes',
      'project_id = ? AND writing_status = ? AND deleted_at IS NULL',
      [projectId, 'TODO'],
    );
    final inProgress = await _count(
      'scenes',
      'project_id = ? AND writing_status = ? AND deleted_at IS NULL',
      [projectId, 'IN_PROGRESS'],
    );
    final done = await _count(
      'scenes',
      'project_id = ? AND writing_status = ? AND deleted_at IS NULL',
      [projectId, 'DONE'],
    );
    final totalResources = await _count(
      'film_resources',
      'project_id = ? AND is_archived = 0 AND deleted_at IS NULL',
      [projectId],
    );
    final shootingDays = await _count(
      'shooting_days',
      'project_id = ? AND deleted_at IS NULL',
      [projectId],
    );
    return Dashboard(
      totalActs: totalActs,
      totalCharacters: totalCharacters,
      totalLocations: storyLocations + shootingLocations,
      totalScenes: totalScenes,
      todoScenes: todo,
      inProgressScenes: inProgress,
      doneScenes: done,
      progressPercent: totalScenes == 0 ? 0 : (done / totalScenes) * 100,
      totalResources: totalResources,
      totalShootingDays: shootingDays,
    );
  }

  Future<List<Act>> acts(int projectId) async {
    final rows = await _db.query(
      'acts',
      where: 'project_id = ? AND deleted_at IS NULL',
      whereArgs: [projectId],
      orderBy: 'sequence_order ASC',
    );
    return rows.map(Act.fromMap).toList();
  }

  Future<Act> createAct(int projectId, Map<String, dynamic> body) async {
    await _require(projectId, ProjectPermission.manageStory);
    final title = body['title']?.toString().trim() ?? '';
    final titleError = ActValidators.title(title);
    if (titleError != null) throw Exception(titleError);
    final maxOrder = Sqflite.firstIntValue(await _db.rawQuery(
          'SELECT COALESCE(MAX(sequence_order), 0) FROM acts '
          'WHERE project_id = ? AND deleted_at IS NULL',
          [projectId],
        )) ??
        0;
    final order =
        _intOrNull(body['sequenceOrder'] ?? body['sequence_order']) ??
            maxOrder + 1;
    if (order <= 0) {
      throw Exception('Thứ tự phải lớn hơn 0.');
    }
    if (await _count(
          'acts',
          'project_id = ? AND sequence_order = ? AND deleted_at IS NULL',
          [projectId, order],
        ) >
        0) {
      throw Exception('Thứ tự này đã tồn tại trong dự án.');
    }
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('acts', {
        'project_id': projectId,
        'title': title,
        'description': _emptyToNull(body['description']),
        'sequence_order': order,
      });
      await _recordCreate(
        txn,
        table: 'acts',
        entityType: 'ACT',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    final rows = await _db.query('acts', where: 'id = ?', whereArgs: [id]);
    return Act.fromMap(rows.single);
  }

  Future<Act> updateAct(
    int projectId,
    int actId,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageStory);
    await _ensureRowInProject(
      table: 'acts',
      id: actId,
      projectId: projectId,
      label: 'hoi',
    );
    final title = body['title']?.toString().trim() ?? '';
    final titleError = ActValidators.title(title);
    if (titleError != null) throw Exception(titleError);
    final order =
        body['sequenceOrder'] as int? ?? body['sequence_order'] as int?;
    if (order == null || order <= 0) {
      throw Exception('Thu tu phai lon hon 0.');
    }
    final rows = await _db.query(
      'acts',
      where: 'project_id = ? AND deleted_at IS NULL',
      whereArgs: [projectId],
      orderBy: 'sequence_order ASC, id ASC',
    );
    final ordered = rows.map((row) => Map<String, Object?>.from(row)).toList();
    final currentIndex = ordered.indexWhere((row) => row['id'] == actId);
    if (currentIndex < 0) {
      throw Exception('Khong tim thay hoi can xu ly.');
    }
    final current = ordered.removeAt(currentIndex);
    current['title'] = title;
    current['description'] = _emptyToNull(body['description']);
    final targetIndex =
        order <= 1 ? 0 : order > ordered.length + 1 ? ordered.length : order - 1;
    ordered.insert(targetIndex, current);
    final previousOrder = {
      for (final row in rows) row['id'] as int: row['sequence_order'] as int,
    };
    final affectedIds = <int>{actId};
    for (var index = 0; index < ordered.length; index++) {
      final id = ordered[index]['id'] as int;
      if (previousOrder[id] != index + 1) affectedIds.add(id);
    }
    await _db.transaction((txn) async {
      for (var index = 0; index < ordered.length; index++) {
        await txn.update(
          'acts',
          {'sequence_order': -(index + 1)},
          where: 'id = ? AND project_id = ?',
          whereArgs: [ordered[index]['id'], projectId],
        );
      }
      for (var index = 0; index < ordered.length; index++) {
        final row = ordered[index];
        await txn.update(
          'acts',
          {
            'title': row['title'],
            'description': row['description'],
            'sequence_order': index + 1,
          },
          where: 'id = ? AND project_id = ?',
          whereArgs: [row['id'], projectId],
        );
      }
      for (final id in affectedIds) {
        await _recordUpdate(
          txn,
          table: 'acts',
          entityType: 'ACT',
          id: id,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      }
    });
    final updatedRows =
        await _db.query('acts', where: 'id = ?', whereArgs: [actId]);
    return Act.fromMap(updatedRows.single);
  }

  Future<void> deleteAct(int projectId, int actId) async {
    await _require(projectId, ProjectPermission.manageStory);
    await _ensureRowInProject(
      table: 'acts',
      id: actId,
      projectId: projectId,
      label: 'hoi',
    );
    final sceneRows = await _db.query(
      'scenes',
      columns: ['id'],
      where: 'act_id = ? AND project_id = ? AND deleted_at IS NULL',
      whereArgs: [actId, projectId],
    );
    final sceneIds = sceneRows.map((row) => row['id'] as int).toList();
    if (await _isOnlineAccount()) {
      await _db.transaction((txn) async {
        await _deleteSceneLinksForIds(txn, sceneIds);
        for (final sceneId in sceneIds) {
          await txn.update(
            'scenes',
            {
              'deleted_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ? AND project_id = ?',
            whereArgs: [sceneId, projectId],
          );
          await _recordDelete(
            txn,
            table: 'scenes',
            entityType: 'SCENE',
            id: sceneId,
            projectId: projectId,
            dependencyGroup: 'project:$projectId',
          );
        }
        await _recordDelete(
          txn,
          table: 'acts',
          entityType: 'ACT',
          id: actId,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      });
      return;
    }
    await _db.transaction((txn) async {
      if (sceneIds.isNotEmpty) {
        await _deleteSceneLinksForIds(txn, sceneIds);
        final marks = List.filled(sceneIds.length, '?').join(',');
        await txn.delete(
          'scenes',
          where: 'id IN ($marks) AND project_id = ?',
          whereArgs: [...sceneIds, projectId],
        );
      }
      await txn.delete(
        'acts',
        where: 'id = ? AND project_id = ?',
        whereArgs: [actId, projectId],
      );
    });
  }

  Future<List<StoryCharacter>> characters(
    int projectId, {
    String? search,
    String? roleType,
    bool includeArchived = false,
  }) async {
    final args = <Object?>[projectId];
    var where = 'project_id = ? AND deleted_at IS NULL';
    if (!includeArchived) where += ' AND is_archived = 0';
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      where += ' AND name LIKE ?';
      args.add('%$term%');
    }
    if (roleType != null && roleType.isNotEmpty) {
      where += ' AND role_type = ?';
      args.add(roleType);
    }
    final rows = await _db.query(
      'characters',
      where: where,
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(StoryCharacter.fromMap).toList();
  }

  Future<StoryCharacter> characterById(int characterId) async {
    final rows = await _db.query(
      'characters',
      where: 'id = ?',
      whereArgs: [characterId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Không tìm thấy nhân vật.');
    return StoryCharacter.fromMap(rows.single);
  }

  Future<StoryCharacter> createCharacter(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageCharacters);
    await _ensureCharacterNameAvailable(projectId, body['name']?.toString());
    final payload = _characterPayload(projectId, body);
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('characters', payload);
      await _recordCreate(
        txn,
        table: 'characters',
        entityType: 'CHARACTER',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return characterById(id);
  }

  Future<StoryCharacter> updateCharacter(
    int projectId,
    int characterId,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageCharacters);
    final existing = await characterById(characterId);
    if (existing.projectId != projectId) {
      throw Exception('Không tìm thấy nhân vật.');
    }
    await _ensureCharacterNameAvailable(
      projectId,
      body['name']?.toString(),
      exceptId: characterId,
    );
    final payload =
        _characterPayload(projectId, body, characterId: characterId);
    await _db.transaction((txn) async {
      await txn.update(
        'characters',
        payload,
        where: 'id = ?',
        whereArgs: [characterId],
      );
      await _recordUpdate(
        txn,
        table: 'characters',
        entityType: 'CHARACTER',
        id: characterId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return characterById(characterId);
  }

  Future<StoryCharacter> uploadCharacterImage(
    int projectId,
    int characterId,
    XFile file,
  ) async {
    await _require(projectId, ProjectPermission.manageCharacters);
    await _ensureCharacterInProject(projectId, characterId);
    final character = await characterById(characterId);
    String? imagePath;
    try {
      imagePath = await _imageStorageService.copyPickedImage(
        file,
        folder: 'characters',
      );
      await _db.transaction((txn) async {
        await txn.update(
          'characters',
          {
            'image_path': imagePath,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND project_id = ?',
          whereArgs: [characterId, projectId],
        );
        await _recordFileUpload(
          txn,
          projectId: projectId,
          entityTable: 'characters',
          entityId: characterId,
          localPath: imagePath!,
        );
        await _recordUpdate(
          txn,
          table: 'characters',
          entityType: 'CHARACTER',
          id: characterId,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      });
      final oldPath = character.imagePath;
      if (oldPath != null && oldPath.isNotEmpty) {
        await _imageStorageService.deleteIfAppOwned(oldPath);
      }
    } catch (_) {
      if (imagePath != null) {
        await _imageStorageService.deleteIfAppOwned(imagePath);
      }
      rethrow;
    }
    return characterById(characterId);
  }

  Future<void> deleteCharacter(int projectId, int characterId) async {
    await _require(projectId, ProjectPermission.manageCharacters);
    await _ensureCharacterInProject(projectId, characterId);
    await _db.transaction((txn) async {
      await txn.delete(
        'scene_characters',
        where: 'character_id = ?',
        whereArgs: [characterId],
      );
      if (await _isOnlineAccount()) {
        await txn.update(
          'characters',
          {
            'is_archived': 1,
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND project_id = ?',
          whereArgs: [characterId, projectId],
        );
        await _recordDelete(
          txn,
          table: 'characters',
          entityType: 'CHARACTER',
          id: characterId,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      } else {
        await txn.delete(
          'characters',
          where: 'id = ? AND project_id = ?',
          whereArgs: [characterId, projectId],
        );
      }
    });
  }

  Future<void> archiveCharacter(int projectId, int characterId) async {
    await _require(projectId, ProjectPermission.manageCharacters);
    await _ensureCharacterInProject(
      projectId,
      characterId,
      includeArchived: true,
    );
    await _db.transaction((txn) async {
      await txn.update(
        'characters',
        {
          'is_archived': 1,
          if (await _isOnlineAccount())
            'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND project_id = ?',
        whereArgs: [characterId, projectId],
      );
      if (await _isOnlineAccount()) {
        await _recordDelete(
          txn,
          table: 'characters',
          entityType: 'CHARACTER',
          id: characterId,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      } else {
        await _recordUpdate(
          txn,
          table: 'characters',
          entityType: 'CHARACTER',
          id: characterId,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      }
    });
  }

  Future<List<StoryLocation>> locations(
    int projectId, {
    String? search,
    String? settingType,
    String? timeOfDay,
  }) =>
      storyLocations(projectId, search: search);

  Future<List<StoryLocation>> storyLocations(
    int projectId, {
    String? search,
    bool includeArchived = false,
  }) async {
    final args = <Object?>[projectId];
    var where = 'project_id = ? AND deleted_at IS NULL';
    if (!includeArchived) where += ' AND is_archived = 0';
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      where += ' AND name LIKE ?';
      args.add('%$term%');
    }
    final rows = await _db.query(
      'story_locations',
      where: where,
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(StoryLocation.fromMap).toList();
  }

  Future<StoryLocation> createLocation(
    int projectId,
    Map<String, dynamic> body,
  ) =>
      createStoryLocation(projectId, body);

  Future<StoryLocation> createStoryLocation(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageStoryLocations);
    final name = body['name']?.toString().trim() ?? '';
    final error = LocationValidators.storyLocationName(name);
    if (error != null) throw Exception(error);
    await _ensureStoryLocationNameAvailable(projectId, name);
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('story_locations', {
        'project_id': projectId,
        'name': name,
        'description': _emptyToNull(body['description']),
        'notes': _emptyToNull(body['notes']),
        'is_archived': 0,
      });
      await _recordCreate(
        txn,
        table: 'story_locations',
        entityType: 'STORY_LOCATION',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return storyLocationById(id);
  }

  Future<StoryLocation> updateStoryLocation(
    int projectId,
    int id,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageStoryLocations);
    final name = body['name']?.toString().trim() ?? '';
    final error = LocationValidators.storyLocationName(name);
    if (error != null) throw Exception(error);
    await _ensureStoryLocationNameAvailable(projectId, name, exceptId: id);
    await _db.transaction((txn) async {
      await txn.update(
        'story_locations',
        {
          'name': name,
          'description': _emptyToNull(body['description']),
          'notes': _emptyToNull(body['notes']),
        },
        where: 'id = ? AND project_id = ?',
        whereArgs: [id, projectId],
      );
      await _recordUpdate(
        txn,
        table: 'story_locations',
        entityType: 'STORY_LOCATION',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return storyLocationById(id);
  }

  Future<StoryLocation> storyLocationById(int id) async {
    final rows = await _db.query(
      'story_locations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Không tìm thấy bối cảnh truyện.');
    return StoryLocation.fromMap(rows.single);
  }

  Future<void> deleteLocation(int projectId, int locationId) =>
      archiveStoryLocation(projectId, locationId);

  Future<void> archiveStoryLocation(int projectId, int id) async {
    await _require(projectId, ProjectPermission.manageStoryLocations);
    final used = await _count('scenes', 'story_location_id = ?', [id]);
    if (used > 0 || await _isOnlineAccount()) {
      await _db.transaction((txn) async {
        await txn.update(
          'story_locations',
          {
            'is_archived': 1,
            if (await _isOnlineAccount())
              'deleted_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND project_id = ?',
          whereArgs: [id, projectId],
        );
        if (await _isOnlineAccount()) {
          await _recordDelete(
            txn,
            table: 'story_locations',
            entityType: 'STORY_LOCATION',
            id: id,
            projectId: projectId,
            dependencyGroup: 'project:$projectId',
          );
        } else {
          await _recordUpdate(
            txn,
            table: 'story_locations',
            entityType: 'STORY_LOCATION',
            id: id,
            projectId: projectId,
            dependencyGroup: 'project:$projectId',
          );
        }
      });
      return;
    }
    await _db.delete(
      'story_locations',
      where: 'id = ? AND project_id = ?',
      whereArgs: [id, projectId],
    );
  }

  Future<List<ShootingLocation>> shootingLocations(int projectId) async {
    final rows = await _db.query(
      'shooting_locations',
      where: 'project_id = ? AND is_active = 1 AND deleted_at IS NULL',
      whereArgs: [projectId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(ShootingLocation.fromMap).toList();
  }

  Future<ShootingLocation> shootingLocationById(int id) async {
    final rows = await _db.query(
      'shooting_locations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Không tìm thấy địa điểm quay.');
    return ShootingLocation.fromMap(rows.single);
  }

  Future<ShootingLocation> createShootingLocation(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageShootingLocations);
    final payload = _shootingLocationPayload(projectId, body);
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('shooting_locations', payload);
      await _recordCreate(
        txn,
        table: 'shooting_locations',
        entityType: 'SHOOTING_LOCATION',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return shootingLocationById(id);
  }

  Future<ShootingLocation> updateShootingLocation(
    int projectId,
    int id,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageShootingLocations);
    final payload = _shootingLocationPayload(projectId, body, creating: false);
    await _db.transaction((txn) async {
      await txn.update(
        'shooting_locations',
        payload,
        where: 'id = ? AND project_id = ?',
        whereArgs: [id, projectId],
      );
      await _recordUpdate(
        txn,
        table: 'shooting_locations',
        entityType: 'SHOOTING_LOCATION',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return shootingLocationById(id);
  }

  Future<void> archiveShootingLocation(int projectId, int id) async {
    await _require(projectId, ProjectPermission.manageShootingLocations);
    await _db.transaction((txn) async {
      await txn.update(
        'shooting_locations',
        {
          'is_active': 0,
          if (await _isOnlineAccount())
            'deleted_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND project_id = ?',
        whereArgs: [id, projectId],
      );
      if (await _isOnlineAccount()) {
        await _recordDelete(
          txn,
          table: 'shooting_locations',
          entityType: 'SHOOTING_LOCATION',
          id: id,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      } else {
        await _recordUpdate(
          txn,
          table: 'shooting_locations',
          entityType: 'SHOOTING_LOCATION',
          id: id,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      }
    });
  }

  Future<List<FilmResource>> resources(
    int projectId, {
    String? search,
    String? resourceType,
  }) async {
    final args = <Object?>[projectId];
    var where = 'project_id = ? AND is_archived = 0 AND deleted_at IS NULL';
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      where += ' AND name LIKE ?';
      args.add('%$term%');
    }
    if (resourceType != null && resourceType.isNotEmpty) {
      where += ' AND resource_type = ?';
      args.add(resourceType);
    }
    final rows = await _db.query(
      'film_resources',
      where: where,
      whereArgs: args,
      orderBy: 'resource_type ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(FilmResource.fromMap).toList();
  }

  Future<FilmResource> resourceById(int id) async {
    final rows = await _db.query(
      'film_resources',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Không tìm thấy tài nguyên.');
    return FilmResource.fromMap(rows.single);
  }

  Future<FilmResource> createResource(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageResources);
    final payload = _resourcePayload(projectId, body);
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('film_resources', payload);
      await _recordCreate(
        txn,
        table: 'film_resources',
        entityType: 'FILM_RESOURCE',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return resourceById(id);
  }

  Future<FilmResource> updateResource(
    int projectId,
    int id,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageResources);
    final payload = _resourcePayload(projectId, body, creating: false);
    await _db.transaction((txn) async {
      await txn.update(
        'film_resources',
        payload,
        where: 'id = ? AND project_id = ?',
        whereArgs: [id, projectId],
      );
      await _recordUpdate(
        txn,
        table: 'film_resources',
        entityType: 'FILM_RESOURCE',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return resourceById(id);
  }

  Future<void> archiveResource(int projectId, int id) async {
    await _require(projectId, ProjectPermission.manageResources);
    await _db.transaction((txn) async {
      await txn.update(
        'film_resources',
        {
          'is_archived': 1,
          if (await _isOnlineAccount())
            'deleted_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND project_id = ?',
        whereArgs: [id, projectId],
      );
      if (await _isOnlineAccount()) {
        await _recordDelete(
          txn,
          table: 'film_resources',
          entityType: 'FILM_RESOURCE',
          id: id,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      } else {
        await _recordUpdate(
          txn,
          table: 'film_resources',
          entityType: 'FILM_RESOURCE',
          id: id,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      }
    });
  }

  Future<List<Scene>> scenes(
    int projectId, {
    String? search,
    int? actId,
    int? locationId,
    int? characterId,
    String? settingType,
    String? timeOfDay,
    String? status,
    String? productionStatus,
    bool unscheduledOnly = false,
  }) async {
    final args = <Object?>[projectId];
    var where = 's.project_id = ? AND s.deleted_at IS NULL';
    if (search != null && search.trim().isNotEmpty) {
      where += ' AND (s.title LIKE ? OR s.summary LIKE ?)';
      args.addAll(['%${search.trim()}%', '%${search.trim()}%']);
    }
    if (actId != null) {
      where += ' AND s.act_id = ?';
      args.add(actId);
    }
    if (locationId != null) {
      where += ' AND s.story_location_id = ?';
      args.add(locationId);
    }
    if (settingType != null && settingType.isNotEmpty) {
      where += ' AND s.setting_type = ?';
      args.add(settingType);
    }
    if (timeOfDay != null && timeOfDay.isNotEmpty) {
      where += ' AND s.time_of_day = ?';
      args.add(timeOfDay);
    }
    if (status != null && status.isNotEmpty) {
      where += ' AND s.writing_status = ?';
      args.add(status);
    }
    if (productionStatus != null && productionStatus.isNotEmpty) {
      where += ' AND s.production_status = ?';
      args.add(productionStatus);
    }
    if (characterId != null) {
      where += '''
        AND EXISTS (
          SELECT 1 FROM scene_characters sc
          WHERE sc.scene_id = s.id AND sc.character_id = ?
        )
      ''';
      args.add(characterId);
    }
    if (unscheduledOnly) {
      where += '''
        AND NOT EXISTS (
          SELECT 1
          FROM shooting_day_scenes sds
          JOIN shooting_days sd ON sd.id = sds.shooting_day_id
          WHERE sds.scene_id = s.id AND sd.status IN ('DRAFT','CONFIRMED','IN_PROGRESS')
        )
      ''';
    }
    final rows = await _db.rawQuery('''
      SELECT s.*, a.title AS act_title, sl.name AS story_location_name,
             sh.name AS shooting_location_name,
             sh.address AS shooting_location_address,
             sh.supports_interior, sh.supports_exterior
      FROM scenes s
      JOIN acts a ON a.id = s.act_id
      JOIN story_locations sl ON sl.id = s.story_location_id
      LEFT JOIN shooting_locations sh ON sh.id = s.planned_shooting_location_id
      WHERE $where
      ORDER BY s.scene_number ASC
    ''', args);
    final result = <Scene>[];
    for (final row in rows) {
      final id = row['id'] as int;
      result.add(
        Scene.fromMap(
          row,
          characters: await _sceneCharacters(id),
          resources: await _sceneResources(id),
        ),
      );
    }
    return result;
  }

  Future<Scene> sceneById(int id) async {
    final result = await scenesByIds([id]);
    if (result.isEmpty) throw Exception('Không tìm thấy cảnh.');
    return result.single;
  }

  Future<List<Scene>> scenesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final marks = List.filled(ids.length, '?').join(',');
    final rows = await _db.rawQuery('''
      SELECT s.*, a.title AS act_title, sl.name AS story_location_name,
             sh.name AS shooting_location_name,
             sh.address AS shooting_location_address,
             sh.supports_interior, sh.supports_exterior
      FROM scenes s
      JOIN acts a ON a.id = s.act_id
      JOIN story_locations sl ON sl.id = s.story_location_id
      LEFT JOIN shooting_locations sh ON sh.id = s.planned_shooting_location_id
      WHERE s.id IN ($marks) AND s.deleted_at IS NULL
      ORDER BY s.scene_number ASC
    ''', ids);
    final result = <Scene>[];
    for (final row in rows) {
      final id = row['id'] as int;
      result.add(
        Scene.fromMap(
          row,
          characters: await _sceneCharacters(id),
          resources: await _sceneResources(id),
        ),
      );
    }
    return result;
  }

  Future<Scene> createScene(int projectId, Map<String, dynamic> body) async {
    await _require(projectId, ProjectPermission.manageStory);
    final payload = _scenePayload(projectId, body);
    final characterIds = (body['characterIds'] as List? ?? const [])
        .map((item) => item as int)
        .toList();
    final resourceEntries = _resourceEntries(body['resourceRequirements']);
    await _validateSceneWrite(projectId, payload, characterIds, resourceEntries);
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('scenes', payload);
      await _replaceSceneLinks(txn, id, characterIds, resourceEntries);
      await _recordCreate(
        txn,
        table: 'scenes',
        entityType: 'SCENE',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return sceneById(id);
  }

  Future<Scene> updateScene(
    int projectId,
    int sceneId,
    Map<String, dynamic> body,
  ) async {
    await _require(projectId, ProjectPermission.manageStory);
    final payload = _scenePayload(projectId, body, sceneId: sceneId);
    final characterIds = (body['characterIds'] as List? ?? const [])
        .map((item) => item as int)
        .toList();
    final resourceEntries = _resourceEntries(body['resourceRequirements']);
    await _validateSceneWrite(
      projectId,
      payload,
      characterIds,
      resourceEntries,
      sceneId: sceneId,
    );
    await _db.transaction((txn) async {
      await txn.update(
        'scenes',
        payload,
        where: 'id = ? AND project_id = ?',
        whereArgs: [sceneId, projectId],
      );
      await _replaceSceneLinks(txn, sceneId, characterIds, resourceEntries);
      await _recordUpdate(
        txn,
        table: 'scenes',
        entityType: 'SCENE',
        id: sceneId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return sceneById(sceneId);
  }

  Future<Scene> updateSceneStatus(
    int projectId,
    int sceneId,
    String status,
  ) async {
    await _require(projectId, ProjectPermission.manageStory);
    await _ensureSceneInProject(projectId, sceneId);
    final values = <String, Object?>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (SceneValidators.writingStatuses.contains(status)) {
      if (status == 'DONE') {
        final scene = await sceneById(sceneId);
        if (scene.summary.trim().isEmpty) {
          throw Exception('Cần nhập tóm tắt trước khi hoàn tất cảnh.');
        }
      }
      values['writing_status'] = status;
    } else if (SceneValidators.productionStatuses.contains(status)) {
      final scene = await sceneById(sceneId);
      if (status == 'READY_FOR_PLANNING') {
        final readyError = _readyForPlanningError(scene);
        if (readyError != null) throw Exception(readyError);
      }
      values['production_status'] = status;
    } else {
      throw Exception('Trạng thái cảnh không hợp lệ.');
    }
    await _db.transaction((txn) async {
      await txn.update(
        'scenes',
        values,
        where: 'id = ? AND project_id = ?',
        whereArgs: [sceneId, projectId],
      );
      await _recordUpdate(
        txn,
        table: 'scenes',
        entityType: 'SCENE',
        id: sceneId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return sceneById(sceneId);
  }

  Future<void> deleteScene(int projectId, int sceneId) async {
    await _require(projectId, ProjectPermission.manageStory);
    await _ensureSceneInProject(projectId, sceneId);
    if (await _isOnlineAccount()) {
      await _db.transaction((txn) async {
        await _deleteSceneLinksForIds(txn, [sceneId]);
        await txn.update(
          'scenes',
          {
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND project_id = ?',
          whereArgs: [sceneId, projectId],
        );
        await _recordDelete(
          txn,
          table: 'scenes',
          entityType: 'SCENE',
          id: sceneId,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
      });
      return;
    }
    await _db.transaction((txn) async {
      await _deleteSceneLinksForIds(txn, [sceneId]);
      await txn.delete(
        'scenes',
        where: 'id = ? AND project_id = ?',
        whereArgs: [sceneId, projectId],
      );
    });
  }

  Future<List<PlannerGroup>> planner(int projectId) async {
    final allScenes = await scenes(projectId);
    final groups = <int, List<Scene>>{};
    for (final scene in allScenes) {
      groups.putIfAbsent(scene.storyLocationId, () => []).add(scene);
    }
    final result = groups.entries
        .map(
          (entry) => PlannerGroup(
            locationName: entry.value.first.storyLocationName,
            sceneCount: entry.value.length,
            totalEstimatedMinutes: entry.value.fold(
              0,
              (sum, scene) => sum + scene.estimatedDurationMinutes,
            ),
            scenes: entry.value,
          ),
        )
        .toList();
    result.sort((a, b) => a.locationName.compareTo(b.locationName));
    return result;
  }

  Future<AnalyticsSummary> analyticsSummary(int projectId) async {
    return AnalyticsSummary.fromDashboard(await dashboard(projectId));
  }

  Future<List<CharacterFrequency>> characterFrequency(int projectId) async {
    final rows = await _db.rawQuery('''
      SELECT c.id AS character_id, c.name, COUNT(s.id) AS scene_count
      FROM characters c
      LEFT JOIN scene_characters sc ON sc.character_id = c.id
      LEFT JOIN scenes s ON s.id = sc.scene_id
        AND s.project_id = c.project_id
        AND s.deleted_at IS NULL
      WHERE c.project_id = ? AND c.is_archived = 0 AND c.deleted_at IS NULL
      GROUP BY c.id, c.name
      ORDER BY scene_count DESC, c.name COLLATE NOCASE ASC
    ''', [projectId]);
    return rows.map(CharacterFrequency.fromMap).toList();
  }

  Future<List<ShootingDay>> shootingDays(
    int projectId, {
    DateTime? month,
    DateTime? date,
  }) async {
    final args = <Object?>[projectId];
    var where = 'project_id = ? AND deleted_at IS NULL';
    if (month != null) {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      where += ' AND shooting_date >= ? AND shooting_date < ?';
      args.addAll([_dateOnly(start), _dateOnly(end)]);
    }
    if (date != null) {
      where += ' AND shooting_date = ?';
      args.add(_dateOnly(date));
    }
    final rows = await _db.query(
      'shooting_days',
      where: where,
      whereArgs: args,
      orderBy: 'shooting_date ASC, id ASC',
    );
    final result = <ShootingDay>[];
    for (final row in rows) {
      result.add(await _shootingDayFromRow(row));
    }
    return result;
  }

  Future<ShootingDay> createShootingDay(
    int projectId, {
    required DateTime date,
    required String title,
    int? maxMinutes,
    String? notes,
  }) async {
    await _require(projectId, ProjectPermission.manageSchedule);
    final project = await projectById(projectId);
    final dateError = ShootingDayValidators.dateWithinProject(
      date,
      project.startDate,
    );
    if (dateError != null) throw Exception(dateError);
    final effectiveMaxMinutes = maxMinutes ?? project.maxShootingMinutesPerDay;
    final maxError = ShootingDayValidators.maxMinutes('$effectiveMaxMinutes');
    if (maxError != null) throw Exception(maxError);
    final now = DateTime.now().toIso8601String();
    late final int id;
    await _db.transaction((txn) async {
      id = await txn.insert('shooting_days', {
        'project_id': projectId,
        'shooting_date': _dateOnly(date),
        'title': title.trim().isEmpty ? 'Ngày quay' : title.trim(),
        'status': 'DRAFT',
        'max_minutes': effectiveMaxMinutes,
        'notes': _emptyToNull(notes),
        'created_by': await _currentUserId(),
        'created_at': now,
        'updated_at': now,
      });
      await _recordCreate(
        txn,
        table: 'shooting_days',
        entityType: 'SHOOTING_DAY',
        id: id,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return shootingDayById(id);
  }

  Future<ShootingDay> updateShootingDay(
    int projectId,
    int shootingDayId, {
    required DateTime date,
    required String title,
    int? maxMinutes,
    String? notes,
  }) async {
    await _require(projectId, ProjectPermission.manageSchedule);
    final currentDay = await shootingDayById(shootingDayId);
    if (currentDay.projectId != projectId) {
      throw Exception('Không tìm thấy ngày quay trong dự án này.');
    }
    _ensureShootingDayEditable(currentDay);
    final titleError = FormValidators.requiredTrimmed(title, 'Tiêu đề');
    if (titleError != null) throw Exception(titleError);
    final project = await projectById(projectId);
    final dateError = ShootingDayValidators.dateWithinProject(
      date,
      project.startDate,
    );
    if (dateError != null) throw Exception(dateError);
    final effectiveMaxMinutes = maxMinutes ?? project.maxShootingMinutesPerDay;
    final maxError = ShootingDayValidators.maxMinutes('$effectiveMaxMinutes');
    if (maxError != null) throw Exception(maxError);
    if (currentDay.totalMinutes > effectiveMaxMinutes) {
      throw Exception(
          'Số phút tối đa không được nhỏ hơn tổng thời lượng cảnh.');
    }
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      final updated = await txn.update(
        'shooting_days',
        {
          'shooting_date': _dateOnly(date),
          'title': title.trim(),
          'max_minutes': effectiveMaxMinutes,
          'notes': _emptyToNull(notes),
          'updated_at': now,
        },
        where: 'id = ? AND project_id = ?',
        whereArgs: [shootingDayId, projectId],
      );
      if (updated == 0) {
        throw Exception('Không tìm thấy ngày quay trong dự án này.');
      }
      await _recordUpdate(
        txn,
        table: 'shooting_days',
        entityType: 'SHOOTING_DAY',
        id: shootingDayId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
    return shootingDayById(shootingDayId);
  }

  Future<ShootingDay> shootingDayById(int id) async {
    final rows = await _db.query(
      'shooting_days',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Không tìm thấy ngày quay.');
    return _shootingDayFromRow(rows.single);
  }

  Future<void> addSceneToShootingDay(
    int projectId,
    int shootingDayId,
    int sceneId, {
    String? plannedStartTime,
    String? plannedEndTime,
  }) async {
    await _require(projectId, ProjectPermission.manageSchedule);
    final day = await shootingDayById(shootingDayId);
    if (day.projectId != projectId) {
      throw Exception('Không tìm thấy ngày quay trong dự án này.');
    }
    _ensureShootingDayEditable(day);
    final timeError =
        FormValidators.timeOrder(plannedStartTime, plannedEndTime);
    if (timeError != null) throw Exception(timeError);
    final scene = await sceneById(sceneId);
    if (scene.projectId != projectId) {
      throw Exception('Không tìm thấy cảnh trong dự án này.');
    }
    if (scene.productionStatus != 'READY_FOR_PLANNING') {
      throw Exception('Chỉ có thể thêm cảnh sẵn sàng và chưa lên lịch.');
    }
    final readyError = _readyForPlanningError(scene);
    if (readyError != null) throw Exception(readyError);
    if (day.totalMinutes + scene.estimatedDurationMinutes > day.maxMinutes) {
      throw Exception('Tổng thời lượng vượt quá giới hạn ngày quay.');
    }
    final resourceError = _resourceAvailabilityErrorForDay(day, scene);
    if (resourceError != null) throw Exception(resourceError);
    final duplicate = await _activeScheduleCount(sceneId);
    if (duplicate > 0) throw Exception('Cảnh này đã được lên lịch.');
    final count = await _count(
      'shooting_day_scenes',
      'shooting_day_id = ?',
      [shootingDayId],
    );
    await _db.transaction((txn) async {
      await txn.insert('shooting_day_scenes', {
        'shooting_day_id': shootingDayId,
        'scene_id': sceneId,
        'sequence_order': count + 1,
        'planned_start_time': plannedStartTime,
        'planned_end_time': plannedEndTime,
      });
      await txn.update(
        'scenes',
        {
          'production_status': 'SCHEDULED',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sceneId],
      );
      await _recordUpdate(
        txn,
        table: 'scenes',
        entityType: 'SCENE',
        id: sceneId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
      await _recordUpdate(
        txn,
        table: 'shooting_days',
        entityType: 'SHOOTING_DAY',
        id: shootingDayId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
  }

  Future<void> removeSceneFromShootingDay(
    int projectId,
    int shootingDayId,
    int sceneId,
  ) async {
    await _require(projectId, ProjectPermission.manageSchedule);
    final day = await shootingDayById(shootingDayId);
    if (day.projectId != projectId) {
      throw Exception('Không tìm thấy ngày quay trong dự án này.');
    }
    _ensureShootingDayEditable(day);
    await _db.transaction((txn) async {
      await txn.delete(
        'shooting_day_scenes',
        where: 'shooting_day_id = ? AND scene_id = ?',
        whereArgs: [shootingDayId, sceneId],
      );
      await txn.update(
        'scenes',
        {
          'production_status': 'READY_FOR_PLANNING',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sceneId],
      );
      await _recordUpdate(
        txn,
        table: 'scenes',
        entityType: 'SCENE',
        id: sceneId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
      await _recordUpdate(
        txn,
        table: 'shooting_days',
        entityType: 'SHOOTING_DAY',
        id: shootingDayId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
  }

  Future<void> reorderShootingDayScenes(
    int projectId,
    int shootingDayId,
    List<int> sceneIds,
  ) async {
    await _require(projectId, ProjectPermission.manageSchedule);
    final day = await shootingDayById(shootingDayId);
    if (day.projectId != projectId) {
      throw Exception('Không tìm thấy ngày quay trong dự án này.');
    }
    _ensureShootingDayEditable(day);
    await _db.transaction((txn) async {
      for (var index = 0; index < sceneIds.length; index++) {
        await txn.update(
          'shooting_day_scenes',
          {'sequence_order': -(index + 1)},
          where: 'shooting_day_id = ? AND scene_id = ?',
          whereArgs: [shootingDayId, sceneIds[index]],
        );
      }
      for (var index = 0; index < sceneIds.length; index++) {
        await txn.update(
          'shooting_day_scenes',
          {
            'sequence_order': index + 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'shooting_day_id = ? AND scene_id = ?',
          whereArgs: [shootingDayId, sceneIds[index]],
        );
      }
      await _recordUpdate(
        txn,
        table: 'shooting_days',
        entityType: 'SHOOTING_DAY',
        id: shootingDayId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
  }

  Future<void> updateShootingDaySceneTime(
    int projectId,
    int shootingDayId,
    int sceneId, {
    String? plannedStartTime,
    String? plannedEndTime,
  }) async {
    await _require(projectId, ProjectPermission.manageSchedule);
    final day = await shootingDayById(shootingDayId);
    if (day.projectId != projectId) {
      throw Exception('Không tìm thấy ngày quay trong dự án này.');
    }
    _ensureShootingDayEditable(day);
    final timeError =
        FormValidators.timeOrder(plannedStartTime, plannedEndTime);
    if (timeError != null) throw Exception(timeError);
    await _db.transaction((txn) async {
      await txn.update(
        'shooting_day_scenes',
        {
          'planned_start_time': _emptyToNull(plannedStartTime),
          'planned_end_time': _emptyToNull(plannedEndTime),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'shooting_day_id = ? AND scene_id = ?',
        whereArgs: [shootingDayId, sceneId],
      );
      await _recordUpdate(
        txn,
        table: 'shooting_days',
        entityType: 'SHOOTING_DAY',
        id: shootingDayId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
    });
  }

  Future<void> updateShootingDayStatus(
    int projectId,
    int shootingDayId,
    String status,
  ) async {
    final permission = status == 'CONFIRMED'
        ? ProjectPermission.confirmSchedule
        : ProjectPermission.manageSchedule;
    await _require(projectId, permission);
    final currentDay = await shootingDayById(shootingDayId);
    if (currentDay.projectId != projectId) {
      throw Exception('Không tìm thấy ngày quay trong dự án này.');
    }
    if (currentDay.status == 'COMPLETED' && status != 'COMPLETED') {
      throw Exception('Không thể sửa ngày quay đã hoàn tất.');
    }
    if (status == 'CONFIRMED') {
      final days = await shootingDays(projectId);
      final conflicts = _conflictService.detect(
        shootingDays: days,
        scenesById: {
          for (final day in days)
            for (final item in day.scenes) item.scene.id: item.scene,
        },
        userCanConfirm: await _permissionService.can(
          projectId,
          await _currentUserId(),
          ProjectPermission.confirmSchedule,
        ),
      );
      if (conflicts.any((item) => item.blocking)) {
        throw Exception(
            'Hãy giải quyết xung đột lịch quay trước khi xác nhận.');
      }
    }
    final sceneStatus = switch (status) {
      'IN_PROGRESS' => 'SHOOTING',
      'COMPLETED' => 'SHOT',
      'CANCELLED' => 'READY_FOR_PLANNING',
      _ => 'SCHEDULED',
    };
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.update(
        'shooting_days',
        {
          'status': status,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [shootingDayId],
      );
      await _recordUpdate(
        txn,
        table: 'shooting_days',
        entityType: 'SHOOTING_DAY',
        id: shootingDayId,
        projectId: projectId,
        dependencyGroup: 'project:$projectId',
      );
      await txn.rawUpdate('''
        UPDATE scenes
        SET production_status = ?, updated_at = ?
        WHERE id IN (
          SELECT scene_id FROM shooting_day_scenes WHERE shooting_day_id = ?
        )
      ''', [sceneStatus, now, shootingDayId]);
    });
  }

  Future<List<String>> generateSuggestedSchedule(
    int projectId, {
    required DateTime startDate,
  }) async {
    await _require(projectId, ProjectPermission.manageSchedule);
    final project = await projectById(projectId);
    final ready = await scenes(
      projectId,
      productionStatus: 'READY_FOR_PLANNING',
      unscheduledOnly: true,
    );
    final plan = _optimizer.generate(
      project: project,
      readyScenes: ready,
      startDate: startDate,
    );
    final now = DateTime.now().toIso8601String();
    final userId = await _currentUserId();
    await _db.transaction((txn) async {
      for (final day in plan.days) {
        final dayId = await txn.insert('shooting_days', {
          'project_id': projectId,
          'shooting_date': _dateOnly(day.date),
          'title': day.title,
          'status': 'DRAFT',
          'max_minutes': day.maxMinutes,
          'notes': 'Generated suggested schedule',
          'created_by': userId,
          'created_at': now,
          'updated_at': now,
        });
        await _recordCreate(
          txn,
          table: 'shooting_days',
          entityType: 'SHOOTING_DAY',
          id: dayId,
          projectId: projectId,
          dependencyGroup: 'project:$projectId',
        );
        for (final draftScene in day.scenes) {
          await txn.insert('shooting_day_scenes', {
            'shooting_day_id': dayId,
            'scene_id': draftScene.scene.id,
            'sequence_order': draftScene.sequenceOrder,
            'planned_start_time': draftScene.plannedStartTime,
            'planned_end_time': draftScene.plannedEndTime,
          });
          await txn.update(
            'scenes',
            {
              'production_status': 'SCHEDULED',
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [draftScene.scene.id],
          );
          await _recordUpdate(
            txn,
            table: 'scenes',
            entityType: 'SCENE',
            id: draftScene.scene.id,
            projectId: projectId,
            dependencyGroup: 'project:$projectId',
          );
        }
      }
    });
    return plan.warnings;
  }

  Future<List<ScheduleConflict>> scheduleConflicts(int projectId) async {
    final days = await shootingDays(projectId);
    final scenesList = await scenes(projectId);
    return _conflictService.detect(
      shootingDays: days,
      scenesById: {for (final scene in scenesList) scene.id: scene},
      userCanConfirm: await _permissionService.can(
        projectId,
        await _currentUserId(),
        ProjectPermission.confirmSchedule,
      ),
    );
  }

  Future<Uint8List> exportPdf(int projectId) async {
    await _require(projectId, ProjectPermission.exportProject);
    return _pdfExportService.buildProjectPdf(
      project: await projectById(projectId),
      dashboard: await dashboard(projectId),
      acts: await acts(projectId),
      scenes: await scenes(projectId),
      characters: await characters(projectId),
      storyLocations: await storyLocations(projectId),
      shootingLocations: await shootingLocations(projectId),
      resources: await resources(projectId),
      shootingDays: await shootingDays(projectId),
    );
  }

  Future<ProjectMember> _memberByUser(int projectId, int userId) async {
    final rows = await _db.rawQuery('''
      SELECT pm.*, u.full_name, u.email
      FROM project_members pm
      JOIN users u ON u.id = pm.user_id
      WHERE pm.project_id = ? AND pm.user_id = ?
      LIMIT 1
    ''', [projectId, userId]);
    if (rows.isEmpty || rows.single['deleted_at'] != null) {
      throw Exception('Không tìm thấy thành viên dự án.');
    }
    return ProjectMember.fromMap(rows.single);
  }

  Future<int> _ownerCount(int projectId) async {
    return Sqflite.firstIntValue(await _db.rawQuery(
          '''
          SELECT COUNT(*)
          FROM project_members
          WHERE project_id = ? AND role = 'OWNER' AND deleted_at IS NULL
          ''',
          [projectId],
        )) ??
        0;
  }

  String _normalizeEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized);
    if (!valid) throw Exception('Email thành viên không hợp lệ.');
    return normalized;
  }

  String _normalizeMemberRole(String role, {bool creating = false}) {
    final normalized = role.trim().toUpperCase();
    const roles = {
      'OWNER',
      'SCREENWRITER',
      'PRODUCER',
      'ASSISTANT_DIRECTOR',
      'CREW',
      'VIEWER',
    };
    if (!roles.contains(normalized)) {
      throw Exception('Vai trò thành viên không hợp lệ.');
    }
    if (creating && normalized == 'OWNER') {
      throw Exception('Không thêm OWNER bằng màn thành viên.');
    }
    return normalized;
  }

  Future<int> _ensureLocalUser(
    DatabaseExecutor executor, {
    required String email,
    required String fullName,
  }) async {
    final rows = await executor.query(
      'users',
      columns: ['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.single['id'] as int;
    return executor.insert('users', {
      'full_name': fullName.trim().isEmpty ? email : fullName.trim(),
      'email': email,
      'password_hash': 'invited-member',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> _ensureMemberLocalUuid(
    DatabaseExecutor executor,
    int projectId,
    int userId,
  ) async {
    final rows = await executor.query(
      'project_members',
      columns: ['local_uuid'],
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Không tìm thấy thành viên để ghi metadata đồng bộ.');
    }
    final existing = rows.single['local_uuid'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final localUuid = generateUuid();
    await executor.update(
      'project_members',
      {'local_uuid': localUuid},
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
    );
    return localUuid;
  }

  Future<void> _markMemberChanged(
    DatabaseExecutor executor, {
    required int projectId,
    required int userId,
    required SyncOperationType operation,
  }) async {
    final mode = await _usageMode();
    final accountId = await _accountId();
    final localUuid = await _ensureMemberLocalUuid(executor, projectId, userId);
    final rows = await executor.query(
      'project_members',
      columns: ['sync_status', 'local_version'],
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
      limit: 1,
    );
    final currentStatus = EntitySyncStatusCodec.fromDb(
      rows.isEmpty ? null : rows.single['sync_status'] as String?,
    );
    final currentVersion =
        rows.isEmpty ? 0 : rows.single['local_version'] as int? ?? 0;
    final nextStatus = mode == AppUsageMode.offlineGuest
        ? EntitySyncStatus.localOnly
        : switch (operation) {
            SyncOperationType.create => EntitySyncStatus.pendingCreate,
            SyncOperationType.update =>
              currentStatus == EntitySyncStatus.pendingCreate
                  ? EntitySyncStatus.pendingCreate
                  : EntitySyncStatus.pendingUpdate,
            SyncOperationType.delete => EntitySyncStatus.pendingDelete,
            SyncOperationType.uploadFile => EntitySyncStatus.pendingUpdate,
          };
    await executor.update(
      'project_members',
      {
        'workspace_type':
            mode == AppUsageMode.offlineGuest ? 'LOCAL_GUEST' : 'CLOUD_ACCOUNT',
        'owner_account_id': mode == AppUsageMode.offlineGuest ? null : accountId,
        'sync_status': nextStatus.dbValue,
        'local_version': currentVersion + 1,
        'sync_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
    );
    if (mode == AppUsageMode.offlineGuest) return;
    await _syncQueueRepository.enqueueWithExecutor(
      executor,
      entityType: 'PROJECT_MEMBER',
      entityId: localUuid,
      operation: operation,
      payload: await _projectMemberSyncPayload(
        executor,
        projectId: projectId,
        userId: userId,
      ),
      accountId: accountId,
      projectId: projectId,
      dependencyGroup: 'project:$projectId',
    );
  }

  Future<Map<String, Object?>> _projectMemberSyncPayload(
    DatabaseExecutor executor, {
    required int projectId,
    required int userId,
  }) async {
    final rows = await executor.rawQuery('''
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

  Map<String, Object?> _characterPayload(
    int projectId,
    Map<String, dynamic> body, {
    int? characterId,
  }) {
    final name = body['name']?.toString().trim() ?? '';
    final nameError = CharacterValidators.name(name);
    if (nameError != null) throw Exception(nameError);
    final role = body['roleType']?.toString() ?? 'SUPPORT';
    final roleError = CharacterValidators.roleType(role);
    if (roleError != null) throw Exception(roleError);
    final now = DateTime.now().toIso8601String();
    return {
      'project_id': projectId,
      'name': name,
      'role_type': role,
      'psychological_description':
          _emptyToNull(body['psychologicalDescription']) ??
              _emptyToNull(body['description']),
      'appearance_description': _emptyToNull(body['appearanceDescription']),
      if (body.containsKey('imagePath'))
        'image_path': _emptyToNull(body['imagePath']),
      if (characterId == null) 'is_archived': 0,
      if (characterId == null) 'created_at': now,
      'updated_at': now,
    };
  }

  Map<String, Object?> _shootingLocationPayload(
    int projectId,
    Map<String, dynamic> body, {
    bool creating = true,
  }) {
    final name = body['name']?.toString().trim() ?? '';
    final address = body['address']?.toString().trim() ?? '';
    final nameError = LocationValidators.shootingLocationName(name);
    final addressError = LocationValidators.shootingAddress(address);
    final latError = FormValidators.optionalLatitude(
      body['latitude']?.toString(),
      body['longitude']?.toString(),
    );
    final lngError = FormValidators.optionalLongitude(
      body['longitude']?.toString(),
      body['latitude']?.toString(),
    );
    final phoneError = FormValidators.optionalPhone(
      body['contactPhone']?.toString(),
    );
    final timeError = FormValidators.timeOrder(
      body['availableFromTime']?.toString(),
      body['availableToTime']?.toString(),
    );
    for (final error in [
      nameError,
      addressError,
      latError,
      lngError,
      phoneError,
      timeError
    ]) {
      if (error != null) throw Exception(error);
    }
    return {
      'project_id': projectId,
      'name': name,
      'address': address,
      'province_city': _emptyToNull(body['provinceCity']),
      'district': _emptyToNull(body['district']),
      'latitude': double.tryParse(body['latitude']?.toString() ?? ''),
      'longitude': double.tryParse(body['longitude']?.toString() ?? ''),
      'contact_name': _emptyToNull(body['contactName']),
      'contact_phone': _emptyToNull(body['contactPhone']),
      'supports_interior': body['supportsInterior'] == false ? 0 : 1,
      'supports_exterior': body['supportsExterior'] == false ? 0 : 1,
      'available_from_time': _emptyToNull(body['availableFromTime']),
      'available_to_time': _emptyToNull(body['availableToTime']),
      'notes': _emptyToNull(body['notes']),
      'image_path': _emptyToNull(body['imagePath']),
      if (creating) 'is_active': 1,
    };
  }

  Map<String, Object?> _resourcePayload(
    int projectId,
    Map<String, dynamic> body, {
    bool creating = true,
  }) {
    final name = body['name']?.toString().trim() ?? '';
    final type = body['resourceType']?.toString() ?? 'OTHER';
    final quantity = _intOrNull(body['quantityTotal']) ?? 0;
    for (final error in [
      ResourceValidators.name(name),
      ResourceValidators.type(type),
      quantity <= 0 ? 'Quantity must be greater than 0' : null,
    ]) {
      if (error != null) throw Exception(error);
    }
    return {
      'project_id': projectId,
      'name': name,
      'resource_type': type,
      'quantity_total': quantity,
      'unit': _emptyToNull(body['unit']),
      'status': _emptyToNull(body['status']) ?? 'AVAILABLE',
      'image_path': _emptyToNull(body['imagePath']),
      'notes': _emptyToNull(body['notes']),
      if (creating) 'is_archived': 0,
    };
  }

  Map<String, Object?> _scenePayload(
    int projectId,
    Map<String, dynamic> body, {
    int? sceneId,
  }) {
    final number = _intOrNull(body['sceneNumber']) ?? 0;
    final title = _emptyToNull(body['title']);
    final summary = body['summary']?.toString().trim() ?? '';
    final estimatedDuration = _intOrNull(
          body['estimatedDurationMinutes'] ?? body['estimatedMinutes'],
        ) ??
        1;
    for (final error in [
      number <= 0 ? 'Số cảnh phải lớn hơn 0' : null,
      SceneValidators.titleOrSummary(title, summary),
      SceneValidators.settingType(body['settingType']?.toString() ?? 'INT'),
      SceneValidators.timeOfDay(body['timeOfDay']?.toString() ?? 'DAY'),
      SceneValidators.estimatedDuration('$estimatedDuration'),
    ]) {
      if (error != null) throw Exception(error);
    }
    final now = DateTime.now().toIso8601String();
    return {
      'project_id': projectId,
      'act_id': _intOrNull(body['actId']),
      'story_location_id':
          _intOrNull(body['storyLocationId'] ?? body['locationId']),
      'planned_shooting_location_id':
          _intOrNull(body['plannedShootingLocationId']),
      'scene_number': number,
      'title': title,
      'summary': summary,
      'setting_type': body['settingType'] ?? 'INT',
      'time_of_day': body['timeOfDay'] ?? 'DAY',
      'estimated_duration_minutes': estimatedDuration,
      'priority': _intOrNull(body['priority']) ?? 3,
      'writing_status': body['writingStatus'] ?? body['status'] ?? 'TODO',
      'production_status': body['productionStatus'] ?? 'NOT_READY',
      if (sceneId == null) 'created_at': now,
      'updated_at': now,
    };
  }

  Future<void> _ensureCharacterNameAvailable(
    int projectId,
    String? rawName, {
    int? exceptId,
  }) async {
    final name = rawName?.trim() ?? '';
    final nameError = CharacterValidators.name(name);
    if (nameError != null) throw Exception(nameError);
    final args = <Object?>[projectId, name];
    var where = 'project_id = ? AND is_archived = 0 AND deleted_at IS NULL '
        'AND name = ? COLLATE NOCASE';
    if (exceptId != null) {
      where += ' AND id <> ?';
      args.add(exceptId);
    }
    if (await _count('characters', where, args) > 0) {
      throw Exception('Tên nhân vật đã tồn tại trong dự án.');
    }
  }

  Future<void> _ensureStoryLocationNameAvailable(
    int projectId,
    String? rawName, {
    int? exceptId,
  }) async {
    final name = rawName?.trim() ?? '';
    final nameError = LocationValidators.storyLocationName(name);
    if (nameError != null) throw Exception(nameError);
    final args = <Object?>[projectId, name];
    var where = 'project_id = ? AND is_archived = 0 AND deleted_at IS NULL '
        'AND name = ? COLLATE NOCASE';
    if (exceptId != null) {
      where += ' AND id <> ?';
      args.add(exceptId);
    }
    if (await _count('story_locations', where, args) > 0) {
      throw Exception('Tên bối cảnh truyện đã tồn tại trong dự án.');
    }
  }

  Future<void> _validateSceneWrite(
    int projectId,
    Map<String, Object?> payload,
    List<int> characterIds,
    List<Map<String, Object?>> resourceEntries, {
    int? sceneId,
  }) async {
    if (sceneId != null) {
      await _ensureSceneInProject(projectId, sceneId);
    }

    final actId = payload['act_id'] as int?;
    if (actId == null ||
        await _count(
              'acts',
              'id = ? AND project_id = ? AND deleted_at IS NULL',
              [actId, projectId],
            ) ==
            0) {
      throw Exception('Cần chọn hồi.');
    }

    final storyLocationId = payload['story_location_id'] as int?;
    if (storyLocationId == null ||
        await _count(
              'story_locations',
              'id = ? AND project_id = ? AND is_archived = 0 '
                  'AND deleted_at IS NULL',
              [storyLocationId, projectId],
            ) ==
            0) {
      throw Exception('Cần chọn bối cảnh truyện.');
    }

    final sceneNumber = payload['scene_number'] as int;
    final duplicateArgs = <Object?>[projectId, sceneNumber];
    var duplicateWhere =
        'project_id = ? AND scene_number = ? AND deleted_at IS NULL';
    if (sceneId != null) {
      duplicateWhere += ' AND id <> ?';
      duplicateArgs.add(sceneId);
    }
    if (await _count('scenes', duplicateWhere, duplicateArgs) > 0) {
      throw Exception('Số cảnh đã tồn tại trong dự án.');
    }

    final uniqueCharacters = characterIds.toSet();
    if (uniqueCharacters.length != characterIds.length) {
      throw Exception('Khong them cung mot nhan vat hai lan.');
    }
    for (final characterId in uniqueCharacters) {
      await _ensureCharacterInProject(projectId, characterId);
    }

    final writingStatus = payload['writing_status']?.toString();
    if (!SceneValidators.writingStatuses.contains(writingStatus)) {
      throw Exception('Trạng thái viết không hợp lệ.');
    }
    if (writingStatus == 'DONE' &&
        (payload['summary']?.toString().trim().isEmpty ?? true)) {
      throw Exception('Cần nhập tóm tắt trước khi hoàn tất cảnh.');
    }
    final productionStatus = payload['production_status']?.toString();
    if (!SceneValidators.productionStatuses.contains(productionStatus)) {
      throw Exception('Trạng thái sản xuất không hợp lệ.');
    }

    Map<String, Object?>? shootingLocation;
    final shootingLocationId = payload['planned_shooting_location_id'] as int?;
    if (shootingLocationId != null) {
      final rows = await _db.query(
        'shooting_locations',
        where: 'id = ? AND project_id = ? AND is_active = 1 '
            'AND deleted_at IS NULL',
        whereArgs: [shootingLocationId, projectId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw Exception('Địa điểm quay không khả dụng.');
      }
      shootingLocation = rows.single;
    }

    final settingType = payload['setting_type']?.toString();
    if (settingType == 'INT' &&
        shootingLocation != null &&
        shootingLocation['supports_interior'] == 0) {
      throw Exception('Địa điểm quay đã chọn không hỗ trợ cảnh nội cảnh.');
    }
    if (settingType == 'EXT' &&
        shootingLocation != null &&
        shootingLocation['supports_exterior'] == 0) {
      throw Exception('Địa điểm quay đã chọn không hỗ trợ cảnh ngoại cảnh.');
    }

    final seenResources = <int>{};
    for (final entry in resourceEntries) {
      final resourceId = entry['resource_id'] as int?;
      if (resourceId == null) {
        throw Exception('Lựa chọn tài nguyên không hợp lệ.');
      }
      if (!seenResources.add(resourceId)) {
        throw Exception('Không thêm cùng một tài nguyên hai lần.');
      }
      final requiredQuantity = entry['required_quantity'] as int? ?? 1;
      final rows = await _db.query(
        'film_resources',
        where: 'id = ? AND project_id = ? AND is_archived = 0 '
            'AND deleted_at IS NULL',
        whereArgs: [resourceId, projectId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw Exception('Tài nguyên không khả dụng.');
      }
      final totalQuantity = rows.single['quantity_total'] as int;
      final quantityError = ResourceValidators.requiredQuantity(
        requiredQuantity: requiredQuantity,
        totalQuantity: totalQuantity,
      );
      if (quantityError != null) throw Exception(quantityError);
    }

    if (productionStatus == 'READY_FOR_PLANNING' &&
        shootingLocationId == null) {
      throw Exception('Hãy gán địa điểm quay trước khi lên lịch cảnh này.');
    }
  }

  Future<void> _replaceSceneLinks(
    Transaction txn,
    int sceneId,
    List<int> characterIds,
    List<Map<String, Object?>> resourceEntries,
  ) async {
    await txn.delete('scene_characters',
        where: 'scene_id = ?', whereArgs: [sceneId]);
    for (final characterId in characterIds.toSet()) {
      await txn.insert('scene_characters', {
        'scene_id': sceneId,
        'character_id': characterId,
      });
    }
    await txn
        .delete('scene_resources', where: 'scene_id = ?', whereArgs: [sceneId]);
    for (final entry in resourceEntries) {
      await txn.insert('scene_resources', {
        'scene_id': sceneId,
        ...entry,
      });
    }
  }

  Future<void> _deleteSceneLinksForIds(
    Transaction txn,
    List<int> sceneIds,
  ) async {
    if (sceneIds.isEmpty) return;
    final marks = List.filled(sceneIds.length, '?').join(',');
    await txn.delete(
      'shooting_day_scenes',
      where: 'scene_id IN ($marks)',
      whereArgs: sceneIds,
    );
    await txn.delete(
      'scene_characters',
      where: 'scene_id IN ($marks)',
      whereArgs: sceneIds,
    );
    await txn.delete(
      'scene_resources',
      where: 'scene_id IN ($marks)',
      whereArgs: sceneIds,
    );
  }

  List<Map<String, Object?>> _resourceEntries(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (entry) => {
            'resource_id': _intOrNull(entry['resourceId']),
            'required_quantity': _intOrNull(entry['requiredQuantity']) ?? 1,
            'notes': _emptyToNull(entry['notes']),
          },
        )
        .toList();
  }

  Future<List<SceneCharacter>> _sceneCharacters(int sceneId) async {
    final rows = await _db.rawQuery('''
      SELECT c.*
      FROM characters c
      JOIN scene_characters sc ON sc.character_id = c.id
      WHERE sc.scene_id = ?
        AND c.is_archived = 0
        AND c.deleted_at IS NULL
      ORDER BY c.name COLLATE NOCASE ASC
    ''', [sceneId]);
    return rows.map(SceneCharacter.fromMap).toList();
  }

  Future<List<SceneResource>> _sceneResources(int sceneId) async {
    final rows = await _db.rawQuery('''
      SELECT r.*, sr.required_quantity, sr.notes AS scene_resource_notes
      FROM film_resources r
      JOIN scene_resources sr ON sr.resource_id = r.id
      WHERE sr.scene_id = ?
      ORDER BY r.name COLLATE NOCASE ASC
    ''', [sceneId]);
    return rows.map(SceneResource.fromMap).toList();
  }

  Future<ShootingDay> _shootingDayFromRow(Map<String, Object?> row) async {
    final dayId = row['id'] as int;
    final links = await _db.query(
      'shooting_day_scenes',
      where: 'shooting_day_id = ?',
      whereArgs: [dayId],
      orderBy: 'sequence_order ASC',
    );
    final sceneMap = {
      for (final scene in await scenesByIds(
        links.map((link) => link['scene_id'] as int).toList(),
      ))
        scene.id: scene,
    };
    final dayScenes = links
        .where((link) => sceneMap.containsKey(link['scene_id']))
        .map((link) =>
            ShootingDayScene.fromMap(link, scene: sceneMap[link['scene_id']]!))
        .toList()
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return ShootingDay.fromMap(row, scenes: dayScenes);
  }

  void _ensureShootingDayEditable(ShootingDay day) {
    if (day.status == 'COMPLETED') {
      throw Exception('Không thể sửa ngày quay đã hoàn tất.');
    }
    if (day.status == 'CANCELLED') {
      throw Exception('Không thể sửa ngày quay đã hủy.');
    }
  }

  Future<int> _activeScheduleCount(int sceneId) async {
    final rows = await _db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM shooting_day_scenes sds
      JOIN shooting_days sd ON sd.id = sds.shooting_day_id
      WHERE sds.scene_id = ? AND sd.status IN ('DRAFT','CONFIRMED','IN_PROGRESS')
    ''', [sceneId]);
    return rows.single['count'] as int? ?? 0;
  }

  Future<int> _count(String table, String where, List<Object?> args) async {
    final value = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM $table WHERE $where', args),
    );
    return value ?? 0;
  }

  Future<void> _ensureRowInProject({
    required String table,
    required int id,
    required int projectId,
    required String label,
    bool includeDeleted = false,
    String? activeWhere,
  }) async {
    var where = 'id = ? AND project_id = ?';
    final args = <Object?>[id, projectId];
    if (!includeDeleted) where += ' AND deleted_at IS NULL';
    if (activeWhere != null && activeWhere.isNotEmpty) {
      where += ' AND ($activeWhere)';
    }
    if (await _count(table, where, args) == 0) {
      throw Exception('Khong tim thay $label trong du an nay.');
    }
  }

  Future<void> _ensureCharacterInProject(
    int projectId,
    int characterId, {
    bool includeArchived = false,
  }) {
    return _ensureRowInProject(
      table: 'characters',
      id: characterId,
      projectId: projectId,
      label: 'nhan vat',
      activeWhere: includeArchived ? null : 'is_archived = 0',
    );
  }

  Future<void> _ensureSceneInProject(int projectId, int sceneId) {
    return _ensureRowInProject(
      table: 'scenes',
      id: sceneId,
      projectId: projectId,
      label: 'canh',
    );
  }

  Future<double> _projectProgress(int projectId) async {
    final total = await _count(
      'scenes',
      'project_id = ? AND deleted_at IS NULL',
      [projectId],
    );
    if (total == 0) return 0;
    final done = await _count(
      'scenes',
      'project_id = ? AND writing_status = ? AND deleted_at IS NULL',
      [projectId, 'DONE'],
    );
    return (done / total) * 100;
  }

  String? _readyForPlanningError(Scene scene) {
    if (scene.plannedShootingLocationId == null) {
      return 'Hãy gán địa điểm quay trước khi lên lịch cảnh này.';
    }
    if (scene.estimatedDurationMinutes <= 0) {
      return 'Cần nhập thời lượng ước tính trước khi lên lịch.';
    }
    if (scene.summary.trim().isEmpty && (scene.title ?? '').trim().isEmpty) {
      return 'Cần nhập tiêu đề hoặc tóm tắt trước khi lên lịch.';
    }
    if (scene.settingType == 'INT' && !scene.shootingLocationSupportsInterior) {
      return 'Địa điểm quay không hỗ trợ cảnh nội cảnh.';
    }
    if (scene.settingType == 'EXT' && !scene.shootingLocationSupportsExterior) {
      return 'Địa điểm quay không hỗ trợ cảnh ngoại cảnh.';
    }
    for (final resource in scene.resources) {
      if (resource.requiredQuantity > resource.quantityTotal) {
        return 'Số lượng tài nguyên cần dùng vượt quá số lượng hiện có.';
      }
    }
    return null;
  }

  String? _resourceAvailabilityErrorForDay(ShootingDay day, Scene addedScene) {
    final usage = <int, int>{};
    for (final item in day.scenes) {
      for (final resource in item.scene.resources) {
        usage.update(
          resource.id,
          (value) => value + resource.requiredQuantity,
          ifAbsent: () => resource.requiredQuantity,
        );
      }
    }
    for (final resource in addedScene.resources) {
      final required = (usage[resource.id] ?? 0) + resource.requiredQuantity;
      if (required > resource.quantityTotal) {
        return 'Thêm cảnh này cần $required ${resource.name}, '
            'nhưng chỉ có ${resource.quantityTotal}.';
      }
    }
    return null;
  }

  String _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .split('T')
        .first;
  }

  DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String? _emptyToNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
