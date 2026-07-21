import 'package:sqflite/sqflite.dart';

import '../core/auth/session_manager.dart';
import '../core/storage/session_storage.dart';
import '../core/storage/token_storage.dart';
import '../core/utils/hash_utils.dart';
import '../data/remote/remote_data_source.dart';
import '../models/cinex_models.dart';

class AuthRepository {
  AuthRepository(
    this._db,
    this._sessionStorage, {
    RemoteDataSource? remoteDataSource,
    SessionManager? sessionManager,
    TokenStorage tokenStorage = const SecureTokenStorage(),
  })  : _remoteDataSource = remoteDataSource,
        _sessionManager = sessionManager ??
            SessionManager(_db, _sessionStorage, tokenStorage);

  final Database _db;
  final SessionStorage _sessionStorage;
  final RemoteDataSource? _remoteDataSource;
  final SessionManager _sessionManager;

  Future<AuthSession> login(String email, String password) async {
    final remote = _remoteDataSource;
    if (remote != null) {
      final session = await remote.login(email.trim(), password);
      await _sessionManager.startOnlineAccount(
        user: session.user,
        accessToken: session.accessToken,
      );
      return session;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final rows = await _db.query(
      'users',
      where: 'email = ? COLLATE NOCASE AND is_active = 1',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Email hoặc mật khẩu không đúng.');
    }
    final row = rows.single;
    if (!PasswordHasher.verify(password, row['password_hash'] as String)) {
      throw Exception('Email hoặc mật khẩu không đúng.');
    }
    final user = AppUser.fromMap(row);
    await _sessionStorage.writeCurrentUserId(user.id);
    return AuthSession(
      accessToken: 'local-${user.id}',
      tokenType: 'Local',
      expiresIn: 0,
      user: user,
    );
  }

  Future<AuthSession> register(
    String displayName,
    String email,
    String password,
    String confirmPassword,
  ) async {
    final remote = _remoteDataSource;
    if (remote != null) {
      final session = await remote.register(
        displayName.trim(),
        email.trim(),
        password,
        confirmPassword,
      );
      await _sessionManager.startOnlineAccount(
        user: session.user,
        accessToken: session.accessToken,
      );
      return session;
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (displayName.trim().isEmpty) {
      throw Exception('Tên hiển thị là bắt buộc.');
    }
    if (!normalizedEmail.contains('@')) {
      throw Exception('Email không hợp lệ.');
    }
    if (password.length < 8 ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      throw Exception(
          'Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.');
    }
    if (password != confirmPassword) {
      throw Exception('Mật khẩu xác nhận không khớp.');
    }
    final existing = await _db.query(
      'users',
      columns: ['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('Email này đã có tài khoản.');
    }
    final now = DateTime.now().toIso8601String();
    final id = await _db.insert(
      'users',
      {
        'full_name': displayName.trim(),
        'email': normalizedEmail,
        'password_hash': PasswordHasher.hash(password),
        'is_active': 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final user = AppUser(
      id: id,
      email: normalizedEmail,
      fullName: displayName.trim(),
      createdAt: DateTime.parse(now),
    );
    await _sessionStorage.writeCurrentUserId(user.id);
    return AuthSession(
      accessToken: 'local-${user.id}',
      tokenType: 'Local',
      expiresIn: 0,
      user: user,
    );
  }

  Future<AppUser> useOfflineGuest() async {
    final guestId = await _sessionManager.startOfflineGuest();
    final rows = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [guestId],
      limit: 1,
    );
    return AppUser.fromMap(rows.single);
  }

  Future<AppUser?> currentUser() async {
    return _sessionManager.currentUser();
  }

  Future<AppUser> me() async {
    final user = await currentUser();
    if (user == null) {
      throw Exception('Không có phiên cục bộ đang hoạt động.');
    }
    return user;
  }

  Future<void> logout() => _sessionManager.logout();
}
