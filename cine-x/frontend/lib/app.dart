import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/auth/app_mode_service.dart';
import 'core/auth/session_manager.dart';
import 'core/config/app_config.dart';
import 'core/database/database_service.dart';
import 'core/network/api_client.dart';
import 'core/network/backend_connection_provider.dart';
import 'core/network/connectivity_service.dart';
import 'core/permissions/permission_service.dart';
import 'core/storage/session_storage.dart';
import 'core/storage/token_storage.dart';
import 'core/sync/conflict_repository.dart';
import 'core/sync/sync_coordinator.dart';
import 'core/sync/sync_queue_repository.dart';
import 'core/theme/app_theme.dart';
import 'data/local/local_data_source.dart';
import 'data/remote/remote_data_source.dart';
import 'features/auth/presentation/screens/session_gate.dart';
import 'features/synchronization/presentation/providers/sync_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/cinex_repository.dart';

class CineXApp extends StatelessWidget {
  const CineXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final database = DatabaseService.instance.database;
    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: DatabaseService.instance),
        Provider<SessionStorage>(
          create: (_) => const SharedPreferencesSessionStorage(),
        ),
        Provider<TokenStorage>(
          create: (_) => const SecureTokenStorage(),
        ),
        ProxyProvider<TokenStorage, ApiClient>(
          update: (_, tokenStorage, __) =>
              ApiClient(AppConfig.apiBaseUrl, tokenStorage),
        ),
        ProxyProvider<ApiClient, RemoteDataSource>(
          update: (_, client, __) => ApiRemoteDataSource(client),
        ),
        ProxyProvider<ApiClient, ConnectivityService>(
          update: (_, client, __) => ConnectivityService(client),
        ),
        Provider<PermissionService>(
          create: (_) => PermissionService(database),
        ),
        Provider<LocalDataSource>(
          create: (_) => LocalDataSource(database),
        ),
        Provider<SyncQueueRepository>(
          create: (_) => SyncQueueRepository(database),
        ),
        Provider<ConflictRepository>(
          create: (_) => ConflictRepository(database),
        ),
        ProxyProvider2<SessionStorage, TokenStorage, SessionManager>(
          update: (_, session, tokenStorage, __) =>
              SessionManager(database, session, tokenStorage),
        ),
        ProxyProvider<SessionStorage, AppModeService>(
          update: (_, session, __) => AppModeService(session),
        ),
        ProxyProvider3<SessionStorage, RemoteDataSource, SessionManager,
            AuthRepository>(
          update: (_, session, remote, sessionManager, __) => AuthRepository(
            database,
            session,
            remoteDataSource: remote,
            sessionManager: sessionManager,
          ),
        ),
        ProxyProvider4<SessionStorage, PermissionService, LocalDataSource,
            SyncQueueRepository, CineXRepository>(
          update: (_, session, permissions, local, queue, __) =>
              CineXRepository(
            database,
            session,
            permissions,
            localDataSource: local,
            syncQueueRepository: queue,
          ),
        ),
        ProxyProvider6<SessionStorage, ConnectivityService, RemoteDataSource,
            SyncQueueRepository, ConflictRepository, LocalDataSource,
            SyncCoordinator>(
          update: (
            _,
            session,
            connectivity,
            remote,
            queue,
            conflicts,
            local,
            __,
          ) =>
              SyncCoordinator(
            database: database,
            sessionStorage: session,
            connectivityService: connectivity,
            remoteDataSource: remote,
            queueRepository: queue,
            conflictRepository: conflicts,
            localDataSource: local,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BackendConnectionProvider.local(database),
        ),
        ChangeNotifierProxyProvider<AuthRepository, AuthProvider>(
          create: (_) => AuthProvider.empty(),
          update: (_, repository, provider) =>
              (provider ?? AuthProvider.empty())..attach(repository),
        ),
        ChangeNotifierProxyProvider<CineXRepository, ProjectProvider>(
          create: (_) => ProjectProvider.empty(),
          update: (_, repository, provider) =>
              (provider ?? ProjectProvider.empty())..attach(repository),
        ),
        ChangeNotifierProxyProvider<SyncCoordinator, SyncProvider>(
          create: (_) => SyncProvider.empty(),
          update: (_, coordinator, provider) =>
              (provider ?? SyncProvider.empty())..attach(coordinator),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CINE-X',
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const SessionGate(),
      ),
    );
  }
}
