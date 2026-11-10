# Firestore Collection Schema Specification

This document provides the complete, field-by-field schema specification for every Firestore collection utilized by Leavexa.

---

## 1. `users`

### Purpose
Stores central user profiles, role assignments, departmental affiliations, and administrative approval states.

### Document ID Strategy
Directly mapped to the Firebase Authentication User ID (`request.auth.uid`).

### Schema Fields
| Field Name | Data Type | Required | Default | Constraints & Allowed Values | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `uid` | `String` | Yes | — | Matches Auth UID | Unique Firebase Auth identifier. |
| `fullName` | `String` | Yes | — | Length 2–100 chars | User's formal legal/academic name. |
| `email` | `String` | Yes | — | Valid email format, lowercase | Institutional email address. |
| `employeeId` | `String` | Yes | — | 3–30 chars, uppercase | Assigned university employee ID. |
| `departmentId` | `String` | Yes | — | References `departments.id` | Associated academic department slug. |
| `departmentName` | `String` | Yes | — | Matches department name | Denormalized human-readable department name. |
| `designation` | `String` | Yes | — | Non-empty | Academic rank (e.g. "Assistant Professor"). |
| `role` | `String` | Yes | `'faculty'` | `'faculty'`, `'department_head'`, `'registrar'`, `'admin'` | System authorization role. |
| `phone` | `String?` | No | `null` | Optional phone number | Contact telephone number. |
| `photoUrl` | `String?` | No | `null` | Valid Storage URL | Firebase Storage avatar download URL. |
| `isActive` | `Boolean` | Yes | `false` | `true`, `false` | Account active toggle. |
| `approvalStatus` | `String` | Yes | `'pending'` | `'pending'`, `'approved'`, `'rejected'` | Administrative registration status. |
| `createdAt` | `Timestamp` | Yes | serverTimestamp | ISO-8601 or Firestore Timestamp | Profile creation timestamp. |
| `approvedAt` | `Timestamp?` | No | `null` | Firestore Timestamp | Admin approval timestamp (stamped by Cloud Function). |
| `approvedBy` | `String?` | No | `null` | References `users.uid` | Admin UID who approved the faculty account. |
| `rejectionReason`| `String?` | No | `null` | Non-empty if rejected | Reason provided upon rejection. |

### Example Document
```json
{
  "uid": "k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "fullName": "Dr. Sarah Jenkins",
  "email": "sarah.jenkins@university.edu",
  "employeeId": "FAC-1024",
  "departmentId": "dept_cse",
  "departmentName": "Computer Science & Engineering",
  "designation": "Associate Professor",
  "role": "faculty",
  "phone": "+1 (555) 234-5678",
  "photoUrl": "https://firebasestorage.googleapis.com/v0/b/leavexa.appspot.com/o/profile_images%2Fk8X1qL9pMn0ZaB2vCd4eFg5hIj%2Favatar_1794210000000.jpg?alt=media",
  "isActive": true,
  "approvalStatus": "approved",
  "createdAt": "2026-09-15T08:30:00.000Z",
  "approvedAt": "2026-09-16T10:15:00.000Z",
  "approvedBy": "admin_root_uid"
}
```

