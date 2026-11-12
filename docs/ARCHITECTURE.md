# LEAVEXA Architecture

## System Overview
LEAVEXA separates client presentation (Flutter) from trusted enforcement (Firestore Rules, Storage Rules, Firebase Auth Custom Claims, and Cloud Functions).

```text
Flutter App (Faculty / Dept Head / Registrar / Admin)
  ├── Firebase Auth (Email/Password + Custom Claims: role, approvalStatus, departmentId)
  ├── Cloud Firestore (users, departments, employee_ids, leave_applications, leave_balances, notifications, audit_logs)
  ├── Firebase Storage (leave_documents/{uid}/{appId}/{file}, profile_images/{uid}/{file})
  ├── Cloud Functions (trusted callables + Firestore lifecycle triggers + retry scheduler)
  └── Firebase Cloud Messaging (role-based multicast + SHA-256 token doc IDs)
```

## Leave Application & Approval Workflow
1. **Faculty Registration**: Atomic Firestore batch reserves `/employee_ids/{EMPLOYEE_ID}` and creates `/users/{uid}` (`role: faculty`, `approvalStatus: pending`, `isActive: false`).
2. **Admin Approval**: `approveFacultyRegistration` callable sets `approvalStatus: approved`, `isActive: true`, assigns Custom Claims, and seeds annual `/leave_balances`.
3. **Leave Submission**: `ApplyLeaveScreen` pre-allocates a unique `applicationId`, uploads any attachment to `leave_documents/{uid}/{applicationId}/...`, and invokes `submitLeaveApplication` callable (derives `applicantUid` & `departmentId` server-side; prevents overwriting existing IDs). Local drafts are stored user-scoped in `SharedPreferences`.
4. **Department Head Review**: Department Head (`department_head` matching `departmentId`) reviews `pending` applications and updates status to `forwarded` or `rejected`.
5. **Registrar Final Decision**: Registrar (`registrar`) reviews `forwarded` applications only and sets `approved` or `rejected`.
6. **Atomic Leave Balance Deduction**: `onLeaveApplicationUpdate` trigger atomically increments `used` on `/leave_balances/{uid}_{type}_{year}` inside a Firestore transaction and stamps `balanceDeducted: true` (idempotent against retries).
7. **Department Transfer**: Admin invokes `transferFacultyDepartment` callable; future applications use the new `departmentId`, while historical `leave_applications` preserve their original `departmentId` snapshot.

## Core Firestore Collections
- `users/{uid}` — Profiles, roles, department assignments, approval/active state
- `departments/{deptId}` — 10 canonical academic departments and assigned `headUid` / `headEmail`
- `employee_ids/{employeeId}` — Atomic uniqueness reservations
- `leave_applications/{applicationId}` — Leave lifecycle documents & review timestamps
- `leave_balances/{uid}_{leaveType}_{year}` — Annual allotted vs used balances
- `notifications/{notificationId}` — In-app notification inbox
- `notification_events/{eventId}` — Idempotency locks and delivery retry tracking
- `audit_logs/{logId}` — Immutable server-written administrative & approval audit trail
- `system_config/{docId}` — Bootstrap lock and university metadata cache
