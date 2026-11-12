# Firebase Setup & Local Emulator Guide

## Project Configuration
- **Firebase Project ID**: `leavexa` (`73712036420`)
- **Registered Apps**: Android (`com.leavexa.leavexa`), iOS, Web (configured via `lib/firebase_options.dart` and `android/app/google-services.json`)
- **Configured Emulator Ports (`firebase.json`)**:
  - Auth: `127.0.0.1:9099`
  - Functions: `127.0.0.1:5001`
  - Firestore: `127.0.0.1:8088`
  - Storage: `127.0.0.1:9199`
  - Emulator UI: `127.0.0.1:4000`

## Environment Configuration (Local Only, Gitignored)
Copy `.env.institutional.example` to `.env.institutional` (already matched by `.gitignore` rule `.env.*`) and supply the 12 `STAFF_*_PASSWORD` variables locally before running `functions/scripts/provision_fixed_staff.js` in the Emulator.

Never commit `.env.institutional`, `*serviceAccount*.json`, `*firebase-adminsdk*.json`, `key.properties`, or `*.jks` files.

## Running Automated Emulator Suites
```bash
# Cloud Functions & FCM unit tests
npm --prefix functions test

# Hardened Rules static matrix
node test/security/rules_evaluation_test.js

# Full Firebase Emulator suite (Auth, Firestore, Functions, Storage)
firebase emulators:exec --only auth,firestore,functions,storage --project leavexa \
  "NODE_PATH=$(pwd)/functions/node_modules:$(pwd)/test/security/node_modules $(pwd)/test/security/node_modules/.bin/mocha \
  test/security/firestore_rules_emulator_test.js \
  test/security/storage_rules_emulator_test.js \
  test/security/institutional_12_accounts_emulator_test.js \
  test/security/professional_registration_stabilization_test.js \
  test/security/local_e2e_workflow_emulator_test.js"
```

## Connecting Android Debug Builds to Emulators
- **Android Virtual Emulator**: `flutter run --dart-define=USE_FIREBASE_EMULATOR=true` (uses `10.0.2.2` automatically).
- **Physical Android Device via USB/ADB**:
  ```bash
  adb reverse tcp:9099 tcp:9099 && adb reverse tcp:8088 tcp:8088 && adb reverse tcp:5001 tcp:5001 && adb reverse tcp:9199 tcp:9199
  flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=EMULATOR_HOST=127.0.0.1
  ```
