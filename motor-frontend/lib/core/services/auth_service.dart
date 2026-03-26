// ============================================================
//  auth_service.dart  —  Local Authentication (SharedPreferences)
//  In production: replace with JWT / OAuth flow against your API
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String username;
  final String role; // admin | operator | viewer
  final String token;

  const AuthUser({
    required this.username,
    required this.role,
    required this.token,
  });
}

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';
  static const _roleKey = 'auth_role';

  // ── Hardcoded demo credentials (replace with real API auth) ───────
  static const _demoAccounts = {
    'admin': {'password': 'admin123', 'role': 'admin'},
    'operator': {'password': 'op@2024', 'role': 'operator'},
    'viewer': {'password': 'view123', 'role': 'viewer'},
  };

  Future<AuthUser?> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network

    final account = _demoAccounts[username.toLowerCase()];
    if (account == null) return null;
    if (account['password'] != password) return null;

    final user = AuthUser(
      username: username,
      role: account['role']!,
      token: 'demo_token_${username}_${DateTime.now().millisecondsSinceEpoch}',
    );

    await _persist(user);
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
  }

  Future<AuthUser?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final username = prefs.getString(_usernameKey);
    final role = prefs.getString(_roleKey);

    if (token == null || username == null || role == null) return null;
    return AuthUser(username: username, role: role, token: token);
  }

  Future<void> _persist(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, user.token);
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_roleKey, user.role);
  }
}
