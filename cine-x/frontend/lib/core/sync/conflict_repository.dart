import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../utils/uuid.dart';
import 'sync_models.dart';

class SyncConflictRecord {
  const SyncConflictRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localPayload,
    required this.remotePayload,
    required this.conflictingFields,
    required this.createdAt,
    this.accountId,
    this.projectId,
    this.basePayload,
    this.localUpdatedAt,
    this.remoteUpdatedAt,
    this.resolution,
    this.resolvedAt,
  });

  final String id;
  final String? accountId;
  final String? projectId;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> remotePayload;
  final Map<String, dynamic>? basePayload;
  final List<String> conflictingFields;
  final DateTime? localUpdatedAt;
  final DateTime? remoteUpdatedAt;
  final DateTime createdAt;
  final String? resolution;
  final DateTime? resolvedAt;

  factory SyncConflictRecord.fromMap(Map<String, Object?> map) {
    return SyncConflictRecord(
      id: map['id'] as String,
      accountId: map['account_id'] as String?,
      projectId: map['project_id'] as String?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      localPayload: jsonDecode(map['local_payload_json'] as String? ?? '{}')
          as Map<String, dynamic>,
      remotePayload: jsonDecode(map['remote_payload_json'] as String? ?? '{}')
          as Map<String, dynamic>,
      basePayload: map['base_payload_json'] == null
          ? null
          : jsonDecode(map['base_payload_json'] as String)
              as Map<String, dynamic>,
      conflictingFields:
          (jsonDecode(map['conflicting_fields_json'] as String? ?? '[]')
                  as List)
              .map((item) => item.toString())
              .toList(),
      localUpdatedAt: _dateTimeOrNull(map['local_updated_at']),
      remoteUpdatedAt: _dateTimeOrNull(map['remote_updated_at']),
      createdAt: DateTime.parse(map['created_at'] as String),
      resolution: map['resolution'] as String?,
      resolvedAt: _dateTimeOrNull(map['resolved_at']),
    );
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class ConflictRepository {
  ConflictRepository(this._db);

  final Database _db;

  Future<void> create({
    required String entityType,
    required String entityId,
    required Map<String, Object?> localPayload,
    required Map<String, Object?> remotePayload,
    required List<String> conflictingFields,
    String? accountId,
    int? projectId,
    Map<String, Object?>? basePayload,
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert(
      'sync_conflicts',
      {
        'id': generateUuid(),
        'account_id': accountId,
        'project_id': projectId?.toString(),
        'entity_type': entityType,
        'entity_id': entityId,
        'local_payload_json': jsonEncode(localPayload),
        'remote_payload_json': jsonEncode(remotePayload),
        'base_payload_json':
            basePayload == null ? null : jsonEncode(basePayload),
        'conflicting_fields_json': jsonEncode(conflictingFields),
        'local_updated_at': localUpdatedAt?.toIso8601String(),
        'remote_updated_at': remoteUpdatedAt?.toIso8601String(),
        'created_at': now,
        'resolution': null,
        'resolved_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncConflictRecord>> unresolved({int? projectId}) async {
    final rows = await _db.query(
      'sync_conflicts',
      where: projectId == null
          ? 'resolution IS NULL'
          : 'resolution IS NULL AND project_id = ?',
      whereArgs: projectId == null ? null : [projectId.toString()],
      orderBy: 'created_at DESC',
    );
    return rows.map(SyncConflictRecord.fromMap).toList();
  }

  Future<int> unresolvedCount({int? projectId}) async {
    final rows = await _db.rawQuery(
      projectId == null
          ? '''
            SELECT COUNT(*) AS count
            FROM sync_conflicts
            WHERE resolution IS NULL
          '''
          : '''
            SELECT COUNT(*) AS count
            FROM sync_conflicts
            WHERE resolution IS NULL AND project_id = ?
          ''',
      projectId == null ? null : [projectId.toString()],
    );
    return rows.single['count'] as int? ?? 0;
  }

  Future<void> markResolved(
    String conflictId,
    ConflictResolution resolution,
  ) async {
    await _db.update(
      'sync_conflicts',
      {
        'resolution': resolution.dbValue,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [conflictId],
    );
  }
}
