# FCM Device Token Management & Lifecycle

## 1. Multi-Device Token Subcollection Schema

To enable professors and administrative staff to receive push alerts across multiple phones, tablets, and desktop workstations simultaneously, device tokens are stored in a dedicated subcollection under each user document.

### Path
`/users/{uid}/fcm_tokens/{tokenId}`

### Document ID Strategy
The document ID is the first 32 characters of the SHA-256 hash of the device token string:
`tokenId = sha256(token).substring(0, 32)`
This ensures deterministic updates, prevents special-character escaping issues in document paths, and guarantees idempotent overwrites during token refreshes.

### Document Fields
```typescript
interface FcmTokenDocument {
  token: string;              // Full registration token string
  platform: 'android' | 'ios' | 'web' | 'macos' | 'windows' | 'linux';
  deviceModel: string;        // e.g., 'Pixel 8 Pro', 'iPhone 15,2', 'Chrome Mac'
  createdAt: Timestamp;       // Initial registration timestamp
  lastSeenAt: Timestamp;      // Last login or token refresh timestamp
}
```

---

## 2. Client Lifecycle Operations: [`FcmService`](file:///Users/Arman/Desktop/leavexa/lib/services/fcm_service.dart)

### A. Token Registration (`registerDeviceToken`)
- Invoked automatically upon:
  1. Successful email/password login (`AuthRepository.loginAndGetProfile`)
  2. Successful Google Sign-In (`AuthRepository.signInWithGoogle`)
  3. Session restoration on app startup (`AuthRepository.restoreSession`)
- Retrieves the current token via `FirebaseMessaging.instance.getToken()`.
- Writes or merges the token document with `lastSeenAt: FieldValue.serverTimestamp()`.

### B. Token Refresh Handling (`onTokenRefresh`)
- Subscribes to `FirebaseMessaging.instance.onTokenRefresh`.
- If Firebase Messaging rotates the device token (e.g. app restoration or security update), the service updates Firestore immediately with the new token.

### C. Token Cleanup on Logout (`unregisterDeviceToken`)
- Invoked when the user taps Sign Out (`AuthRepository.logout()`).
- Deletes the specific device token document from `users/{uid}/fcm_tokens/{tokenId}` before destroying the local session.
- **Privacy Guarantee**: Ensures the device no longer receives push notifications intended for that user once logged out.

---

## 3. Server-Side Stale & Expired Token Pruning

When Cloud Functions dispatch multicast notifications via `admin.messaging().sendEachForMulticast(message)`:

```javascript
const invalidDocIds = [];
response.responses.forEach((resp, idx) => {
  if (!resp.success && resp.error) {
    const code = resp.error.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/mismatched-credential'
    ) {
      invalidDocIds.push(tokenDocs[idx].id);
    }
  }
});

// Automatic Firestore cleanup batch
if (invalidDocIds.length > 0) {
  const batch = db.batch();
  invalidDocIds.forEach((docId) => {
    batch.delete(db.collection('users').doc(recipientUid).collection('fcm_tokens').doc(docId));
  });
  await batch.commit();
}
```

### Handled Error Codes
- `messaging/registration-token-not-registered`: The app was uninstalled or the user cleared app data.
- `messaging/invalid-registration-token`: The token format is malformed or obsolete.
- `messaging/mismatched-credential`: The token belongs to a different sender ID.
