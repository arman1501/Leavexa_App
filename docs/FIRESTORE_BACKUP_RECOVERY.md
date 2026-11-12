# Firestore Backup & Disaster Recovery Plan

**Project**: `leavexa` (`projects/leavexa/databases/(default)`, `STANDARD`, `FIRESTORE_NATIVE`)

## 1. Critical Collections Requiring Backup
- `users` (profiles, roles, `departmentId`, `approvalStatus`, `isActive`)
- `departments` (canonical 10 departments and `headUid` bindings)
- `employee_ids` (uniqueness reservations)
- `leave_applications` (active and historical applications with department snapshots)
- `leave_balances` (annual allotted & used leave balances)
- `audit_logs` (immutable compliance trail)
- `notifications` & `system_config`

## 2. Spark (Free) vs. Blaze (Paid) Backup Options

| Capability | Available on Spark? | Notes |
|---|---|---|
| **Managed Firestore Export (`gcloud firestore export` to GCS)** | **No (Requires Blaze)** | Automated/managed GCS exports and scheduled Cloud Storage backups require Blaze billing. |
| **Point-in-Time Recovery (PITR)** | **No (Requires Blaze)** | Continuous 7-day PITR is a paid Cloud Firestore feature. |
| **Read-Only Admin SDK JSON Snapshot** | **Yes (Free, Manual)** | Small university-scale datasets can be exported read-only via a local Node Admin SDK script (`serviceAccountKey.json`) to an encrypted local drive within Spark's 50K daily read quota. |

## 3. Recommended Schedule & Retention (Once on Blaze)
- **Frequency**: Daily automated export of `users`, `departments`, `employee_ids`, `leave_applications`, `leave_balances`, and `audit_logs`; pre-deployment snapshot before any schema/rules migration.
- **Retention**: 30 days daily, 12 months monthly archive.
- **Access Control & Accidental Deletion Protection**:
  - Store backups in a dedicated restricted GCS bucket (or encrypted local vault) accessible only to Project Owners.
  - Enable GCS Bucket Versioning / Object Lock (Retention Policy) and restrict `roles/datastore.owner` so clients cannot delete `audit_logs` or `leave_balances` (`allow write: if false` in `firestore.rules`).

## 4. Recovery & Verification Procedure
1. **Restore into Staging / Emulator First**: Import backup data into a local Firestore Emulator (`firebase emulators:start --import=...`) or a non-production staging project before touching production.
2. **Verify Data Integrity**: Confirm document counts match for `users` (including all 12 institutional accounts), `departments` (10), `employee_ids`, `leave_applications`, and `leave_balances`.
3. **Reconcile Auth Custom Claims**: Run `syncUserCustomClaims` / `provision_fixed_staff.js` (read/reconcile mode) if user role metadata was restored.
