// ─────────────────────────────────────────────────────────────────────────────
//  firestore_service.dart  –  Firestore CRUD base helper
// ─────────────────────────────────────────────────────────────────────────────

// TODO: Add `cloud_firestore` to pubspec.yaml before uncommenting.
//
// import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  // final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Add a document to [collection]. Returns the generated document ID.
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    // final ref = await _db.collection(collection).add(data);
    // return ref.id;
    throw UnimplementedError('FirestoreService.addDocument not yet implemented.');
  }

  /// Set (overwrite) a document with a known [docId].
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    // await _db.collection(collection).doc(docId).set(data);
    throw UnimplementedError('FirestoreService.setDocument not yet implemented.');
  }

  /// Update specific fields of a document.
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    // await _db.collection(collection).doc(docId).update(data);
    throw UnimplementedError('FirestoreService.updateDocument not yet implemented.');
  }

  /// Delete a document.
  Future<void> deleteDocument(String collection, String docId) async {
    // await _db.collection(collection).doc(docId).delete();
    throw UnimplementedError('FirestoreService.deleteDocument not yet implemented.');
  }

  /// Fetch a single document by ID.
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    // final snap = await _db.collection(collection).doc(docId).get();
    // return snap.exists ? snap.data() : null;
    throw UnimplementedError('FirestoreService.getDocument not yet implemented.');
  }

  /// Fetch all documents in a collection.
  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    // final snap = await _db.collection(collection).get();
    // return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    throw UnimplementedError('FirestoreService.getCollection not yet implemented.');
  }
}
