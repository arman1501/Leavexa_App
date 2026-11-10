# Firestore Security Access Matrix & Authorization Rules

## 1. Master Security Access Matrix

The following matrix documents the exact permissions enforced by [`firestore.rules`](file:///Users/Arman/Desktop/leavexa/firestore.rules) across all user roles and collections.

| Collection | Operation | Faculty | Department Head | Registrar | Administrator | Unauthenticated | Cloud Functions (Admin SDK) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`users`** | **Read** | Own profile | Own Dept profiles | All profiles | All profiles | ❌ Denied | ✅ Full Access |
| | **Create** | ✅ Self-registration (`faculty`, `pending`, `inactive` only) | ❌ Denied | ❌ Denied | ✅ Any role | ❌ Denied | ✅ Full Access |
| | **Update** | Contact info only (`phone`, `photoUrl`) | Contact info only | Contact info only | ✅ Full update | ❌ Denied | ✅ Full Access |
| | **Delete** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Full Access |
| **`employee_ids`** | **Read** | ✅ Authenticated | ✅ Authenticated | ✅ Authenticated | ✅ Authenticated | ❌ Denied | ✅ Full Access |
| | **Create** | ✅ Own UID only (atomic transaction with user profile) | ❌ Denied | ❌ Denied | ✅ Admin setup | ❌ Denied | ✅ Full Access |
| | **Update** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Full Access |
| | **Delete** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Full Access |
| **`leave_applications`** | **Read** | Own applications | Own Dept applications | All applications | All applications | ❌ Denied | ✅ Full Access |
| | **Create** | ✅ Apply for self (`status: 'pending'`) | ❌ Denied (as head) | ❌ Denied (as reg) | ❌ Client create | ❌ Denied | ✅ Full Access |
| | **Update** | ❌ Denied | ✅ Forward/Reject (`status`, `headComment`, `headUid`, `headActionAt`) | ✅ Approve/Reject (`status`, `registrarComment`, `registrarUid`, `registrarActionAt`) | ✅ Admin override | ❌ Denied | ✅ Full Access (trigger stamps `balanceDeducted`) |
| | **Delete** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Full Access |
| **`leave_balances`** | **Read** | Own balances | Own Dept balances | All balances | All balances | ❌ Denied | ✅ Full Access |
| | **Write** | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Admin update | ❌ Denied | ✅ Full Access (atomic deductions & provisioning) |
| **`notifications`** | **Read** | Own inbox | Own inbox | Own inbox | Own inbox | ❌ Denied | ✅ Full Access |
| | **Create** | Self-notifications | Notify own Dept members | Notify any user | Notify any user | ❌ Denied | ✅ Full Access |
| | **Update** | Mark read (`isRead`) | Mark read (`isRead`) | Mark read (`isRead`) | Mark read (`isRead`) | ❌ Denied | ✅ Full Access |
| | **Delete** | Dismiss own | Dismiss own | Dismiss own | Dismiss own | ❌ Denied | ✅ Full Access |
| **`departments`** | **Read** | ✅ Authenticated | ✅ Authenticated | ✅ Authenticated | ✅ Authenticated | ❌ Denied | ✅ Full Access |
| | **Write** | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Admin update | ❌ Denied | ✅ Full Access |
| **`leave_types`** | **Read** | ✅ Authenticated | ✅ Authenticated | ✅ Authenticated | ✅ Authenticated | ❌ Denied | ✅ Full Access |
| | **Write** | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Admin update | ❌ Denied | ✅ Full Access |
| **`audit_logs`** | **Read** | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Admin read | ❌ Denied | ✅ Full Access |
| | **Write** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Append-only (Cloud Functions) |
| **`system_config`** | **Read** | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Admin read | ❌ Denied | ✅ Full Access |
| | **Write** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Server bootstrap mutex |

---

## 2. Critical Security Mechanisms in [`firestore.rules`](file:///Users/Arman/Desktop/leavexa/firestore.rules)

### A. Role Verification & Claim Synchronization
Security rules prioritize Custom Claims embedded in `request.auth.token` while maintaining backward-compatible fallback to user document inspection:
```javascript
function getRole() {
  return request.auth.token.role != null
    ? request.auth.token.role
    : (userDocExists() ? getUserDoc().role : 'faculty');
}

function isAdmin() {
  return isAuthenticated() && getRole() == 'admin';
}

function isRegistrar() {
  return isAuthenticated() && (getRole() == 'registrar' || isAdmin());
}

function isDeptHead() {
  return isAuthenticated() && (getRole() == 'department_head' || isAdmin());
}
```

### B. Field-Level Immutability via `diff().affectedKeys()`
In `leave_applications`, reviewers are strictly prevented from altering core application terms (dates, applicant name, leave type, total days, reason, or attachment URL).

#### Department Head Update Restriction:
```javascript
request.resource.data.diff(resource.data).affectedKeys()
  .hasOnly(['status', 'headUid', 'headComment', 'headActionAt'])
```
*If a Department Head attempts to modify `totalDays` or change `applicantUid`, the write is rejected with `PERMISSION_DENIED`.*

#### Registrar Update Restriction:
```javascript
request.resource.data.diff(resource.data).affectedKeys()
  .hasOnly(['status', 'registrarUid', 'registrarComment', 'registrarActionAt'])
```
*Registrar review can only execute once the document status is `'forwarded'`, and cannot overwrite Department Head notes.*

### C. Cross-Document Transaction Guards (`existsAfter` & `getAfter`)
To prevent registration race conditions or arbitrary Employee ID reservation hoarding:
```javascript
match /users/{uid} {
  allow create: if (isOwner(uid) &&
                    request.resource.data.role == 'faculty' &&
                    request.resource.data.approvalStatus == 'pending' &&
                    request.resource.data.isActive == false &&
                    existsAfter(/databases/$(database)/documents/employee_ids/$(request.resource.data.employeeId)) &&
                    getAfter(/databases/$(database)/documents/employee_ids/$(request.resource.data.employeeId)).data.uid == uid);
}

match /employee_ids/{employeeId} {
  allow create: if isAuthenticated() &&
                   request.resource.data.uid == request.auth.uid &&
                   !exists(/databases/$(database)/documents/employee_ids/$(employeeId)) &&
                   existsAfter(/databases/$(database)/documents/users/$(request.auth.uid)) &&
                   getAfter(/databases/$(database)/documents/users/$(request.auth.uid)).data.employeeId == employeeId;
}
```
*Both documents MUST be committed within the exact same atomic transaction.*

---

## 3. Server-Side Privilege Separation (Cloud Functions Trust Boundary)

Privileged operations are entirely inaccessible from client SDKs:
1. **Initial Admin Provisioning**: Guarded by a transactional mutex on `system_config/bootstrap`. Only executes if no active admin exists, stamping custom claims via Firebase Admin Auth SDK.
2. **Leave Balance Deductions**: Client applications cannot update `leave_balances`. The Cloud Function trigger `onLeaveApplicationUpdate` runs with Admin credentials upon detecting `status == 'approved'`.
3. **Audit Logging**: `audit_logs` has `allow write: if false;` to prevent client tampering.
