# Role & Permission Reference Specification

## 1. Institutional Roles & Custom Claims

Leavexa employs a hierarchical, role-based access control (RBAC) model aligned with university governance. Identity and authorization are cryptographically sealed within Firebase Authentication **Custom Claims** issued on user ID tokens:

```json
{
  "iss": "https://securetoken.google.com/leavexa",
  "aud": "leavexa",
  "auth_time": 1794210000,
  "user_id": "k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "sub": "k8X1qL9pMn0ZaB2vCd4eFg5hIj",
  "email": "faculty@university.edu",
  "email_verified": true,
  "role": "faculty",
  "approvalStatus": "approved",
  "departmentId": "dept_cse"
}
```

### Claim Field Dictionary
- `role`: Canonical role string (`'faculty'`, `'department_head'`, `'registrar'`, `'admin'`).
- `approvalStatus`: Registration verification state (`'pending'`, `'approved'`, `'rejected'`).
- `departmentId`: Institutional department slug (`'dept_cse'`, `'dept_eee'`, etc.). Present for Faculty and Department Heads.

---

## 2. Comprehensive Role Capability Matrix

| Operational Capability | Faculty | Department Head | Registrar | Administrator | System / Server |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Self-Registration (Pending/Inactive)** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **View Own Profile & Balances** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Update Personal Contact Info** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Upload Profile Photo** | ✅ | ❌ (UI not integrated) | ❌ (UI not integrated) | ❌ (UI not integrated) | ✅ |
| **Apply for Leave & Upload Attachment**| ✅ | ❌ | ❌ | ❌ | ❌ |
| **View Personal Applications** | ✅ | ✅ (Own) | ✅ (Own) | ✅ (Own) | ✅ |
| **Delete Attachment (Draft/Unsubmitted)**| ✅ | ❌ | ❌ | ✅ | ✅ |
| **Delete Attachment (Post-Submission)** | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Admin cleanup | ✅ |
| **Review Dept Pending Applications** | ❌ | ✅ (Own Dept Only)| ❌ | ✅ Override | ✅ |
| **Forward Application to Registrar** | ❌ | ✅ (Own Dept Only)| ❌ | ✅ Override | ✅ |
| **Reject Application at Dept Level** | ❌ | ✅ (Own Dept Only)| ❌ | ✅ Override | ✅ |
| **Review University Forwarded Queue** | ❌ | ❌ | ✅ Full Access | ✅ Full Access | ✅ |
| **Grant Final Approval to Leave** | ❌ | ❌ | ✅ Full Access | ✅ Override | ✅ |
| **Reject Application at Registrar Level**| ❌ | ❌ | ✅ Full Access | ✅ Override | ✅ |
| **Deduct Leave Balances** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Trigger Only |
| **Approve / Reject Faculty Accounts** | ❌ | ❌ | ❌ | ✅ Full Access | ✅ |
| **Create Staff Accounts (Head/Registrar)**| ❌ | ❌ | ❌ | ✅ Full Access | ✅ |
| **Activate / Deactivate Accounts** | ❌ | ❌ | ❌ | ✅ (Except self) | ✅ |
| **Read Forensic Audit Logs** | ❌ | ❌ | ❌ | ✅ Read-only | ✅ Append-only |
| **Modify System Config & Bootstrap** | ❌ | ❌ | ❌ | ✅ Read-only | ✅ Mutex-only |

---

## 3. Defense-in-Depth Security Boundaries

Authorization is enforced redundantly across four layers to guarantee zero trust:

```
┌────────────────────────────────────────────────────────┐
│ Layer 1: Client UI Routing & Action Guards             │
│ • AppRoutes role routing & visibility conditions      │
│ • Disabled buttons and hidden tabs for non-permitted   │
└───────────────────────────┬────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│ Layer 2: Cloud Firestore & Storage Security Rules      │
│ • Token claim inspection & resource owner validation   │
│ • Field-level affectedKeys lock down                   │
│ • Direct write blocking on balances, logs, and config  │
└───────────────────────────┬────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│ Layer 3: Cloud Functions Handler Authorization         │
│ • assertIsAdmin(context) checks on all privileged APIs │
│ • Atomic multi-document transaction boundaries         │
└───────────────────────────┬────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│ Layer 4: Immutable Forensic Audit Trail                │
│ • Cryptographically records actorUid, role, and action │
│ • Append-only; client modification strictly prohibited│
└────────────────────────────────────────────────────────┘
```

1. **Client UI Layer**: Prevents invalid actions from being exposed to unauthorized users (e.g., hiding approval buttons from Faculty).
2. **Security Rules Layer**: The primary boundary. Even if a modified client issues raw gRPC or REST requests, unauthorized queries and writes are rejected with `PERMISSION_DENIED`.
3. **Callable Function Layer**: Privileged endpoints verify caller claims using the Firebase Admin Auth SDK before initiating mutations.
4. **Audit Trail Layer**: Every state change, account approval, and balance deduction produces an immutable record in `audit_logs`.
