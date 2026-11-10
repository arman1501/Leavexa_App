// ─────────────────────────────────────────────────────────────────────────────
//  notification_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class NotificationModel {
  final String id;
  final String recipientUid;
  final String title;
  final String body;
  final String
  type; // 'leave_applied' | 'leave_approved' | 'leave_rejected' | 'leave_forwarded'
  final String? relatedApplicationId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientUid,
    required this.title,
    required this.body,
    required this.type,
    this.relatedApplicationId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedCreatedAt;
    final rawDate = map['createdAt'];
    if (rawDate is DateTime) {
      parsedCreatedAt = rawDate;
    } else if (rawDate != null && rawDate.runtimeType.toString() == 'Timestamp') {
      // Handles Cloud Firestore Timestamp without direct import coupling if dynamic
      parsedCreatedAt = (rawDate as dynamic).toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return NotificationModel(
      id: map['id'] as String? ?? '',
      recipientUid: map['recipientUid'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      relatedApplicationId: map['relatedApplicationId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'recipientUid': recipientUid,
    'title': title,
    'body': body,
    'type': type,
    'relatedApplicationId': relatedApplicationId,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      recipientUid: recipientUid,
      title: title,
      body: body,
      type: type,
      relatedApplicationId: relatedApplicationId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
