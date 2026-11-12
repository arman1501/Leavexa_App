# LEAVEXA — Final Project Report (Phase 34)

**Project**: LEAVEXA (`leavexa`)  
**Platform**: Flutter + Firebase (currently on **Spark** free plan)

---

## 1. Five-Category Completion Breakdown

### A. Implemented Locally
- **Strict 12-Account Institutional Allowlist & Session Revalidation**: `lib/core/constants/app_constants.dart`, `lib/services/auth_service.dart`, `functions/src/roles.js`, `functions/src/approvals.js`, `firestore.rules`, `storage.rules`.
- **Phase 20 Functional & UI Fixes**: Synchronized attachment `applicationId` + overwrite prevention (`apply_leave_screen.dart`, `leaves.js`), persistent user-scoped Save/Delete Draft (`SharedPreferences`), dynamic real-data `DeptCalendarScreen`, `ProfileScreen` clipboard copy actions, and `RegistrarDashboard` notifications shortcut.
- **Phase 34 Notification Platform Prep**: Android 8+ `leavexa_high_importance_channel` registration in `MainActivity.kt` (`IMPORTANCE_HIGH`, duplicate-safe) and iOS `Runner.entitlements` (`aps-environment`).
- **Complete Project Documentation**: `README.md`, `docs/ARCHITECTURE.md`, `docs/FIREBASE_SETUP.md`, `docs/SECURITY.md`, `docs/DEPLOYMENT_GUIDE.md`, `docs/INSTITUTIONAL_ACCOUNT_HANDOVER.md`, `docs/FIRESTORE_BACKUP_RECOVERY.md`, `docs/NOTIFICATION_SETUP.md`, `docs/PRODUCTION_READINESS.md`.

### B. Tested Successfully in Emulators & Automated Suites
- `flutter analyze --no-fatal-infos`: `0` errors, `0` warnings.
- `flutter test`: All unit, widget, workflow, auth, Phase 20, and notification config regression tests pass.
- `npm --prefix functions test`: Cloud Functions + FCM mock/unit tests pass (`59/59`).
- `node test/security/rules_evaluation_test.js`: Hardened `diff()` & RBAC security matrix passes (`19/19`).
- Firebase Emulator Suite (`auth, firestore, functions, storage`): Full E2E (`85/85`), including 10x10 department isolation, attachment `applicationId` sync, atomic leave balance deduction, duplicate deduction protection, and Faculty department transfer.
- Standard Debug APK (`flutter build apk --debug`): Built cleanly (`build/app/outputs/flutter-apk/app-debug.apk`).

### C. Already Deployed & Verified in Production (`leavexa`)
- All **12 designated institutional accounts** provisioned/reconciled with matching Auth Custom Claims, Firestore `/users/{uid}`, `/employee_ids/{empId}`, and `/departments/{deptId}` (existing Admin UID `0PpyKNwpZNafypFXClFiVZEseFh2` preserved).
- Production `firestore.rules` deployed and active.
- All **4** composite indexes in `firestore.indexes.json` deployed and verified.

### D. Blocked by Spark / Billing
- **Cloud Functions Production Deployment**: `cloudfunctions.googleapis.com` is disabled (`HTTP 403 SERVICE_DISABLED`); requires Blaze billing.
- **Firebase Storage Initialization & `storage.rules` Deployment**: `leavexa.firebasestorage.app` is not initialized in Firebase Console (`Get Started` required; newer projects require Blaze).
- **Android Production Release Signing**: `android/app/build.gradle.kts` currently uses debug signing for `release` (requires a real release keystore outside git).

### E. Not Verified (Physical-Device Testing Excluded)
- Live end-to-end UI execution on physical Android/iOS devices.
- Live FCM push delivery on physical hardware and iOS APNs `.p8` delivery.

---

## 2. Final Production Readiness Verdict
LEAVEXA is **fully implemented and verified locally and in Firebase Emulators**, with **production institutional accounts, Firestore Rules, and Firestore Indexes deployed**, but is **not yet fully Production Ready** until Blaze billing is approved to initialize Firebase Storage and deploy Cloud Functions, followed by physical-device acceptance testing.
