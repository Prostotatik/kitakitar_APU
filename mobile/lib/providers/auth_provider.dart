import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kitakitar_mobile/services/auth_service.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      try {
        _user = user;
        notifyListeners();
      } catch (e) {
        // Ignore PigeonUserDetails and other deserialization errors
        debugPrint('AuthProvider: authStateChanges error: $e');
        _user = null;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('AuthProvider: authStateChanges stream error: $e');
      _user = null;
      notifyListeners();
    });
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _authService.signInWithEmail(email, password);
      if (credential?.user != null) {
        _user = credential!.user;
        await _ensureUserDocument();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _authService.signInWithGoogle();
      if (credential?.user != null) {
        _user = credential!.user;
        await _ensureUserDocument();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential =
          await _authService.registerWithEmail(name, email, password);
      if (credential?.user != null) {
        _user = credential!.user;
        await _createUserDocument(name, email, 'email');
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _authService.registerWithGoogle();
      if (credential?.user != null) {
        _user = credential!.user;
        await _createUserDocument(
          _user!.displayName ?? 'User',
          _user!.email ?? '',
          'google',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
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
      return 'No access to data. Deploy Firestore rules (see FIRESTORE_RULES_FIX.md).';
    }
    if (s.contains('invalid-credential') || s.contains('wrong-password') ||
        s.contains('user-not-found') || s.contains('invalid-email') ||
        s.contains('auth credential is incorrect')) {
      return 'Invalid email or password.';
    }
    return s;
  }

  Future<void> _ensureUserDocument() async {
    if (_user == null) return;

    final existingUser = await _firestoreService.getUser(_user!.uid);
    if (existingUser == null) {
      await _createUserDocument(
        _user!.displayName ?? 'User',
        _user!.email ?? '',
        _user!.providerData.first.providerId == 'google.com' ? 'google' : 'email',
      );
    } else {
      // Update last login
      await _firestoreService.updateUser(_user!.uid, {
        'lastLoginAt': DateTime.now(),
      });
    }
  }

  Future<void> _createUserDocument(String name, String email, String provider) async {
    if (_user == null) return;

    final userModel = UserModel(
      id: _user!.uid,
      name: name,
      email: email,
      avatarUrl: _user!.photoURL,
      points: 0,
      totalWeight: 0,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      provider: provider,
      stats: {},
    );

    await _firestoreService.createUser(userModel);
  }
}

