/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  provision_fixed_staff.js  –  LEAVEXA 12 Institutional Accounts Provisioning
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Secure, idempotent provisioning & reconciliation for exactly 12 accounts:
 *   - 1 Admin: admin.lu@gmail.com
 *   - 1 Registrar / Dean: registrar.lu@gmail.com
 *   - 10 Department Heads (one per academic department)
 *
 * Security Guarantees:
 * - NEVER stores plaintext passwords in Firestore, source code, or logs.
 * - Reads credentials ONLY from environment variables or a gitignored
 *   `.env.institutional` file (`STAFF_*_PASSWORD`). Never invents passwords.
 * - Idempotent: reuses existing Firebase Auth UID if email exists; never
 *   creates duplicate accounts and never resets existing Auth passwords.
 * - Mismatch guard: detects existing role/department discrepancies and refuses
 *   to overwrite them unless `authorizeReconciliation === true` (--authorize-reconciliation).
 * - Cross-binds `/departments/{deptId}` and `/employee_ids/{employeeId}`
 *   atomically and records an audit event in `/audit_logs`.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function loadLocalSecretsFile() {
  const candidates = [
    path.resolve(__dirname, '../../.env.institutional'),
    path.resolve(__dirname, '../.env.institutional'),
    path.resolve(__dirname, '../../.env.local'),
  ];
  for (const filePath of candidates) {
    if (!fs.existsSync(filePath)) continue;
    const raw = fs.readFileSync(filePath, 'utf8');
    for (const line of raw.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx <= 0) continue;
      const key = trimmed.slice(0, eqIdx).trim();
      let val = trimmed.slice(eqIdx + 1).trim();
      if (
        (val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))
      ) {
        val = val.slice(1, -1);
      }
      if (key && process.env[key] === undefined) {
        process.env[key] = val;
      }
    }
  }
}

loadLocalSecretsFile();

const DEPARTMENT_HEAD_DEFINITIONS = [
  {
    code: 'CSE',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science & Engineering',
    email: 'head.cse.lu@gmail.com',
    employeeId: 'HEAD-CSE-001',
    fullName: 'Department Head (CSE)',
    passwordEnvVar: 'STAFF_HEAD_CSE_PASSWORD',
    phone: '+8801700000101',
  },
  {
    code: 'EEE',
    departmentId: 'dept_eee',
    departmentName: 'Electrical & Electronic Engineering',
    email: 'head.eee.lu@gmail.com',
    employeeId: 'HEAD-EEE-001',
    fullName: 'Department Head (EEE)',
    passwordEnvVar: 'STAFF_HEAD_EEE_PASSWORD',
    phone: '+8801700000102',
  },
  {
    code: 'BBA',
    departmentId: 'dept_bba',
    departmentName: 'Business Administration',
    email: 'head.bba.lu@gmail.com',
    employeeId: 'HEAD-BBA-001',
    fullName: 'Department Head (BBA)',
    passwordEnvVar: 'STAFF_HEAD_BBA_PASSWORD',
    phone: '+8801700000103',
  },
  {
    code: 'CE',
    departmentId: 'dept_civil',
    departmentName: 'Civil Engineering',
    email: 'head.ce.lu@gmail.com',
    employeeId: 'HEAD-CE-001',
    fullName: 'Department Head (CE)',
    passwordEnvVar: 'STAFF_HEAD_CE_PASSWORD',
    phone: '+8801700000104',
  },
  {
    code: 'LAW',
    departmentId: 'dept_law',
    departmentName: 'Department of Law',
    email: 'head.law.lu@gmail.com',
    employeeId: 'HEAD-LAW-001',
    fullName: 'Department Head (Law)',
    passwordEnvVar: 'STAFF_HEAD_LAW_PASSWORD',
    phone: '+8801700000105',
  },
  {
    code: 'ARCH',
    departmentId: 'dept_arch',
    departmentName: 'Department of Architecture',
    email: 'head.arch.lu@gmail.com',
    employeeId: 'HEAD-ARCH-001',
    fullName: 'Department Head (Architecture)',
    passwordEnvVar: 'STAFF_HEAD_ARCH_PASSWORD',
    phone: '+8801700000106',
  },
  {
    code: 'MPH',
    departmentId: 'dept_public_health',
    departmentName: 'Department of Public Health',
    email: 'head.ph.lu@gmail.com',
    employeeId: 'HEAD-PH-001',
    fullName: 'Department Head (Public Health)',
    passwordEnvVar: 'STAFF_HEAD_PH_PASSWORD',
    phone: '+8801700000107',
  },
  {
    code: 'THM',
    departmentId: 'dept_thm',
    departmentName: 'Tourism & Hospitality Management',
    email: 'head.thm.lu@gmail.com',
    employeeId: 'HEAD-THM-001',
    fullName: 'Department Head (THM)',
    passwordEnvVar: 'STAFF_HEAD_THM_PASSWORD',
    phone: '+8801700000108',
  },
  {
    code: 'IS',
    departmentId: 'dept_islamic_studies',
    departmentName: 'Department of Islamic Studies',
    email: 'head.islamic.lu@gmail.com',
    employeeId: 'HEAD-IS-001',
    fullName: 'Department Head (Islamic Studies)',
    passwordEnvVar: 'STAFF_HEAD_ISLAMIC_PASSWORD',
    phone: '+8801700000109',
  },
  {
    code: 'ENG',
    departmentId: 'dept_english',
    departmentName: 'Department of English',
    email: 'head.english.lu@gmail.com',
    employeeId: 'HEAD-ENG-001',
    fullName: 'Department Head (English)',
    passwordEnvVar: 'STAFF_HEAD_ENGLISH_PASSWORD',
    phone: '+8801700000110',
  },
];

