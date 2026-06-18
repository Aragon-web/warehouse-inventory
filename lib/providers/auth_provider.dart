import 'package:flutter/material.dart';
import '../database/auth.dart' as db;

enum AuthState { loading, setup, login, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.loading;
  String _username = '';
  String _error = '';

  AuthState get state => _state;
  bool get isLoading => _state == AuthState.loading;
  bool get isSetup => _state == AuthState.setup;
  bool get isLogin => _state == AuthState.login;
  bool get isAuthenticated => _state == AuthState.authenticated;
  String get username => _username;
  String get error => _error;

  void clearError() => _error = '';

  Future<void> checkStatus() async {
    try {
      final result = await db.authStatus();
      if (result.configured) {
        _state = AuthState.login;
      } else {
        _state = AuthState.setup;
      }
    } catch (_) {
      _state = AuthState.setup;
    }
    notifyListeners();
  }

  Future<void> setup(String user, String pass, String pass2) async {
    _error = '';
    if (pass != pass2) {
      _error = 'كلمتا المرور غير متطابقتين';
      notifyListeners();
      return;
    }
    try {
      await db.authSetup(user, pass);
      _state = AuthState.authenticated;
      _username = user;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> login(String user, String pass) async {
    _error = '';
    try {
      await db.authLogin(user, pass);
      _state = AuthState.authenticated;
      _username = user;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }
}
