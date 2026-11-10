# User Management & Provisioning API Specification

## 1. Overview

User management operations in Leavexa govern the creation, profiling, role assignment, and lifecycle activation of institutional accounts across the four academic roles: **Faculty**, **Department Head**, **Registrar**, and **Administrator**.

The architecture enforces a strict security boundary:
- **Client SDKs** are restricted to updating personal contact details (`phone`, `photoUrl`).
- **Privileged Staff Accounts & Status Changes** are executed exclusively through server-side Cloud Functions or Admin transactions.

---

## 2. Client-Side Operations: [`UserRepository`](file:///Users/Arman/Desktop/leavexa/lib/repositories/user_repository.dart)

### A. Atomic Faculty Profile Creation: `createFacultyUser`
- **Method**: `Future<void> createFacultyUser(UserModel user)`
- **Behavior**: Executes an atomic Firestore transaction creating both the uniqueness mutex in `employee_ids/{normalizedEmployeeId}` and the user profile in `users/{uid}`.
- **Enforcement**: [`firestore.rules`](file:///Users/Arman/Desktop/leavexa/firestore.rules) lines 92–102 and 136–145 verify cross-document existence (`existsAfter` / `getAfter`).

### B. User Profile Queries & Streaming
- **Fetch Profile**: `Future<UserModel?> getUserById(String uid)`
  - Reads `users/{uid}`. Returns parsed `UserModel` or `null`.
- **Stream Profile**: `Stream<UserModel?> streamUserById(String uid)`
  - Real-time document listener on `users/{uid}` for immediate UI reactivity when an admin approves or updates an account.

### C. Personal Contact Update: `updateUser`
- **Method**: `Future<void> updateUser(String uid, Map<String, dynamic> data)`
- **Allowed Keys**: Only personal contact info (e.g. `phone`, `photoUrl`).
- **Security Check**: Enforced by `firestore.rules` line 108. An ordinary faculty user attempting to update `role`, `approvalStatus`, `isActive`, `employeeId`, or `departmentId` is rejected with `PERMISSION_DENIED`.

---

## 3. Server-Side Cloud Function Endpoints

### A. Staff Account Creation: `createStaffAccount`

Provisions a new Department Head or Registrar account. Can only be invoked by an active, approved Administrator.

- **Type**: HTTPS Callable Function (`functions.https.onCall`)
- **Authorization**: Caller must have `role == 'admin'` in `context.auth.token` or in `users/{context.auth.uid}`.
- **Request Parameters (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `email` | `String` | Yes | Staff member's institutional email address. |
  | `password` | `String` | Yes | Initial login password ($\ge 6$ characters). |
  | `fullName` | `String` | Yes | Full legal name. |
  | `employeeId` | `String` | Yes | Unique employee ID. |
  | `role` | `String` | Yes | Must be `'department_head'` or `'registrar'`. |
  | `departmentId` | `String` | Cond. | Required if `role == 'department_head'` (e.g., `'dept_cse'`). |
  | `departmentName`| `String` | Cond. | Required if `role == 'department_head'`. |
  | `designation` | `String` | No | Job title (defaults to role title). |
  | `phone` | `String` | No | Contact telephone number. |
- **Execution Pipeline**:
  1. Validates admin permissions via `assertIsAdmin(context)`.
  2. Checks `employee_ids/{employeeId}` for uniqueness.
  3. Creates Firebase Auth user via `auth.createUser(...)`.
  4. Assigns Firebase Custom Claims: `{ role, approvalStatus: 'approved', departmentId }`.
  5. Writes `users/{newUid}` profile document and `employee_ids/{employeeId}` record in an atomic batch.
  6. Appends audit log entry (`action: 'STAFF_ACCOUNT_CREATED'`).
- **Success Response**:
  ```json
  {
    "success": true,
    "uid": "new_staff_uid_12345",
    "message": "department_head account created successfully with custom claims."
  }
  ```
- **Error Exceptions**:
  - `unauthenticated`: Caller is not logged in.
  - `permission-denied`: Caller is not an active Administrator.
  - `invalid-argument`: Missing required fields, invalid role, or missing department info.
  - `already-exists`: Employee ID is already registered.

---

### B. Account Activation & Deactivation: `setUserActive`

Toggles an account's active state. Deactivating an account disables the Firebase Auth record and updates the Firestore profile, immediately preventing further system access.

- **Type**: HTTPS Callable Function
- **Authorization**: Administrator only.
- **Request Parameters (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `targetUid` | `String` | Yes | UID of the user account being modified. |
  | `isActive` | `Boolean` | Yes | Desired state (`true` for active, `false` for inactive). |
- **Safety Rule**:
  - Prevents administrator self-deactivation: `if (targetUid === context.auth.uid && !isActive)` throws `failed-precondition`.
- **Side Effects**:
  - Updates Firebase Auth: `auth.updateUser(targetUid, { disabled: !isActive })`.
  - Updates Firestore: `users/{targetUid}` with `{ isActive, updatedAt, updatedBy }`.
  - Appends audit log: `action: 'USER_ACTIVATED'` or `'USER_DEACTIVATED'`.
- **Success Response**:
  ```json
  {
    "success": true,
    "targetUid": "faculty_uid_to_toggle",
    "isActive": false
  }
  ```

---

### C. Custom Claims Synchronization: `syncUserCustomClaims`

Aligns Firebase Auth Custom Claims (`role`, `approvalStatus`, `departmentId`) with the authoritative Firestore profile document.

- **Type**: HTTPS Callable Function
- **Authorization**: Administrator, or the authenticated user synchronizing their own account.
- **Request Parameters (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `targetUid` | `String` | No | Defaults to caller's UID if omitted. |
- **Success Response**:
  ```json
  {
    "success": true,
    "claims": {
      "role": "faculty",
      "approvalStatus": "approved",
      "departmentId": "dept_cse"
    }
  }
  ```

---

### D. Employee ID Availability Verification: `checkEmployeeId`

Pre-checks whether a proposed Employee ID is available for registration against the internal uniqueness registry.

- **Type**: HTTPS Callable Function
- **Authorization**: Public / Unauthenticated allowed (used during initial registration typing).
- **Request Parameters (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `employeeId` | `String` | Yes | Proposed ID to evaluate (e.g., `'FAC-1024'`). |
- **Success Response**:
  ```json
  {
    "isAvailable": true,
    "message": "Employee ID FAC-1024 is available for reservation.",
    "limitationNotice": "Employee IDs are checked for system uniqueness and atomic reservation, but not validated against external university HR records."
  }
  ```
