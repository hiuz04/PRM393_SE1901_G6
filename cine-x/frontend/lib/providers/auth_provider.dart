import 'package:flutter/foundation.dart';

import '../models/cinex_models.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider.empty();

  AuthRepository? _repository;
  AppUser? user;
  bool initializing = true;
  bool loading = false;
  String? error;

  bool get authenticated => user != null;

  void attach(AuthRepository repository) {
    _repository = repository;
  }

  Future<void> bootstrap() async {
    final repository = _repository;
    if (repository == null) return;
    initializing = true;
    error = null;
    notifyListeners();
    try {
      user = await repository.currentUser();
    } catch (_) {
      user = null;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    return _withLoading(() async {
      final session = await _repository!.login(email.trim(), password);
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
      user = session.user;
    });
  }

  Future<bool> useOfflineGuest() async {
    return _withLoading(() async {
      user = await _repository!.useOfflineGuest();
    });
  }

  Future<void> logout() async {
    await _repository?.logout();
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
    } catch (ex) {
      error = ex.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
