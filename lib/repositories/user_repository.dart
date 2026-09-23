// ─────────────────────────────────────────────────────────────────────────────
//  user_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../core/constants/app_constants.dart';

class UserRepository {
  final FirestoreService _firestore;
  UserRepository({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  Future<void> createUser(UserModel user) async {
    await _firestore.setDocument(
      AppConstants.usersCollection,
      user.uid,
      user.toMap(),
    );
  }

  Future<UserModel?> getUserById(String uid) async {
    final data = await _firestore.getDocument(
      AppConstants.usersCollection,
      uid,
    );
    if (data == null) return null;
    return UserModel.fromMap(data);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _firestore.updateDocument(
      AppConstants.usersCollection,
      uid,
      fields,
    );
  }
}
