import '../core/api_service.dart';
import '../core/token_storage.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiService _api;
  final TokenStorage _storage;

  // POST /auth/login
  Future<User> login(String email, String password) async {
    final body = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_name': 'aralpet-mobile',
    });
    return _saveSession(body);
  }

  // POST /auth/register
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final body = await _api.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'device_name': 'aralpet-mobile',
    });
    return _saveSession(body);
  }

  // On app start: if a token is saved, ask GET /me who it belongs to.
  Future<User?> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null) return null;

    try {
      final body = await _api.get('/me');
      return User.fromJson(body['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _storage.clear(); // token expired or account deactivated
      }
      return null; // offline: show login, keep token for next launch
    } catch (_) {
      return null;
    }
  }

  // POST /auth/logout (deletes the token on the server too)
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Even if the server can't be reached, sign out locally.
    } finally {
      await _storage.clear();
    }
  }

  Future<User> _saveSession(dynamic body) async {
    final data = body['data'] as Map<String, dynamic>;
    await _storage.saveToken(data['token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }
}