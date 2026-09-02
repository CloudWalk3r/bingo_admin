import 'package:flutter/material.dart';

/// Simple credential-based gate for the admin dashboard.
///
/// Credentials are hardcoded for now — swap [_signIn] for a Firebase Auth
/// call when real admin accounts are provisioned.
class AuthProvider with ChangeNotifier {
  static const String _adminEmail = 'admin@bingo.lk';
  static const String _adminPassword = 'bingo@123';

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get email => _email;

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Small delay so the button's loading state is visible.
    await Future.delayed(const Duration(milliseconds: 600));

    final matches = email.trim().toLowerCase() == _adminEmail &&
        password == _adminPassword;

    if (matches) {
      _isAuthenticated = true;
      _email = _adminEmail;
      _errorMessage = null;
    } else {
      _isAuthenticated = false;
      _errorMessage = 'Invalid email or password. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
    return _isAuthenticated;
  }

  void logout() {
    _isAuthenticated = false;
    _email = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
