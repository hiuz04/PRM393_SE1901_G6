import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/act_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/project_provider.dart';
import 'screens/project/project_launcher_screen.dart';

void main() {
  runApp(const CineXApp());
}

class CineXApp extends StatelessWidget {
  const CineXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => ActProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
        title: 'Cine-X',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB3261E)),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
          appBarTheme: const AppBarTheme(centerTitle: false),
        ),
        home: const ProjectLauncherScreen(),
      ),
    );
  }
}
