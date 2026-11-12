# LEAVEXA — University Faculty Leave Management System

**LEAVEXA** is a role-based Flutter + Firebase Faculty Leave Management System built for Leading University (`leavexa`), supporting strict institutional access control, 10-department data isolation, multi-stage leave approvals, atomic leave balance accounting, and push notifications.

## Technology Stack
- **Frontend**: Flutter (Dart SDK `^3.11.0`, Material 3, Light & Dark theme)
- **Backend & Database**: Firebase Authentication, Cloud Firestore, Cloud Functions for Firebase (Node.js 22 / `firebase-functions ^5.0.0`), Firebase Storage, Firebase Cloud Messaging (FCM)
- **Local Testing**: Firebase Emulator Suite (`auth:9099`, `functions:5001`, `firestore:8088`, `storage:9199`), Flutter Test, Mocha

## Four User Roles
1. **Faculty (`faculty`)**: Self-registers with unique Employee ID, awaits Admin approval, applies for leave (with local draft persistence & attachments), tracks balances, cancels pending requests.
2. **Department Head (`department_head`)**: Exactly 10 designated department heads (`dept_cse`..`dept_english`); reviews, forwards, or rejects leave requests strictly within their own department; views department calendar & faculty directory.
3. **Registrar / Dean (`registrar`)**: Reviews Head-forwarded applications across all departments, performs final approval/rejection (never sees unforwarded `pending` applications).
4. **System Administrator (`admin`)**: Approves/rejects Faculty registrations, manages staff & department transfers, views audit trails and university info.

## Quick Local Emulator Run
```bash
# 1. Start local Firebase Emulators
firebase emulators:start --only auth,firestore,functions,storage --project leavexa

# 2. Seed 12 institutional accounts into Emulator (reads gitignored .env.institutional)
node functions/scripts/provision_fixed_staff.js

# 3. Run Flutter app against local Emulators
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

## Documentation Index
- [Architecture](docs/ARCHITECTURE.md)
- [Firebase Setup](docs/FIREBASE_SETUP.md)
- [Security Architecture](docs/SECURITY.md)
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Institutional Account Handover](docs/INSTITUTIONAL_ACCOUNT_HANDOVER.md)
- [Firestore Backup & Recovery](docs/FIRESTORE_BACKUP_RECOVERY.md)
- [Notification Setup (Android & iOS)](docs/NOTIFICATION_SETUP.md)
- [Production Readiness](docs/PRODUCTION_READINESS.md)
- [Final Project Report](docs/LEAVEXA_FINAL_PROJECT_REPORT.md)
