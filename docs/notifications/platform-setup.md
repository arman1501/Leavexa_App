# Android & iOS Platform Setup Reference

## 1. Android Configuration

### A. Manifest Permissions & Services ([`android/app/src/main/AndroidManifest.xml`](file:///Users/Arman/Desktop/leavexa/android/app/src/main/AndroidManifest.xml))
The following permissions and metadata elements are configured:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:label="Leavexa"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- Default High Importance Notification Channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="leavexa_high_importance_channel" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/ic_launcher" />
        ...
```

### B. Android 13+ Runtime Permission Handling
- Starting in Android 13 (API level 33), notifications require explicit runtime user consent.
- Handled automatically by `FcmService.requestNotificationPermissions()`.

### C. Android Notification Channel
- Channel ID: `leavexa_high_importance_channel`
- Channel Name: `Leavexa Notifications`
- Importance: `High` (displays heads-up banner and sounds alert).

---

## 2. iOS Configuration & APNs Prerequisites

### A. Information Property List ([`ios/Runner/Info.plist`](file:///Users/Arman/Desktop/leavexa/ios/Runner/Info.plist))
Background notification handling requires the `remote-notification` background mode:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### B. Apple Developer Portal Prerequisites (Production Setup)
1. **Apple Push Notification Service (APNs) Authentication Key**:
   - Generate a `.p8` APNs Authentication Key in the Apple Developer Member Center (`Keys` section).
   - Record the Key ID (10 characters) and Apple Team ID (10 characters).
2. **Firebase Console Upload**:
   - Navigate to **Firebase Console $\rightarrow$ Project Settings $\rightarrow$ Cloud Messaging $\rightarrow$ Apple app configuration**.
   - Upload the `.p8` key and specify Key ID and Team ID.
3. **App Capabilities in Xcode**:
   - Enable **Push Notifications** under `Signing & Capabilities`.
   - Enable **Background Modes** with `Remote notifications` and `Background fetch` checked.

> [!IMPORTANT]
> **Physical Device Constraint**: iOS push notification delivery cannot be tested on the iOS Simulator because Apple does not provision real APNs device tokens for simulated hardware. Real push delivery must be verified on a registered physical iPhone with an active Apple Developer Team profile.

---

## 3. Background Message Processing Requirements

To ensure message handling works even when the app is minimized or backgrounded:
1. `FirebaseMessaging.onBackgroundMessage` is registered at the entry point in [`lib/main.dart`](file:///Users/Arman/Desktop/leavexa/lib/main.dart) before `runApp`.
2. The handler function [`firebaseMessagingBackgroundHandler`](file:///Users/Arman/Desktop/leavexa/lib/services/fcm_service.dart#L17-L28) is annotated with `@pragma('vm:entry-point')` so Flutter's tree shaker preserves it for the isolated background Dart VM.
