# LEAVEXA Security Architecture

## Multi-Layer Defense-in-Depth
1. **Strict 12-Account Institutional Allowlist**:
   - Enforced across Flutter (`AppConstants.institutionalAccountAllowlist` in `lib/core/constants/app_constants.dart`), Cloud Functions (`INSTITUTIONAL_ALLOWLIST` in `functions/src/roles.js`), `firestore.rules`, and `storage.rules`.
   - Unknown emails cannot access `admin`, `registrar`, or `department_head` roles, even with forged Custom Claims.
   - Institutional emails cannot self-register as `faculty` or be transferred via department transfer.
2. **Authentication & Session Revalidation (`AuthService`)**:
   - Passwords are verified exclusively by Firebase Authentication (never stored in Firestore or Flutter code).
   - Login/restore validates Firebase Auth email vs Firestore `/users/{uid}`, Custom Claims vs Firestore profile, `approvalStatus == 'approved'`, and `isActive == true`.
   - `restoreSession()` calls `firebaseUser.reload()` and `getIdTokenResult(true)` to revoke disabled or modified sessions immediately.
   - Login errors use non-enumerating messages (`Invalid email or password.`).
3. **10-Department Isolation**:
   - `isConsistentDeptHead()` in `firestore.rules` and `isDeptHeadForApp()` in `storage.rules` require matching non-empty `departmentId` in both Auth token claims and `/users/{uid}`.
   - Department Heads can only read/review `leave_applications` and `leave_documents` matching their exact `departmentId`.
4. **Workflow Integrity (`diff().hasOnly()`)**:
   - Department Heads can only update `status` (`pending -> forwarded | rejected`), `headUid`, `headComment`, and `headActionAt`.
   - Registrars can only read `forwarded`/`approved`/`rejected` applications (never unforwarded `pending`) and cannot overwrite Head review fields.
   - `audit_logs`, `system_config`, and `leave_balances` client writes are denied (`allow write: if false`).
5. **Storage Security (`storage.rules`)**:
   - `leave_documents/{uid}/{appId}/{filename}`: `<= 10 MB`, PDF/PNG/JPEG only (verified via magic-byte header inspection in `StorageService`), immutable (`allow update: if false`), and tied to synchronized `applicationId`.
   - `profile_images/{uid}/{filename}`: `<= 5 MB`, image MIME types only, owner or Admin only.
