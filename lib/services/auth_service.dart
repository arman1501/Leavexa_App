// ─────────────────────────────────────────────────────────────────────────────
//  auth_service.dart  –  Firebase Auth wrapper
// ─────────────────────────────────────────────────────────────────────────────

// TODO: Add `firebase_auth` to pubspec.yaml before uncommenting Firebase code.
//
// import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in with email and password.
  Future<void> signIn({required String email, required String password}) async {
    // await _auth.signInWithEmailAndPassword(email: email, password: password);
    throw UnimplementedError('AuthService.signIn not yet implemented.');
  }

  /// Register a new user.
  Future<String> register({
    required String email,
    required String password,
  }) async {
    // final credential = await _auth.createUserWithEmailAndPassword(
    //   email: email, password: password);
    // return credential.user!.uid;
    throw UnimplementedError('AuthService.register not yet implemented.');
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    // await _auth.signOut();
    throw UnimplementedError('AuthService.signOut not yet implemented.');
  }

  /// Send password reset email.
  Future<void> sendPasswordReset(String email) async {
    // await _auth.sendPasswordResetEmail(email: email);
    throw UnimplementedError('AuthService.sendPasswordReset not yet implemented.');
  }

  /// Returns the current signed-in user's UID, or null.
  String? get currentUid {
    // return _auth.currentUser?.uid;
    return null;
  }

  /// Stream of auth state changes.
  // Stream<User?> get authStateChanges => _auth.authStateChanges();
}
