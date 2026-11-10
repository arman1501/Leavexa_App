# Firestore Query & Composite Index Specification

## 1. Indexing Overview

Cloud Firestore automatically creates single-field indexes for every field in ascending and descending order, as well as an array-contains index for array fields.

However, queries that combine **multiple equality filters (`==`)**, **inequality filters (`<`, `>`, `!=`)**, or **equality filters with sort orders (`orderBy`)** require explicit **Composite Indexes**.

---

## 2. Configured Composite Indexes: [`firestore.indexes.json`](file:///Users/Arman/Desktop/leavexa/firestore.indexes.json)

The repository defines four composite indexes in `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "leave_applications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "departmentId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "appliedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "leave_applications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "applicantUid", "order": "ASCENDING" },
        { "fieldPath": "appliedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "role", "order": "ASCENDING" },
        { "fieldPath": "approvalStatus", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "recipientUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## 3. Query-to-Index Mapping & Analysis

### A. Leave Applications Queries

| Service / Location | Query Logic | Fields Filtered & Ordered | Index Status | Security Rule Alignment |
| :--- | :--- | :--- | :--- | :--- |
| `LeaveService.getPendingForDepartment` | `collection('leave_applications').where('departmentId', '==', deptId).where('status', '==', 'pending')` + in-memory sort by `appliedAt` | `departmentId == ?`, `status == 'pending'` | Supported by automatic single/compound or Index #1 | Matches Head rule: `resource.data.departmentId == getUserDepartmentId()` |
| `LeaveService.getApplicationsByUser` | `collection('leave_applications').where('applicantUid', '==', uid)` + in-memory sort by `appliedAt` | `applicantUid == ?` | Single-field index on `applicantUid` (or Index #2 if `orderBy` added) | Matches Owner rule: `resource.data.applicantUid == request.auth.uid` |
| `LeaveService.getForwardedApplications` | `collection('leave_applications').where('status', '==', 'forwarded')` + in-memory sort by `appliedAt` | `status == 'forwarded'` | Single-field index on `status` | Matches Registrar rule: `isRegistrar()` |
| `functions/src/leaves.js:onLeaveApplicationUpdate` | Trigger on doc update: `leave_applications/{applicationId}` | Direct doc listener | No index required (direct listener) | Trigger runs with Admin SDK |

#### Optimization Finding:
Currently, `LeaveService` executes the filter in Firestore (`where(...)`) and performs chronological sorting in Dart memory:
```dart
final apps = data.map((m) => LeaveApplicationModel.fromMap(m)).toList();
apps.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
```
Because Index #1 (`departmentId ASC, status ASC, appliedAt DESC`) and Index #2 (`applicantUid ASC, appliedAt DESC`) are already defined in `firestore.indexes.json`, adding `.orderBy('appliedAt', descending: true)` directly into `FirestoreService.queryCollection` would delegate sorting to the database engine, reducing client memory consumption when result sets grow large.

---

### B. Users Collection Queries

| Service / Location | Query Logic | Fields Filtered & Ordered | Index Status | Security Rule Alignment |
| :--- | :--- | :--- | :--- | :--- |
| Admin Faculty Queue | `collection('users').where('role', '==', 'faculty').where('approvalStatus', '==', 'pending').orderBy('createdAt', descending: true)` | `role == ?`, `approvalStatus == ?`, `createdAt DESC` | **Index #3** (`role ASC, approvalStatus ASC, createdAt DESC`) | Permitted: `isAdmin()` has universal read access on `users` |
| `functions/src/roles.js` | `collection('users').where('role', '==', 'admin').limit(1)` | `role == 'admin'` | Single-field index on `role` | Server-side Admin SDK |

---

### C. Notifications Queries

| Service / Location | Query Logic | Fields Filtered & Ordered | Index Status | Security Rule Alignment |
| :--- | :--- | :--- | :--- | :--- |
| `NotificationService.getForUser` | `collection('notifications').where('recipientUid', '==', uid)` + in-memory sort by `createdAt` | `recipientUid == ?` | Supported by Single-field or **Index #4** (`recipientUid ASC, createdAt DESC`) | Permitted: `resource.data.recipientUid == request.auth.uid` |
| `NotificationService.streamForUser` | `streamCollection('notifications', isEqualTo: {'recipientUid': uid})` | `recipientUid == ?` | Real-time listener | Matches Security Rule |

---

### D. Leave Balances Queries

| Service / Location | Query Logic | Fields Filtered & Ordered | Index Status | Security Rule Alignment |
| :--- | :--- | :--- | :--- | :--- |
| `LeaveRepository.balancesForUser` | `collection('leave_balances').where('userUid', '==', uid)` | `userUid == ?` | Single-field automatic index on `userUid` | Permitted: `resource.data.userUid == request.auth.uid` |
| `functions/src/leaves.js` fallback | `collection('leave_balances').where('userUid', '==', uid).where('leaveTypeId', '==', typeId).limit(1)` | `userUid == ?`, `leaveTypeId == ?` | Automatic composite equality index | Server-side Admin SDK |

---

## 4. Query & Security Rules Compatibility Audit

Firestore rules operate as **request filters**, not result filters. A query will fail with `PERMISSION_DENIED` unless every document that *could* be returned by the query is authorized by the rules.

- **Faculty Query Compatibility**: Faculty queries always specify `.where('applicantUid', '==', currentUid)`. This guarantees that Firestore rules evaluate only the user's own documents (`resource.data.applicantUid == request.auth.uid`), which succeeds.
- **Department Head Query Compatibility**: Department Head queries specify `.where('departmentId', '==', headDeptId)`. This matches rule line 163 (`isDeptHead() && resource.data.departmentId == getUserDepartmentId()`). Unscoped queries across all departments are prevented both by client logic and security rules.
- **Registrar Query Compatibility**: Registrar queries specify `.where('status', '==', 'forwarded')`. Since `isRegistrar()` grants universal read access to `leave_applications`, this query evaluates without error.

---

## 5. Pagination & Scaling Strategy Recommendations

As university records accumulate over academic semesters, queries should adopt **cursor-based pagination** using document snapshots:

```dart
// Recommended cursor-based pagination pattern for future iterations
Query<Map<String, dynamic>> query = firestore
    .collection('leave_applications')
    .where('applicantUid', isEqualTo: uid)
    .orderBy('appliedAt', descending: true)
    .limit(20);

if (lastDocumentSnapshot != null) {
  query = query.startAfterDocument(lastDocumentSnapshot);
}
```

- **Avoid Offset-based Pagination**: Firestore charges for skipped documents when using `.offset(n)`. Cursor-based pagination (`startAfterDocument`) ensures $O(1)$ read cost per page.
- **Index Preservation**: Existing indexes in `firestore.indexes.json` fully support cursor pagination on `appliedAt` and `createdAt`.
