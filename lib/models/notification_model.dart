// ─────────────────────────────────────────────────────────────────────────────
//  notification_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class NotificationModel {
  final String id;
  final String recipientUid;
  final String title;
  final String body;
  final String type; // 'leave_applied' | 'leave_approved' | 'leave_rejected' | 'leave_forwarded'
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
    return NotificationModel(
      id: map['id'] as String,
      recipientUid: map['recipientUid'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] as String,
      relatedApplicationId: map['relatedApplicationId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
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
