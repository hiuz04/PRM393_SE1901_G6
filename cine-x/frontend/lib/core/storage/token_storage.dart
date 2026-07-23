import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStorage {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage();

  static const _key = 'cinex_access_token';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
