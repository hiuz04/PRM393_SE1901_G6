import 'package:sqflite/sqflite.dart';

import '../../models/cinex_models.dart';
import '../storage/session_storage.dart';
import '../storage/token_storage.dart';
import '../sync/sync_models.dart';

class SessionManager {
  SessionManager(this._db, this._sessionStorage, this._tokenStorage);

  static const guestEmail = 'local.guest@cinex.local';
  static const guestName = 'Offline Guest';

  final Database _db;
  final SessionStorage _sessionStorage;
  final TokenStorage _tokenStorage;

  Future<AppUser?> currentUser() async {
    final userId = await _sessionStorage.readCurrentUserId();
    if (userId == null) return null;
    final rows = await _db.query(
      'users',
      where: 'id = ? AND is_active = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await logout();
      return null;
    }
    return AppUser.fromMap(rows.single);
  }

  Future<AppUsageMode> currentMode() => _sessionStorage.readUsageMode();

  Future<int> startOfflineGuest() async {
    final guestId = await _ensureGuestUser();
    await _tokenStorage.clear();
    await _sessionStorage.writeCurrentUserId(guestId);
    await _sessionStorage.writeUsageMode(AppUsageMode.offlineGuest);
    await _sessionStorage.writeCurrentAccountId(null);
    return guestId;
  }

  Future<void> startOnlineAccount({
    required AppUser user,
    required String accessToken,
  }) async {
    await _upsertUser(user);
    await _tokenStorage.writeToken(accessToken);
    await _sessionStorage.writeCurrentUserId(user.id);
    await _sessionStorage.writeUsageMode(AppUsageMode.onlineAccount);
    await _sessionStorage.writeCurrentAccountId('${user.id}');
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    await _sessionStorage.clear();
  }

  Future<int> _ensureGuestUser() async {
    final rows = await _db.query(
      'users',
      columns: ['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [guestEmail],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.single['id'] as int;
    final now = DateTime.now().toIso8601String();
    return _db.insert(
      'users',
      {
        'full_name': guestName,
        'email': guestEmail,
        'password_hash': 'offline-guest-disabled',
        'is_active': 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _upsertUser(AppUser user) async {
    final now = DateTime.now().toIso8601String();
    final values = {
      'id': user.id,
      'full_name': user.fullName,
      'email': user.email,
      'password_hash': 'online-account-secure-token',
      'is_active': user.isActive ? 1 : 0,
      'created_at': user.createdAt?.toIso8601String() ?? now,
    };
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'users',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [user.id],
        limit: 1,
      );
      if (rows.isEmpty) {
        await txn.insert(
          'users',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        return;
      }
      await txn.update(
        'users',
        {
          'full_name': user.fullName,
          'email': user.email,
          'password_hash': 'online-account-secure-token',
          'is_active': user.isActive ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [user.id],
      );
    });
  }
}
