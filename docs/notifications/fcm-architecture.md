# FCM System Architecture & Security Perimeter

## 1. Architectural Topology

Leavexa implements an asynchronous, serverless push notification pipeline combining Flutter client services, Firebase Cloud Messaging, Cloud Firestore event triggers, and Firebase Admin Messaging SDK.

```
                  ┌──────────────────────────────────────────────┐
                  │            LEAVEXA FLUTTER CLIENT            │
                  │   lib/services/fcm_service.dart              │
                  └───────┬──────────────────────────────▲───────┘
                          │                              │
          1. Token Registration / Delete                 │ 7. Push Delivery
          users/{uid}/fcm_tokens/{tokenId}               │    (FCM APNs/FCM Android)
                          │                              │
                          ▼                              │
┌───────────────────────────────────┐                    │
│          CLOUD FIRESTORE          │                    │
│  • users/{uid}/fcm_tokens/        │                    │
│  • leave_applications/{appId}     │                    │
│  • notifications/{notifId}        │                    │
└──────────────┬────────────────────┘                    │
               │                                         │
        2. Firestore Event Trigger                       │
       (onCreate / onUpdate)                             │
               ▼                                         │
┌───────────────────────────────────┐                    │
│     FIREBASE CLOUD FUNCTIONS      │                    │
│   functions/src/notifications.js  │                    │
│                                   │                    │
│ • Fetch user tokens               │                    │
│ • Prune expired tokens            │                    │
│ • Write in-app notification doc   │                    │
│ • Dispatch multicast payload      ├────────────────────┘
└───────────────────────────────────┘
```

---

## 2. Payload Structure

All push notifications dispatched by Leavexa contain both a standard user-visible `notification` block (displayed by the OS tray) and a typed `data` dictionary (consumed by the app for background processing and deep navigation).

### Standard Multicast Payload
```json
{
  "notification": {
    "title": "Leave Application Approved!",
    "body": "Your Medical Leave request has received final approval from the Registrar."
  },
  "data": {
    "type": "leave_approved",
    "relatedApplicationId": "app_cse_1001",
    "recipientUid": "faculty_uid_789",
    "click_action": "FLUTTER_NOTIFICATION_CLICK",
    "timestamp": "2026-11-09T17:00:00.000Z",
    "status": "approved"
  },
  "tokens": [
    "fcm_token_device_alpha",
    "fcm_token_device_beta"
  ]
}
```

---

## 3. Defense-in-Depth Security Boundaries

### A. Client Side Protection
- Flutter clients only register and unregister device tokens via [`FcmService`](file:///Users/Arman/Desktop/leavexa/lib/services/fcm_service.dart).
- Clients cannot invoke push dispatching or forge notifications to other users.

### B. Firestore Security Rules Enforcement
Under [`firestore.rules`](file:///Users/Arman/Desktop/leavexa/firestore.rules):
```javascript
match /users/{uid}/fcm_tokens/{tokenId} {
  // Only the token owner can register, view, refresh, or clean up their own device tokens
  allow read, write: if isOwner(uid);
}
```
- Cross-user reading or writing of tokens is blocked with `PERMISSION_DENIED`.
- Unauthenticated access is rejected unconditionally.

### C. Server-Side Execution
- Functions running in [`functions/src/notifications.js`](file:///Users/Arman/Desktop/leavexa/functions/src/notifications.js) use the trusted Firebase Admin SDK (`admin.messaging()`), bypassing client Firestore rules to read device tokens and execute cleanup batches.

---

## 4. Interaction Lifecycle Handling

1. **Foreground State**:
   - `FirebaseMessaging.onMessage` fires in the running application.
   - Triggers `onForegroundMessage` callback to refresh in-app notification badges and display custom UI alerts without disturbing ongoing forms.
2. **Background State (App in recents / minimized)**:
   - System displays notification in native OS tray using the Android notification channel (`leavexa_high_importance_channel`) or iOS banner.
   - When tapped, `FirebaseMessaging.onMessageOpenedApp` executes and invokes `FcmService.handleNotificationNavigation(message.data)`.
3. **Terminated State (Cold launch from push notification tap)**:
   - User taps push notification while the app process is terminated.
   - The OS launches the Flutter engine; `FcmService.initialize()` calls `FirebaseMessaging.instance.getInitialMessage()`.
   - The payload metadata is parsed, and `navigatorKey.currentState.pushNamed(...)` routes the user directly to the target record.
