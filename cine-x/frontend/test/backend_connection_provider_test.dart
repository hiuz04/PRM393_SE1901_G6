import 'package:cine_x/core/network/api_client.dart';
import 'package:cine_x/core/network/backend_connection_provider.dart';
import 'package:cine_x/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({this.response, this.failure})
      : super('http://localhost', MemoryTokenStorage());

  final Object? response;
  final Object? failure;
  String? requestedPath;
  Duration? requestedTimeout;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const {},
    Duration timeout = const Duration(seconds: 20),
  }) async {
    requestedPath = path;
    requestedTimeout = timeout;
    if (failure != null) {
      throw failure!;
    }
    return response;
  }
}

void main() {
  test('BackendConnectionProvider marks online from health endpoint', () async {
    final client = FakeApiClient(response: <String, dynamic>{'status': 'UP'});
    final provider = BackendConnectionProvider.empty()..attach(client);

    await provider.check();

    expect(client.requestedPath, '/health');
    expect(client.requestedTimeout, const Duration(seconds: 3));
    expect(provider.status, BackendConnectionStatus.online);
    expect(provider.error, isNull);
  });

  test('BackendConnectionProvider marks offline on connection failure',
      () async {
    final provider = BackendConnectionProvider.empty()
      ..attach(FakeApiClient(failure: Exception('offline')));

    await provider.check();

    expect(provider.status, BackendConnectionStatus.offline);
    expect(provider.error, 'Unable to connect to the server');
  });
}
