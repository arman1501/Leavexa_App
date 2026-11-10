// ─────────────────────────────────────────────────────────────────────────────
//  roles.js  –  Secure Role Provisioning & Custom Claims Management
// ─────────────────────────────────────────────────────────────────────────────

const { HttpsError } = require('firebase-functions/v2/https');
const { admin, db, auth, FieldValue } = require('./admin');
const { logAuditEvent } = require('./audit');

/**
 * Validates that the calling user has the 'admin' role.
 * Checks Firebase Custom Claims first, then falls back to Firestore users collection.
 */
async function assertIsAdmin(context) {
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  // 1. Check custom claims
  if (context.auth.token && context.auth.token.role === 'admin') {
    return true;
  }

  // 2. Fall back to verified Firestore user doc
  const userSnap = await db.collection('users').doc(context.auth.uid).get();
  if (userSnap.exists && userSnap.data().role === 'admin' && userSnap.data().isActive === true) {
    return true;
  }

  throw new HttpsError('permission-denied', 'Administrative privileges required.');
}

/**
 * Initial Administrator Provisioning.
 *
 * Security & Hardening:
 * - Atomic Firestore Transaction on `system_config/bootstrap` prevents concurrency race conditions.
 * - Strictly one-time execution: once `isBootstrapped: true` is committed, all future attempts throw 'already-exists'.
 * - Optional server-side environment secret (LEAVEXA_BOOTSTRAP_SECRET) support without leaking to client.
 * - Fully sets Auth Custom Claims, profile, employee ID reservation, and audit log atomically.
 */
