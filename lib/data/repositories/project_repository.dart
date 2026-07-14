import 'package:sqflite/sqflite.dart';

import '../../models/dashboard_summary.dart';
import '../../models/project.dart';
import '../local/app_database.dart';

class ProjectRepository {
  ProjectRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Project>> getAllProjects() async {
    final db = await _database.database;
    final maps = await db.query(
      'Projects',
      orderBy: 'datetime(created_at) DESC, id DESC',
    );

    return maps.map(Project.fromMap).toList();
  }

  Future<Project?> getProjectById(int id) async {
    final db = await _database.database;
    final maps = await db.query(
      'Projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Project.fromMap(maps.first);
  }

  Future<int> insertProject(Project project) async {
    final db = await _database.database;
    return db.insert('Projects', project.toMap());
  }

  Future<int> updateProject(Project project) async {
    final id = project.id;
    if (id == null) {
      throw ArgumentError('Project id is required for updates.');
    }

    final db = await _database.database;
    return db.update(
      'Projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProject(int id) async {
    final db = await _database.database;
    return db.delete('Projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<DashboardSummary> getDashboardSummary(int projectId) async {
    final db = await _database.database;

    final characterRows = await db.rawQuery(
      'SELECT COUNT(*) FROM Characters WHERE project_id = ?',
      [projectId],
    );

    final sceneRows = await db.rawQuery(
      '''
      SELECT COUNT(*)
      FROM Scenes
      INNER JOIN Acts ON Acts.id = Scenes.act_id
      WHERE Acts.project_id = ?
      ''',
      [projectId],
    );

    final doneSceneRows = await db.rawQuery(
      '''
      SELECT COUNT(*)
      FROM Scenes
      INNER JOIN Acts ON Acts.id = Scenes.act_id
      WHERE Acts.project_id = ?
        AND UPPER(COALESCE(Scenes.status, '')) = ?
      ''',
      [projectId, 'DONE'],
    );

    return DashboardSummary(
      totalCharacters: Sqflite.firstIntValue(characterRows) ?? 0,
      totalScenes: Sqflite.firstIntValue(sceneRows) ?? 0,
      doneScenes: Sqflite.firstIntValue(doneSceneRows) ?? 0,
    );
  }
}
