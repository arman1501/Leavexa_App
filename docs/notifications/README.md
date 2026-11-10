# Leavexa FCM & Push Notification System

## 1. Executive Summary

This directory documents the comprehensive, secure, role-based Firebase Cloud Messaging (FCM) push notification architecture implemented in Phase 16 of the **Leavexa** project.

Leavexa pairs client-side device token lifecycle management with server-side Cloud Functions notification dispatching, ensuring non-repudiation, zero credential exposure in client apps, and atomic multi-device push delivery across academic approval workflows.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LEAVEXA PUSH NOTIFICATION TOPOLOGY                │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Client Event          ──> Firestore (Leave Submission, Review, Vetting)   │
│ 2. Background Trigger    ──> Cloud Functions (onCreate / onUpdate triggers) │
│ 3. Recipient Resolution  ──> Role & Department Query (Head/Reg/Admin/User)  │
│ 4. Token Fetch           ──> users/{uid}/fcm_tokens/{tokenId} (Multi-device)│
│ 5. Multicast FCM Dispatch──> admin.messaging().sendEachForMulticast()       │
│ 6. Stale Token Pruning   ──> Invalid / unregistered tokens automatically purged
│ 7. Device Presentation   ──> Foreground / Background / Terminated App Tap   │
│ 8. Target Navigation     ──> FcmService.handleNotificationNavigation()      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Notification Documentation Suite

| Document | File Path | Scope & Focus |
| :--- | :--- | :--- |
| **FCM Architecture** | [`fcm-architecture.md`](fcm-architecture.md) | High-level system architecture, security perimeter, data payload format, and client/server separation. |
| **Notification Events** | [`notification-events.md`](notification-events.md) | Exhaustive lifecycle event mapping, role-based recipient matrix, titles, bodies, and triggers. |
| **Token Management** | [`token-management.md`](token-management.md) | Token generation, multi-device subcollection schema, security rules, and automatic stale token pruning. |
| **Platform Setup** | [`platform-setup.md`](platform-setup.md) | Android channels/permissions, iOS APNs entitlements, Info.plist configurations, and physical device prerequisites. |
| **Testing Guide** | [`testing-guide.md`](testing-guide.md) | Mocking strategies, unit tests, widget tests, Cloud Functions tests, and live emulator verification. |

---

## 3. Core Guarantees & Constraints

1. **Zero Client Privilege**: Flutter client applications never possess FCM server keys, service account credentials, or direct messaging dispatch APIs. Push messages originate strictly from trusted server-side Cloud Functions.
2. **Multi-Device Support**: A single university user can log in simultaneously across multiple devices (e.g., Android phone, iPad, web dashboard). Notifications are delivered via multicast to all active tokens.
3. **Idempotent Delivery**: All notification dispatches carry deterministic idempotency keys, preventing duplicate alerts during Cloud Functions retries.
4. **Stale Token Cleanup**: If a device uninstalls the app or rotates its token, FCM rejection codes (`messaging/registration-token-not-registered`) immediately trigger automatic deletion from the user's Firestore token registry.
5. **Private Token Ownership**: Security rules enforce that `users/{uid}/fcm_tokens/{tokenId}` can only be read or modified by the authenticated owner user.
