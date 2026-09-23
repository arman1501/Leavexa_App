// ─────────────────────────────────────────────────────────────────────────────
//  storage_service.dart  –  Firebase Storage wrapper (document uploads)
// ─────────────────────────────────────────────────────────────────────────────

// TODO: Add `firebase_storage` to pubspec.yaml before uncommenting.
//
// import 'dart:io';
// import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  // final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a file and return its download URL.
  Future<String> uploadDocument({
    required String uid,
    required String applicationId,
    // required File file,
  }) async {
    // final ref = _storage.ref('documents/$uid/$applicationId');
    // await ref.putFile(file);
    // return await ref.getDownloadURL();
    throw UnimplementedError('StorageService.uploadDocument not yet implemented.');
  }

  /// Delete a file by its URL.
  Future<void> deleteByUrl(String downloadUrl) async {
    // final ref = _storage.refFromURL(downloadUrl);
    // await ref.delete();
    throw UnimplementedError('StorageService.deleteByUrl not yet implemented.');
  }
}
