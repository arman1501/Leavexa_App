# Notification Setup (FCM, Android & iOS APNs)

## 1. Android Notification Channel (Implemented)
- **Channel ID**: `leavexa_high_importance_channel`
- **Manifest Meta-Data**: `android/app/src/main/AndroidManifest.xml` declares `POST_NOTIFICATIONS` and `com.google.firebase.messaging.default_notification_channel_id = leavexa_high_importance_channel`.
- **Native Registration**: `android/app/src/main/kotlin/com/leavexa/leavexa/MainActivity.kt` registers `NotificationChannel("leavexa_high_importance_channel", "LEAVEXA Leave Alerts", NotificationManager.IMPORTANCE_HIGH)` in `onCreate()` only if the channel does not already exist (preventing duplicate channels).

## 2. iOS APNs Configuration Preparation
- `ios/Runner/Info.plist` includes `UIBackgroundModes` with `fetch` and `remote-notification`.
- `ios/Runner/Runner.entitlements` has been prepared with `<key>aps-environment</key><string>development</string>`.
- **Required Manual Steps Before iOS Release**:
  1. Open `ios/Runner.xcworkspace` in Xcode -> **Signing & Capabilities** -> add **Push Notifications** (links `Runner.entitlements`; switch `aps-environment` to `production` for App Store/TestFlight archive).
  2. In Apple Developer Portal -> **Certificates, Identifiers & Profiles -> Keys**, create an **Apple Push Notifications service (APNs)** `.p8` key and record the **Key ID** and **Team ID**.
  3. In **Firebase Console -> Project Settings -> Cloud Messaging -> Apple app configuration**, upload the `.p8` key along with your **Key ID** and **Team ID**.

## 3. Client & Backend Notification Architecture
- **Client (`lib/services/fcm_service.dart`)**: Requests OS permission, computes SHA-256 `tokenDocId`, registers per-device tokens under `users/{uid}/fcm_tokens/{docId}`, handles `onTokenRefresh`, cleans up only the signing-out device token on logout, and routes deep links (`leave_submitted`, `leave_forwarded`, `approval`, `rejection`, `leave_cancelled`, `registration_pending`).
- **Backend (`functions/src/notifications.js`)**: Role-based multicast to Department Head / Registrars / Admins, per-device delivery tracking, stale token pruning, idempotency locks (`notification_events`), and 30-day retention pruning (`processNotificationRetries`).

## 4. Verification Status
- **Verified**: Android manifest/channel registration, iOS Info.plist/entitlements presence, and **59/59** Functions/FCM mock & unit tests.
- **Not Yet Verified**: Live end-to-end push delivery on physical Android/iOS hardware (requires deploying Cloud Functions on Blaze + real APNs `.p8` key for iOS).
