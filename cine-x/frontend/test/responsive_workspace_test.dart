import 'package:cine_x/core/permissions/permission_service.dart';
import 'package:cine_x/core/storage/session_storage.dart';
import 'package:cine_x/models/cinex_models.dart';
import 'package:cine_x/providers/workspace_provider.dart';
import 'package:cine_x/repositories/cinex_repository.dart';
import 'package:cine_x/features/projects/presentation/screens/project_workspace_v2_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  testWidgets('Workspace uses rail on wide layout', (tester) async {
    final db = _FakeDatabase();
    final project = Project(
      id: 1,
      ownerId: 1,
      title: 'CINE-X',
      progressPercent: 0,
    );
    final provider = WorkspaceProvider(
      CineXRepository(
        db,
        MemorySessionStorage(),
        PermissionService(db),
      ),
      project,
    )..dashboard = Dashboard(
        totalActs: 0,
        totalCharacters: 0,
        totalLocations: 0,
        totalScenes: 0,
        todoScenes: 0,
        inProgressScenes: 0,
        doneScenes: 0,
        progressPercent: 0,
      );

    await tester.binding.setSurfaceSize(const Size(1100, 800));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: ProjectWorkspaceScreen(project: project)),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}

class _FakeDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
