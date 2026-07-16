import 'package:flutter/foundation.dart';

import 'api_client.dart';

enum BackendConnectionStatus { idle, checking, online, offline }

class BackendConnectionProvider extends ChangeNotifier {
  BackendConnectionProvider.empty();

  ApiClient? _client;
  BackendConnectionStatus status = BackendConnectionStatus.idle;
  String? error;
  DateTime? checkedAt;

  bool get checking => status == BackendConnectionStatus.checking;
  bool get online => status == BackendConnectionStatus.online;

  void attach(ApiClient client) {
    _client = client;
  }

  Future<void> check() async {
    final client = _client;
    if (client == null) {
      return;
    }

    status = BackendConnectionStatus.checking;
    error = null;
    notifyListeners();

    try {
      final data = await client.get(
        '/health',
        timeout: const Duration(seconds: 3),
      );
      if (data is Map<String, dynamic> && data['status'] == 'UP') {
        status = BackendConnectionStatus.online;
      } else {
        status = BackendConnectionStatus.offline;
        error = 'Server health check returned an unexpected response';
      }
    } catch (_) {
      status = BackendConnectionStatus.offline;
      error = 'Unable to connect to the server';
    } finally {
      checkedAt = DateTime.now();
      notifyListeners();
    }
  }
}
