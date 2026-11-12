// ─────────────────────────────────────────────────────────────────────────────
//  roles.js  –  Secure Role Provisioning & Custom Claims Management
// ─────────────────────────────────────────────────────────────────────────────

const { HttpsError } = require('firebase-functions/v2/https');
const { admin, db, auth, FieldValue } = require('./admin');
const { logAuditEvent } = require('./audit');

const INSTITUTIONAL_ALLOWLIST = Object.freeze({
  'admin.lu@gmail.com': { role: 'admin', departmentId: 'admin_office' },
  'registrar.lu@gmail.com': { role: 'registrar', departmentId: 'registrar_office' },
  'head.cse.lu@gmail.com': { role: 'department_head', departmentId: 'dept_cse' },
  'head.eee.lu@gmail.com': { role: 'department_head', departmentId: 'dept_eee' },
  'head.bba.lu@gmail.com': { role: 'department_head', departmentId: 'dept_bba' },
  'head.ce.lu@gmail.com': { role: 'department_head', departmentId: 'dept_civil' },
  'head.law.lu@gmail.com': { role: 'department_head', departmentId: 'dept_law' },
  'head.arch.lu@gmail.com': { role: 'department_head', departmentId: 'dept_arch' },
  'head.ph.lu@gmail.com': { role: 'department_head', departmentId: 'dept_public_health' },
  'head.thm.lu@gmail.com': { role: 'department_head', departmentId: 'dept_thm' },
  'head.islamic.lu@gmail.com': { role: 'department_head', departmentId: 'dept_islamic_studies' },
  'head.english.lu@gmail.com': { role: 'department_head', departmentId: 'dept_english' },
});

function getInstitutionalSpec(email) {
  if (!email || typeof email !== 'string') return null;
  return INSTITUTIONAL_ALLOWLIST[email.trim().toLowerCase()] || null;
}

function assertInstitutionalAccountConfig(email, role, departmentId) {
  const spec = getInstitutionalSpec(email);
  if (!spec) {
    throw new HttpsError('permission-denied', 'This institutional account is not authorized.');
  }
  if (spec.role !== role) {
    throw new HttpsError('invalid-argument', 'Your account role or department configuration is invalid.');
  }
  if (role === 'department_head' && String(departmentId || '').trim() !== spec.departmentId) {
    throw new HttpsError('invalid-argument', 'Your account role or department configuration is invalid.');
  }
  return spec;
}

/**
 * Validates that the calling user has the 'admin' role.
 * Checks Firebase Custom Claims first, then falls back to Firestore users collection.
 */
