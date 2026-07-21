import 'package:shared_preferences/shared_preferences.dart';

import '../sync/sync_models.dart';

abstract class SessionStorage {
  Future<int?> readCurrentUserId();

  Future<void> writeCurrentUserId(int userId);

  Future<AppUsageMode> readUsageMode();

  Future<void> writeUsageMode(AppUsageMode mode);

  Future<String?> readCurrentAccountId();

  Future<void> writeCurrentAccountId(String? accountId);

  Future<void> clear();
}

class SharedPreferencesSessionStorage implements SessionStorage {
  const SharedPreferencesSessionStorage();

  static const _currentUserIdKey = 'cinex_current_user_id';
  static const _usageModeKey = 'cinex_usage_mode';
  static const _accountIdKey = 'cinex_current_account_id';

  @override
  Future<int?> readCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentUserIdKey);
  }

  @override
  Future<void> writeCurrentUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserIdKey, userId);
  }

  @override
  Future<AppUsageMode> readUsageMode() async {
    final prefs = await SharedPreferences.getInstance();
    return AppUsageModeCodec.fromStorage(prefs.getString(_usageModeKey));
  }

  @override
  Future<void> writeUsageMode(AppUsageMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usageModeKey, mode.storageValue);
  }

  @override
  Future<String?> readCurrentAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountIdKey);
  }

  @override
  Future<void> writeCurrentAccountId(String? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null || accountId.isEmpty) {
      await prefs.remove(_accountIdKey);
      return;
    }
    await prefs.setString(_accountIdKey, accountId);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
    await prefs.remove(_usageModeKey);
    await prefs.remove(_accountIdKey);
  }
}

class MemorySessionStorage implements SessionStorage {
  int? currentUserId;
  AppUsageMode usageMode = AppUsageMode.offlineGuest;
  String? currentAccountId;

  @override
  Future<int?> readCurrentUserId() async => currentUserId;

  @override
  Future<void> writeCurrentUserId(int userId) async {
    currentUserId = userId;
  }

  @override
  Future<AppUsageMode> readUsageMode() async => usageMode;

  @override
  Future<void> writeUsageMode(AppUsageMode mode) async {
    usageMode = mode;
  }

  @override
  Future<String?> readCurrentAccountId() async => currentAccountId;

  @override
  Future<void> writeCurrentAccountId(String? accountId) async {
    currentAccountId = accountId;
  }

  @override
  Future<void> clear() async {
    currentUserId = null;
    currentAccountId = null;
    usageMode = AppUsageMode.offlineGuest;
  }
}
