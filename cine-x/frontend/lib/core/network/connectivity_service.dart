import '../errors/app_exception.dart';
import 'api_client.dart';
import '../sync/sync_models.dart';

class ConnectivityService {
  const ConnectivityService(this._client);

  final ApiClient _client;

  Future<NetworkStatus> status() async {
    try {
      await _client.get('/health', timeout: const Duration(seconds: 5));
      return NetworkStatus.online;
    } on AppException {
      return NetworkStatus.offline;
    } catch (_) {
      return NetworkStatus.offline;
    }
  }
}
