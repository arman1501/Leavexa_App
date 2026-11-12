# LEAVEXA Production Readiness Report

**Current Verdict**: **PARTIAL — Not Fully Production Ready (Spark Plan Preserved)**

## Status Matrix

| Component | Status | Notes |
|---|---|---|
| 12 Institutional Accounts (Auth + Firestore + Claims) | **COMPLETE & VERIFIED (Production)** | All 12 active, Admin UID `0PpyKNwpZNafypFXClFiVZEseFh2` preserved, live sign-in verified. |
| Firestore Security Rules (`firestore.rules`) | **DEPLOYED & VERIFIED (Production)** | 12-email allowlist, `diff().hasOnly()`, 10-dept isolation active in `leavexa`. |
| Firestore Composite Indexes (`firestore.indexes.json`) | **DEPLOYED & VERIFIED (Production)** | All 4 composite indexes deployed on `leavexa`. |
| Flutter App & Phase 20 Fixes | **LOCALLY TESTED (`212/212`)** | Synced attachment `applicationId`, SharePrefs Save Draft, dynamic Dept Calendar, Profile copy, Registrar notifications. |
| Cloud Functions (`functions/`) | **BLOCKED BY SPARK / BILLING** | `cloudfunctions.googleapis.com` disabled (`403 SERVICE_DISABLED`); `59/59` unit & `85/85` Emulator E2E passed. |
| Firebase Storage & `storage.rules` | **BLOCKED BY CONSOLE / BILLING** | `leavexa.firebasestorage.app` not initialized in Console; verified in Storage Emulator. |
| Live Push Notifications & Physical Device QA | **NOT VERIFIED** | Requires Blaze Cloud Functions deployment, Storage init, and physical device walkthrough. |

## Go-Live Checklist (Requires User Billing Approval)
1. Upgrade `leavexa` to **Blaze** and set a **Billing Budget Alert**.
2. Initialize **Firebase Storage** in Firebase Console (`leavexa.firebasestorage.app`).
3. Run `firebase deploy --only storage,functions --project leavexa`.
4. Configure Android release keystore (`android/key.properties`) and iOS APNs `.p8` key.
5. Run physical Android/iOS acceptance testing across all 4 roles and 12 institutional accounts.