async function assertIsAdmin(context) {
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const tokenEmail = context.auth.token && context.auth.token.email
    ? String(context.auth.token.email).trim().toLowerCase()
    : '';
  if (tokenEmail && tokenEmail !== 'admin.lu@gmail.com') {
    throw new HttpsError('permission-denied', 'This institutional account is not authorized.');
  }

  const userSnap = await db.collection('users').doc(context.auth.uid).get();

  // If a Firestore user doc exists, verify it hasn't been deactivated or demoted
  if (userSnap.exists) {
    const userData = userSnap.data();
    const docEmail = userData.email ? String(userData.email).trim().toLowerCase() : '';
    if (docEmail && docEmail !== 'admin.lu@gmail.com') {
      throw new HttpsError('permission-denied', 'This institutional account is not authorized.');
    }
    if (userData.role !== 'admin' || userData.isActive === false) {
      throw new HttpsError('permission-denied', 'Administrative privileges required.');
    }
    return true;
  }

  // Fallback for pre-seeded admin custom claims without a profile doc
  if (context.auth.token && context.auth.token.role === 'admin') {
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

  const normalizedEmail = String(email).trim().toLowerCase();
  const normalizedEmployeeId = String(employeeId).trim().toUpperCase();
  const cleanFullName = String(fullName).trim();
  const cleanPhone = typeof phone === 'string' && phone.trim().length > 0 ? phone.trim() : null;

  if (!normalizedEmail || !cleanFullName || normalizedEmployeeId.length < 3) {
    throw new HttpsError('invalid-argument', 'Valid email, fullName, and employeeId (min 3 characters) are required.');
  }

  if (role !== 'department_head' && role !== 'registrar') {
    throw new HttpsError('invalid-argument', "Role must be 'department_head' or 'registrar'.");
  }

  if (role === 'department_head' && (!departmentId || !departmentName)) {
    throw new HttpsError('invalid-argument', 'departmentId and departmentName are required for Department Heads.');
  }

  // Enforce centralized 12-account institutional email allowlist
  assertInstitutionalAccountConfig(normalizedEmail, role, departmentId);

  // Check if normalized Employee ID is already reserved
  const empRef = db.collection('employee_ids').doc(normalizedEmployeeId);
  const empSnap = await empRef.get();
  if (empSnap.exists) {
    throw new HttpsError('already-exists', `Employee ID ${normalizedEmployeeId} is already in use.`);
  }

  // Pass phoneNumber to Firebase Auth only when strictly E.164 compliant
  const e164Phone = cleanPhone && /^\+[1-9]\d{6,14}$/.test(cleanPhone) ? cleanPhone : undefined;

  // Create Firebase Auth user
  let userRecord;
  try {
    userRecord = await auth.createUser({
      email: normalizedEmail,
      password,
      displayName: cleanFullName,
      phoneNumber: e164Phone,
    });
  } catch (err) {
    if (err && (err.code === 'auth/email-already-exists' || err.code === 'auth/email-already-in-use')) {
      throw new HttpsError('already-exists', `Email ${normalizedEmail} is already registered.`);
    }
    throw err;
  }

  const newUid = userRecord.uid;

  try {
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
      email: normalizedEmail,
      fullName: cleanFullName,
      employeeId: normalizedEmployeeId,
      departmentId: role === 'registrar' ? 'registrar_office' : departmentId,
      departmentName: role === 'registrar' ? 'Office of the Registrar' : departmentName,
      designation: (designation && String(designation).trim()) || (role === 'registrar' ? 'Registrar' : 'Department Head'),
      phone: cleanPhone,
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
      employeeId: normalizedEmployeeId,
      reservedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();

    await logAuditEvent({
      actorUid: context.auth.uid,
      actorRole: 'admin',
      action: 'STAFF_ACCOUNT_CREATED',
      targetType: 'user',
      targetId: newUid,
      details: {
        role,
        email: normalizedEmail,
        employeeId: normalizedEmployeeId,
        departmentId: staffProfile.departmentId,
      },
    });

    return {
      success: true,
      uid: newUid,
      message: `${role} account created successfully with custom claims.`,
    };
  } catch (err) {
    // Compensating rollback: never leave an orphaned Firebase Auth user if profile provisioning fails
    if (typeof auth.deleteUser === 'function') {
      await auth.deleteUser(newUid).catch(() => {});
    }
    throw err;
  }
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

  if (!isActive && typeof auth.revokeRefreshTokens === 'function') {
    await auth.revokeRefreshTokens(targetUid);
  }

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
  if (user.role !== 'faculty' || getInstitutionalSpec(user.email)) {
    assertInstitutionalAccountConfig(user.email, user.role, user.departmentId);
  }
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
 * Securely provisions or synchronizes the 12 designated institutional accounts:
 * - 1 System Admin (admin.lu@gmail.com)
 * - 1 Registrar / Dean (registrar.lu@gmail.com)
 * - 10 Department Heads (head.<dept>.lu@gmail.com)
 */
async function provisionFixedStaffAccountsHandler(data, context) {
  const envSecret = process.env.LEAVEXA_BOOTSTRAP_SECRET;
  const isSecretValid = envSecret && data && data.bootstrapKey === envSecret;

  if (!isSecretValid) {
    await assertIsAdmin(context);
  }

  const { runProvisioning } = require('../scripts/provision_fixed_staff');
  const results = await runProvisioning({
    authorizeReconciliation: Boolean(data && data.authorizeReconciliation),
    actorUid: context?.auth?.uid || 'SYSTEM_PROVISIONING',
  });

  return {
    success: true,
    accounts: results,
  };
}

/**
 * Transfers a Faculty member to another verified department (Admin-only).
 * Preserves existing historical leave_applications with their original departmentId
 * while updating future applications, custom claims, and audit_logs.
 */
async function transferFacultyDepartmentHandler(data, context) {
  await assertIsAdmin(context);

  const targetUid = data && typeof data.targetUid === 'string' ? data.targetUid.trim() : '';
  const newDepartmentId = data && typeof data.newDepartmentId === 'string' ? data.newDepartmentId.trim() : '';
  const reason = data && typeof data.reason === 'string' ? data.reason.trim() : 'Official administrative transfer';

  if (!targetUid || !newDepartmentId) {
    throw new HttpsError('invalid-argument', 'targetUid and newDepartmentId are required.');
  }

  const userRef = db.collection('users').doc(targetUid);
  const deptRef = db.collection('departments').doc(newDepartmentId);

  const [userSnap, deptSnap] = await Promise.all([userRef.get(), deptRef.get()]);
  if (!userSnap.exists) {
    throw new HttpsError('not-found', `User ${targetUid} does not exist.`);
  }
  if (!deptSnap.exists || deptSnap.data().isActive === false) {
    throw new HttpsError('failed-precondition', `Target department '${newDepartmentId}' does not exist or is inactive.`);
  }

  const userData = userSnap.data() || {};
  if (userData.role !== 'faculty' || getInstitutionalSpec(userData.email)) {
    throw new HttpsError('failed-precondition', 'Only faculty members can be transferred via department transfer.');
  }

  const prevDeptId = userData.departmentId || null;
  const prevDeptName = userData.departmentName || null;
  if (prevDeptId === newDepartmentId) {
    throw new HttpsError('failed-precondition', 'Faculty member is already assigned to the selected department.');
  }

  const deptData = deptSnap.data() || {};
  const newDepartmentName = deptData.name || (data && data.newDepartmentName) || newDepartmentId;

  await userRef.update({
    departmentId: newDepartmentId,
    departmentName: newDepartmentName,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: context.auth.uid,
  });

  await auth.setCustomUserClaims(targetUid, {
    role: 'faculty',
    approvalStatus: userData.approvalStatus || 'pending',
    departmentId: newDepartmentId,
  });

  if (typeof auth.revokeRefreshTokens === 'function') {
    await auth.revokeRefreshTokens(targetUid);
  }

  const notifRef = db.collection('notifications').doc();
  await notifRef.set({
    id: notifRef.id,
    recipientUid: targetUid,
    title: 'Department Assignment Updated',
    body: `Your official department has been updated to ${newDepartmentName}. Existing historical applications remain under your prior department record.`,
    type: 'department_transfer',
    isRead: false,
    createdAt: new Date().toISOString(),
  });

  await logAuditEvent({
    actorUid: context.auth.uid,
    actorRole: 'admin',
    action: 'FACULTY_DEPARTMENT_TRANSFER',
    targetType: 'user',
    targetId: targetUid,
    details: {
      previousDepartmentId: prevDeptId,
      previousDepartmentName: prevDeptName,
      newDepartmentId,
      newDepartmentName,
      reason,
    },
  });

  return {
    success: true,
    targetUid,
    previousDepartmentId: prevDeptId,
    newDepartmentId,
    newDepartmentName,
  };
}

module.exports = {
  INSTITUTIONAL_ALLOWLIST,
  getInstitutionalSpec,
  assertInstitutionalAccountConfig,
  assertIsAdmin,
  provisionInitialAdminHandler,
  createStaffAccountHandler,
  setUserActiveHandler,
  syncUserCustomClaimsHandler,
  provisionFixedStaffAccountsHandler,
  transferFacultyDepartmentHandler,
};
