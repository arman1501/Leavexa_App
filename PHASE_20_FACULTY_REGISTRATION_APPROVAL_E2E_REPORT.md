# Leavexa Phase 20 — Faculty Registration & Admin Approval E2E Verification Report

**Date**: 2026-11-10  
**Environment**: Local Firebase Emulator Suite (Auth: `127.0.0.1:9099`, Firestore: `127.0.0.1:8088`, Functions: `127.0.0.1:5001`, Storage: `127.0.0.1:9199`)  
**Project ID**: `leavexa`  
**Execution Target**: Actual Emulator Suite & Headless Flutter Engine  

---

## 1. Executive Summary

Following the Phase 19.1 fix for the Faculty Registration Firestore `PERMISSION_DENIED` issue (which resolved employee ID casing serialization mismatches and length boundary handling), Phase 20 performed a rigorous end-to-end audit and test execution of the entire Faculty lifecycle:
1. **Faculty Registration**: Verified via live Firebase Auth + Firestore transactions and the Flutter `RegisterScreen` UI.
2. **Pending Account State**: Verified security isolation preventing unapproved users from creating leave applications, accessing administrative endpoints, or bypassing the login gate.
3. **Admin Verification & Cloud Functions**: Verified query of pending faculty, inspection of submitted details, and authoritative approval execution via `approveFacultyRegistrationHandler`.
4. **Faculty Activation**: Verified profile status change to `approved` / `isActive: true`, provisioning of annual leave balance allocations across 7 leave types, dispatch of in-app notification, and Firebase Auth Custom Claims synchronization (`{ role: 'faculty', approvalStatus: 'approved', departmentId: 'dept_cse' }`).
5. **Negative Test Matrix**: Verified rejection of duplicate employee IDs, duplicate emails, invalid employee IDs (< 3 or > 30 chars), unapproved leave creation, unauthorized escalation, and unauthorized approval execution.

---

## 2. Test Account Identification

| Entity | Field | Verified Value |
| :--- | :--- | :--- |
| **Admin Test Account** | UID | `admin_e2e_test` |
| | Email | `admin.e2e@leavexa.edu` |
| | Role / Claims | `{ role: 'admin', approvalStatus: 'approved' }` |
| **Faculty Lifecycle Test Account** | UID | `faculty_e2e_1794279534204` / `faculty_e2e_new` |
| | Email | `faculty.e2e.1794279534204@leavexa.edu` |
| | Employee ID | `FAC-E2E-2720` (entered lowercase, normalized to uppercase) |
| | Department | `dept_cse` (`Computer Science & Engineering`) |
| | Designation | `Assistant Professor` |
| | Initial Role | `faculty` |
| | Initial Status | `approvalStatus: 'pending'`, `isActive: false` |
| | Profile Photo | `photoUrl: null` (profile photo completely optional) |

*(Note: Passwords are never logged or stored in reports in accordance with security guidelines).*

---

## 3. End-to-End Workflow Verification Results

### Step 1: Faculty Registration
- **Auth Creation**: Successfully created in Firebase Auth Emulator (`admin.auth().createUser()`). Initial Auth record has no elevated custom claims (`customClaims: {}`), `disabled: false`, `emailVerified: false`.
- **Atomic Profile & Reservation Creation**:
  - `employee_ids/FAC-E2E-2720` created with `{ uid: faculty_uid }`.
  - `users/{uid}` created with:
    ```json
    {
      "uid": "faculty_e2e_...",
      "fullName": "Dr. New Faculty Member",
      "email": "faculty.e2e....@leavexa.edu",
      "employeeId": "FAC-E2E-2720",
      "departmentId": "dept_cse",
      "departmentName": "Computer Science & Engineering",
      "designation": "Assistant Professor",
      "role": "faculty",
      "phone": "+8801700000000",
      "approvalStatus": "pending",
      "isActive": false,
      "photoUrl": null
    }
    ```
