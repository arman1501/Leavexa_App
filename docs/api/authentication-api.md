# Authentication API Specification

## 1. Overview

The Leavexa Authentication API encapsulates all identity, sign-in, registration, session restoration, and credential recovery operations. It is centralized in [`lib/services/auth_service.dart`](file:///Users/Arman/Desktop/leavexa/lib/services/auth_service.dart) and consumed by [`lib/repositories/auth_repository.dart`](file:///Users/Arman/Desktop/leavexa/lib/repositories/auth_repository.dart).

All operations interface with **Firebase Authentication** for identity verification, followed by mandatory profile validation against the Cloud Firestore `users/{uid}` document.

---

## 2. API Operations

### A. Primary Sign-In: `loginAndGetProfile`

Authenticates a user via institutional email and password, fetches their Firestore profile, verifies account activity and approval status, and prepares the user model for routing.

- **Dart Interface**: `Future<UserModel> loginAndGetProfile({required String email, required String password})`
- **Underlying Protocol**: `FirebaseAuth.signInWithEmailAndPassword` followed by Firestore `users/{uid}.get()`.
- **Inputs**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `email` | `String` | Yes | Institutional email address (e.g., `faculty@university.edu`). |
  | `password` | `String` | Yes | User account password. |
- **Validation Pipeline**:
  1. Authenticates against Firebase Auth.
  2. Fetches `users/{uid}` from Firestore.
  3. Checks `profile.role` against known roles (`faculty`, `department_head`, `registrar`, `admin`).
  4. For Faculty: verifies `approvalStatus == 'approved'` and `isActive == true`.
  5. For Staff/Admin: verifies `isActive == true`.
- **Success Response**: Returns authenticated and validated [`UserModel`](file:///Users/Arman/Desktop/leavexa/lib/models/user_model.dart).
- **Error Exceptions (`AuthException`)**:
  - `invalid-credentials`: Email/password mismatch.
  - `user-not-found`: User does not exist in Firebase Auth.
  - `missing-profile`: Auth record exists, but Firestore `users/{uid}` profile is missing.
  - `pending-approval`: Faculty registration is awaiting Administrator approval.
  - `account-rejected`: Faculty registration was rejected by Administrator.
  - `account-inactive`: Account has been deactivated by Administrator.
  - `network-error`: Device is offline or Firebase servers unreachable.

---

### B. Faculty Self-Registration: `registerFaculty`

Performs end-to-end faculty registration: creates a Firebase Auth user, commits an atomic registration transaction in Firestore, and automatically signs out the user until administrative approval.

- **Dart Interface**:
  ```dart
  Future<void> registerFaculty({
    required String fullName,
    required String employeeId,
    required String email,
    required String phone,
    required String departmentName,
    required String designation,
    required String password,
  })
  ```
- **Inputs**:
  | Field | Type | Description |
  | :--- | :--- | :--- |
  | `fullName` | `String` | Legal name of the faculty member. |
  | `employeeId` | `String` | Unique university employee ID (e.g., `FAC-1024`). |
  | `email` | `String` | Institutional email address. |
  | `phone` | `String` | Primary contact number. |
  | `departmentName` | `String` | Academic department title. |
  | `designation` | `String` | Academic position (e.g., "Assistant Professor"). |
  | `password` | `String` | Account password ($\ge 6$ characters). |
- **Atomic Registration Flow**:
  1. Calls `FirebaseAuth.createUserWithEmailAndPassword`.
  2. Normalizes `employeeId` to uppercase and formats `departmentId`.
  3. Runs Firestore transaction via `UserRepository.createFacultyUser`:
     - Reads `employee_ids/{normalizedEmployeeId}`. If present, throws `duplicate-employee-id`.
     - Writes `employee_ids/{normalizedEmployeeId}` with `{ uid: user.uid, createdAt: serverTimestamp }`.
     - Writes `users/{uid}` with `role: 'faculty'`, `approvalStatus: 'pending'`, `isActive: false`.
  4. If the Firestore write fails, the created Firebase Auth user is immediately deleted (rollback).
  5. Signs out the user immediately (`_firebaseAuth.signOut()`) to prevent unapproved session usage.
- **Error Exceptions**:
  - `email-already-in-use`: Email is already registered.
  - `duplicate-employee-id`: Employee ID is already reserved in `employee_ids`.
  - `weak-password`: Password is less than 6 characters.

---

### C. Google OAuth Sign-In: `signInWithGoogle`

Authenticates via Google Sign-In (`GoogleSignIn.instance.authenticate()`), exchanges OAuth tokens for Firebase credentials, and verifies whether the user is an active registered institution member.

- **Dart Interface**: `Future<UserModel> signInWithGoogle()`
- **Security & Registration Policy**:
  - *No Auto-Registration*: If no matching `users/{uid}` document exists in Firestore, Leavexa **immediately signs out** the Google session and throws `AuthException(code: 'google-no-account')`.
  - Prompts unregistered users to complete the formal faculty registration form.
  - Existing registered users have their profile vetted against `isActive` and `approvalStatus`.
- **Error Exceptions**:
  - `google-sign-in-cancelled`: User closed the Google account selector.
  - `google-sign-in-failed`: Native Google Play Services / iOS SDK error.
  - `google-no-account`: Google authentication succeeded, but user is not registered in Firestore.
  - `missing-id-token`: OAuth response lacked a valid ID token.

---

### D. Session Restoration: `restoreSession`

Invoked during application boot by [`SplashScreen`](file:///Users/Arman/Desktop/leavexa/lib/screens/splash/splash_screen.dart) to check for a persisted Firebase session.

- **Dart Interface**: `Future<UserModel?> restoreSession()`
- **Behavior**:
  - If `FirebaseAuth.currentUser == null`, returns `null` (routes to Login).
  - If a user session exists, fetches and re-verifies `users/{uid}` from Firestore.
  - If the profile is valid and approved, returns `UserModel` (routes to corresponding role dashboard).
  - If the user was deactivated or rejected in the background, signs out the session and throws `AuthException`.

---

### E. Password Reset: `sendPasswordReset`

Dispatches a password reset email to the specified address.

- **Dart Interface**: `Future<void> sendPasswordReset(String email)`
- **Enumeration Protection**:
  - If Firebase Auth returns `user-not-found`, the exception is swallowed silently and returns success.
  - Prevents attackers from harvesting valid institutional email addresses by observing error responses.

---

### F. Dual Sign-Out: `signOut`

Comprehensively terminates active sessions across both authentication providers.

- **Dart Interface**: `Future<void> signOut()`
- **Behavior**:
  - Clears in-memory cached `_currentUserModel`.
  - Signs out of Google Sign-In adapter (`_googleAdapter.signOut()`).
  - Signs out of Firebase Auth (`_firebaseAuth.signOut()`).
