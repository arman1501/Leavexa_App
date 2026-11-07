
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class AuthService {
  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  AuthService({
    FirebaseAuth? auth,
    UserRepository? userRepository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userRepository = userRepository ?? UserRepository();

  // Current Firebase user
  User? get currentUser => _auth.currentUser;

  // Current Firebase UID
  String? get currentUid => _auth.currentUser?.uid;

  // Authentication state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email and Password Login
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Basic Registration (for existing AuthRepository compatibility)
  Future<String> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user?.uid;

    if (uid == null) {
      throw Exception('Registration failed.');
    }

    return uid;
  }

  // Faculty Registration with Firestore Profile
  Future<void> registerFaculty({
    required String fullName,
    required String employeeId,
    required String email,
    required String phone,
    required String departmentName,
    required String designation,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('Account creation failed.');
    }

    final departmentId = departmentName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final user = UserModel(
      uid: firebaseUser.uid,
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      employeeId: employeeId.trim(),
      departmentId: departmentId,
      departmentName: departmentName,
      designation: designation,
      role: 'faculty',
      phone: phone.trim(),
      isActive: false,
      approvalStatus: 'pending',
      createdAt: DateTime.now(),
    );

    try {
      await _userRepository.createUser(user);
    } catch (e) {
      await firebaseUser.delete();
      rethrow;
    }

    await _auth.signOut();
  }

  // Forgot Password
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
