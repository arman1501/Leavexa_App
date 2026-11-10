# Leavexa Firestore Database Architecture & Schema Documentation

## 1. System Overview

**Leavexa** is an enterprise-grade Smart Faculty Leave Management System developed for academic institutions. The application utilizes **Google Cloud Firestore** in standard multi-region NoSQL document mode as its core transactional and relational data store, complemented by **Firebase Authentication**, **Cloud Functions**, and **Firebase Storage**.

The database architecture is designed around high concurrency, non-blocking asynchronous workflows, multi-role academic hierarchies, and cryptographic auditability.

```
┌────────────────────────────────────────────────────────────────────────┐
│                          LEAVEXA CLIENT (Flutter)                      │
│      Faculty  │  Department Head  │  Registrar  │  Administrator       │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │  Client SDK (gRPC / TLS)
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       FIRESTORE SECURITY RULES                         │
│   • Role-Based Access Control via Custom Claims & Document Inspection │
│   • Field-Level Immutability (affectedKeys validation)                 │
│   • Cross-Document Transactional Integrity (existsAfter / getAfter)    │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
┌─────────────────────────────────┐   ┌──────────────────────────────────┐
│      FIRESTORE DOCUMENT STORE   │   │     FIREBASE CLOUD FUNCTIONS     │
│   9 Core Collections            │◄──┤  (Node.js 22 Admin SDK Runtime)  │
│   • users           • notifs    │   │  • provisionInitialAdmin         │
│   • employee_ids    • depts     │   │  • approveFacultyRegistration    │
│   • leave_apps      • types     │   │  • onLeaveApplicationUpdate      │
│   • leave_balances  • audit_logs│   │  • checkEmployeeId               │
│   • system_config               │   └──────────────────────────────────┘
└─────────────────────────────────┘
```

---

## 2. Documentation Directory Map

This documentation suite provides a deep, authoritative audit of the Leavexa database implementation directly derived from source code analysis:

| Document | File Path | Focus & Purpose |
| :--- | :--- | :--- |
| **Collection Schema** | [`collection-schema.md`](collection-schema.md) | Exhaustive field-by-field dictionary, data types, document ID strategies, JSON payloads, and managing handlers for all 9 collections. |
| **Data Relationships** | [`relationships.md`](relationships.md) | 1:1, 1:N, and N:M entity relationships, reference patterns, denormalization rationale, and historical snapshot integrity. |
| **Security Access Matrix** | [`security-access-matrix.md`](security-access-matrix.md) | Role-by-role CRUD access matrix, field immutability constraints, and Firestore Security Rules enforcement rules. |
| **Indexes & Queries** | [`indexes.md`](indexes.md) | Composite index catalog, client & function query mapping, ordering paradigms, and pagination scalability recommendations. |
| **Data Integrity** | [`data-integrity.md`](data-integrity.md) | Transactions, atomic increments, idempotent trigger deduplication, state machines, and NoSQL foreign key mitigation. |
| **ER Diagram** | [`architecture.mmd`](architecture.mmd) | Complete Mermaid ER-style diagram of collections, primary keys, foreign keys, and cardinalities. |

---

## 3. Discovered Firestore Collections

Through static and dynamic code inspection across `lib/models/`, `lib/repositories/`, `lib/services/`, `functions/src/`, `firestore.rules`, and `firestore.indexes.json`, exactly **9 Firestore collections** constitute the database:

| # | Collection Name | Purpose | Primary Document Key Strategy | Managing Layer |
| :-: | :--- | :--- | :--- | :--- |
| 1 | `users` | User profile registry, role assignments, department bindings, and approval statuses. | Firebase Auth UID (`request.auth.uid`) | `UserRepository`, `AuthService`, `roles.js`, `approvals.js` |
| 2 | `employee_ids` | Institutional Employee ID uniqueness registry and reservation mutex. | Normalized Employee ID (e.g., `FAC-1024`, uppercase) | `UserRepository`, `roles.js`, `employee.js` |
| 3 | `leave_applications` | Academic leave requests, workflow approval stages, dates, reasons, and attachment URLs. | Unique application ID (e.g. `APP_1794...` or UUID) | `LeaveService`, `LeaveRepository`, `ApplyLeaveScreen`, `leaves.js` |
| 4 | `leave_balances` | Annual allotted vs. used quota balances per faculty member and leave type. | Composite key: `{userUid}_{leaveTypeId}_{year}` | `approvals.js`, `leaves.js`, `LeaveRepository` |
| 5 | `notifications` | Real-time targeted user in-app notification inbox. | Composite ID: `{microseconds}_{recipientUid}` or auto-ID | `NotificationService`, `approvals.js` |
| 6 | `departments` | Academic department catalog with assigned Department Head UID. | Department ID slug (e.g., `dept_cse`, `dept_eee`) | Seeded / Admin-managed |
| 7 | `leave_types` | University leave category catalog, allowance bounds, and document requirements. | Leave type code/slug (e.g., `casual_leave`, `duty_leave`) | Seeded / Admin-managed |
| 8 | `audit_logs` | Immutable, append-only forensic log of all administrative and lifecycle operations. | Auto-generated Firestore ID | `functions/src/audit.js` (Server-only) |
| 9 | `system_config` | System-wide configuration flags, bootstrap lock mutex, and security toggles. | Singleton document ID (e.g., `bootstrap`) | `functions/src/roles.js` (Server-only) |

---

## 4. Core Design Principles

1. **Denormalization for Historical Immutability**:
   Leave applications denormalize applicant name, employee ID, department name, and leave type name at the time of submission. If a faculty member later updates their legal name or department, historic leave documents remain immutable and legally accurate.
2. **Double-Lock Transactional Reservations**:
   To prevent duplicate Employee ID registration under race conditions, registration executes an atomic two-document transaction spanning `employee_ids/{employeeId}` and `users/{uid}`, enforced bi-directionally in `firestore.rules` via `existsAfter` and `getAfter`.
3. **Trigger-Driven Balance Accounting**:
   Faculty leave balances are **never** directly deducted by client applications. The deduction is handled exclusively by a server-side Cloud Function trigger (`onLeaveApplicationUpdate`) with atomic `FieldValue.increment` and idempotency gating (`balanceDeducted: true`).
4. **Least Privilege Security Posture**:
   Administrative documents (`audit_logs`, `system_config`) have `allow write: if false;` in client rules, ensuring they can only be manipulated by privileged Cloud Functions using the Firebase Admin SDK.
