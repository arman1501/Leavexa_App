// ─────────────────────────────────────────────────────────────────────────────
//  approvals.js  –  Faculty Approval Workflow & Default Balance Provisioning
// ─────────────────────────────────────────────────────────────────────────────

const { HttpsError } = require('firebase-functions/v2/https');
const { admin, db, auth, FieldValue } = require('./admin');
const { assertIsAdmin, getInstitutionalSpec } = require('./roles');
const { logAuditEvent } = require('./audit');
const {
  sendPushNotificationToUser,
  sendPushNotificationToAdmins,
} = require('./notifications');

const DEFAULT_LEAVE_ALLOCATIONS = [
  { leaveTypeId: 'casual', leaveTypeName: 'Casual Leave', totalAllotted: 10 },
  { leaveTypeId: 'medical', leaveTypeName: 'Medical Leave', totalAllotted: 14 },
  { leaveTypeId: 'sick', leaveTypeName: 'Sick Leave', totalAllotted: 14 }, // Backward compatibility alias
  { leaveTypeId: 'earned', leaveTypeName: 'Earned Leave', totalAllotted: 30 },
  { leaveTypeId: 'duty', leaveTypeName: 'Duty Leave', totalAllotted: 14 },
  { leaveTypeId: 'station', leaveTypeName: 'Station Leave', totalAllotted: 5 },
  { leaveTypeId: 'study', leaveTypeName: 'Study Leave', totalAllotted: 30 },
];

/**
 * Approves a pending Faculty registration (Admin-only).
 * Updates user profile, provisions Custom Claims, initializes annual leave balances,
 * dispatches notifications and appends an audit log entry.
 */
