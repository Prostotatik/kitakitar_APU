import 'package:firebase_auth/firebase_auth.dart';

/// Auth layer specifically for recycling centers (web).
///
/// Equivalent of AuthService from mobile, but:
/// - role `center` instead of `user`;
/// - without Google Sign-In (according to the description, email+password is enough for the center website).
class CenterAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // TODO: here you can call a cloud function setUserRole(role: 'center')
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // TODO: set displayName to the center name and call setUserRole('center')
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

