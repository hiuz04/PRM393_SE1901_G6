import '../../../../core/network/api_client.dart';
import '../../../projects/data/models/cinex_models.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthSession> login(String email, String password) async {
    final data = await _client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthSession> register(
    String displayName,
    String email,
    String password,
    String confirmPassword,
  ) async {
    final data = await _client.post(
      '/auth/register',
      body: {
        'displayName': displayName,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<AppUser> me() async {
    final data = await _client.get('/auth/me');
    return AppUser.fromJson(data as Map<String, dynamic>);
  }
}
