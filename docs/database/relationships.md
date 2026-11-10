# Firestore Entity Relationships & Denormalization Strategy

## 1. Overview of Relationships

In Google Cloud Firestore, relationships are maintained through a combination of **document key references**, **composite index IDs**, and **strategic denormalization**.

Because Firestore is a document-oriented NoSQL database without SQL joins or foreign key cascade constraints, Leavexa employs denormalization to ensure fast single-document reads while leveraging server-side Cloud Function triggers and transactions to preserve referential consistency.

---

## 2. Detailed Entity Relationships

### A. Users and Departments (1:N and 1:1)

```
┌─────────────────────────┐               ┌─────────────────────────┐
│       departments       │ 1           N │          users          │
│ • id (PK)               ├───────────────┤ • departmentId (FK)     │
│ • name                  │               │ • departmentName (Denorm│
│ • headUid (FK)          ├───────────────┤ • role                  │
└─────────────────────────┘ 1           1 └─────────────────────────┘
```

- **Member Association (1:N)**: Each faculty user belongs to exactly one academic department identified by `users.departmentId` referencing `departments.id`.
- **Department Head Assignment (1:1)**: Each department has an assigned Department Head identified by `departments.headUid` referencing `users.uid`.
- **Denormalized Field**: `users.departmentName` copies `departments.name`. This allows user profile cards, headers, and dashboard badges to render immediately without performing an extra round-trip query to `departments`.

---

### B. Users and Employee IDs (1:1 Bi-Directional Mutex)

```
┌─────────────────────────┐ 1           1 ┌─────────────────────────┐
│          users          │               │      employee_ids       │
│ • uid (PK)              ├───────────────┤ • employeeId (PK)       │
│ • employeeId            │               │ • uid (FK)              │
└─────────────────────────┘               └─────────────────────────┘
```

- **Uniqueness Lock**: In Firestore, field values within a collection cannot have unique constraints enforced at the database layer. Uniqueness is achieved by creating a separate collection `employee_ids` where the document ID *is* the uppercase Employee ID.
- **Bi-Directional Binding**:
  - `users/{uid}` stores `employeeId`.
  - `employee_ids/{employeeId}` stores `uid`.
- **Atomic Creation**: Both documents are written simultaneously in a Firestore transaction during registration. `firestore.rules` uses `existsAfter` and `getAfter` to ensure neither document can be created without the other.

---

### C. Users and Leave Applications (1:N)

```
┌─────────────────────────┐ 1           N ┌─────────────────────────┐
│          users          │               │   leave_applications    │
│ • uid (PK)              ├───────────────┤ • applicantUid (FK)     │
│ • fullName              │               │ • applicantName (Denorm)│
│ • employeeId            │               │ • applicantEmpId (Denor)│
│ • departmentId          │               │ • headUid (FK)          │
│                         │               │ • registrarUid (FK)     │
└─────────────────────────┘               └─────────────────────────┘
```

- **Submission Hierarchy**: A user can submit multiple leave applications over their academic career (`leave_applications.applicantUid == users.uid`).
- **Reviewer Links**:
  - `headUid`: Identifies the Department Head who reviewed/forwarded the application.
  - `registrarUid`: Identifies the Registrar who gave final approval or rejection.
- **Denormalized Snapshots**:
  - `applicantName`: Copied from `users.fullName`.
  - `applicantEmployeeId`: Copied from `users.employeeId`.
  - `departmentName`: Copied from `users.departmentName`.
  - `leaveTypeName`: Copied from `leave_types.name`.
- **Snapshot Immutability Rationale**: Academic leave applications represent formal institutional records. If a faculty member changes their legal name, marries, or transfers departments 3 years after a leave was taken, historic records **must** reflect the exact name and department at the moment the leave was approved.

---

### D. Leave Applications and Leave Balances (N:1 per Category/Year)

```
┌─────────────────────────┐ N           1 ┌─────────────────────────┐
│   leave_applications    │               │     leave_balances      │
│ • applicantUid (FK)     ├───────────────┤ • userUid (FK)          │
│ • leaveTypeId (FK)      │               │ • leaveTypeId (FK)      │
│ • startDate (Year)      │               │ • year                  │
│ • totalDays             │               │ • totalAllotted         │
│ • balanceDeducted       │               │ • used (Incremented)    │
└─────────────────────────┘               └─────────────────────────┘
```

