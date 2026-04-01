import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/center_auth_service.dart';

/// Provider-like layer for the recycling center (web).
///
/// Holds:
/// - current Firebase `User`;
/// - loading/error state;
/// - methods login/register/reset/signOut.
class CenterAuthProvider with ChangeNotifier {
  final CenterAuthService _authService = CenterAuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CenterAuthProvider() {
    _authService.authStateChanges.listen(
      (user) {
        _user = user;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('CenterAuthProvider: authStateChanges error: $e');
        _user = null;
        notifyListeners();
      },
    );
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final cred = await _authService.signInWithEmail(email, password);
      _user = cred?.user;

      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final cred = await _authService.registerWithEmail(email, password);
      _user = cred?.user;

      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  static String _mapAuthError(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
      return 'No access to data. Check Firestore rules for center role.';
    }
    if (s.contains('invalid-credential') ||
        s.contains('wrong-password') ||
        s.contains('user-not-found') ||
        s.contains('invalid-email')) {
      return 'Invalid email or password.';
    }
    return s;
  }
}

