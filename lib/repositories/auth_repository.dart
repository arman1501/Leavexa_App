// ─────────────────────────────────────────────────────────────────────────────
//  auth_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;
  AuthRepository({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<void> login({required String email, required String password}) =>
      _authService.signIn(email: email, password: password);

  Future<String> register({
    required String email,
    required String password,
  }) =>
      _authService.register(email: email, password: password);

  Future<void> logout() => _authService.signOut();

  Future<void> forgotPassword(String email) =>
      _authService.sendPasswordReset(email);

  String? get currentUserId => _authService.currentUid;
}
