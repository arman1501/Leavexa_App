# Institutional Account Handover — LEAVEXA

**Firebase Project**: `leavexa`  
**Security Notice**: This document intentionally omits all passwords, private keys, service account JSONs, and tokens.

## Safe Institutional Account Inventory (12 Accounts)

| # | Email | Role | Department ID | Employee ID | Production Firebase UID |
|---|---|---|---|---|---|
| 1 | `admin.lu@gmail.com` | `admin` | `admin_office` | `ADMIN-001` | `0PpyKNwpZNafypFXClFiVZEseFh2` |
| 2 | `registrar.lu@gmail.com` | `registrar` | `registrar_office` | `REG-001` | `Hbr8GfkC3tMoG6CAxrtmFXYwj5l1` |
| 3 | `head.cse.lu@gmail.com` | `department_head` | `dept_cse` | `HEAD-CSE-001` | `pdsgkXGmYyORw7APsSTqpbnGHbw1` |
| 4 | `head.eee.lu@gmail.com` | `department_head` | `dept_eee` | `HEAD-EEE-001` | `snIzkBXhVtSNcQO7IRIwnoN5lqx1` |
| 5 | `head.bba.lu@gmail.com` | `department_head` | `dept_bba` | `HEAD-BBA-001` | `ynsPQEoEoNNlhs6VdH08OgbrzDZ2` |
| 6 | `head.ce.lu@gmail.com` | `department_head` | `dept_civil` | `HEAD-CE-001` | `wKP8irHUbxXoyj7mdHVbq8ZzpFk2` |
| 7 | `head.law.lu@gmail.com` | `department_head` | `dept_law` | `HEAD-LAW-001` | `KXKYTyQZuRWfv11ON2lPPhlck2z1` |
| 8 | `head.arch.lu@gmail.com` | `department_head` | `dept_arch` | `HEAD-ARCH-001` | `PB4vZJu4TgO7dMlFI99jwbXa24D2` |
| 9 | `head.ph.lu@gmail.com` | `department_head` | `dept_public_health` | `HEAD-PH-001` | `kJ6Gxpq4w8U8tRqbUY3QM15bYa52` |
| 10 | `head.thm.lu@gmail.com` | `department_head` | `dept_thm` | `HEAD-THM-001` | `7GRMKqtBaFXTgcKLnJmT4SqFRDa2` |
| 11 | `head.islamic.lu@gmail.com` | `department_head` | `dept_islamic_studies` | `HEAD-IS-001` | `NZIIekbyMfVrc0R16pFYvJUvZB52` |
| 12 | `head.english.lu@gmail.com` | `department_head` | `dept_english` | `HEAD-ENG-001` | `8mRccuBeucbJrdVItFVFhWD6qin1` |

## Secure Credential Handover & Protection Rules
1. **Out-of-Band Delivery**: Deliver each account's initial password individually to the authorized office holder via an encrypted, one-to-one channel (or sealed institutional letter). **Never** post passwords in group chats, Slack/WhatsApp groups, email threads, or git repositories.
2. **Immediate Password Rotation**: Require each officer (especially `admin.lu@gmail.com` and `registrar.lu@gmail.com`) to rotate their initial password immediately after first sign-in using Firebase Auth's password reset or account update flow.
3. **Protecting Admin & Registrar Accounts**:
   - Restrict Firebase Console / GCP IAM access to named university IT administrators only.
   - Enable **2-Step Verification / MFA** on the underlying Google Workspace / Gmail accounts and Firebase Console administrator accounts.
   - Never share `serviceAccountKey.json` or `.env.institutional`; delete temporary local service account keys once provisioning is complete or store them in an encrypted vault.
4. **Compromised Account Recovery**:
   - Immediately disable the affected Auth account or call `setUserActive(..., isActive: false)` (which revokes refresh tokens).
   - Rotate the password in Firebase Auth, inspect `/audit_logs` for unauthorized actions, and re-enable only after verification.