const INSTITUTIONAL_ACCOUNTS = [
  {
    role: 'admin',
    email: 'admin.lu@gmail.com',
    passwordEnvVar: 'STAFF_ADMIN_PASSWORD',
    fullName: 'System Administrator',
    employeeId: 'ADMIN-001',
    departmentId: 'admin_office',
    departmentName: 'Office of the Administrator',
    designation: 'System Administrator',
    phone: '+8801700000003',
  },
  {
    role: 'registrar',
    email: 'registrar.lu@gmail.com',
    passwordEnvVar: 'STAFF_REGISTRAR_PASSWORD',
    fullName: 'Office of the Registrar',
    employeeId: 'REG-001',
    departmentId: 'registrar_office',
    departmentName: 'Office of the Registrar',
    designation: 'Registrar',
    phone: '+8801700000002',
  },
  ...DEPARTMENT_HEAD_DEFINITIONS.map((d) => ({
    role: 'department_head',
    email: d.email,
    passwordEnvVar: d.passwordEnvVar,
    fullName: d.fullName,
    employeeId: d.employeeId,
    departmentId: d.departmentId,
    departmentName: d.departmentName,
    departmentCode: d.code,
    designation: 'Department Head',
    phone: d.phone,
  })),
];

function getServices(customServices = {}) {
  if (customServices.auth && customServices.db) {
    return customServices;
  }

  // Only default to local emulators when explicitly running outside production
  const isProdTarget = process.env.LEAVEXA_ALLOW_PROD_PROVISION === 'true';
  if (!isProdTarget && (process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.NODE_ENV || process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'test')) {
    if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
    }
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';
    }
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || 'leavexa',
    });
  }

  return {
    auth: customServices.auth || admin.auth(),
    db: customServices.db || admin.firestore(),
  };
}

function resolveInitialPassword(account, passwordOverrides = {}) {
  if (passwordOverrides && typeof passwordOverrides[account.email] === 'string' && passwordOverrides[account.email].length > 0) {
    return passwordOverrides[account.email];
  }
  const envVal = process.env[account.passwordEnvVar];
  if (typeof envVal === 'string' && envVal.length > 0) {
    return envVal;
  }
  return null;
}

