import '../../../core/api/api_client.dart';

class LoginResult {
  final String token;
  final Map<String, dynamic> user;

  const LoginResult({required this.token, required this.user});
}

class AuthApi {
  final ApiClient _api;

  AuthApi({ApiClient? client}) : _api = client ?? ApiClient();

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.post('/v1/login', {
      'username': username,
      'password': password,
    });

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Login response missing token.');
    }

    final user = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    return LoginResult(token: token, user: user);
  }

  Future<void> logout(String token) async {
    try {
      await _api.post('/logout', const {}, token: token);
    } on ApiException {
      // Server-side logout is best-effort; we still clear the token locally.
    }
  }
}
