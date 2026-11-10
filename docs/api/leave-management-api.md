# Leave Management API Specification

## 1. Overview

The Leave Management API manages the application, retrieval, and status tracking of academic leave requests. Operations are provided through [`lib/services/leave_service.dart`](file:///Users/Arman/Desktop/leavexa/lib/services/leave_service.dart) and [`lib/repositories/leave_repository.dart`](file:///Users/Arman/Desktop/leavexa/lib/repositories/leave_repository.dart).

All read and create operations interact with Cloud Firestore's `leave_applications` and `leave_balances` collections, subject to role-based access control in `firestore.rules`.

---

## 2. API Operations

### A. Submit Leave Application: `applyLeave`

Submits a new academic leave application on behalf of the authenticated faculty member.

- **Dart Interface**:
  ```dart
  Future<void> applyLeave({
    required LeaveApplicationModel application,
  })
  ```
- **Inputs ([`LeaveApplicationModel`](file:///Users/Arman/Desktop/leavexa/lib/models/leave_application_model.dart))**:
  | Field | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `id` | `String` | Yes | Unique ID generated client-side (e.g. `APP_${timestamp}`). |
  | `applicantUid` | `String` | Yes | Submitting faculty member UID (must match `request.auth.uid`). |
  | `applicantName` | `String` | Yes | Denormalized faculty full name. |
  | `applicantEmployeeId` | `String` | Yes | Denormalized employee ID. |
  | `departmentId` | `String` | Yes | Assigned department slug (must match faculty profile). |
  | `departmentName` | `String` | Yes | Denormalized department name. |
  | `leaveTypeId` | `String` | Yes | Leave category slug (`casual_leave`, `duty_leave`, etc.). |
  | `leaveTypeName` | `String` | Yes | Denormalized leave type name. |
  | `startDate` | `DateTime` | Yes | Inclusive start date. |
  | `endDate` | `DateTime` | Yes | Inclusive end date ($\ge$ `startDate`). |
  | `totalDays` | `int` | Yes | Number of business days requested ($1 \le \text{totalDays} \le 60$). |
  | `reason` | `String` | Yes | Detailed reason for absence. |
  | `documentUrl` | `String?` | No | Download URL of supporting document uploaded to Storage. |
  | `status` | `String` | Yes | Initial status must be `'pending'`. |
  | `appliedAt` | `DateTime` | Yes | Submission timestamp. |
- **Security Validation ([`firestore.rules`](file:///Users/Arman/Desktop/leavexa/firestore.rules))**:
  - `isApprovedAndActive()`: Faculty must be active and approved.
  - `applicantUid == request.auth.uid`: Cannot submit on behalf of other users.
  - `status == 'pending'`: Cannot create in forwarded/approved state.
  - `departmentId == getUserDepartmentId()`: Department must match faculty member's profile.
  - Reviewer fields (`headUid`, `headComment`, `registrarUid`, `registrarComment`) must be empty or null.
- **Success Response**: Future completes with `void`. Document created at `leave_applications/{id}`.
- **Errors**: Throws FirebaseException with code `'permission-denied'` if constraints fail.

---

### B. Faculty Leave History: `getApplicationsByUser` & `streamApplicationsByUser`

Fetches or streams all leave applications filed by a specific faculty member, sorted chronologically.

- **Future Method**: `Future<List<LeaveApplicationModel>> getApplicationsByUser(String applicantUid)`
- **Stream Method**: `Stream<List<LeaveApplicationModel>> streamApplicationsByUser(String applicantUid)`
- **Query Filter**: `collection('leave_applications').where('applicantUid', '==', applicantUid)`
- **Sort Order**: Sorted descending by `appliedAt` (most recent first).
- **Security Check**: Non-owner faculty attempting to query another faculty member's `applicantUid` receive `PERMISSION_DENIED`.

---

### C. Department Head Review Queue: `getPendingForDepartment` & `streamPendingForDepartment`

Fetches or streams all pending leave applications belonging to a specific department.

- **Future Method**: `Future<List<LeaveApplicationModel>> getPendingForDepartment(String departmentId)`
- **Stream Method**: `Stream<List<LeaveApplicationModel>> streamPendingForDepartment(String departmentId)`
- **Query Filter**: `collection('leave_applications').where('departmentId', '==', departmentId).where('status', '==', 'pending')`
- **Security Check**: Enforced by line 163 of `firestore.rules`. Department Heads can only query their own assigned department (`departmentId == getUserDepartmentId()`). Unscoped queries across other departments fail.

---

### D. Registrar Review Queue: `getForwardedApplications` & `streamForwardedApplications`

Fetches or streams all applications that have been reviewed and forwarded by Department Heads across the university.

- **Future Method**: `Future<List<LeaveApplicationModel>> getForwardedApplications()`
- **Stream Method**: `Stream<List<LeaveApplicationModel>> streamForwardedApplications()`
- **Query Filter**: `collection('leave_applications').where('status', '==', 'forwarded')`
- **Security Check**: Authorized for users with `role == 'registrar'` or `role == 'admin'`.

---

### E. Individual Application Detail: `getApplicationById`

Retrieves a single application document by its ID.

- **Dart Interface**: `Future<LeaveApplicationModel?> getApplicationById(String id)`
- **Path**: `leave_applications/{id}`
- **Permissions**: Allowed for the applicant, the applicant's Department Head, the Registrar, or an Admin.

---

### F. Leave Balance Inquiries: `balancesForUser` & `streamBalancesForUser`

Retrieves annual quota allowances, consumed days, and remaining balances for a faculty member.

- **Future Method**: `Future<List<LeaveBalanceModel>> balancesForUser(String uid)`
- **Stream Method**: `Stream<List<LeaveBalanceModel>> streamBalancesForUser(String uid)`
- **Query Filter**: `collection('leave_balances').where('userUid', '==', uid)`
- **Output ([`LeaveBalanceModel`](file:///Users/Arman/Desktop/leavexa/lib/models/leave_balance_model.dart))**:
  - `totalAllotted`: Annual days granted.
  - `used`: Consumed days deducted by completed leave approvals.
  - `remaining`: Computed property (`totalAllotted - used`).
- **Permissions**: Owner user, their Department Head, Registrar, Admin.