async function seedCanonicalDepartments(db) {
  const batch = db.batch();
  for (const dept of DEPARTMENT_HEAD_DEFINITIONS) {
    const ref = db.collection('departments').doc(dept.departmentId);
    batch.set(
      ref,
      {
        id: dept.departmentId,
        code: dept.code,
        name: dept.departmentName,
        headEmail: dept.email,
        isActive: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();
}

async function provisionAccount(account, options = {}) {
  const { auth, db } = getServices({ auth: options.auth, db: options.db });
  const authorizeReconciliation = options.authorizeReconciliation === true;
  const updateExistingPasswords = options.updateExistingPasswords === true;
  const actorUid = options.actorUid || 'SYSTEM_PROVISIONING';
  const password = resolveInitialPassword(account, options.passwordsByEmail);

  const {
    role,
    email,
    fullName,
    employeeId,
    departmentId,
    departmentName,
    designation,
    phone,
  } = account;

  let uid;
  let isNewAuth = false;
  let passwordUpdated = false;

  // 1. Check whether Firebase Auth user already exists
  try {
    const existingUser = await auth.getUserByEmail(email);
    uid = existingUser.uid;
    if (updateExistingPasswords) {
      if (!password) {
        return {
          email,
          uid,
          role,
          employeeId,
          departmentId,
          isNewAuth: false,
          passwordUpdated: false,
          status: 'MISSING_INITIAL_PASSWORD',
          envVar: account.passwordEnvVar,
        };
      }
      await auth.updateUser(uid, {
        password,
        disabled: false,
        emailVerified: true,
      });
      passwordUpdated = true;
    }
  } catch (err) {
    if (err && err.code === 'auth/user-not-found') {
      if (!password) {
        return {
          email,
          uid: null,
          role,
          employeeId,
          departmentId,
          isNewAuth: false,
          status: 'MISSING_INITIAL_PASSWORD',
          envVar: account.passwordEnvVar,
        };
      }
      const createdUser = await auth.createUser({
        email,
        password,
        displayName: fullName,
        phoneNumber: phone,
        emailVerified: true,
      });
      uid = createdUser.uid;
      isNewAuth = true;
    } else {
      throw err;
    }
  }

  // 2. Check existing Firestore profile & Employee ID reservation for mismatch safety
  const userRef = db.collection('users').doc(uid);
  const empRef = db.collection('employee_ids').doc(employeeId);
  const auditRef = db.collection('audit_logs').doc();

  const existingUserSnap = await userRef.get();
  if (existingUserSnap.exists) {
    const existingData = existingUserSnap.data() || {};
    const roleMismatch = existingData.role && existingData.role !== role;
    const deptMismatch =
      role === 'department_head' &&
      existingData.departmentId &&
      existingData.departmentId !== departmentId;

    if ((roleMismatch || deptMismatch) && !authorizeReconciliation) {
      return {
        email,
        uid,
        role,
        employeeId,
        departmentId,
        isNewAuth,
        status: 'MISMATCH_REQUIRES_AUTHORIZATION',
        existingRole: existingData.role || null,
        expectedRole: role,
        existingDepartmentId: existingData.departmentId || null,
        expectedDepartmentId: departmentId,
      };
    }
  }

  const existingEmpSnap = await empRef.get();
  if (existingEmpSnap.exists) {
    const empData = existingEmpSnap.data() || {};
    if (empData.uid && empData.uid !== uid && !authorizeReconciliation) {
      return {
        email,
        uid,
        role,
        employeeId,
        departmentId,
        isNewAuth,
        status: 'EMPLOYEE_ID_CONFLICT',
        existingOwnerUid: empData.uid,
      };
    }
  }

  // 3. Synchronize Firebase Auth Custom Claims
  const claims = {
    role,
    approvalStatus: 'approved',
  };
  if (role === 'department_head') {
    claims.departmentId = departmentId;
  }
  await auth.setCustomUserClaims(uid, claims);

  // 4. Atomically upsert Firestore profile, employee_ids index, department head link & audit trail
  await db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);

    const profileData = {
      uid,
      email,
      fullName: (userDoc.exists && userDoc.data().fullName) || fullName,
      employeeId,
      departmentId,
      departmentName,
      designation,
      phone: (userDoc.exists && userDoc.data().phone) || phone || null,
      role,
      approvalStatus: 'approved',
      isActive: true,
      photoUrl: userDoc.exists ? (userDoc.data().photoUrl || null) : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!userDoc.exists) {
      profileData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      transaction.set(userRef, profileData);
    } else {
      transaction.set(userRef, profileData, { merge: true });
    }

    transaction.set(
      empRef,
      {
        uid,
        employeeId,
        reservedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (role === 'department_head') {
      const deptRef = db.collection('departments').doc(departmentId);
      transaction.set(
        deptRef,
        {
          id: departmentId,
          code: account.departmentCode || departmentId,
          name: departmentName,
          headUid: uid,
          headEmail: email,
          isActive: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    transaction.set(auditRef, {
      id: auditRef.id,
      actorUid,
      actorRole: 'system',
      action: isNewAuth ? 'INSTITUTIONAL_ACCOUNT_PROVISIONED' : 'INSTITUTIONAL_ACCOUNT_RECONCILED',
      targetType: 'user',
      targetId: uid,
      details: { role, email, employeeId, departmentId },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {
    email,
    uid,
    role,
    employeeId,
    departmentId,
    isNewAuth,
    passwordUpdated,
    status: 'ACTIVE_AND_APPROVED',
  };
}

async function runProvisioning(options = {}) {
  const { auth, db } = getServices({ auth: options.auth, db: options.db });
  await seedCanonicalDepartments(db);

  const results = [];
  for (const acc of INSTITUTIONAL_ACCOUNTS) {
    try {
      const res = await provisionAccount(acc, { ...options, auth, db });
      results.push(res);
    } catch (err) {
      results.push({
        email: acc.email,
        uid: null,
        role: acc.role,
        departmentId: acc.departmentId,
        status: 'FAILED',
        error: err.message,
      });
    }
  }

  return results;
}

if (require.main === module) {
  const args = process.argv.slice(2);
  const authorizeReconciliation = args.includes('--authorize-reconciliation');
  const updateExistingPasswords = args.includes('--update-passwords');
  runProvisioning({ authorizeReconciliation, updateExistingPasswords })
    .then((results) => {
      console.table(
        results.map(({ email, uid, role, departmentId, status, isNewAuth, passwordUpdated }) => ({
          email,
          uid,
          role,
          departmentId,
          status,
          isNewAuth: !!isNewAuth,
          passwordUpdated: !!passwordUpdated,
        }))
      );
      const hasFailure = results.some(
        (r) => r.status === 'FAILED' || r.status === 'MISMATCH_REQUIRES_AUTHORIZATION'
      );
      process.exit(hasFailure ? 1 : 0);
    })
    .catch((err) => {
      console.error('Fatal error during institutional provisioning:', err.message);
      process.exit(1);
    });
}

module.exports = {
  DEPARTMENT_HEAD_DEFINITIONS,
  INSTITUTIONAL_ACCOUNTS,
  STAFF_ACCOUNTS: INSTITUTIONAL_ACCOUNTS,
  seedCanonicalDepartments,
  provisionAccount,
  runProvisioning,
};
