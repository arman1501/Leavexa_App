# LEAVEXA — Staff Account Provisioning Report

**Project**: Leavexa Faculty Leave Management System  
**Document Version**: 1.0.0  
**Date**: 2026-11-10  
**Environment**: Firebase Local Emulator Suite (Auth: `9099`, Firestore: `8088`, Functions: `5001`)  
**Status**: **ALL ACCOUNTS PROVISIONED & VERIFIED (PASS)**

---

## 1. Executive Summary

In accordance with the LEAVEXA Security & Role-Based Access Control Architecture, three fixed administrative staff accounts have been configured, provisioned, and verified via the secure Firebase Admin SDK / Cloud Functions backend.

Public registration with these administrative email addresses is strictly prohibited across the client UI, authentication validation layers, and Firestore Security Rules.

| Account Role | Designated Email | Password Strategy | Employee ID | Department ID / Name | Auth & Profile Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Department Head** | `department.head.lu@gmail.com` | `LU_Head@63A` | `HEAD-CSE-001` | `dept_cse` (Computer Science & Engineering) | **ACTIVE & APPROVED** |
| **Registrar / Dean** | `registrar.lu@gmail.com` | `LU_Register@63A` | `REG-001` | `registrar_office` (Office of the Registrar) | **ACTIVE & APPROVED** |
| **System Admin** | `admin.lu@gmail.com` | `LU_Admin@63A` | `ADMIN-001` | `admin_office` (Office of the Administrator) | **ACTIVE & APPROVED** |

---

## 2. Admin Authentication Setup Audit Findings

### 2.1 Firebase Authentication State
- **Initial Audit**: Firebase Authentication contained synthetic E2E accounts (`admin.e2e@leavexa.edu`), but no production or designated staff accounts existed.
- **After Provisioning**: All three designated accounts exist in Firebase Authentication with verified emails and secure credentials.

### 2.2 Firestore User Profile & Role Configuration
- In Firestore, user profiles reside at `/users/{uid}`.
- Every profile includes:
  - `role`: (`admin` | `department_head` | `registrar`)
  - `approvalStatus`: `'approved'`
  - `isActive`: `true`
  - `departmentId` & `departmentName`
  - `designation`
  - `employeeId`
  - `photoUrl`: `null` (Optional across all roles)
- Employee ID uniqueness is cross-indexed in `/employee_ids/{employeeId}`.

### 2.3 How Login Email & Routing is Determined
1. **Credentials Input**: User enters email and password into `LoginScreen` (`lib/screens/auth/login_screen.dart`). No login email is hardcoded.
2. **Authentication**: `FirebaseAuth.signInWithEmailAndPassword` validates the credentials.
3. **Profile Lookup & Role Validation**: `AuthService.loginAndGetProfile()` retrieves `/users/{uid}` from Firestore and verifies that `isActive == true` and `role` matches one of `AppStrings.allRoles`.
4. **Dashboard Navigation**:
   - `department_head` $\rightarrow$ `AppRoutes.headDashboard` (`/head/dashboard`)
   - `registrar` $\rightarrow$ `AppRoutes.registrarDashboard` (`/registrar/dashboard`)
   - `admin` $\rightarrow$ `AppRoutes.adminDashboard` (`/admin/dashboard`)

---

## 3. Security Hardening & Isolation Implementation

### 3.1 Plaintext Password Protection
- Plaintext passwords are **NEVER** stored in Firestore documents, Flutter source code, GitHub repositories, or application logs.
- Provisioning engine receives passwords via environment variables (`STAFF_HEAD_PASSWORD`, `STAFF_REGISTRAR_PASSWORD`, `STAFF_ADMIN_PASSWORD`).

### 3.2 Idempotent Provisioning Engine
- The provisioning engine (`functions/scripts/provision_fixed_staff.js`) checks if each user already exists in Firebase Auth before calling `createUser`.
- Re-running the script synchronizes Firestore profiles and custom claims **without resetting or overwriting passwords**.

### 3.3 Prevention of Public Self-Registration for Reserved Emails
Attempting to register any of the reserved staff emails through Faculty self-registration is blocked at three independent layers:
1. **Form Validation** (`lib/core/utils/validators.dart` & `RegisterScreen`):
   - `Validators.facultyEmail()` checks `AppConstants.isReservedStaffEmail(email)`.
   - Returns immediate inline validation error: `"This email is reserved for administrative staff."`
2. **Pre-flight Service Guard** (`lib/services/auth_service.dart`):
   - Throws `AuthException(code: AuthErrorCode.invalidCredentials)` before initiating Auth creation.
3. **Firestore Security Rules** (`firestore.rules`):
   - Rejects document creation with gRPC Code 7 (`PERMISSION_DENIED`) if `request.resource.data.email in ['department.head.lu@gmail.com', 'registrar.lu@gmail.com', 'admin.lu@gmail.com']`.

---

## 4. Verification Test Results

### 4.1 Automated Login Verification (`signInWithPassword`)
| Test Target | Email | Result | Token Received | Firestore Verification |
| :--- | :--- | :---: | :---: | :--- |
| **Department Head** | `department.head.lu@gmail.com` | **PASS** | Valid JWT | Role: `department_head`, Department: `dept_cse`, Active: `true` |
| **Registrar** | `registrar.lu@gmail.com` | **PASS** | Valid JWT | Role: `registrar`, Department: `registrar_office`, Active: `true` |
| **Admin** | `admin.lu@gmail.com` | **PASS** | Valid JWT | Role: `admin`, Department: `admin_office`, Active: `true` |

### 4.2 Security Rules & Public Registration Blocking
- **Scenario 17**: Self-registration using reserved staff emails is rejected by security rules $\rightarrow$ **PASS** (Code 7 `PERMISSION_DENIED`).
- **Flutter Unit Tests**: Reserved email validation test $\rightarrow$ **PASS**.

---

## 5. Instructions for System Administrators

### 5.1 Logging In
1. Launch the Leavexa mobile application (or run in emulator debug mode).
2. On the **Login Screen**:
   - **For Admin**: Email `admin.lu@gmail.com`, Password `LU_Admin@63A`
   - **For Department Head**: Email `department.head.lu@gmail.com`, Password `LU_Head@63A`
   - **For Registrar**: Email `registrar.lu@gmail.com`, Password `LU_Register@63A`
3. Tap **Sign In**. The system validates credentials, reads the verified profile from Firestore, and routes directly to the authorized dashboard.

### 5.2 Re-running Provisioning or Changing Passwords
- To re-run or synchronize provisioning locally:
  ```bash
  cd functions
  node scripts/provision_fixed_staff.js
  ```
- To customize passwords during initial deployment:
  ```bash
  STAFF_HEAD_PASSWORD="CustomPassword123!" \
  STAFF_REGISTRAR_PASSWORD="CustomPassword123!" \
  STAFF_ADMIN_PASSWORD="CustomPassword123!" \
  node scripts/provision_fixed_staff.js
  ```
- In production, passwords can be rotated by the respective staff members through standard Firebase Auth password reset flows or via the Firebase Admin Console.
