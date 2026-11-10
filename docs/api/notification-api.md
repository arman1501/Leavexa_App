# In-App Notification API Specification

## 1. Overview

The Notification API handles user notification dispatch, real-time unread badges, and read receipt tracking. Client operations are implemented in [`lib/services/notification_service.dart`](file:///Users/Arman/Desktop/leavexa/lib/services/notification_service.dart), while automated lifecycle alerts are dispatched by Cloud Functions in `functions/src/approvals.js`.

---

## 2. Client Operations: [`NotificationService`](file:///Users/Arman/Desktop/leavexa/lib/services/notification_service.dart)

### A. Send Notification: `send`
- **Method**:
  ```dart
  Future<void> send({
    required String recipientUid,
    required String title,
    required String body,
    required String type,
    String? relatedApplicationId,
  })
  ```
- **Document Path**: `notifications/{microseconds}_{recipientUid}`
- **Security Check ([`firestore.rules`](file:///Users/Arman/Desktop/leavexa/firestore.rules))**:
  - Staff (Admin, Registrar) can notify any user.
  - Department Heads can only notify members belonging to their own department.
  - Ordinary users can only create self-notifications (`recipientUid == request.auth.uid`).

### B. Mark as Read: `markRead`
- **Method**: `Future<void> markRead(String notificationId)`
- **Behavior**: Updates `isRead: true` on `notifications/{notificationId}`.
- **Security Enforcement**: The recipient user is strictly limited via `diff().affectedKeys().hasOnly(['isRead'])`. They cannot alter notification content or timestamps.

### C. Fetch User Notifications: `getForUser`
- **Method**: `Future<List<NotificationModel>> getForUser(String uid)`
- **Query**: `collection('notifications').where('recipientUid', '==', uid)`
- **Sorting**: Client sorts descending by `createdAt`.
- **Security Check**: Enforces `resource.data.recipientUid == request.auth.uid`. Users cannot read another user's inbox.

### D. Real-Time Notification Stream: `streamForUser`
- **Method**: `Stream<List<NotificationModel>> streamForUser(String uid)`
- **Behavior**: Real-time snapshot stream used by app bars, drawer badges, and notifications screen.

---

## 3. Server-Dispatched Lifecycle Notifications

| Trigger Event | Target Recipient | Notification Type | Title | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Faculty Approved** | Applicant | `'approval'` | "Account Approved!" | Informs user of admin approval and full portal access. |
| **Faculty Rejected** | Applicant | `'rejection'` | "Account Registration Rejected" | Informs user of registration rejection with detailed reason. |
| **Leave Forwarded** | Applicant | `'leave_forwarded'` | "Leave Application Forwarded" | Alerts applicant that Department Head endorsed their request. |
| **Leave Approved** | Applicant | `'leave_approved'` | "Leave Application Approved" | Alerts applicant that Registrar granted final approval. |
| **Leave Rejected** | Applicant | `'leave_rejected'` | "Leave Application Rejected" | Alerts applicant that request was turned down with reviewer notes. |