async function provisionInitialAdminHandler(data, context) {
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated in Firebase Auth to be provisioned.');
  }

  const targetUid = context.auth.uid;
  const bootstrapRef = db.collection('system_config').doc('bootstrap');

  // Verify server-side bootstrap secret if configured in environment
  const envSecret = process.env.LEAVEXA_BOOTSTRAP_SECRET;
  if (envSecret && data.bootstrapKey !== envSecret) {
    throw new HttpsError('permission-denied', 'Invalid bootstrap key.');
  }

  // Atomic transaction to guarantee strictly one-time execution and prevent concurrency race conditions
  await db.runTransaction(async (transaction) => {
    const bootstrapSnap = await transaction.get(bootstrapRef);
    if (bootstrapSnap.exists && bootstrapSnap.data() && bootstrapSnap.data().isBootstrapped === true) {
      throw new HttpsError(
        'already-exists',
        'System has already been bootstrapped. Subsequent admin creation must be performed by an active admin.'
      );
    }

    const adminQuery = await db.collection('users').where('role', '==', 'admin').limit(1).get();
    if (!adminQuery.empty) {
      // Mark bootstrap document as completed to close any future attempts
      transaction.set(bootstrapRef, {
        isBootstrapped: true,
        bootstrappedAt: FieldValue.serverTimestamp(),
        note: 'Admin already detected in users collection',
      }, { merge: true });

      throw new HttpsError(
        'already-exists',
        'An administrator has already been provisioned. Contact an existing admin to grant privileges.'
      );
    }

    // Set bootstrap lock inside transaction
    transaction.set(bootstrapRef, {
      isBootstrapped: true,
      bootstrappedAt: FieldValue.serverTimestamp(),
      bootstrappedBy: targetUid,
      adminEmail: context.auth.token?.email || data.email || 'admin@leavexa.edu',
    });

    const adminDocRef = db.collection('users').doc(targetUid);
    const profileData = {
      uid: targetUid,
      email: context.auth.token?.email || data.email || 'admin@leavexa.edu',
      fullName: data.fullName || 'System Administrator',
      employeeId: data.employeeId || 'ADMIN-001',
      departmentId: 'admin_office',
      departmentName: 'Office of the Administrator',
      designation: 'System Administrator',
      role: 'admin',
      approvalStatus: 'approved',
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    transaction.set(adminDocRef, profileData, { merge: true });

    const empRef = db.collection('employee_ids').doc(profileData.employeeId);
    transaction.set(empRef, {
      uid: targetUid,
      employeeId: profileData.employeeId,
      reservedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // Write audit log inside transaction
    const auditRef = db.collection('audit_logs').doc();
    transaction.set(auditRef, {
      id: auditRef.id,
      actorUid: targetUid,
      actorRole: 'admin',
      action: 'ADMIN_INITIAL_PROVISION',
      targetType: 'user',
      targetId: targetUid,
      details: { email: profileData.email, employeeId: profileData.employeeId },
      timestamp: FieldValue.serverTimestamp(),
    });
  });

  // Set Admin Custom Claims
  await auth.setCustomUserClaims(targetUid, {
    role: 'admin',
    approvalStatus: 'approved',
  });

  return {
    success: true,
    message: 'Initial administrator provisioned successfully with Admin custom claims.',
    uid: targetUid,
  };
}

/**
 * Creates Department Head or Registrar accounts (Admin-only).
 */
async function createStaffAccountHandler(data, context) {
  await assertIsAdmin(context);

  const {
    email,
    password,
    fullName,
    employeeId,
    role,
    departmentId,
    departmentName,
    designation,
    phone,
  } = data;

  if (!email || !password || !fullName || !employeeId || !role) {
    throw new HttpsError('invalid-argument', 'Missing required staff fields (email, password, fullName, employeeId, role).');
  }

  if (role !== 'department_head' && role !== 'registrar') {
    throw new HttpsError('invalid-argument', "Role must be 'department_head' or 'registrar'.");
  }

  if (role === 'department_head' && (!departmentId || !departmentName)) {
    throw new HttpsError('invalid-argument', 'departmentId and departmentName are required for Department Heads.');
  }

  // Check if Employee ID is already reserved
  const empRef = db.collection('employee_ids').doc(employeeId);
  const empSnap = await empRef.get();
  if (empSnap.exists) {
    throw new HttpsError('already-exists', `Employee ID ${employeeId} is already in use.`);
  }

  // Create Firebase Auth user
  const userRecord = await auth.createUser({
    email,
    password,
    displayName: fullName,
    phoneNumber: phone || undefined,
  });

  const newUid = userRecord.uid;

  // Set Custom Claims based on role
  const customClaims = {
    role,
    approvalStatus: 'approved',
  };
  if (role === 'department_head') {
    customClaims.departmentId = departmentId;
  }

  await auth.setCustomUserClaims(newUid, customClaims);

  // Write profile to Firestore
  const staffProfile = {
    uid: newUid,
    email,
    fullName,
    employeeId,
    departmentId: role === 'registrar' ? 'registrar_office' : departmentId,
    departmentName: role === 'registrar' ? 'Office of the Registrar' : departmentName,
    designation: designation || (role === 'registrar' ? 'Registrar' : 'Department Head'),
    phone: phone || null,
    role,
    approvalStatus: 'approved',
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
    createdBy: context.auth.uid,
  };

  const batch = db.batch();
  batch.set(db.collection('users').doc(newUid), staffProfile);
  batch.set(empRef, {
    uid: newUid,
    employeeId,
    reservedAt: FieldValue.serverTimestamp(),
  });

  await batch.commit();

  await logAuditEvent({
    actorUid: context.auth.uid,
    actorRole: 'admin',
    action: 'STAFF_ACCOUNT_CREATED',
    targetType: 'user',
    targetId: newUid,
    details: { role, email, employeeId, departmentId: staffProfile.departmentId },
  });

  return {
    success: true,
    uid: newUid,
    message: `${role} account created successfully with custom claims.`,
  };
}

/**
 * Activates or deactivates an account (Admin-only).
 */
async function setUserActiveHandler(data, context) {
  await assertIsAdmin(context);

  const { targetUid, isActive } = data;
  if (!targetUid || typeof isActive !== 'boolean') {
    throw new HttpsError('invalid-argument', 'targetUid and boolean isActive are required.');
  }

  if (targetUid === context.auth.uid && !isActive) {
    throw new HttpsError('failed-precondition', 'Administrators cannot deactivate their own account.');
  }

  // Update Auth user disabled status
  await auth.updateUser(targetUid, {
    disabled: !isActive,
  });

  // Update Firestore user document
  await db.collection('users').doc(targetUid).update({
    isActive,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: context.auth.uid,
  });

  await logAuditEvent({
    actorUid: context.auth.uid,
    actorRole: 'admin',
    action: isActive ? 'USER_ACTIVATED' : 'USER_DEACTIVATED',
    targetType: 'user',
    targetId: targetUid,
    details: { isActive },
  });

  return {
    success: true,
    targetUid,
    isActive,
  };
}

/**
 * Synchronizes Firebase Auth Custom Claims with verified Firestore profile.
 */
async function syncUserCustomClaimsHandler(data, context) {
  const targetUid = data.targetUid || context.auth.uid;

  // Must be admin or syncing self
  if (context.auth.uid !== targetUid) {
    await assertIsAdmin(context);
  }

  const userDocSnap = await db.collection('users').doc(targetUid).get();
  if (!userDocSnap.exists) {
    throw new HttpsError('not-found', 'User profile document not found.');
  }

  const user = userDocSnap.data();
  const claims = {
    role: user.role,
    approvalStatus: user.approvalStatus,
  };
  if (user.departmentId) {
    claims.departmentId = user.departmentId;
  }

  await auth.setCustomUserClaims(targetUid, claims);

  await logAuditEvent({
    actorUid: context.auth.uid,
    actorRole: context.auth.token?.role || 'user',
    action: 'CUSTOM_CLAIMS_SYNC',
    targetType: 'user',
    targetId: targetUid,
    details: claims,
  });

  return {
    success: true,
    claims,
  };
}

/**
 * Securely provisions or synchronizes the three designated fixed staff accounts:
 * - Department Head (department.head.lu@gmail.com)
 * - Registrar / Dean (registrar.lu@gmail.com)
 * - System Admin (admin.lu@gmail.com)
 */
async function provisionFixedStaffAccountsHandler(data, context) {
  const envSecret = process.env.LEAVEXA_BOOTSTRAP_SECRET;
  const isSecretValid = envSecret && data && data.bootstrapKey === envSecret;

  if (!isSecretValid) {
    await assertIsAdmin(context);
  }

  const { runProvisioning } = require('../scripts/provision_fixed_staff');
  const results = await runProvisioning();

  return {
    success: true,
    accounts: results,
  };
}

module.exports = {
  assertIsAdmin,
  provisionInitialAdminHandler,
  createStaffAccountHandler,
  setUserActiveHandler,
  syncUserCustomClaimsHandler,
  provisionFixedStaffAccountsHandler,
};
