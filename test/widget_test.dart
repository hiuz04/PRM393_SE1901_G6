import 'package:cine_x/data/local/app_database.dart';
import 'package:cine_x/data/repositories/act_repository.dart';
import 'package:cine_x/data/repositories/project_repository.dart';
import 'package:cine_x/models/act.dart';
import 'package:cine_x/models/dashboard_summary.dart';
import 'package:cine_x/models/project.dart';
import 'package:cine_x/screens/project/project_detail_screen.dart';
import 'package:cine_x/screens/project/project_launcher_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cine_x/providers/act_provider.dart';
import 'package:cine_x/providers/dashboard_provider.dart';
import 'package:cine_x/providers/project_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  tearDownAll(AppDatabase.instance.close);

  test('dashboard progress is zero when there are no scenes', () {
    const summary = DashboardSummary(
      totalCharacters: 3,
      totalScenes: 0,
      doneScenes: 0,
    );

    expect(summary.progress, 0);
    expect(summary.progressPercentage, 0);
  });

  test('database opens and repositories support Module 1 flows', () async {
    await _resetDatabase();
    addTearDown(_resetDatabase);

    final database = await AppDatabase.instance.database;
    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.first.values.single, 1);

    final tables = await database.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name IN (
          'Projects',
          'Acts',
          'Characters',
          'Locations',
          'Scenes',
          'Scene_Characters'
        )
      ''');
    expect(
      tables.map((row) => row['name']),
      containsAll(<String>[
        'Projects',
        'Acts',
        'Characters',
        'Locations',
        'Scenes',
        'Scene_Characters',
      ]),
    );

    final projectRepository = ProjectRepository();
    final actRepository = ActRepository();

    final projectId = await projectRepository.insertProject(
      Project(
        title: 'Night Draft',
        genre: 'Thriller',
        description: 'A test project.',
        createdAt: DateTime(2026, 7, 10).toIso8601String(),
      ),
    );

    final createdProject = await projectRepository.getProjectById(projectId);
    expect(createdProject?.title, 'Night Draft');

    await projectRepository.updateProject(
      createdProject!.copyWith(title: 'Night Draft Revised'),
    );
    expect(
      (await projectRepository.getProjectById(projectId))?.title,
      'Night Draft Revised',
    );

    final secondActId = await actRepository.insertAct(
      Act(projectId: projectId, title: 'Middle', sequenceOrder: 2),
    );
    final firstActId = await actRepository.insertAct(
      Act(projectId: projectId, title: 'Opening', sequenceOrder: 1),
    );

    final orderedActs = await actRepository.getActsByProject(projectId);
    expect(orderedActs.map((act) => act.sequenceOrder), [1, 2]);

    await actRepository.updateAct(
      orderedActs.first.copyWith(title: 'Opening Revised', sequenceOrder: 3),
    );
    expect(await actRepository.getNextSequenceOrder(projectId), 4);

    final deletedActId = await actRepository.insertAct(
      Act(projectId: projectId, title: 'Deleted beat', sequenceOrder: 4),
    );
    expect((await actRepository.getActsByProject(projectId)).length, 3);
    await actRepository.deleteAct(deletedActId);
    expect((await actRepository.getActsByProject(projectId)).length, 2);

    final characterId = await database.insert('Characters', {
      'project_id': projectId,
      'name': 'Lead',
      'role_type': 'Hero',
    });
    final locationId = await database.insert('Locations', {
      'project_id': projectId,
      'name': 'Studio',
    });
    final doneSceneId = await database.insert('Scenes', {
      'act_id': secondActId,
      'location_id': locationId,
      'scene_number': 1,
      'summary': 'Finished scene',
      'status': 'DONE',
    });
    await database.insert('Scenes', {
      'act_id': firstActId,
      'location_id': locationId,
      'scene_number': 2,
      'summary': 'Todo scene',
      'status': 'TODO',
    });
    await database.insert('Scene_Characters', {
      'scene_id': doneSceneId,
      'character_id': characterId,
    });

    final summary = await projectRepository.getDashboardSummary(projectId);
    expect(summary.totalCharacters, 1);
    expect(summary.totalScenes, 2);
    expect(summary.doneScenes, 1);
    expect(summary.progressPercentage, 50);

    await projectRepository.deleteProject(projectId);
    expect(await _countRows(database, 'Projects'), 0);
    expect(await _countRows(database, 'Acts'), 0);
    expect(await _countRows(database, 'Scenes'), 0);
    expect(await _countRows(database, 'Characters'), 0);
    expect(await _countRows(database, 'Locations'), 0);
    expect(await _countRows(database, 'Scene_Characters'), 0);
  });

  testWidgets('project launcher renders on a small screen', (tester) async {
    await _setSmallScreen(tester);
    final project = Project(
      id: 1,
      title: 'A Very Compact Screen Project',
      genre: 'Drama',
      description: 'A layout check for the launcher card.',
      createdAt: DateTime(2026, 7, 10).toIso8601String(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ProjectProvider(
              repository: _FakeProjectRepository(projects: [project]),
            ),
          ),
        ],
        child: const MaterialApp(home: ProjectLauncherScreen()),
      ),
    );
    await _pumpAsyncFrames(tester);

    expect(find.byType(ProjectLauncherScreen), findsOneWidget);
    expect(find.text('Cine-X Projects'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('project detail dashboard fits on a small screen', (
    tester,
  ) async {
    await _setSmallScreen(tester);
    final project = Project(
      id: 1,
      title: 'Compact Project',
      genre: 'Drama',
      description: 'Small screen layout check.',
      createdAt: DateTime(2026, 7, 10).toIso8601String(),
    );
    const summary = DashboardSummary(
      totalCharacters: 0,
      totalScenes: 0,
      doneScenes: 0,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ProjectProvider(
              repository: _FakeProjectRepository(
                projects: [project],
                selectedProject: project,
                summary: summary,
              ),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => ActProvider(repository: _FakeActRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => DashboardProvider(
              repository: _FakeProjectRepository(summary: summary),
            ),
          ),
        ],
        child: const MaterialApp(home: ProjectDetailScreen(projectId: 1)),
      ),
    );
    await _pumpAsyncFrames(tester);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _resetDatabase() async {
  await AppDatabase.instance.close();
  final databasePath = await getDatabasesPath();
  await deleteDatabase(join(databasePath, 'cine_x.db'));
}

Future<int> _countRows(Database database, String tableName) async {
  final rows = await database.rawQuery('SELECT COUNT(*) FROM $tableName');
  return Sqflite.firstIntValue(rows) ?? 0;
}

Future<void> _setSmallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpAsyncFrames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository({
    List<Project>? projects,
    Project? selectedProject,
    DashboardSummary? summary,
  }) : _projects = projects ?? const [],
       _selectedProject = selectedProject,
       _summary = summary ?? DashboardSummary.empty();

  final List<Project> _projects;
  final Project? _selectedProject;
  final DashboardSummary _summary;

  @override
  Future<List<Project>> getAllProjects() async => _projects;

  @override
  Future<Project?> getProjectById(int id) async {
    if (_selectedProject?.id == id) {
      return _selectedProject;
    }

    for (final project in _projects) {
      if (project.id == id) {
        return project;
      }
    }

    return null;
  }

  @override
  Future<DashboardSummary> getDashboardSummary(int projectId) async => _summary;
}

class _FakeActRepository extends ActRepository {
  _FakeActRepository({List<Act>? acts}) : _acts = acts ?? const [];

  final List<Act> _acts;

  @override
  Future<List<Act>> getActsByProject(int projectId) async => _acts;

  @override
  Future<int> getNextSequenceOrder(int projectId) async => _acts.length + 1;
}
