# Leavexa API & Backend Architecture Reference

## 1. Executive Overview

This directory provides the authoritative reference documentation for all backend interfaces, APIs, protocols, and data contracts powering **Leavexa** (Smart Faculty Leave Management System).

Leavexa is built on a serverless, event-driven Google Firebase architecture combining:
- **Firebase Authentication**: Cryptographic user identity, session management, and JWT Custom Claims.
- **Cloud Firestore**: Real-time document database with declarative Security Rules.
- **Firebase Cloud Functions (2nd Gen / Node.js 22)**: Privileged backend compute, transactional triggers, and administrative operations.
- **Firebase Cloud Storage**: Secure object store for academic leave attachments and profile imagery.

```
┌────────────────────────────────────────────────────────────────────────┐
│                          LEAVEXA FLUTTER CLIENT                        │
│             (Web, iOS, Android, macOS - Flutter 3.32+ / Dart 3.11)     │
└────────────┬───────────────────┬───────────────────┬───────────────────┘
             │                   │                   │
             │ HTTPS (Callable)  │ gRPC / TLS (Rules)│ Storage REST
             ▼                   ▼                   ▼
┌───────────────────────┐ ┌───────────────────┐ ┌────────────────────────┐
│ CLOUD FUNCTIONS       │ │ CLOUD FIRESTORE   │ │ CLOUD STORAGE          │
│ • provisionAdmin      │ │ • users           │ │ • leave_documents/     │
│ • createStaffAccount  │ │ • leave_apps      │ │ • profile_images/      │
│ • approveFaculty      │ │ • leave_balances  │ │                        │
│ • rejectFaculty       │ │ • employee_ids    │ │ (Enforced by           │
│ • setUserActive       │ │ • notifications   │ │  storage.rules)        │
│ • checkEmployeeId     │ │ • audit_logs      │ └────────────────────────┘
│ • syncClaims          │ │ • system_config   │
│                       │ │ (Enforced by      │
│ [Firestore Trigger]   │ │  firestore.rules) │
│ • onLeaveAppUpdate    │ └─────────▲─────────┘
└───────────┬───────────┘           │
            └───────────────────────┘ (Admin SDK Updates)
```

---

## 2. API Documentation Catalog

| Document | Path | Coverage & Scope |
| :--- | :--- | :--- |
| **Authentication API** | [`authentication-api.md`](authentication-api.md) | Firebase Auth operations, email/password login, Google OAuth, session restoration, password reset, and token verification. |
| **User Management API** | [`user-management-api.md`](user-management-api.md) | Faculty self-registration, atomic employee ID reservation, profile queries, contact editing, and staff provisioning. |
| **Leave Management API** | [`leave-management-api.md`](leave-management-api.md) | Leave submission, balance queries, department queue filters, registrar view, and real-time streams. |
| **Approval Workflow API** | [`approval-workflow-api.md`](approval-workflow-api.md) | Department Head review, Registrar final approval, trigger-based atomic leave balance deduction, and faculty account vetting. |
| **Notification API** | [`notification-api.md`](notification-api.md) | In-app alerts, read receipts, real-time inbox streaming, and automated server notification dispatches. |
| **Storage API** | [`storage-api.md`](storage-api.md) | Document & image uploads, magic header MIME sniffing, size limit enforcement, and safe object deletion. |
| **Cloud Functions Reference** | [`cloud-functions-reference.md`](cloud-functions-reference.md) | Exhaustive parameter, validation, error, and response specifications for all 8 Cloud Functions. |
| **Error Codes Taxonomy** | [`error-codes.md`](error-codes.md) | Complete mapping of client `AuthErrorCode`, Cloud Functions `HttpsError`, Storage validation, and Firestore security errors. |
| **Role & Permission Reference**| [`role-permission-reference.md`](role-permission-reference.md) | Custom Claims format, permission matrix, and role hierarchy across Faculty, Head, Registrar, and Admin. |

---

## 3. Communication Protocols & Trust Boundaries

### A. Client-to-Backend Transport
1. **Firebase Authentication (TLS 1.3 / HTTPS)**:
   - Client authenticates against `identitytoolkit.googleapis.com`.
   - On success, Firebase Auth issues a signed JWT (`idToken`) containing Custom Claims (`role`, `approvalStatus`, `departmentId`).
2. **Cloud Firestore (HTTP/2 / gRPC)**:
   - Client streams and writes documents directly to Firestore endpoints.
   - Every request carries the signed JWT. Firestore Security Rules evaluate authentication, roles, affected keys, and document data on every operation.
3. **Cloud Functions HTTPS Callable (`functions.https.onCall`)**:
   - Client invokes functions via `POST https://{region}-{project}.cloudfunctions.net/{functionName}`.
   - The Firebase SDK automatically serializes arguments and injects the caller's verified `context.auth` (UID, token, claims).
4. **Cloud Storage (HTTPS REST / Chunked Uploads)**:
   - File uploads execute directly against Google Cloud Storage buckets, governed by `storage.rules`.

### B. Security Perimeter & Backend Privilege Separation
- **No Direct Admin Writes from Client**: Operations affecting financial leave balances, system configuration locks, and forensic audit logs cannot be invoked from Flutter client SDKs. Client security rules evaluate `allow write: if false;` for these paths.
- **Server-Side Admin SDK**: Cloud Functions run with elevated Service Account credentials (`firebase-admin`), bypassing Security Rules to perform atomic multi-document adjustments and record audit logs.
