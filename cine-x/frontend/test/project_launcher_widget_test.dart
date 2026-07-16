import 'package:cine_x/features/auth/presentation/providers/auth_provider.dart';
import 'package:cine_x/features/projects/presentation/providers/project_provider.dart';
import 'package:cine_x/features/projects/presentation/screens/project_launcher_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Project launcher shows empty state', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider.empty()..initializing = false,
          ),
          ChangeNotifierProvider(create: (_) => ProjectProvider.empty()),
        ],
        child: const MaterialApp(home: ProjectLauncherScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No projects yet'), findsOneWidget);
  });
}
