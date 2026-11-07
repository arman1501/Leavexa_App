
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // Add a document with an auto-generated ID.
  Future<String> addDocument(
      String collection,
      Map<String, dynamic> data,
      ) async {
    final ref = await _db.collection(collection).add(data);
    return ref.id;
  }

  // Create or overwrite a document.
  Future<void> setDocument(
      String collection,
      String docId,
      Map<String, dynamic> data,
      ) async {
    await _db.collection(collection).doc(docId).set(data);
  }

  // Update existing document fields.
  Future<void> updateDocument(
      String collection,
      String docId,
      Map<String, dynamic> data,
      ) async {
    await _db.collection(collection).doc(docId).update(data);
  }

  // Delete a document.
  Future<void> deleteDocument(
      String collection,
      String docId,
      ) async {
    await _db.collection(collection).doc(docId).delete();
  }

  // Fetch a single document.
  Future<Map<String, dynamic>?> getDocument(
      String collection,
      String docId,
      ) async {
    final snapshot =
    await _db.collection(collection).doc(docId).get();

    if (!snapshot.exists) return null;

    return snapshot.data();
  }

  // Fetch all documents in a collection.
  Future<List<Map<String, dynamic>>> getCollection(
      String collection,
      ) async {
    final snapshot = await _db.collection(collection).get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }
}
