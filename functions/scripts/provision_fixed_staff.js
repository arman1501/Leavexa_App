/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  provision_fixed_staff.js  –  LEAVEXA Fixed Staff Account Provisioning
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Secure idempotent provisioning for:
 * 1. Department Head: department.head.lu@gmail.com
 * 2. Registrar / Dean: registrar.lu@gmail.com
 * 3. System Admin: admin.lu@gmail.com
 *
 * Security Guarantees:
 * - NEVER writes plaintext passwords to Firestore or logs.
 * - Idempotent: If an account exists in Firebase Auth, leaves password intact
 *   and synchronizes profile and Custom Claims.
 * - Cross-binds employee_ids reservation atomically.
 * - Records audit trail in Firestore `audit_logs`.
 */

'use strict';

const admin = require('firebase-admin');

// Connect to Emulators if configured or running locally
if (process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.NODE_ENV || process.env.NODE_ENV === 'development') {
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

const auth = admin.auth();
const db = admin.firestore();

// Fixed staff definitions with credentials supplied via environment or default specification
const STAFF_ACCOUNTS = [
  {
    role: 'department_head',
    email: 'department.head.lu@gmail.com',
    passwordEnvVar: 'STAFF_HEAD_PASSWORD',
    defaultPassword: process.env.STAFF_HEAD_PASSWORD || 'LU_Head@63A',
    fullName: 'Department Head (CSE)',
    employeeId: 'HEAD-CSE-001',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science & Engineering',
    designation: 'Department Head',
    phone: '+8801700000001',
  },
  {
    role: 'registrar',
    email: 'registrar.lu@gmail.com',
    passwordEnvVar: 'STAFF_REGISTRAR_PASSWORD',
    defaultPassword: process.env.STAFF_REGISTRAR_PASSWORD || 'LU_Register@63A',
    fullName: 'Office of the Registrar',
    employeeId: 'REG-001',
    departmentId: 'registrar_office',
    departmentName: 'Office of the Registrar',
    designation: 'Registrar',
    phone: '+8801700000002',
  },
  {
    role: 'admin',
    email: 'admin.lu@gmail.com',
    passwordEnvVar: 'STAFF_ADMIN_PASSWORD',
    defaultPassword: process.env.STAFF_ADMIN_PASSWORD || 'LU_Admin@63A',
    fullName: 'System Administrator',
    employeeId: 'ADMIN-001',
    departmentId: 'admin_office',
    departmentName: 'Office of the Administrator',
    designation: 'System Administrator',
    phone: '+8801700000003',
  },
];

async function provisionAccount(account) {
  const {
    role,
    email,
    defaultPassword,
    fullName,
    employeeId,
    departmentId,
    departmentName,
    designation,
    phone,
  } = account;

  let uid;
  let isNewAuth = false;

  // 1. Check if Firebase Auth account already exists
  try {
    const existingUser = await auth.getUserByEmail(email);
    uid = existingUser.uid;
    console.log(`[AUTH] Existing user found for ${email} (UID: ${uid}). Password preserved.`);
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      const createdUser = await auth.createUser({
        email,
        password: defaultPassword,
        displayName: fullName,
        phoneNumber: phone,
        emailVerified: true,
      });
      uid = createdUser.uid;
      isNewAuth = true;
      console.log(`[AUTH] Created new Auth account for ${email} (UID: ${uid}).`);
    } else {
      throw err;
    }
  }

  // 2. Set Custom Claims
  const claims = {
    role,
    approvalStatus: 'approved',
  };
  if (role === 'department_head') {
    claims.departmentId = departmentId;
  }
  await auth.setCustomUserClaims(uid, claims);
  console.log(`[CLAIMS] Custom claims set for ${email}:`, claims);

  // 3. Atomically upsert Firestore user profile & employee ID reservation
  const userRef = db.collection('users').doc(uid);
  const empRef = db.collection('employee_ids').doc(employeeId);
  const auditRef = db.collection('audit_logs').doc();

  await db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);

    const profileData = {
      uid,
      email,
      fullName,
      employeeId,
      departmentId,
      departmentName,
      designation,
      phone: phone || null,
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

    // Reserve Employee ID
    transaction.set(empRef, {
      uid,
      employeeId,
      reservedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Record audit event
    transaction.set(auditRef, {
      id: auditRef.id,
      actorUid: 'SYSTEM_BOOTSTRAP',
      actorRole: 'system',
      action: isNewAuth ? 'STAFF_ACCOUNT_PROVISIONED' : 'STAFF_ACCOUNT_SYNCHRONIZED',
      targetType: 'user',
      targetId: uid,
      details: { role, email, employeeId, departmentId },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  console.log(`[FIRESTORE] Profile and Employee ID (${employeeId}) synchronized for ${email}.`);

  return {
    email,
    uid,
    role,
    employeeId,
    departmentId,
    isNewAuth,
    status: 'ACTIVE_AND_APPROVED',
  };
}

async function runProvisioning() {
  console.log('================================================================');
  console.log('  LEAVEXA Fixed Staff Account Provisioning Engine');
  console.log('================================================================');

  const results = [];
  for (const acc of STAFF_ACCOUNTS) {
    try {
      const res = await provisionAccount(acc);
      results.push(res);
    } catch (err) {
      console.error(`[ERROR] Provisioning failed for ${acc.email}:`, err.message);
      results.push({ email: acc.email, status: 'FAILED', error: err.message });
    }
  }

  console.log('\n================================================================');
  console.log('  Provisioning Summary');
  console.log('================================================================');
  console.table(results);
  return results;
}

if (require.main === module) {
  runProvisioning()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Fatal error during provisioning:', err);
      process.exit(1);
    });
}

module.exports = {
  STAFF_ACCOUNTS,
  provisionAccount,
  runProvisioning,
};
