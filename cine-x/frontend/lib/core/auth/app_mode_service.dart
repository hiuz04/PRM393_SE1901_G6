import '../storage/session_storage.dart';
import '../sync/sync_models.dart';

class AppModeService {
  const AppModeService(this._sessionStorage);

  final SessionStorage _sessionStorage;

  Future<AppUsageMode> currentMode() => _sessionStorage.readUsageMode();

  Future<void> useOfflineGuest() {
    return _sessionStorage.writeUsageMode(AppUsageMode.offlineGuest);
  }

  Future<void> useOnlineAccount(String accountId) async {
    await _sessionStorage.writeUsageMode(AppUsageMode.onlineAccount);
    await _sessionStorage.writeCurrentAccountId(accountId);
  }
}