- **UI Registration Experience**:
  - `RegisterScreen`: Entered mixed-case `fac-cse-909`. Form submission auto-normalized to `FAC-CSE-909`.
  - SnackBar confirmed: `"Registration successful! Your account is pending admin approval."`.
  - User was automatically signed out pending administrator approval.

### Step 2: Pending Account Experience & Security Enforcement
- **Login Rejection**: Calling `loginAndGetProfile()` for a pending faculty user correctly throws `AuthErrorCode.pendingApproval` with message:
  `"Your registration is pending administrator approval."`.
- **UI State**: The user remains on the Login screen; navigation to the Faculty Dashboard is strictly prohibited.
- **Security Rules Enforcement**:
  - Pending faculty attempting to create a document in `leave_applications` is rejected with `PERMISSION_DENIED` (`isApprovedAndActive()` evaluates to `false`).
  - Access to `system_config`, `audit_logs`, or other users' profiles is rejected with `PERMISSION_DENIED`.

### Step 3: Admin Verification & Cloud Function Approval
- **Admin Query**:
  - Admin queries `users` with `approvalStatus == 'pending'`. The newly registered faculty user appears in the pending query with full details (`fullName`, `email`, `employeeId`, `departmentName`, `designation`).
- **Approval Execution**:
  - Admin invokes `approveFacultyRegistrationHandler({ targetUid: faculty_uid }, { auth: { uid: 'admin_e2e_test', token: { role: 'admin' } } })`.
  - Result: `{ success: true, targetUid: faculty_uid, message: "Faculty ... approved, balances provisioned, and custom claims updated." }`.

### Step 4: Faculty Activation Verification
- **Firestore Profile Update**:
  - `approvalStatus` transitioned to `'approved'`.
  - `isActive` transitioned to `true`.
  - `approvedBy` stamped as `'admin_e2e_test'`.
  - `approvedAt` and `updatedAt` server timestamps recorded.
- **Leave Balance Initialization**:
  - 7 annual leave allocations provisioned in `leave_balances`:
    - `casual` (10 days allotted, 0 used)
    - `medical` (14 days allotted, 0 used)
    - `sick` (14 days allotted, 0 used - compatibility alias)
    - `earned` (30 days allotted, 0 used)
    - `duty` (14 days allotted, 0 used)
    - `station` (5 days allotted, 0 used)
    - `study` (30 days allotted, 0 used)
- **Notification Delivery**:
  - Notification created in `notifications` collection:
    `{ recipientUid: faculty_uid, type: 'approval', isRead: false, title: 'Account Approved!' }`.
- **Custom Claims Synchronization**:
  - Firebase Auth Custom Claims updated to:
    `{ role: 'faculty', approvalStatus: 'approved', departmentId: 'dept_cse' }`.
- **Application Capabilities**:
  - Once approved, the faculty user submits a leave application in `leave_applications`. The transaction succeeds with `assertSucceeds`!
  - `FacultyDashboard` renders clean circular initials avatar via `AppAvatar` (`photoUrl` is `null`).
  - `ProfileScreen` renders full faculty details without requiring a photo upload.

---

## 4. Negative Test Matrix

| # | Test Scenario | Expected Result | Actual Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| **5.1** | Duplicate Employee ID Reservation | Security rules reject reservation of an already claimed ID | `PERMISSION_DENIED` | **PASS** |
| **5.2** | Duplicate Email in Auth | Firebase Auth rejects duplicate email registration | `auth/email-already-exists` | **PASS** |
| **5.3** | Invalid Employee ID (< 3 chars) | Security rules reject `size() < 3` (`'AB'`) | `PERMISSION_DENIED` | **PASS** |
| **5.4** | Invalid Employee ID (> 30 chars) | Security rules reject `size() > 30` (35 chars) | `PERMISSION_DENIED` | **PASS** |
| **5.5** | Unapproved Leave Application | Pending faculty cannot create leave application | `PERMISSION_DENIED` | **PASS** |
| **5.6** | Faculty Admin Operation Escalation | Faculty writing to `system_config` / `audit_logs` | `PERMISSION_DENIED` | **PASS** |
| **5.7** | Unauthorized Profile Approval | Non-admin calling `approveFacultyRegistrationHandler` | `permission-denied` (HttpsError) | **PASS** |
| **5.8** | Unauthenticated Profile Approval | Unauthenticated caller to Cloud Function | `unauthenticated` (HttpsError) | **PASS** |

