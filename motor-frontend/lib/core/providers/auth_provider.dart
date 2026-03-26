// ============================================================
//  auth_provider.dart  —  Authentication state management
// ============================================================

import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _auth;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _error;
  bool _loading = false;

  AuthProvider(this._auth) {
    _init();
  }

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAdmin => _user?.role == 'admin';
  bool get canOperate => _user?.role == 'admin' || _user?.role == 'operator';

  Future<void> _init() async {
    final stored = await _auth.getStoredUser();
    if (stored != null) {
      _user = stored;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _auth.login(username, password);
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid username or password.';
        _status = AuthStatus.unauthenticated;
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }
}