- **Deterministic Linkage**: A leave application belongs to a balance record deterministically keyed by:
  $$\text{Balance ID} = \text{applicantUid} + \text{"\_"} + \text{leaveTypeId} + \text{"\_"} + \text{startDate.year}$$
- **Atomic Deduction**: When an application transitions to `'approved'`, the Cloud Function trigger `onLeaveApplicationUpdate` locates this balance record, increments `used` by `totalDays`, and updates the application with `balanceDeducted: true`.
- **Idempotency Guard**: If `balanceDeducted == true`, subsequent trigger executions skip deduction, preventing duplicate deduction.

---

### E. Leave Applications and Notifications (1:N Event-Driven)

```
┌─────────────────────────┐ 1           N ┌─────────────────────────┐
│   leave_applications    │               │      notifications      │
│ • id (PK)               ├───────────────┤ • relatedAppId (FK)     │
│ • applicantUid          │               │ • recipientUid (FK)     │
│ • status                │               │ • type                  │
└─────────────────────────┘               └─────────────────────────┘
```

- **Lifecycle Event Notifications**:
  - On submission: Department Head receives notification (`type: 'leave_applied'`).
  - On forwarding: Registrar receives notification (`type: 'leave_forwarded'`).
  - On approval/rejection: Applicant receives notification (`type: 'leave_approved'` / `'leave_rejected'`).
- **Loose Coupling**: Notifications reference `relatedApplicationId` as a soft link. If an application is viewed, the UI can deep-link into details.

---

### F. Leave Applications and Audit Logs (1:N Immutable Audit Trail)

```
┌─────────────────────────┐ 1           N ┌─────────────────────────┐
│   leave_applications    │               │       audit_logs        │
│ • id (PK)               ├───────────────┤ • relatedAppId (FK)     │
│ • status                │               │ • targetId (FK)         │
│                         │               │ • actorUid (FK)         │
└─────────────────────────┘               └─────────────────────────┘
```

- Every lifecycle change generates an audit log entry (`audit_logs.relatedApplicationId == leave_applications.id`).
- Audit entries record the actor UID, actor role, previous status, new status, and timestamp.
- Audit logs are append-only (`allow write: if false;` in client rules) and cannot be deleted or modified.

---

## 3. Denormalization Handling & Consistency Analysis

| Source Collection | Target Collection | Denormalized Fields | Update Strategy | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `departments` | `users` | `departmentName` | Synchronized via `UserRepository` / Admin updates | Fast profile rendering without department join. |
| `users` | `leave_applications` | `applicantName`, `applicantEmployeeId` | **Never updated (Immutable Snapshot)** | Legal/academic historical accuracy at time of filing. |
| `departments` | `leave_applications` | `departmentName` | **Never updated (Immutable Snapshot)** | Reflects departmental budget at time of leave. |
| `leave_types` | `leave_applications` | `leaveTypeName` | **Never updated (Immutable Snapshot)** | Preserves policy name under which leave was granted. |
| `leave_types` | `leave_balances` | `leaveTypeName` | Synchronized on annual batch generation | Instant balance card rendering without catalog query. |

---

## 4. Referential Integrity in NoSQL

Because Cloud Firestore does not provide relational foreign key constraints or cascading deletes:

1. **Delete Prevention**:
   - `users`, `employee_ids`, `leave_applications`, `audit_logs`, and `system_config` deny client-side deletion (`allow delete: if false;`).
   - This eliminates orphaned references caused by accidental client deletions.
2. **Transaction Boundaries**:
   - All multi-document mutations that require consistent linkage (User Registration + Employee ID reservation, Approval + Claim sync + Balance provisioning) run inside Firestore Transactions or Batches.
3. **Soft References**:
   - Relationships store plain String IDs (`applicantUid`, `departmentId`, `leaveTypeId`). Client models check for nullity and provide graceful fallbacks (`departmentName ?? 'General'`) in the event of administrative re-organizations.