---

## 5. Comprehensive Test Execution Log

```
1. Live Firebase Emulator Lifecycle Suite (Mocha):
   test/security/faculty_lifecycle_emulator_e2e_test.js
   ✔ 1.1 Creates Firebase Auth account with verified email credentials
   ✔ 1.2 Creates Firestore profile and normalizes Employee ID to uppercase with pending/inactive status
   ✔ 2.1 Unapproved pending Faculty cannot create leave applications
   ✔ 2.2 Unapproved pending Faculty cannot access system_config, audit_logs or other users
   ✔ 3.1 Admin queries pending registrations and verifies submitted information
   ✔ 3.2 Admin approves the Faculty account using secure Cloud Function
   ✔ 4.1 Firestore profile reflects approved and active status with audit fields
   ✔ 4.2 Initialized annual leave balances in leave_balances collection
   ✔ 4.3 Delivered congratulations in-app notification
   ✔ 4.4 Synchronized Firebase Auth Custom Claims
   ✔ 4.5 Approved Faculty can now submit a leave application successfully
   ✔ 5.1 Duplicate Employee ID reservation attempt is denied
   ✔ 5.2 Duplicate Email in Firebase Auth is rejected
   ✔ 5.3 Invalid Employee ID (<3 characters or >30 characters) is denied by rules
   ✔ 5.4 Faculty attempting Admin-only operations is denied
   ✔ 5.5 Unauthorized non-admin attempting to approve another account via Cloud Function is rejected
   -> 16 passing (864ms)

2. Firestore Rules Emulator Suite (Mocha):
   test/security/firestore_rules_emulator_test.js
   -> 22 passing (1s)

3. Static Security Evaluation Suite:
   test/security/rules_evaluation_test.js
   -> 19 passing (all rules syntax and key checks pass)

4. Flutter E2E Workflow Tests:
   test/workflows/faculty_lifecycle_e2e_workflow_test.dart
   -> 4 passing (Registration, Pending Login, Admin Approval, Faculty Dashboard & Profile)

5. Full Flutter Application Test Suite:
   flutter test
   -> 163 passing (0 failures across all unit, widget, service, and workflow tests)

6. Flutter Static Code Analysis:
   flutter analyze --no-fatal-infos
   -> 0 errors, 0 warnings

7. Cloud Functions Backend Test Suite:
   cd functions && npm test
   -> 44 passing
```

---

## 6. Architectural and Security Conclusions

1. **Root Cause Confirmed Resolved**: The Firestore permission error during registration was completely resolved by normalizing `employeeId` to uppercase during model serialization, aligning with the reservation document path.
2. **Strict RBAC Maintained**: Registration only ever allows `role: 'faculty'`, `approvalStatus: 'pending'`, and `isActive: false`. No privilege escalation is possible from the client.
3. **Idempotent and Authoritative Approvals**: Faculty approvals are executed exclusively through the trusted Cloud Functions backend, guaranteeing that profile activation, custom claims assignment, default balance provisioning, notification dispatch, and audit logging happen atomically.
4. **Profile Photo Optionality**: The application operates with zero mandatory photo requirements across all 4 roles. Initials-based clean circular avatars render seamlessly whenever `photoUrl` is `null`.
5. **Production Isolation**: All verification was conducted strictly on the local Firebase Emulator Suite without writing to or altering any production Firebase resources.
