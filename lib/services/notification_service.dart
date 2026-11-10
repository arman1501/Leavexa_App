// ─────────────────────────────────────────────────────────────────────────────
//  notification_service.dart  –  In-app Notification Writer
// ─────────────────────────────────────────────────────────────────────────────

import '../models/notification_model.dart';
import '../core/constants/app_constants.dart';
import 'firestore_service.dart';

class NotificationService {
  final FirestoreService _firestore;
  NotificationService({FirestoreService? firestore})
    : _firestore = firestore ?? FirestoreService();

  /// Write an in-app notification to Firestore.
  Future<void> send({
    required String recipientUid,
    required String title,
    required String body,
    required String type,
    String? relatedApplicationId,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}_$recipientUid';
    final notification = NotificationModel(
      id: id,
      recipientUid: recipientUid,
      title: title,
      body: body,
      type: type,
      relatedApplicationId: relatedApplicationId,
      createdAt: DateTime.now(),
    );
    await _firestore.setDocument(
      AppConstants.notificationsCollection,
      id,
      notification.toMap(),
    );
  }

  /// Mark a notification as read.
  Future<void> markRead(String notificationId) async {
    await _firestore.updateDocument(
      AppConstants.notificationsCollection,
      notificationId,
      {'isRead': true},
    );
  }

  /// Fetch all notifications for a user using indexed query.
  Future<List<NotificationModel>> getForUser(String uid) async {
    final data = await _firestore.queryCollection(
      AppConstants.notificationsCollection,
      isEqualTo: {'recipientUid': uid},
    );
    final notifications =
        data.map((m) => NotificationModel.fromMap(m)).toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  /// Real-time stream of notifications for a user.
  Stream<List<NotificationModel>> streamForUser(String uid) {
    return _firestore
        .streamCollection(
          AppConstants.notificationsCollection,
          isEqualTo: {'recipientUid': uid},
        )
        .map((list) {
          final notifications =
              list.map((m) => NotificationModel.fromMap(m)).toList();
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }
}
