# Leavexa Notification Event Specifications

## 1. Complete Event Catalog

Leavexa supports **7 primary workflow notification events** spanning faculty leave filing, departmental recommendations, registrar final approvals, and administrator faculty account vetting.

| # | Event Key | Trigger Source | Recipient(s) | Title | Payload Type | Deep Link Route |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | Faculty Submits Leave | `onLeaveApplicationCreate` | Department Head(s) of applicant's department | `New Leave Request Submitted` | `leave_submitted` | `/head/leave-request-details` |
| **2** | Head Forwards Leave | `onLeaveApplicationUpdate` (`pending` $\rightarrow$ `forwarded`) | All active Registrars | `Leave Application Forwarded` | `leave_forwarded` | `/registrar/final-approval` |
| **3** | Head Rejects Leave | `onLeaveApplicationUpdate` (`pending` $\rightarrow$ `rejected`) | Applicant Faculty | `Leave Application Rejected` | `leave_rejected` | `/faculty/leave-details` |
| **4** | Registrar Approves Leave | `onLeaveApplicationUpdate` (`forwarded` $\rightarrow$ `approved`) | Applicant Faculty | `Leave Application Approved!` | `leave_approved` | `/faculty/leave-details` |
| **5** | Registrar Rejects Leave | `onLeaveApplicationUpdate` (`forwarded` $\rightarrow$ `rejected`) | Applicant Faculty | `Leave Application Rejected` | `leave_rejected` | `/faculty/leave-details` |
| **6** | Admin Approves Faculty | `approveFacultyRegistration` (Callable) | Approved Faculty member | `Account Approved!` | `faculty_approved` | `/faculty/dashboard` |
| **7** | Admin Rejects Faculty | `rejectFacultyRegistration` (Callable) | Rejected Faculty member | `Account Registration Rejected` | `faculty_rejected` | `/login` |
| **8** | New Faculty Registration | `onUserCreate` (`role: faculty`, `pending`) | All active Administrators | `New Faculty Registration` | `registration_pending` | `/admin/dashboard` |

---

## 2. Exhaustive Event Payload Details

### Event 1: `leave_submitted`
- **Trigger**: Creation of `leave_applications/{applicationId}`
- **Recipient Resolution**: Active users where `role == 'department_head'` and `departmentId == applicationData.departmentId`.
- **Title**: `New Leave Request Submitted`
- **Body**: `${applicantName} submitted a ${leaveTypeName} application for ${totalDays} day(s).`
- **Data Payload**:
  ```json
  {
    "type": "leave_submitted",
    "applicationId": "app_cse_1001",
    "departmentId": "dept_cse",
    "applicantUid": "fac_uid_123",
    "timestamp": "2026-11-09T17:00:00.000Z"
  }
  ```

### Event 2: `leave_forwarded`
- **Trigger**: Status transition `pending` $\rightarrow$ `forwarded` on `leave_applications/{applicationId}`
- **Recipient Resolution**: Active users where `role == 'registrar'`.
- **Title**: `Leave Application Forwarded`
- **Body**: `Leave request for ${applicantName} has been recommended and forwarded by Department Head.`
- **Data Payload**:
  ```json
  {
    "type": "leave_forwarded",
    "applicationId": "app_cse_1001",
    "departmentId": "dept_cse",
    "timestamp": "2026-11-09T17:05:00.000Z"
  }
  ```

### Event 3: `leave_rejected` (by Department Head)
- **Trigger**: Status transition `pending` $\rightarrow$ `rejected`
- **Recipient Resolution**: `after.applicantUid`
- **Title**: `Leave Application Rejected`
- **Body**: `Your ${leaveTypeName} request was rejected by Department Head. Comment: "${headComment}"`
- **Data Payload**:
  ```json
  {
    "type": "leave_rejected",
    "applicationId": "app_cse_1001",
    "status": "rejected",
    "timestamp": "2026-11-09T17:10:00.000Z"
  }
  ```

### Event 4: `leave_approved` (Final Registrar Approval)
- **Trigger**: Status transition `forwarded` $\rightarrow$ `approved`
- **Recipient Resolution**: `after.applicantUid`
- **Side Effect**: Preceded by atomic leave balance deduction via `processLeaveDeductionTransaction`.
- **Title**: `Leave Application Approved!`
- **Body**: `Your ${leaveTypeName} request has received final approval from the Registrar.`
- **Data Payload**:
  ```json
  {
    "type": "leave_approved",
    "applicationId": "app_cse_1001",
    "status": "approved",
    "timestamp": "2026-11-09T17:15:00.000Z"
  }
  ```

### Event 5: `leave_rejected` (by Registrar)
- **Trigger**: Status transition `forwarded` $\rightarrow$ `rejected`
- **Recipient Resolution**: `after.applicantUid`
- **Title**: `Leave Application Rejected`
- **Body**: `Your ${leaveTypeName} request was rejected by the Registrar. Comment: "${registrarComment}"`

### Event 6: `faculty_approved`
- **Trigger**: Admin invokes callable `approveFacultyRegistration({ targetUid })`
- **Recipient Resolution**: `targetUid`
- **Title**: `Account Approved!`
- **Body**: `Your Leavexa faculty account has been approved by the Administrator. You now have full portal access.`

### Event 7: `faculty_rejected`
- **Trigger**: Admin invokes callable `rejectFacultyRegistration({ targetUid, reason })`
- **Recipient Resolution**: `targetUid`
- **Title**: `Account Registration Rejected`
- **Body**: `Your faculty registration was not approved. Reason: ${reason}`

### Event 8: `registration_pending`
- **Trigger**: Creation of `users/{uid}` with `role: 'faculty'` and `approvalStatus: 'pending'`
- **Recipient Resolution**: All active users where `role == 'admin'`.
- **Title**: `New Faculty Registration`
- **Body**: `${fullName} (${departmentName}) has registered and is awaiting administrator approval.`

---

## 3. Idempotency Keys & Deduplication
To guarantee that background trigger retries do not send duplicate push notifications to user devices, each event generates a deterministic idempotency key:
- Submission: `submit_${applicationId}`
- Forwarding: `forward_${applicationId}`
- Head Rejection: `head_reject_${applicationId}`
- Final Approval: `reg_approve_${applicationId}`
- Final Rejection: `reg_reject_${applicationId}`
- Faculty Approval: `faculty_approve_${targetUid}`
- Faculty Rejection: `faculty_reject_${targetUid}`
- New Registration: `new_user_${uid}`

If an in-app notification document with this key already exists with `fcmDispatched: true`, subsequent retries exit immediately.
