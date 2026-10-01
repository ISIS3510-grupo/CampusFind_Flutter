import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';
import '../data/biometric_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    this.authService = const AuthService(),
    BiometricService? biometricService,
  }) : _biometricService = biometricService ?? BiometricService();

  final AuthService authService;
  final BiometricService _biometricService;
  bool _isBusy = false;
  bool _isAuthenticated = false;
  bool _needsPasswordSignIn = false;
  String? _errorMessage;
  bool _disposed = false;

  bool get isBusy => _isBusy;
  bool get isAuthenticated => _isAuthenticated;
  bool get needsPasswordSignIn => _needsPasswordSignIn;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_isBusy || _disposed) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> requestStudentAccess() async {
    if (_isBusy || _disposed) return;
    _beginAuthentication();
    try {
      if (!authService.hasCurrentUser) {
        _needsPasswordSignIn = true;
        return;
      }

      final available = await _biometricService.canAuthenticate();
      if (_disposed) return;
      if (!available) {
        _needsPasswordSignIn = true;
        return;
      }

      final authenticated = await _biometricService.authenticate();
      if (_disposed) return;
      if (!authenticated || !authService.hasCurrentUser) {
        _needsPasswordSignIn = true;
        return;
      }

      final error = await authService.verifyStudentRole();
      if (_disposed) return;
      _errorMessage = error;
      _isAuthenticated = error == null;
    } catch (_) {
      if (!_disposed) _needsPasswordSignIn = true;
    } finally {
      _finishAuthentication();
    }
  }

  Future<bool> signInStudent(String email, String password) async {
    if (_isBusy || _disposed) return false;
    _beginAuthentication();
    try {
      final error = await authService.signInStudent(email, password);
      if (_disposed) return false;
      _errorMessage = error;
      _isAuthenticated = error == null;
      return _isAuthenticated;
    } catch (_) {
      if (!_disposed) _errorMessage = 'Unable to sign in. Please try again.';
      return false;
    } finally {
      _finishAuthentication();
    }
  }

  void _beginAuthentication() {
    _isBusy = true;
    _isAuthenticated = false;
    _needsPasswordSignIn = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signInAdmin(String email, String password) async {
    if (_isBusy || _disposed) return false;
    _beginAuthentication();
    try {
      final error = await authService.signInAdmin(email, password);
      if (_disposed) return false;
      _errorMessage = error;
      _isAuthenticated = error == null;
      return _isAuthenticated;
    } catch (_) {
      if (!_disposed) _errorMessage = 'Unable to sign in. Please try again.';
      return false;
    } finally {
      _finishAuthentication();
    }
  }

  void _finishAuthentication() {
    _isBusy = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
