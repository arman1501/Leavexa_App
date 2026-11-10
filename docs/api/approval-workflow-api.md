# Approval Workflow & State Machine API Specification

## 1. Multi-Tier Academic Approval Architecture

Leavexa implements a two-tier academic approval workflow for faculty leave requests, followed by server-side atomic accounting:

```
[Faculty Submits: status = 'pending']
                  │
                  ▼
         [Department Head]
       ┌──────────┴──────────┐
       ▼                     ▼
[status = 'forwarded']  [status = 'rejected'] (Terminal)
       │
       ▼
   [Registrar]
 ┌─────┴─────┐
 ▼           ▼
[status = 'approved']   [status = 'rejected'] (Terminal)
 │
 └──► [Cloud Functions Trigger: onLeaveApplicationUpdate]
       • Atomic balance deduction (FieldValue.increment)
       • Idempotency stamp: balanceDeducted = true
       • Immutable audit log entry
```

---

## 2. Department Head Operations: [`LeaveService`](file:///Users/Arman/Desktop/leavexa/lib/services/leave_service.dart)

Department Heads review pending applications submitted by faculty in their own department.

### A. Forward Application: `forwardApplication`
- **Method**:
  ```dart
  Future<void> forwardApplication({
    required String applicationId,
    required String headUid,
    required String comment,
  })
  ```
- **Updates**:
  - `status`: `'forwarded'`
  - `headUid`: `headUid` (must match caller's Auth UID)
  - `headComment`: `comment`
  - `headActionAt`: `DateTime.now().toIso8601String()`
- **Security Rule Enforcement**:
  - `resource.data.status == 'pending'`
  - `resource.data.departmentId == getUserDepartmentId()`
  - `affectedKeys().hasOnly(['status', 'headUid', 'headComment', 'headActionAt'])`

### B. Reject Application: `rejectApplicationByHead`
- **Method**:
  ```dart
  Future<void> rejectApplicationByHead({
    required String applicationId,
    required String headUid,
    required String comment,
  })
  ```
- **Updates**: `status: 'rejected'`, `headUid`, `headComment`, `headActionAt`.
- **Outcome**: Terminal state. Application is rejected; no further review is possible.

---

## 3. Registrar Operations: [`LeaveService`](file:///Users/Arman/Desktop/leavexa/lib/services/leave_service.dart)

The Registrar reviews applications that have already been endorsed and forwarded by a Department Head.

### A. Approve Application: `approveApplicationByRegistrar`
- **Method**:
  ```dart
  Future<void> approveApplicationByRegistrar({
    required String applicationId,
    required String registrarUid,
    required String comment,
  })
  ```
- **Updates**:
  - `status`: `'approved'`
  - `registrarUid`: `registrarUid` (must match caller's Auth UID)
  - `registrarComment`: `comment`
  - `registrarActionAt`: `DateTime.now().toIso8601String()`
- **Security Rule Enforcement**:
  - `resource.data.status == 'forwarded'` *(Registrar cannot approve directly without Head endorsement)*
  - `affectedKeys().hasOnly(['status', 'registrarUid', 'registrarComment', 'registrarActionAt'])`

### B. Reject Application: `rejectApplicationByRegistrar`
- **Method**:
  ```dart
  Future<void> rejectApplicationByRegistrar({
    required String applicationId,
    required String registrarUid,
    required String comment,
  })
  ```
- **Updates**: `status: 'rejected'`, `registrarUid`, `registrarComment`, `registrarActionAt`.

---

## 4. Server-Side Execution: `onLeaveApplicationUpdate` Trigger

Defined in [`functions/src/leaves.js`](file:///Users/Arman/Desktop/leavexa/functions/src/leaves.js), this Firestore trigger listens to changes on `leave_applications/{applicationId}`.

### Workflow Transitions & Actions:

1. **Head Forwarding (`pending` $\rightarrow$ `forwarded`)**:
   - Records audit event `HEAD_FORWARD_LEAVE` with applicant UID, department ID, and head notes.
2. **Head Rejection (`pending` $\rightarrow$ `rejected`)**:
   - Records audit event `HEAD_REJECT_LEAVE`.
3. **Registrar Final Approval (`forwarded` $\rightarrow$ `approved`)**:
   - Records audit event `REGISTRAR_APPROVE_LEAVE`.
   - Executes `processLeaveDeductionTransaction(applicationId, afterData)`.
4. **Registrar Final Rejection (`forwarded` $\rightarrow$ `rejected`)**:
   - Records audit event `REGISTRAR_REJECT_LEAVE`.

### Atomic Leave Balance Deduction Logic:
```javascript
// Inside db.runTransaction:
if (currentApp.balanceDeducted === true) {
  return { success: true, alreadyProcessed: true }; // Idempotent skip
}

// 1. Locate balance document: {userUid}_{leaveTypeId}_{year}
const balanceRef = db.collection('leave_balances').doc(expectedBalanceId);
const balanceSnap = await transaction.get(balanceRef);

// 2. Validate sufficient remaining days
if (currentUsed + totalDays > totalAllotted) {
  transaction.update(appRef, { balanceDeductionError: 'Insufficient balance.' });
  return { success: false, message: 'Insufficient balance' };
}

// 3. Atomically deduct
transaction.update(balanceRef, {
  used: currentUsed + totalDays,
  updatedAt: FieldValue.serverTimestamp(),
});

// 4. Seal application idempotency flag
transaction.update(appRef, {
  balanceDeducted: true,
  deductedDays: totalDays,
  deductedAt: FieldValue.serverTimestamp(),
});
```

---

## 5. Faculty Registration Approval Endpoints (Admin Queue)

### A. Approve Faculty: `approveFacultyRegistration`
- **Type**: HTTPS Callable Function (`functions.https.onCall`)
- **Authorization**: Administrator only.
- **Parameters**: `{ targetUid: string }`
- **Transactional Atomic Batch**:
  1. Updates `users/{targetUid}`: `approvalStatus = 'approved'`, `isActive = true`, `approvedAt = serverTimestamp()`, `approvedBy = adminUid`.
  2. Provisions default leave balances for current year (e.g. 10 Casual, 14 Duty, 5 Station) in `leave_balances`.
  3. Dispatches welcome notification to `notifications`.
  4. Sets Custom Claims in Firebase Auth: `{ role: 'faculty', approvalStatus: 'approved' }`.
  5. Appends audit log: `action: 'FACULTY_APPROVE'`.

### B. Reject Faculty: `rejectFacultyRegistration`
- **Type**: HTTPS Callable Function
- **Authorization**: Administrator only.
- **Parameters**: `{ targetUid: string, reason?: string }`
- **Actions**:
  1. Updates `users/{targetUid}`: `approvalStatus = 'rejected'`, `isActive = false`, `rejectionReason = reason`.
  2. Sets Custom Claims: `{ role: 'faculty', approvalStatus: 'rejected' }`.
  3. Disables Firebase Auth account: `auth.updateUser(targetUid, { disabled: true })`.
  4. Appends audit log: `action: 'FACULTY_REJECT'`.
