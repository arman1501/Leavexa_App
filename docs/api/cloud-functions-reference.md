# Firebase Cloud Functions Reference

## 1. Cloud Functions Architecture

All backend compute operations in Leavexa are centralized in the [`functions/`](file:///Users/Arman/Desktop/leavexa/functions/) directory, running on the **Firebase Functions v2 Node.js 22 runtime** with the **Firebase Admin SDK**.

Exactly **8 Cloud Functions** are registered in [`functions/index.js`](file:///Users/Arman/Desktop/leavexa/functions/index.js):
- 7 HTTPS Callable Functions (`functions.https.onCall`)
- 1 Firestore Event Trigger (`functions.firestore.document(...).onUpdate`)

---

## 2. Exhaustive Function Specifications

---

### 1. `provisionInitialAdmin`

- **Type**: HTTPS Callable (`onCall`)
- **Handler**: `functions/src/roles.js:provisionInitialAdminHandler`
- **Purpose**: Securely provisions the root system administrator and seals the initial bootstrap lock.
- **Authentication**: Caller must be authenticated in Firebase Auth (`context.auth != null`).
- **Required Role**: None (used for initial cold bootstrap).
- **Inputs (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `bootstrapKey` | `String` | Cond. | Mandatory if `LEAVEXA_BOOTSTRAP_SECRET` environment variable is set. |
  | `fullName` | `String` | No | Administrator display name (defaults to "System Administrator"). |
  | `employeeId` | `String` | No | Administrator Employee ID (defaults to "ADMIN-001"). |
  | `email` | `String` | No | Overrides token email if provided. |
- **Validation Rules**:
  1. Rejects unauthenticated callers (`unauthenticated`).
  2. If `LEAVEXA_BOOTSTRAP_SECRET` is defined on server, verifies `data.bootstrapKey === envSecret` (`permission-denied`).
  3. Checks `system_config/bootstrap` mutex. If `isBootstrapped === true` or any admin exists, rejects (`already-exists`, code 409).
- **Execution & Idempotency**: Runs inside `db.runTransaction` guaranteeing strictly single-execution semantics.
- **Collections Affected**:
  - `system_config/bootstrap`: Writes `{ isBootstrapped: true, bootstrappedAt, bootstrappedBy, adminEmail }`.
  - `users/{uid}`: Creates admin profile with `role: 'admin'`, `approvalStatus: 'approved'`, `isActive: true`.
  - `employee_ids/{employeeId}`: Reserves admin employee ID.
  - `audit_logs`: Appends `INITIAL_ADMIN_PROVISIONED` log.
- **Success Response**:
  ```json
  {
    "success": true,
    "message": "Initial administrator provisioned successfully with Admin custom claims.",
    "uid": "root_admin_uid_123"
  }
  ```
- **Error Codes**: `unauthenticated`, `permission-denied`, `already-exists`.

---

### 2. `createStaffAccount`

- **Type**: HTTPS Callable (`onCall`)
- **Handler**: `functions/src/roles.js:createStaffAccountHandler`
- **Purpose**: Creates Department Head or Registrar staff accounts.
- **Authentication**: Authenticated caller.
- **Required Role**: `admin` only (`assertIsAdmin`).
- **Inputs (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `email` | `String` | Yes | Institutional email address. |
  | `password` | `String` | Yes | Password ($\ge 6$ characters). |
  | `fullName` | `String` | Yes | Full legal name. |
  | `employeeId` | `String` | Yes | Unique university Employee ID. |
  | `role` | `String` | Yes | `'department_head'` or `'registrar'`. |
  | `departmentId` | `String` | Cond. | Mandatory if `role === 'department_head'`. |
  | `departmentName`| `String` | Cond. | Mandatory if `role === 'department_head'`. |
  | `designation` | `String` | No | Job title. |
  | `phone` | `String` | No | Phone number. |
- **Validation Rules**:
  - Employee ID must not be previously reserved in `employee_ids`.
  - Department Head must have valid department details.
- **Collections Affected**:
  - `users/{newUid}`: Created with `approvalStatus: 'approved'`, `isActive: true`.
  - `employee_ids/{employeeId}`: Reserved.
  - `audit_logs`: Appends `STAFF_ACCOUNT_CREATED`.
- **Custom Claims Assigned**:
  - Department Head: `{ role: 'department_head', approvalStatus: 'approved', departmentId }`.
  - Registrar: `{ role: 'registrar', approvalStatus: 'approved' }`.
- **Success Response**:
  ```json
  {
    "success": true,
    "uid": "new_uid",
    "message": "department_head account created successfully with custom claims."
  }
  ```
- **Error Codes**: `unauthenticated`, `permission-denied`, `invalid-argument`, `already-exists`.

---

### 3. `setUserActive`

- **Type**: HTTPS Callable (`onCall`)
- **Handler**: `functions/src/roles.js:setUserActiveHandler`
- **Purpose**: Activates or deactivates an existing user account.
- **Authentication**: Authenticated caller.
- **Required Role**: `admin` only.
- **Inputs (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `targetUid` | `String` | Yes | UID of user being updated. |
  | `isActive` | `Boolean` | Yes | Desired active status (`true` / `false`). |
- **Validation & Safety Rules**:
  - Administrator cannot deactivate their own account (`failed-precondition`).
- **Collections Affected**:
  - `users/{targetUid}`: Sets `{ isActive, updatedAt, updatedBy }`.
  - Firebase Auth: Sets `disabled = !isActive`.
  - `audit_logs`: Appends `USER_ACTIVATED` or `USER_DEACTIVATED`.
- **Success Response**:
  ```json
  {
    "success": true,
    "targetUid": "user_uid",
    "isActive": false
  }
  ```
- **Error Codes**: `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition`.

---

### 4. `syncUserCustomClaims`

- **Type**: HTTPS Callable (`onCall`)
- **Handler**: `functions/src/roles.js:syncUserCustomClaimsHandler`
- **Purpose**: Synchronizes Firebase Auth Custom Claims with verified Firestore profile data.
- **Authentication**: Authenticated caller.
- **Required Role**: `admin`, or self if `targetUid === context.auth.uid`.
- **Inputs (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `targetUid` | `String` | No | Defaults to caller's UID if omitted. |
- **Collections Affected**:
  - `audit_logs`: Appends `CUSTOM_CLAIMS_SYNC`.
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
- **Error Codes**: `unauthenticated`, `permission-denied`, `not-found`.

---

### 5. `approveFacultyRegistration`

- **Type**: HTTPS Callable (`onCall`)
- **Handler**: `functions/src/approvals.js:approveFacultyRegistrationHandler`
- **Purpose**: Approves a pending Faculty registration, provisions annual balances, and sends notification.
- **Authentication**: Authenticated caller.
- **Required Role**: `admin` only.
- **Inputs (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `targetUid` | `String` | Yes | UID of the pending faculty user. |
- **Validation Rules**:
  - Target user must exist and have `role === 'faculty'`.
- **Collections Affected**:
  - `users/{targetUid}`: Sets `{ approvalStatus: 'approved', isActive: true, approvedAt, approvedBy }`.
  - `leave_balances/{targetUid}_{typeId}_{year}`: Provisions default annual balances (`casual_leave: 10`, `duty_leave: 14`, `station_leave: 5`).
  - `notifications`: Inserts welcome notification.
  - `audit_logs`: Appends `FACULTY_APPROVE`.
- **Success Response**:
  ```json
  {
    "success": true,
    "targetUid": "faculty_uid",
    "message": "Faculty registration approved, balances initialized, and custom claims set."
  }
  ```
- **Error Codes**: `unauthenticated`, `permission-denied`, `invalid-argument`, `not-found`, `failed-precondition`.

---

### 6. `rejectFacultyRegistration`

- **Type**: HTTPS Callable (`onCall`)
- **Handler**: `functions/src/approvals.js:rejectFacultyRegistrationHandler`
- **Purpose**: Rejects a pending Faculty registration and disables the account.
- **Authentication**: Authenticated caller.
- **Required Role**: `admin` only.
- **Inputs (`data`)**:
  | Parameter | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `targetUid` | `String` | Yes | UID of the faculty user. |
  | `reason` | `String` | No | Optional rejection reason. |
- **Collections Affected**:
  - `users/{targetUid}`: Sets `{ approvalStatus: 'rejected', isActive: false, rejectionReason }`.
  - `notifications`: Dispatches rejection explanation notification.
  - Firebase Auth: Sets `disabled = true`.
  - `audit_logs`: Appends `FACULTY_REJECT`.
- **Success Response**:
  ```json
  {
    "success": true,
    "targetUid": "faculty_uid",
    "message": "Faculty registration rejected and account disabled."
  }
  ```
- **Error Codes**: `unauthenticated`, `permission-denied`, `invalid-argument`, `not-found`.

---

### 7. `checkEmployeeId`

- **Type**: HTTPS Callable (`onCall`)
- **Handler**: `functions/src/employee.js:checkEmployeeIdAvailability`
- **Purpose**: Pre-checks Employee ID availability against the internal `employee_ids` registry.
- **Authentication**: None required (public helper).
- **Inputs (`data`)**: `{ employeeId: string }`
- **Success Response**:
  ```json
  {
    "isAvailable": true,
    "message": "Employee ID FAC-1024 is available for reservation.",
    "limitationNotice": "Employee IDs are checked for system uniqueness and atomic reservation, but not validated against external university HR records."
  }
  ```

---

### 8. `onLeaveApplicationUpdate`

- **Type**: Firestore Document Event Trigger (`onUpdate`)
- **Path**: `leave_applications/{applicationId}`
- **Handler**: `functions/src/leaves.js:onLeaveApplicationUpdateHandler`
- **Purpose**: Listens to leave application lifecycle transitions, records audit events, and executes atomic balance deductions upon Registrar final approval.
- **Event Handling Matrix**:
  | Transition | Audit Action | Transactional Side Effect |
  | :--- | :--- | :--- |
  | `pending` $\rightarrow$ `forwarded` | `HEAD_FORWARD_LEAVE` | None (status advanced by Head) |
  | `pending` $\rightarrow$ `rejected` | `HEAD_REJECT_LEAVE` | None |
  | `forwarded` $\rightarrow$ `approved` | `REGISTRAR_APPROVE_LEAVE` | **Invokes `processLeaveDeductionTransaction`** |
  | `forwarded` $\rightarrow$ `rejected` | `REGISTRAR_REJECT_LEAVE` | None |
- **Idempotency Guarantee**:
  - Checks if `balanceDeducted === true` on the document before executing deduction.
  - Retries or duplicate trigger events skip deduction cleanly.
- **Collections Affected**:
  - `leave_balances`: Increments `used` by `totalDays`.
  - `leave_applications`: Sets `{ balanceDeducted: true, balanceDeductedAt }`.
  - `audit_logs`: Appends `LEAVE_BALANCE_DEDUCTION`.

---

### 9. Internal Test Interface: `exports._internal`

- **Type**: Internal Module Export (Non-Callable, Non-Trigger)
- **Export**: `exports._internal = { processLeaveDeductionTransaction }`
- **Purpose**: Exposes the pure transactional leave deduction logic to Mocha unit test suites ([`functions/test/leaves.test.js`](file:///Users/Arman/Desktop/leavexa/functions/test/leaves.test.js)) for deterministic unit verification without requiring a live Cloud Firestore trigger execution.
- **Access**: Accessible only within server-side Node.js test environments; never exposed over HTTP or callable transports.
