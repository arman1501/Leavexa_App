import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirebaseFirestore? _db;

  FirestoreService({FirebaseFirestore? firestore}) : _db = firestore;

  FirebaseFirestore get firestore => _db ??= FirebaseFirestore.instance;

  // Run a Firestore transaction.
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) {
    return firestore.runTransaction(updateFunction);
  }

  // Add a document with an auto-generated ID.
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final ref = await firestore.collection(collection).add(data);
    return ref.id;
  }

  // Create or overwrite a document.
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await firestore.collection(collection).doc(docId).set(data);
  }

  // Update existing document fields.
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await firestore.collection(collection).doc(docId).update(data);
  }

  // Delete a document.
  Future<void> deleteDocument(String collection, String docId) async {
    await firestore.collection(collection).doc(docId).delete();
  }

  // Fetch a single document.
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    final snapshot = await firestore.collection(collection).doc(docId).get();

    if (!snapshot.exists) return null;

    return snapshot.data();
  }

  // Fetch all documents in a collection.
  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    final snapshot = await firestore.collection(collection).get();

    return snapshot.docs.map((doc) {
      return {...doc.data(), 'id': doc.id};
    }).toList();
  }

  // Query documents in a collection with filters, ordering, and limit.
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    Map<String, Object?>? isEqualTo,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collection);

    if (isEqualTo != null) {
      for (final entry in isEqualTo.entries) {
        if (entry.value != null) {
          query = query.where(entry.key, isEqualTo: entry.value);
        }
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      return {...doc.data(), 'id': doc.id};
    }).toList();
  }

  // Stream documents in a collection with filters.
  Stream<List<Map<String, dynamic>>> streamCollection(
    String collection, {
    Map<String, Object?>? isEqualTo,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = firestore.collection(collection);

    if (isEqualTo != null) {
      for (final entry in isEqualTo.entries) {
        if (entry.value != null) {
          query = query.where(entry.key, isEqualTo: entry.value);
        }
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
    );
  }

  // Stream a single document.
  Stream<Map<String, dynamic>?> streamDocument(
    String collection,
    String docId,
  ) {
    return firestore
        .collection(collection)
        .doc(docId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return null;
          return {...snapshot.data()!, 'id': snapshot.id};
        });
  }
}
