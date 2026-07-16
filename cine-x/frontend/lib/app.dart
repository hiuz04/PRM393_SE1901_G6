import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/network/backend_connection_provider.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/session_gate.dart';
import 'features/projects/data/repositories/cinex_repository.dart';
import 'features/projects/presentation/providers/project_provider.dart';

class CineXApp extends StatelessWidget {
  const CineXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>(create: (_) => const SecureTokenStorage()),
        ProxyProvider<TokenStorage, ApiClient>(
          update: (_, storage, previous) =>
              previous ?? ApiClient(AppConfig.apiBaseUrl, storage),
        ),
        ProxyProvider<ApiClient, AuthRepository>(
          update: (_, client, __) => AuthRepository(client),
        ),
        ProxyProvider<ApiClient, CineXRepository>(
          update: (_, client, __) => CineXRepository(client),
        ),
        ChangeNotifierProxyProvider<ApiClient, BackendConnectionProvider>(
          create: (_) => BackendConnectionProvider.empty(),
          update: (_, client, provider) =>
              (provider ?? BackendConnectionProvider.empty())..attach(client),
        ),
        ChangeNotifierProxyProvider2<AuthRepository, TokenStorage,
            AuthProvider>(
          create: (_) => AuthProvider.empty(),
          update: (_, repository, storage, provider) =>
              (provider ?? AuthProvider.empty())..attach(repository, storage),
        ),
        ChangeNotifierProxyProvider<CineXRepository, ProjectProvider>(
          create: (_) => ProjectProvider.empty(),
          update: (_, repository, provider) =>
              (provider ?? ProjectProvider.empty())..attach(repository),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CINE-X',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const SessionGate(),
      ),
    );
  }
}
