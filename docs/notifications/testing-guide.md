# Push Notification Testing & Verification Guide

## 1. Test Architecture Overview

Leavexa employs a multi-tiered testing strategy ensuring all notification paths, token mutations, and lifecycle navigations are thoroughly verified without requiring physical devices during automated CI/CD runs:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       NOTIFICATION VERIFICATION SUITE                       │
├────────────────────────┬────────────────────────────────────────────────────┤
│ Test Level             │ Test Suite & Framework                             │
├────────────────────────┼────────────────────────────────────────────────────┤
│ Flutter Unit & Widget  │ test/services/fcm_service_test.dart (flutter_test) │
│ Cloud Functions Unit   │ functions/test/notifications.test.js (Mocha / Chai)│
│ Security Rules Emulator│ test/security/firestore_rules_emulator_test.js     │
└────────────────────────┴────────────────────────────────────────────────────┘
```

---

## 2. Flutter Unit & Widget Tests

### Covered Test Cases ([`test/services/fcm_service_test.dart`](file:///Users/Arman/Desktop/leavexa/test/services/fcm_service_test.dart))
1. **Token Document ID Hashing**:
   - Asserts `tokenDocId` outputs a deterministic, 32-character SHA-256 substring.
   - Verifies distinct tokens map to distinct document paths.
2. **Notification Navigation Dispatching**:
   - `leave_submitted` $\rightarrow$ Navigates to [`AppRoutes.leaveRequestDetails`](file:///Users/Arman/Desktop/leavexa/lib/core/routes/app_routes.dart) with `applicationId`.
   - `leave_forwarded` $\rightarrow$ Navigates to [`AppRoutes.finalApproval`](file:///Users/Arman/Desktop/leavexa/lib/core/routes/app_routes.dart) with `applicationId`.
   - `leave_approved` / `leave_rejected` $\rightarrow$ Navigates to [`AppRoutes.leaveDetails`](file:///Users/Arman/Desktop/leavexa/lib/core/routes/app_routes.dart).
   - `registration_pending` $\rightarrow$ Navigates to [`AppRoutes.adminDashboard`](file:///Users/Arman/Desktop/leavexa/lib/core/routes/app_routes.dart).
   - `faculty_approved` $\rightarrow$ Navigates to [`AppRoutes.facultyDashboard`](file:///Users/Arman/Desktop/leavexa/lib/core/routes/app_routes.dart).
   - Fallback / Unknown $\rightarrow$ Navigates to [`AppRoutes.notifications`](file:///Users/Arman/Desktop/leavexa/lib/core/routes/app_routes.dart).
3. **NotificationModel Robustness**:
   - Verifies handling of both ISO-8601 strings and Firestore Timestamp objects without casting exceptions.
   - Verifies `copyWith` immutability when updating `isRead` receipts.

### Command Execution
```bash
flutter test test/services/fcm_service_test.dart
```

---

## 3. Server-Side Cloud Functions Tests

### Covered Test Cases ([`functions/test/notifications.test.js`](file:///Users/Arman/Desktop/leavexa/functions/test/notifications.test.js))
1. **Multicast Message Dispatch**:
   - Tests sending across multiple registered devices simultaneously.
2. **Automatic Stale Token Pruning**:
   - Injects simulated expired tokens (`messaging/registration-token-not-registered`).
   - Asserts invalid tokens are removed from `users/{uid}/fcm_tokens` while valid tokens are preserved.
3. **Zero Token Graceful Handling**:
   - Asserts users with zero registered devices record the in-app notification without throwing exceptions.
4. **Idempotency Enforcement**:
   - Submits duplicate events with the same `idempotencyKey`; asserts the second call skips push dispatching.
5. **Role-Based Multicast Routing**:
   - `sendPushNotificationToDepartmentHead`: Verifies only the head for the specific `departmentId` is notified.
   - `sendPushNotificationToRegistrars`: Verifies delivery to active Registrars.
   - `sendPushNotificationToAdmins`: Verifies delivery to active Admins.
6. **Trigger Integration**:
   - `onLeaveApplicationCreateHandler`: Verified for leave filing $\rightarrow$ Head.
   - `onLeaveApplicationUpdateHandler`: Verified for Head forwarding $\rightarrow$ Registrar.
   - `onUserCreateHandler`: Verified for new faculty $\rightarrow$ Admins.

### Command Execution
```bash
cd functions && npm test
```

---

## 4. Security Rules Emulator Tests

### Covered Test Cases ([`test/security/firestore_rules_emulator_test.js`](file:///Users/Arman/Desktop/leavexa/test/security/firestore_rules_emulator_test.js))
- **Test 17**: Enforces `users/{uid}/fcm_tokens/{tokenId}` ownership:
  - User can create, read, and delete their own device tokens.
  - Another user attempting to create or read tokens is rejected with `PERMISSION_DENIED`.
  - Unauthenticated requests are denied.

### Command Execution
```bash
npx firebase emulators:exec --project leavexa-test-project --only firestore,storage "cd test/security && npx mocha firestore_rules_emulator_test.js"
```
