import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../projects/data/models/cinex_models.dart';
import '../../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider.empty();

  AuthRepository? _repository;
  TokenStorage? _storage;
  AppUser? user;
  bool initializing = true;
  bool loading = false;
  String? error;

  bool get authenticated => user != null;

  void attach(AuthRepository repository, TokenStorage storage) {
    _repository = repository;
    _storage = storage;
  }

  Future<void> bootstrap() async {
    if (_repository == null || _storage == null) {
      return;
    }
    initializing = true;
    error = null;
    notifyListeners();
    try {
      final token = await _storage!.readToken();
      if (token == null || token.isEmpty) {
        user = null;
      } else {
        user = await _repository!.me();
      }
    } catch (_) {
      await _storage!.clear();
      user = null;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    return _withLoading(() async {
      final session = await _repository!.login(email.trim(), password);
      await _storage!.writeToken(session.accessToken);
      user = session.user;
    });
  }

  Future<bool> register(
    String displayName,
    String email,
    String password,
    String confirmPassword,
  ) {
    return _withLoading(() async {
      final session = await _repository!.register(
        displayName.trim(),
        email.trim(),
        password,
        confirmPassword,
      );
      await _storage!.writeToken(session.accessToken);
      user = session.user;
    });
  }

  Future<void> logout() async {
    await _storage?.clear();
    user = null;
    notifyListeners();
  }

  Future<bool> _withLoading(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (ex) {
      error = ex.message;
      return false;
    } catch (_) {
      error = 'Không thể kết nối máy chủ';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