### Access Control & Management
- **Read**: Owner user, Registrar, Admin, and Department Head (restricted to own department members).
- **Create**: Self-registration allowed strictly as `role: 'faculty'`, `approvalStatus: 'pending'`, `isActive: false` with atomic `employee_ids` binding; Admin can provision any role.
- **Update**: User can only edit contact details (`phone`, `photoUrl`); role, status, department, and employeeId are immutable to clients and managed by `functions/src/roles.js` and `functions/src/approvals.js`.
- **Delete**: Denied to all client SDKs.
- **Managing Handlers**: [`UserRepository`](file:///Users/Arman/Desktop/leavexa/lib/repositories/user_repository.dart), [`AuthService`](file:///Users/Arman/Desktop/leavexa/lib/services/auth_service.dart), `roles.js`, `approvals.js`.

---

## 2. `employee_ids`

### Purpose
Acts as a uniqueness constraint and mutex registry to ensure no two accounts ever claim the same institutional Employee ID.

### Document ID Strategy
Normalized uppercase Employee ID string (e.g., `FAC-1024`, `EMP-ADM-99`).

### Schema Fields
| Field Name | Data Type | Required | Constraints | Description |
| :--- | :--- | :---: | :--- | :--- |
| `uid` | `String` | Yes | Matches `users.uid` | The UID of the user reserving or owning this ID. |
| `createdAt` | `Timestamp` | Yes | serverTimestamp | Timestamp when the reservation was sealed. |

### Example Document
```json
{
  "uid": "k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "createdAt": "2026-09-15T08:30:00.000Z"
}
```

### Access Control & Management
- **Read**: Authenticated users (used by pre-registration availability checks).
- **Create**: Client permitted only during atomic registration transaction matching `users/{uid}`; Admin permitted during staff provisioning.
- **Update / Delete**: Denied to clients (`allow update, delete: if false;`).
- **Managing Handlers**: [`UserRepository.createFacultyUser`](file:///Users/Arman/Desktop/leavexa/lib/repositories/user_repository.dart), `functions/src/roles.js`, `functions/src/employee.js`.

---

## 3. `leave_applications`

### Purpose
Core business entity representing an academic leave application across its complete submission, departmental review, registrar approval, and balance deduction lifecycle.

### Document ID Strategy
Generated unique ID prefixed by timestamp or UUID (e.g., `APP_1794210580914` or Firestore auto-ID).

### Schema Fields
| Field Name | Data Type | Required | Default | Constraints & Allowed Values | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `String` | Yes | — | Matches Document ID | Application identifier. |
| `applicantUid` | `String` | Yes | — | Matches `users.uid` | UID of the submitting faculty member. |
| `applicantName` | `String` | Yes | — | Non-empty string | Denormalized faculty full name. |
| `applicantEmployeeId` | `String` | Yes | — | Matches `users.employeeId` | Denormalized employee ID. |
| `departmentId` | `String` | Yes | — | References `departments.id` | Faculty member's department slug. |
| `departmentName` | `String` | Yes | — | Non-empty string | Denormalized department title. |
| `leaveTypeId` | `String` | Yes | — | References `leave_types.id` | Selected leave category. |
| `leaveTypeName` | `String` | Yes | — | Non-empty string | Denormalized leave category name. |
| `startDate` | `String / Date` | Yes | — | ISO-8601 date string | Inclusive start date of leave. |
| `endDate` | `String / Date` | Yes | — | $\ge$ `startDate` | Inclusive end date of leave. |
| `totalDays` | `Int` | Yes | — | $1 \le \text{totalDays} \le 60$ | Total business leave days requested. |
| `reason` | `String` | Yes | — | Non-empty | Justification provided by applicant. |
| `documentUrl` | `String?` | No | `null` | Firebase Storage URL | Download URL of supporting document. |
| `status` | `String` | Yes | `'pending'` | `'pending'`, `'forwarded'`, `'approved'`, `'rejected'`, `'draft'`, `'cancelled'` | Current workflow status. |
| `headComment` | `String?` | No | `null` | Max 500 chars | Department Head review notes. |
| `headActionAt` | `String?` | No | `null` | ISO-8601 timestamp | Timestamp of Department Head action. |
| `headUid` | `String?` | No | `null` | References `users.uid` | UID of Department Head reviewer. |
| `registrarComment` | `String?` | No | `null` | Max 500 chars | Registrar review notes. |
| `registrarActionAt` | `String?` | No | `null` | ISO-8601 timestamp | Timestamp of Registrar final action. |
| `registrarUid` | `String?` | No | `null` | References `users.uid` | UID of Registrar reviewer. |
| `appliedAt` | `String` | Yes | — | ISO-8601 timestamp | Submission timestamp. |
| `balanceDeducted` | `Boolean?` | No | `false` | `true`, `false` | Server stamp confirming balance deduction. |
| `balanceDeductedAt`| `Timestamp?` | No | `null` | Firestore Timestamp | Timestamp when balance was deducted. |
| `balanceDeductionError`| `String?` | No | `null` | Non-empty if failed | Forensic note if balance deduction failed. |

### Example Document
```json
{
  "id": "APP_1794210580914",
  "applicantUid": "k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "applicantName": "Dr. Sarah Jenkins",
  "applicantEmployeeId": "FAC-1024",
  "departmentId": "dept_cse",
  "departmentName": "Computer Science & Engineering",
  "leaveTypeId": "casual_leave",
  "leaveTypeName": "Casual Leave",
  "startDate": "2026-11-15T00:00:00.000",
  "endDate": "2026-11-17T00:00:00.000",
  "totalDays": 3,
  "reason": "Attending IEEE Global Computing Symposium as paper presenter.",
  "documentUrl": "https://firebasestorage.googleapis.com/v0/b/leavexa.appspot.com/o/leave_documents%2Fk8X1qL9pMn0ZaB2vCd4eFg5hIj%2FAPP_1794210580914%2Fconference_acceptance.pdf?alt=media",
  "status": "approved",
  "headComment": "Forwarded with strong recommendation. Academic coverage arranged.",
  "headActionAt": "2026-11-10T14:20:00.000Z",
  "headUid": "head_cse_uid",
  "registrarComment": "Approved per institutional conference leave guidelines.",
  "registrarActionAt": "2026-11-11T09:45:00.000Z",
  "registrarUid": "registrar_main_uid",
  "appliedAt": "2026-11-09T11:00:00.000Z",
  "balanceDeducted": true,
  "balanceDeductedAt": "2026-11-11T09:45:05.120Z"
}
```

### Access Control & Management
- **Read**: Applicant faculty, Department Head (own department applications), Registrar (all), Admin (all).
- **Create**: Active & approved faculty applying for themselves with initial status `'pending'`.
- **Update**: Strictly governed by field-level diff:
  - Department Head can only touch: `status` (`'forwarded'` or `'rejected'`), `headUid`, `headComment`, `headActionAt`.
  - Registrar can only touch: `status` (`'approved'` or `'rejected'`), `registrarUid`, `registrarComment`, `registrarActionAt`.
  - Cloud Functions trigger stamps `balanceDeducted`.
- **Delete**: Denied to clients (`allow delete: if false;`).
- **Managing Handlers**: [`LeaveService`](file:///Users/Arman/Desktop/leavexa/lib/services/leave_service.dart), [`LeaveRepository`](file:///Users/Arman/Desktop/leavexa/lib/repositories/leave_repository.dart), `functions/src/leaves.js`.

---

## 4. `leave_balances`

### Purpose
Tracks annual leave allowances and consumed days for each faculty member by leave category.

### Document ID Strategy
Deterministic composite key: `{userUid}_{leaveTypeId}_{year}` (e.g., `k8X1qL9pMn0ZaB2vCd4eFg5hIj_casual_leave_2026`).

### Schema Fields
| Field Name | Data Type | Required | Constraints | Description |
| :--- | :--- | :---: | :--- | :--- |
| `id` | `String` | Yes | Composite key string | Record identifier. |
| `userUid` | `String` | Yes | References `users.uid` | Beneficiary faculty member UID. |
| `leaveTypeId` | `String` | Yes | References `leave_types.id` | Category of leave. |
| `leaveTypeName` | `String` | Yes | Matches `leave_types.name` | Denormalized category title. |
| `totalAllotted` | `Int` | Yes | $\ge 0$ | Annual allotted quota. |
| `used` | `Int` | Yes | $0 \le \text{used} \le \text{totalAllotted}$ | Consumed leave days. |
| `year` | `Int` | Yes | 4-digit academic year | Gregorian calendar year. |
| `departmentId` | `String?` | No | References `departments.id` | Department affiliation. |
| `createdAt` | `Timestamp?` | No | serverTimestamp | Provisioning timestamp. |
| `updatedAt` | `Timestamp?` | No | serverTimestamp | Last deduction timestamp. |

### Example Document
```json
{
  "id": "k8X1qL9pMn0ZaB2vCd4eFg5hIj_casual_leave_2026",
  "userUid": "k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "leaveTypeId": "casual_leave",
  "leaveTypeName": "Casual Leave",
  "totalAllotted": 10,
  "used": 3,
  "year": 2026,
  "departmentId": "dept_cse",
  "createdAt": "2026-09-16T10:15:00.000Z",
  "updatedAt": "2026-11-11T09:45:05.120Z"
}
```

### Access Control & Management
- **Read**: Owner user, Department Head (for faculty in their department), Registrar, Admin.
- **Write**: Admin and trusted Cloud Functions (`approvals.js` on registration approval, `leaves.js` on registrar approval). Client writes are denied.
- **Managing Handlers**: `functions/src/approvals.js`, `functions/src/leaves.js`, [`LeaveRepository`](file:///Users/Arman/Desktop/leavexa/lib/repositories/leave_repository.dart).

---

## 5. `notifications`

### Purpose
Delivers asynchronous, in-app notifications to individual users regarding account approval, leave workflow progress, and administrative notices.

### Document ID Strategy
Composite key `{microseconds}_{recipientUid}` or auto-generated Firestore ID.

### Schema Fields
| Field Name | Data Type | Required | Constraints & Values | Description |
| :--- | :--- | :---: | :--- | :--- |
| `id` | `String` | Yes | Non-empty | Unique notification ID. |
| `recipientUid` | `String` | Yes | References `users.uid` | Target recipient UID. |
| `title` | `String` | Yes | Max 150 chars | Short notification subject. |
| `body` | `String` | Yes | Max 500 chars | Informational body message. |
| `type` | `String` | Yes | `'leave_applied'`, `'leave_forwarded'`, `'leave_approved'`, `'leave_rejected'`, `'approval'`, `'general'` | Category code. |
| `relatedApplicationId` | `String?` | No | References `leave_applications.id` | Optional linked application ID. |
| `isRead` | `Boolean` | Yes | `false`, `true` | Read acknowledgement flag. |
| `createdAt` | `String / Date` | Yes | ISO-8601 string | Creation timestamp. |

### Example Document
```json
{
  "id": "1794210600000000_k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "recipientUid": "k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "title": "Leave Approved",
  "body": "Your Casual Leave request (APP_1794210580914) has been given final approval by the Registrar.",
  "type": "leave_approved",
  "relatedApplicationId": "APP_1794210580914",
  "isRead": false,
  "createdAt": "2026-11-11T09:45:00.000Z"
}
```

### Access Control & Management
- **Read**: Recipient user (`resource.data.recipientUid == request.auth.uid`).
- **Create**: Authorized staff, server functions, or self-notification.
- **Update**: Recipient user only, constrained strictly to `affectedKeys().hasOnly(['isRead'])`.
- **Delete**: Recipient user may dismiss their own notifications.
- **Managing Handlers**: [`NotificationService`](file:///Users/Arman/Desktop/leavexa/lib/services/notification_service.dart), `functions/src/approvals.js`.

---

## 6. `departments`

### Purpose
Authoritative catalog of academic departments and organizational units within the institution.

### Document ID Strategy
Canonical department slug (e.g., `dept_cse`, `dept_eee`, `dept_bba`, `dept_english`).

### Schema Fields
| Field Name | Data Type | Required | Constraints | Description |
| :--- | :--- | :---: | :--- | :--- |
| `id` | `String` | Yes | Matches Document ID | Unique department slug. |
| `name` | `String` | Yes | Non-empty | Full institutional department title. |
| `shortCode` | `String` | Yes | Uppercase, 2–6 chars | Department abbreviation (e.g. "CSE"). |
| `headUid` | `String` | Yes | References `users.uid` | Assigned Department Head UID. |
| `isActive` | `Boolean` | Yes | `true`, `false` | Department status flag. |

### Example Document
```json
{
  "id": "dept_cse",
  "name": "Computer Science & Engineering",
  "shortCode": "CSE",
  "headUid": "head_cse_uid",
  "isActive": true
}
```

### Access Control & Management
- **Read**: Authenticated users.
- **Write**: Admin only (`allow write: if isAdmin();`).
- **Managing Handlers**: Seed data scripts, Admin management screens.

---

## 7. `leave_types`

### Purpose
Institutional catalog of supported leave types, policy limits, and documentation requirements.

### Document ID Strategy
Canonical leave type slug (e.g., `casual_leave`, `duty_leave`, `station_leave`, `earned_leave`, `sick_leave`).

### Schema Fields
| Field Name | Data Type | Required | Constraints | Description |
| :--- | :--- | :---: | :--- | :--- |
| `id` | `String` | Yes | Matches Document ID | Unique leave type slug. |
| `name` | `String` | Yes | Non-empty | Display name (e.g., "Casual Leave"). |
| `code` | `String` | Yes | Uppercase, 2–5 chars | Short acronym (e.g., "CL"). |
| `defaultDays` | `Int` | Yes | $\ge 0$ | Standard annual allocation. |
| `requiresDocument` | `Boolean`| Yes | `true`, `false` | Mandatory attachment flag. |
| `isActive` | `Boolean` | Yes | `true`, `false` | Active policy toggle. |

### Example Document
```json
{
  "id": "casual_leave",
  "name": "Casual Leave",
  "code": "CL",
  "defaultDays": 10,
  "requiresDocument": false,
  "isActive": true
}
```

### Access Control & Management
- **Read**: Authenticated users.
- **Write**: Admin only (`allow write: if isAdmin();`).
- **Managing Handlers**: Seed catalog, [`LeaveTypeModel.defaultLeaveTypes`](file:///Users/Arman/Desktop/leavexa/lib/models/leave_type_model.dart).

---

## 8. `audit_logs`

### Purpose
Provides an immutable, tamper-evident forensic audit log capturing all privileged actions, role changes, registrations, approvals, and balance transactions.

### Document ID Strategy
Auto-generated Firestore document ID.

### Schema Fields
| Field Name | Data Type | Required | Values & Description |
| :--- | :--- | :---: | :--- |
| `id` | `String` | Yes | Auto-generated document ID. |
| `actorUid` | `String` | Yes | UID of the user or `'system'` executing the action. |
| `actorRole` | `String` | Yes | `'admin'`, `'registrar'`, `'department_head'`, `'system'`. |
| `action` | `String` | Yes | Standard action verb (e.g., `INITIAL_ADMIN_PROVISION`, `FACULTY_APPROVE`, `LEAVE_BALANCE_DEDUCTION`). |
| `targetType` | `String` | Yes | Target resource (`'user'`, `'leave_application'`, `'leave_balance'`, `'system'`). |
| `targetId` | `String?` | No | ID of affected entity. |
| `relatedApplicationId` | `String?` | No | Linked leave application ID. |
| `details` | `Map<String, dynamic>`| Yes | Arbitrary JSON forensic metadata snapshot. |
| `timestamp` | `Timestamp` | Yes | Server timestamp (`FieldValue.serverTimestamp()`). |

### Example Document
```json
{
  "id": "qR8pL2vNm4X9ZaBc",
  "actorUid": "registrar_main_uid",
  "actorRole": "registrar",
  "action": "REGISTRAR_APPROVE_LEAVE",
  "targetType": "leave_application",
  "targetId": "APP_1794210580914",
  "relatedApplicationId": "APP_1794210580914",
  "details": {
    "totalDays": 3,
    "leaveTypeId": "casual_leave",
    "previousStatus": "forwarded",
    "newStatus": "approved"
  },
  "timestamp": "2026-11-11T09:45:00.000Z"
}
```

### Access Control & Management
- **Read**: Admin only (`allow read: if isAdmin();`).
- **Write**: Strictly prohibited from client SDKs (`allow write: if false;`). Appended exclusively by server-side Cloud Functions via `functions/src/audit.js`.

---

## 9. `system_config`

### Purpose
Maintains global system runtime flags and bootstrap mutexes to prevent concurrent initial administrator provisioning.

### Document ID Strategy
Deterministic configuration key (`'bootstrap'`).

### Schema Fields
| Field Name | Data Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `isBootstrapped` | `Boolean` | Yes | Mutex flag. Set to `true` upon first admin setup. |
| `bootstrappedAt` | `Timestamp` | Yes | Server timestamp when bootstrap completed. |
| `bootstrappedBy` | `String` | Yes | UID of initial administrator. |
| `adminEmail` | `String` | Yes | Email address of initial administrator. |
| `note` | `String?` | No | Diagnostic or administrative notes. |

### Example Document
```json
{
  "isBootstrapped": true,
  "bootstrappedAt": "2026-11-08T18:18:00.000Z",
  "bootstrappedBy": "4vJWecJRh2X9amUzWers5ljKHBI1",
  "adminEmail": "root_admin@leavexa.edu"
}
```

### Access Control & Management
- **Read**: Admin only (`allow read: if isAdmin();`).
- **Write**: Client write denied (`allow write: if false;`). Initialized by `functions/src/roles.js:provisionInitialAdminHandler` within a transactional mutex.
