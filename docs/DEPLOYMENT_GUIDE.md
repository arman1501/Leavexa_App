# LEAVEXA Deployment Guide

## Prerequisites
1. Firebase CLI authenticated (`firebase login`) with Owner/Editor permissions on project `leavexa`.
2. **Spark Plan Capabilities**:
   - Firebase Authentication (12 institutional accounts + Faculty)
   - Cloud Firestore database, `firestore.rules`, and `firestore.indexes.json`
3. **Blaze Plan Required Capabilities**:
   - Cloud Functions (`cloudfunctions.googleapis.com`, `cloudbuild.googleapis.com`, `artifactregistry.googleapis.com`, `cloudscheduler.googleapis.com`, `pubsub.googleapis.com`)
   - Firebase Storage initialization (`leavexa.firebasestorage.app` bucket provisioning in Firebase Console)

## Current Deployment Status
- **Deployed on Spark**:
  - `firestore.rules` (`firebase deploy --only firestore:rules --project leavexa`)
  - `firestore.indexes.json` — 4 composite indexes (`firebase deploy --only firestore:indexes --project leavexa`)
  - 12 institutional Auth & Firestore accounts provisioned via `functions/scripts/provision_fixed_staff.js`
- **Pending Blaze / Console Initialization**:
  1. Upgrade project `leavexa` to Blaze in Firebase Console and configure a GCP Billing Budget Alert (e.g., \$2/month) + Artifact Registry cleanup policy.
  2. Open Firebase Console -> **Storage** -> **Get Started** to initialize `leavexa.firebasestorage.app`.
  3. Deploy Storage Rules:
     ```bash
     firebase deploy --only storage --project leavexa
     ```
  4. Deploy Cloud Functions:
     ```bash
     firebase deploy --only functions --project leavexa
     ```

## Release APK Signing Note
`android/app/build.gradle.kts` currently references `signingConfigs.getByName("debug")` for `release`. Before publishing a production APK/AAB, create a dedicated release keystore outside git, configure `android/key.properties` (gitignored), and update `signingConfigs` in `android/app/build.gradle.kts`.