async function approveFacultyRegistrationHandler(data, context) {
  await assertIsAdmin(context);

  const { targetUid } = data;
  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'targetUid is required.');
  }

  const userRef = db.collection('users').doc(targetUid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new HttpsError('not-found', `Faculty user ${targetUid} does not exist.`);
  }

  const userData = userSnap.data();

  if (userData.role !== 'faculty' || getInstitutionalSpec(userData.email)) {
    throw new HttpsError('failed-precondition', `User ${targetUid} is not eligible for faculty approval.`);
  }

  const currentYear = new Date().getFullYear();

  // Execute batch for atomic database state update
  const batch = db.batch();

  // 1. Update user profile to approved & active
  batch.update(userRef, {
    approvalStatus: 'approved',
    isActive: true,
    approvedAt: FieldValue.serverTimestamp(),
    approvedBy: context.auth.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });

  // 2. Initialize default annual leave balances if not already provisioned
  for (const alloc of DEFAULT_LEAVE_ALLOCATIONS) {
    const balanceId = `${targetUid}_${alloc.leaveTypeId}_${currentYear}`;
    const balanceRef = db.collection('leave_balances').doc(balanceId);
    batch.set(balanceRef, {
      id: balanceId,
      userUid: targetUid,
      leaveTypeId: alloc.leaveTypeId,
      leaveTypeName: alloc.leaveTypeName,
      totalAllotted: alloc.totalAllotted,
      used: 0,
      year: currentYear,
      departmentId: userData.departmentId || null,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  // 3. Send congratulations in-app notification
  const notifRef = db.collection('notifications').doc();
  batch.set(notifRef, {
    id: notifRef.id,
    recipientUid: targetUid,
    title: 'Account Approved!',
    body: 'Your Leavexa faculty account has been approved by the Administrator. You now have full portal access.',
    type: 'approval',
    isRead: false,
    createdAt: new Date().toISOString(),
  });

  await batch.commit();

  // 4. Update Firebase Authentication Custom Claims
  await auth.setCustomUserClaims(targetUid, {
    role: 'faculty',
    approvalStatus: 'approved',
    departmentId: userData.departmentId || null,
  });

  // Also ensure Auth user account is enabled
  await auth.updateUser(targetUid, { disabled: false });

  // 5. Dispatch FCM Push Notification & In-app Alert
  await sendPushNotificationToUser(
    targetUid,
    {
      title: 'Account Approved!',
      body: 'Your Leavexa faculty account has been approved by the Administrator. You now have full portal access.',
      type: 'approval',
      data: {
        targetUid,
        role: 'faculty',
      },
    },
    { notificationId: notifRef.id, idempotencyKey: `faculty_approve_${targetUid}` }
  );

  // 6. Append audit log
  await logAuditEvent({
    actorUid: context.auth.uid,
    actorRole: 'admin',
    action: 'FACULTY_APPROVE',
    targetType: 'user',
    targetId: targetUid,
    details: {
      facultyName: userData.fullName,
      email: userData.email,
      employeeId: userData.employeeId,
      departmentId: userData.departmentId,
    },
  });

  return {
    success: true,
    targetUid,
    message: `Faculty ${userData.fullName} approved, balances provisioned, and custom claims updated.`,
  };
}

/**
 * Rejects a pending Faculty registration (Admin-only).
 */
async function rejectFacultyRegistrationHandler(data, context) {
  await assertIsAdmin(context);

  const { targetUid, reason } = data;
  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'targetUid is required.');
  }

  const userRef = db.collection('users').doc(targetUid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new HttpsError('not-found', `Faculty user ${targetUid} does not exist.`);
  }

  const userData = userSnap.data();
  const rejectionReason = reason || 'Verification criteria not satisfied.';

  const batch = db.batch();

  // 1. Update user document
  batch.update(userRef, {
    approvalStatus: 'rejected',
    isActive: false,
    rejectedAt: FieldValue.serverTimestamp(),
    rejectedBy: context.auth.uid,
    rejectionReason,
    updatedAt: FieldValue.serverTimestamp(),
  });

  // 2. Send rejection notification
  const notifRef = db.collection('notifications').doc();
  batch.set(notifRef, {
    id: notifRef.id,
    recipientUid: targetUid,
    title: 'Account Registration Rejected',
    body: `Your faculty registration was not approved. Reason: ${rejectionReason}`,
    type: 'rejection',
    isRead: false,
    createdAt: new Date().toISOString(),
  });

  await batch.commit();

  // 3. Update Firebase Custom Claims
  await auth.setCustomUserClaims(targetUid, {
    role: 'faculty',
    approvalStatus: 'rejected',
    departmentId: userData.departmentId || null,
  });

  // Disable Firebase Auth login
  await auth.updateUser(targetUid, { disabled: true });

  // 4. Dispatch FCM Push Notification & In-app Alert
  await sendPushNotificationToUser(
    targetUid,
    {
      title: 'Account Registration Rejected',
      body: `Your faculty registration was not approved. Reason: ${rejectionReason}`,
      type: 'rejection',
      data: {
        targetUid,
        reason: rejectionReason,
      },
    },
    { notificationId: notifRef.id, idempotencyKey: `faculty_reject_${targetUid}` }
  );

  // 5. Log audit event
  await logAuditEvent({
    actorUid: context.auth.uid,
    actorRole: 'admin',
    action: 'FACULTY_REJECT',
    targetType: 'user',
    targetId: targetUid,
    details: {
      facultyName: userData.fullName,
      email: userData.email,
      employeeId: userData.employeeId,
      reason: rejectionReason,
    },
  });

  return {
    success: true,
    targetUid,
    message: `Faculty ${userData.fullName} registration rejected.`,
  };
}

/**
 * Triggered on creation of a new user document.
 * When a faculty member registers in pending status, notifies active Administrators.
 */
async function onUserCreateHandler(snap, context) {
  const userData = snap.data();
  const uid = context.params.uid;
  if (!userData) return null;

  if (userData.role === 'faculty' && userData.approvalStatus === 'pending') {
    const fullName = userData.fullName || 'A new faculty member';
    const departmentName = userData.departmentName ? ` (${userData.departmentName})` : '';

    await sendPushNotificationToAdmins(
      {
        title: 'New Faculty Registration',
        body: `${fullName}${departmentName} has registered and is awaiting administrator approval.`,
        type: 'registration_pending',
        data: {
          targetUid: uid,
          employeeId: userData.employeeId || '',
          departmentId: userData.departmentId || '',
        },
      },
      { idempotencyKey: `new_user_${uid}` }
    );
  }

  return null;
}

module.exports = {
  approveFacultyRegistrationHandler,
  rejectFacultyRegistrationHandler,
  onUserCreateHandler,
};
