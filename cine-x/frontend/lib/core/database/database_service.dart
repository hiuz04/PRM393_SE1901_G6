import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/hash_utils.dart';
import '../utils/uuid.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const databaseVersion = 5;

  Database? _database;

  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('DatabaseService.initialize() must be called first.');
    }
    return db;
  }

  Future<void> initialize({Database? databaseForTest}) async {
    if (_database != null) return;
    if (databaseForTest != null) {
      _database = databaseForTest;
      return;
    }

    if (!kIsWeb && _isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbDir = await getDatabasesPath();
    if (!kIsWeb) {
      await Directory(dbDir).create(recursive: true);
    }
    final dbPath = p.join(dbDir, 'cine_x_offline.db');
    final database = await openDatabase(
      dbPath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    await _seedDemoData(database);
    _database = database;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  bool get _isDesktop {
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _create(Database db, int version) async {
    await db.transaction((txn) async {
      await _createSchema(txn);
      await txn.insert('app_metadata', {
        'key': 'schema_version',
        'value': '$databaseVersion',
      });
      await txn.insert('app_metadata', {
        'key': 'legacy_json_imported',
        'value': '1',
      });
    });
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      await _createSchema(txn);
      await txn.insert(
        'app_metadata',
        {'key': 'schema_version', 'value': '$newVersion'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _createSchema(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        title TEXT NOT NULL,
        genre TEXT,
        description TEXT,
        start_date TEXT,
        end_date TEXT,
        max_shooting_minutes_per_day INTEGER NOT NULL DEFAULT 480,
        poster_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS project_members (
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role TEXT NOT NULL CHECK(role IN ('OWNER', 'SCREENWRITER', 'PRODUCER')),
        PRIMARY KEY(project_id, user_id)
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS acts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT,
        sequence_order INTEGER NOT NULL,
        UNIQUE(project_id, sequence_order)
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        role_type TEXT NOT NULL,
        psychological_description TEXT,
        appearance_description TEXT,
        image_path TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS story_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS shooting_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        province_city TEXT,
        district TEXT,
        latitude REAL,
        longitude REAL,
        contact_name TEXT,
        contact_phone TEXT,
        supports_interior INTEGER NOT NULL DEFAULT 1,
        supports_exterior INTEGER NOT NULL DEFAULT 1,
        available_from_time TEXT,
        available_to_time TEXT,
        notes TEXT,
        image_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS film_resources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        resource_type TEXT NOT NULL CHECK(
          resource_type IN ('PROP', 'COSTUME', 'EQUIPMENT', 'VEHICLE', 'OTHER')
        ),
        quantity_total INTEGER NOT NULL,
        unit TEXT,
        status TEXT,
        image_path TEXT,
        notes TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS scenes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        act_id INTEGER NOT NULL REFERENCES acts(id) ON DELETE RESTRICT,
        story_location_id INTEGER NOT NULL REFERENCES story_locations(id) ON DELETE RESTRICT,
        planned_shooting_location_id INTEGER REFERENCES shooting_locations(id) ON DELETE SET NULL,
        scene_number INTEGER NOT NULL,
        title TEXT,
        summary TEXT,
        setting_type TEXT NOT NULL CHECK(setting_type IN ('INT', 'EXT')),
        time_of_day TEXT NOT NULL CHECK(time_of_day IN ('DAY', 'NIGHT')),
        estimated_duration_minutes INTEGER NOT NULL DEFAULT 1,
        priority INTEGER NOT NULL DEFAULT 3,
        writing_status TEXT NOT NULL CHECK(writing_status IN ('TODO', 'IN_PROGRESS', 'DONE')),
        production_status TEXT NOT NULL CHECK(
          production_status IN (
            'NOT_READY',
            'READY_FOR_PLANNING',
            'SCHEDULED',
            'SHOOTING',
            'SHOT',
            'CANCELLED'
          )
        ),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(project_id, scene_number)
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS scene_characters (
        scene_id INTEGER NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
        character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE RESTRICT,
        PRIMARY KEY(scene_id, character_id)
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS scene_resources (
        scene_id INTEGER NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
        resource_id INTEGER NOT NULL REFERENCES film_resources(id) ON DELETE RESTRICT,
        required_quantity INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        PRIMARY KEY(scene_id, resource_id)
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS shooting_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        shooting_date TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN (
          'DRAFT',
          'CONFIRMED',
          'IN_PROGRESS',
          'COMPLETED',
          'CANCELLED'
        )),
        max_minutes INTEGER NOT NULL,
        notes TEXT,
        created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS shooting_day_scenes (
        shooting_day_id INTEGER NOT NULL REFERENCES shooting_days(id) ON DELETE CASCADE,
        scene_id INTEGER NOT NULL REFERENCES scenes(id) ON DELETE RESTRICT,
        sequence_order INTEGER NOT NULL,
        planned_start_time TEXT,
        planned_end_time TEXT,
        notes TEXT,
        PRIMARY KEY(shooting_day_id, scene_id),
        UNIQUE(shooting_day_id, sequence_order)
      )
    ''');

    await _ensureLocalFirstSchema(txn);
    await _createIndexes(txn);
  }

  Future<void> _ensureLocalFirstSchema(Transaction txn) async {
    const syncableTables = [
      'projects',
      'project_members',
      'acts',
      'characters',
      'story_locations',
      'shooting_locations',
      'film_resources',
      'scenes',
      'scene_characters',
      'scene_resources',
      'shooting_days',
      'shooting_day_scenes',
    ];

    for (final table in syncableTables) {
      await _ensureSyncMetadataColumns(txn, table);
      await _backfillLocalUuids(txn, table);
      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_local_uuid '
        'ON $table(local_uuid) WHERE local_uuid IS NOT NULL',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_${table}_sync_status '
        'ON $table(sync_status)',
      );
    }

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS file_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
        entity_table TEXT,
        entity_id INTEGER,
        local_path TEXT NOT NULL,
        remote_url TEXT,
        checksum TEXT,
        upload_status TEXT NOT NULL DEFAULT 'LOCAL_ONLY',
        mime_type TEXT,
        file_size INTEGER,
        created_at TEXT,
        updated_at TEXT,
        local_uuid TEXT,
        remote_id TEXT,
        workspace_type TEXT NOT NULL DEFAULT 'LOCAL_GUEST',
        owner_account_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL_ONLY',
        local_version INTEGER NOT NULL DEFAULT 0,
        server_version INTEGER,
        last_synced_at TEXT,
        deleted_at TEXT,
        sync_error TEXT
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        account_id TEXT,
        project_id TEXT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL CHECK(operation IN (
          'CREATE',
          'UPDATE',
          'DELETE',
          'UPLOAD_FILE'
        )),
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

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        account_id TEXT NOT NULL,
        project_id TEXT,
        pull_cursor TEXT,
        last_synced_at TEXT,
        last_push_at TEXT,
        last_pull_at TEXT,
        last_error TEXT,
        PRIMARY KEY(account_id, project_id)
      )
    ''');

    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id TEXT PRIMARY KEY,
        account_id TEXT,
        project_id TEXT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_payload_json TEXT NOT NULL,
        remote_payload_json TEXT NOT NULL,
        base_payload_json TEXT,
        conflicting_fields_json TEXT NOT NULL,
        local_updated_at TEXT,
        remote_updated_at TEXT,
        created_at TEXT NOT NULL,
        resolution TEXT CHECK(resolution IN ('KEEP_LOCAL', 'KEEP_REMOTE', 'MERGED')),
        resolved_at TEXT
      )
    ''');

    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity '
      'ON sync_queue(entity_type, entity_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_account '
      'ON sync_queue(account_id, project_id, created_at)',
    );
    await txn.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_account_global '
      'ON sync_state(account_id) WHERE project_id IS NULL',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_unresolved '
      'ON sync_conflicts(project_id, entity_type) WHERE resolution IS NULL',
    );
    await txn.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_file_assets_local_uuid '
      'ON file_assets(local_uuid) WHERE local_uuid IS NOT NULL',
    );
  }

  Future<void> _ensureSyncMetadataColumns(
    Transaction txn,
    String table,
  ) async {
    await _ensureColumn(txn, table, 'local_uuid', 'TEXT');
    await _ensureColumn(txn, table, 'remote_id', 'TEXT');
    await _ensureColumn(
      txn,
      table,
      'workspace_type',
      "TEXT NOT NULL DEFAULT 'LOCAL_GUEST'",
    );
    await _ensureColumn(txn, table, 'owner_account_id', 'TEXT');
    await _ensureColumn(
      txn,
      table,
      'sync_status',
      "TEXT NOT NULL DEFAULT 'LOCAL_ONLY'",
    );
    await _ensureColumn(
      txn,
      table,
      'local_version',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(txn, table, 'server_version', 'INTEGER');
    await _ensureColumn(txn, table, 'last_synced_at', 'TEXT');
    await _ensureColumn(txn, table, 'deleted_at', 'TEXT');
    await _ensureColumn(txn, table, 'sync_error', 'TEXT');
    await _ensureColumn(txn, table, 'created_at', 'TEXT');
    await _ensureColumn(txn, table, 'updated_at', 'TEXT');
  }

  Future<void> _ensureColumn(
    Transaction txn,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await txn.rawQuery('PRAGMA table_info($table)');
    if (rows.any((row) => row['name'] == column)) return;
    await txn.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _backfillLocalUuids(Transaction txn, String table) async {
    final rows = await txn.rawQuery(
      'SELECT rowid AS row_id FROM $table '
      "WHERE local_uuid IS NULL OR local_uuid = ''",
    );
    for (final row in rows) {
      await txn.update(
        table,
        {'local_uuid': generateUuid()},
        where: 'rowid = ?',
        whereArgs: [row['row_id']],
      );
    }
  }

  Future<void> _createIndexes(Transaction txn) async {
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_owner ON projects(owner_user_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_members_project ON project_members(project_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_members_user ON project_members(user_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_acts_project ON acts(project_id)',
    );
    await txn.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_characters_name_active '
      'ON characters(project_id, name COLLATE NOCASE) WHERE is_archived = 0',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_characters_project ON characters(project_id)',
    );
    await txn.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_story_locations_name_active '
      'ON story_locations(project_id, name COLLATE NOCASE) WHERE is_archived = 0',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_story_locations_project ON story_locations(project_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_shooting_locations_project ON shooting_locations(project_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_resources_project ON film_resources(project_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_scenes_project ON scenes(project_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_scenes_act ON scenes(act_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_scenes_story_location ON scenes(story_location_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_scenes_shooting_location ON scenes(planned_shooting_location_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_scenes_production_status ON scenes(production_status)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_scene_characters_character ON scene_characters(character_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_scene_resources_resource ON scene_resources(resource_id)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_shooting_days_project_date ON shooting_days(project_id, shooting_date)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_shooting_day_scenes_scene ON shooting_day_scenes(scene_id)',
    );
  }

  Future<void> _seedDemoData(Database db) async {
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final passwordHash = PasswordHasher.hash('CineX@123');
      final ownerId = await _ensureDemoUser(
        txn,
        email: 'owner@cinex.local',
        fullName: 'Chủ dự án CINE-X',
        passwordHash: passwordHash,
        now: now,
      );
      final writerId = await _ensureDemoUser(
        txn,
        email: 'writer@cinex.local',
        fullName: 'Biên kịch Demo',
        passwordHash: passwordHash,
        now: now,
      );
      final projectId = await _ensureDemoProject(
        txn,
        ownerId: ownerId,
        now: now,
      );

      await _ensureProjectMember(txn, projectId, ownerId, 'OWNER');
      await _ensureProjectMember(txn, projectId, writerId, 'SCREENWRITER');

      final act1Id = await _ensureAct(
        txn,
        projectId: projectId,
        title: 'Hồi 1 - Khởi đầu',
        description: 'Giới thiệu thế giới và xung đột.',
        sequenceOrder: 1,
      );
      final act2Id = await _ensureAct(
        txn,
        projectId: projectId,
        title: 'Hồi 2 - Đối đầu',
        description: 'Các nhân vật bị đẩy vào lựa chọn khó.',
        sequenceOrder: 2,
      );
      await _ensureAct(
        txn,
        projectId: projectId,
        title: 'Hồi 3 - Ánh sáng',
        description: 'Cao trào và kết thúc.',
        sequenceOrder: 3,
      );

      final linhId = await _ensureCharacter(
        txn,
        projectId: projectId,
        name: 'Linh',
        roleType: 'MAIN',
        psychologicalDescription: 'Kỹ sư ánh sáng trẻ tuổi.',
        now: now,
      );
      final minhId = await _ensureCharacter(
        txn,
        projectId: projectId,
        name: 'Minh',
        roleType: 'SUPPORT',
        psychologicalDescription: 'Trợ lý đạo diễn nội tâm.',
        now: now,
      );
      final crowdId = await _ensureCharacter(
        txn,
        projectId: projectId,
        name: 'Đám đông nhà ga',
        roleType: 'CROWD',
        psychologicalDescription: 'Người dân trong thành phố ngầm.',
        now: now,
      );

      final controlRoomId = await _ensureStoryLocation(
        txn,
        projectId: projectId,
        name: 'Phòng điều khiển ngầm',
        description: 'Không gian điều khiển trong lòng đất.',
        notes: 'Ánh đèn xanh, nhiều màn hình.',
      );
      final stationId = await _ensureStoryLocation(
        txn,
        projectId: projectId,
        name: 'Sân ga trên cao',
        description: 'Sân ga lộ thiên giữa thành phố.',
        notes: 'Gió mạnh, biển quảng cáo khổng lồ.',
      );

      final studioId = await _ensureShootingLocation(
        txn,
        projectId: projectId,
        name: 'Studio A - Phòng điều khiển',
        address: '25 Nguyễn Huệ, Quận 1',
        supportsInterior: true,
        supportsExterior: false,
      );
      final backlotId = await _ensureShootingLocation(
        txn,
        projectId: projectId,
        name: 'Bãi dựng Sky Station',
        address: 'Bối cảnh ngoài trời TP Thủ Đức',
        supportsInterior: false,
        supportsExterior: true,
      );

      final cameraId = await _ensureFilmResource(
        txn,
        projectId: projectId,
        name: 'Máy quay A',
        resourceType: 'EQUIPMENT',
        quantityTotal: 1,
        unit: 'bộ',
      );
      final ledId = await _ensureFilmResource(
        txn,
        projectId: projectId,
        name: 'Bộ đèn LED thực tế',
        resourceType: 'EQUIPMENT',
        quantityTotal: 3,
        unit: 'bộ',
      );

      final scene1Id = await _ensureScene(
        txn,
        projectId: projectId,
        actId: act1Id,
        storyLocationId: controlRoomId,
        shootingLocationId: studioId,
        sceneNumber: 1,
        title: 'Tín hiệu đầu tiên',
        summary:
            'Linh phát hiện một nguồn sáng bất thường dưới lòng thành phố.',
        settingType: 'INT',
        timeOfDay: 'NIGHT',
        estimatedMinutes: 8,
        priority: 1,
        writingStatus: 'DONE',
        productionStatus: 'READY_FOR_PLANNING',
        now: now,
      );
      final scene2Id = await _ensureScene(
        txn,
        projectId: projectId,
        actId: act1Id,
        storyLocationId: stationId,
        shootingLocationId: backlotId,
        sceneNumber: 2,
        title: 'Đường ray mất điện',
        summary:
            'Minh đưa Linh qua sân ga để tránh lực lượng truy đuổi.',
        settingType: 'EXT',
        timeOfDay: 'DAY',
        estimatedMinutes: 12,
        priority: 2,
        writingStatus: 'IN_PROGRESS',
        productionStatus: 'READY_FOR_PLANNING',
        now: now,
      );
      final scene3Id = await _ensureScene(
        txn,
        projectId: projectId,
        actId: act2Id,
        storyLocationId: controlRoomId,
        shootingLocationId: null,
        sceneNumber: 3,
        title: 'Cửa sổ bị khóa',
        summary: 'Nhóm phải quyết định có kích hoạt hệ thống hay không.',
        settingType: 'INT',
        timeOfDay: 'NIGHT',
        estimatedMinutes: 15,
        priority: 3,
        writingStatus: 'TODO',
        productionStatus: 'NOT_READY',
        now: now,
      );

      await _ensureSceneCharacter(txn, scene1Id, linhId);
      await _ensureSceneCharacter(txn, scene2Id, linhId);
      await _ensureSceneCharacter(txn, scene2Id, minhId);
      await _ensureSceneCharacter(txn, scene2Id, crowdId);
      await _ensureSceneCharacter(txn, scene3Id, linhId);
      await _ensureSceneCharacter(txn, scene3Id, minhId);

      await _ensureSceneResource(txn, scene1Id, cameraId, 1);
      await _ensureSceneResource(txn, scene1Id, ledId, 2);
      await _ensureSceneResource(txn, scene2Id, cameraId, 1);
    });
  }

  Future<int> _ensureDemoUser(
    Transaction txn, {
    required String email,
    required String fullName,
    required String passwordHash,
    required String now,
  }) async {
    final rows = await txn.query(
      'users',
      columns: ['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) {
      return txn.insert('users', {
        'full_name': fullName,
        'email': email,
        'password_hash': passwordHash,
        'is_active': 1,
        'created_at': now,
      });
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'users',
      {
        'full_name': fullName,
        'password_hash': passwordHash,
        'is_active': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> _ensureDemoProject(
    Transaction txn, {
    required int ownerId,
    required String now,
  }) async {
    final rows = await txn.query(
      'projects',
      columns: ['id'],
      where:
          'owner_user_id = ? AND (title = ? COLLATE NOCASE OR title = ? COLLATE NOCASE)',
      whereArgs: [ownerId, 'Nguoi Giu Anh Sang', 'Người Giữ Ánh Sáng'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return txn.insert('projects', {
        'owner_user_id': ownerId,
        'title': 'Người Giữ Ánh Sáng',
        'genre': 'Chính kịch khoa học viễn tưởng',
        'description': 'Dự án demo cho CINE-X.',
        'start_date': '2026-07-01',
        'end_date': null,
        'max_shooting_minutes_per_day': 480,
        'poster_url': null,
        'created_at': now,
        'updated_at': now,
      });
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'projects',
      {
        'title': 'Người Giữ Ánh Sáng',
        'genre': 'Chính kịch khoa học viễn tưởng',
        'description': 'Dự án demo cho CINE-X.',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> _ensureProjectMember(
    Transaction txn,
    int projectId,
    int userId,
    String role,
  ) async {
    final rows = await txn.query(
      'project_members',
      columns: ['role'],
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await txn.insert('project_members', {
        'project_id': projectId,
        'user_id': userId,
        'role': role,
      });
      return;
    }
    await txn.update(
      'project_members',
      {'role': role},
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
    );
  }

  Future<int> _ensureAct(
    Transaction txn, {
    required int projectId,
    required String title,
    required String description,
    required int sequenceOrder,
  }) async {
    final rows = await txn.query(
      'acts',
      columns: ['id'],
      where: 'project_id = ? AND sequence_order = ?',
      whereArgs: [projectId, sequenceOrder],
      limit: 1,
    );
    if (rows.isEmpty) {
      return txn.insert('acts', {
        'project_id': projectId,
        'title': title,
        'description': description,
        'sequence_order': sequenceOrder,
      });
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'acts',
      {
        'title': title,
        'description': description,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> _ensureCharacter(
    Transaction txn, {
    required int projectId,
    required String name,
    required String roleType,
    required String psychologicalDescription,
    required String now,
  }) async {
    final rows = await txn.query(
      'characters',
      columns: ['id'],
      where: 'project_id = ? AND name = ? COLLATE NOCASE',
      whereArgs: [projectId, name],
      limit: 1,
    );
    final payload = {
      'project_id': projectId,
      'name': name,
      'role_type': roleType,
      'psychological_description': psychologicalDescription,
      'appearance_description': null,
      'image_path': null,
      'is_archived': 0,
      'updated_at': now,
    };
    if (rows.isEmpty) {
      return txn.insert('characters', {
        ...payload,
        'created_at': now,
      });
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'characters',
      payload,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> _ensureStoryLocation(
    Transaction txn, {
    required int projectId,
    required String name,
    required String description,
    required String notes,
  }) async {
    final rows = await txn.query(
      'story_locations',
      columns: ['id'],
      where: 'project_id = ? AND name = ? COLLATE NOCASE',
      whereArgs: [projectId, name],
      limit: 1,
    );
    final payload = {
      'project_id': projectId,
      'name': name,
      'description': description,
      'notes': notes,
      'is_archived': 0,
    };
    if (rows.isEmpty) {
      return txn.insert('story_locations', payload);
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'story_locations',
      payload,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> _ensureShootingLocation(
    Transaction txn, {
    required int projectId,
    required String name,
    required String address,
    required bool supportsInterior,
    required bool supportsExterior,
  }) async {
    final rows = await txn.query(
      'shooting_locations',
      columns: ['id'],
      where: 'project_id = ? AND name = ? COLLATE NOCASE',
      whereArgs: [projectId, name],
      limit: 1,
    );
    final payload = {
      'project_id': projectId,
      'name': name,
      'address': address,
      'province_city': 'Thành phố Hồ Chí Minh',
      'district': null,
      'latitude': null,
      'longitude': null,
      'contact_name': 'Nhà sản xuất CINE-X',
      'contact_phone': '0900000000',
      'supports_interior': supportsInterior ? 1 : 0,
      'supports_exterior': supportsExterior ? 1 : 0,
      'available_from_time': '08:00',
      'available_to_time': '18:00',
      'notes': 'Địa điểm quay demo.',
      'image_path': null,
      'is_active': 1,
    };
    if (rows.isEmpty) {
      return txn.insert('shooting_locations', payload);
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'shooting_locations',
      payload,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> _ensureFilmResource(
    Transaction txn, {
    required int projectId,
    required String name,
    required String resourceType,
    required int quantityTotal,
    required String unit,
  }) async {
    final rows = await txn.query(
      'film_resources',
      columns: ['id'],
      where: 'project_id = ? AND name = ? COLLATE NOCASE',
      whereArgs: [projectId, name],
      limit: 1,
    );
    final payload = {
      'project_id': projectId,
      'name': name,
      'resource_type': resourceType,
      'quantity_total': quantityTotal,
      'unit': unit,
      'status': 'AVAILABLE',
      'image_path': null,
      'notes': 'Tài nguyên demo.',
      'is_archived': 0,
    };
    if (rows.isEmpty) {
      return txn.insert('film_resources', payload);
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'film_resources',
      payload,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> _ensureScene(
    Transaction txn, {
    required int projectId,
    required int actId,
    required int storyLocationId,
    required int? shootingLocationId,
    required int sceneNumber,
    required String title,
    required String summary,
    required String settingType,
    required String timeOfDay,
    required int estimatedMinutes,
    required int priority,
    required String writingStatus,
    required String productionStatus,
    required String now,
  }) async {
    final rows = await txn.query(
      'scenes',
      columns: ['id'],
      where: 'project_id = ? AND scene_number = ?',
      whereArgs: [projectId, sceneNumber],
      limit: 1,
    );
    final payload = {
      'project_id': projectId,
      'act_id': actId,
      'story_location_id': storyLocationId,
      'planned_shooting_location_id': shootingLocationId,
      'scene_number': sceneNumber,
      'title': title,
      'summary': summary,
      'setting_type': settingType,
      'time_of_day': timeOfDay,
      'estimated_duration_minutes': estimatedMinutes,
      'priority': priority,
      'writing_status': writingStatus,
      'production_status': productionStatus,
      'updated_at': now,
    };
    if (rows.isEmpty) {
      return txn.insert('scenes', {
        ...payload,
        'created_at': now,
      });
    }
    final id = rows.single['id'] as int;
    await txn.update(
      'scenes',
      payload,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> _ensureSceneCharacter(
    Transaction txn,
    int sceneId,
    int characterId,
  ) async {
    await txn.insert(
      'scene_characters',
      {
        'scene_id': sceneId,
        'character_id': characterId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _ensureSceneResource(
    Transaction txn,
    int sceneId,
    int resourceId,
    int requiredQuantity,
  ) async {
    await txn.insert(
      'scene_resources',
      {
        'scene_id': sceneId,
        'resource_id': resourceId,
        'required_quantity': requiredQuantity,
        'notes': null,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
