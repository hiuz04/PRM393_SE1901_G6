import 'package:sqflite/sqflite.dart';

import '../../models/act.dart';
import '../local/app_database.dart';

class ActRepository {
  ActRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Act>> getActsByProject(int projectId) async {
    final db = await _database.database;
    final maps = await db.query(
      'Acts',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sequence_order ASC, id ASC',
    );

    return maps.map(Act.fromMap).toList();
  }

  Future<int> insertAct(Act act) async {
    final db = await _database.database;
    return db.insert('Acts', act.toMap());
  }

  Future<int> updateAct(Act act) async {
    final id = act.id;
    if (id == null) {
      throw ArgumentError('Act id is required for updates.');
    }

    final db = await _database.database;
    return db.update('Acts', act.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAct(int id) async {
    final db = await _database.database;
    return db.delete('Acts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getNextSequenceOrder(int projectId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sequence_order), 0) + 1 FROM Acts WHERE project_id = ?',
      [projectId],
    );

    return Sqflite.firstIntValue(rows) ?? 1;
  }
}
