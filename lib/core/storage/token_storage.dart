import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';

  Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(user));
  }

  Future<({String token, Map<String, dynamic> user})?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final userJson = prefs.getString(_kUser);
    if (token == null || token.isEmpty || userJson == null) return null;
    try {
      final user = jsonDecode(userJson) as Map<String, dynamic>;
      return (token: token, user: user);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}
