// ─────────────────────────────────────────────────────────────────────────────
//  leaves.js  –  Idempotent Atomic Leave Balance Deduction & Lifecycle Audit
// ─────────────────────────────────────────────────────────────────────────────

const { admin, db, FieldValue } = require('./admin');
const { logAuditEvent } = require('./audit');
const {
  sendPushNotificationToUser,
  sendPushNotificationToDepartmentHead,
  sendPushNotificationToRegistrars,
} = require('./notifications');

/**
 * Core atomic leave balance deduction logic.
 * Safely runs inside a Firestore Transaction to guarantee idempotency, concurrency safety,
 * and negative balance prevention.
 *
 * @param {string} applicationId
 * @param {Object} applicationData - Snapshot data of the approved application
 * @returns {Promise<{success: boolean, message: string, deductedDays?: number}>}
 */
async function processLeaveDeductionTransaction(applicationId, applicationData) {
  const appRef = db.collection('leave_applications').doc(applicationId);

  return await db.runTransaction(async (transaction) => {
    // 1. Re-read application document inside the transaction for concurrency lock
    const appSnap = await transaction.get(appRef);
    if (!appSnap.exists) {
      throw new Error(`Application ${applicationId} no longer exists.`);
    }

    const currentApp = appSnap.data();

    // 2. Idempotency Check: prevent duplicate deductions
    if (currentApp.balanceDeducted === true) {
      return {
        success: true,
        alreadyProcessed: true,
        message: `Leave deduction for application ${applicationId} has already been processed.`,
      };
    }

    if (currentApp.status !== 'approved') {
      return {
        success: false,
        message: `Cannot deduct balance: application status is '${currentApp.status}', expected 'approved'.`,
      };
    }

    const applicantUid = currentApp.applicantUid;
    const leaveTypeId = currentApp.leaveTypeId;
    const totalDays = Number(currentApp.totalDays);

    if (!totalDays || totalDays <= 0) {
      throw new Error(`Invalid totalDays value: ${totalDays}`);
    }

    let appYear = new Date().getFullYear();
    if (currentApp.startDate) {
      if (typeof currentApp.startDate.toDate === 'function') {
        appYear = currentApp.startDate.toDate().getFullYear();
      } else if (currentApp.startDate instanceof Date) {
        appYear = currentApp.startDate.getFullYear();
      } else if (typeof currentApp.startDate === 'string') {
        const d = new Date(currentApp.startDate);
        if (!isNaN(d.getTime())) appYear = d.getFullYear();
      }
    }

    // 3. Locate applicant's corresponding leave balance document with alias resolution
    // Handles medical <-> sick, casual <-> casual_leave, etc.
    const aliases = [leaveTypeId];
    if (leaveTypeId === 'medical') aliases.push('sick', 'medical_leave', 'sick_leave');
    if (leaveTypeId === 'sick') aliases.push('medical', 'sick_leave', 'medical_leave');
    if (leaveTypeId === 'casual') aliases.push('casual_leave');
    if (leaveTypeId === 'casual_leave') aliases.push('casual');
    if (leaveTypeId === 'duty') aliases.push('duty_leave');
    if (leaveTypeId === 'duty_leave') aliases.push('duty');
    if (leaveTypeId === 'station') aliases.push('station_leave');
    if (leaveTypeId === 'station_leave') aliases.push('station');
    if (leaveTypeId === 'study') aliases.push('study_leave');
    if (leaveTypeId === 'study_leave') aliases.push('study');
    if (leaveTypeId === 'earned') aliases.push('earned_leave');
    if (leaveTypeId === 'earned_leave') aliases.push('earned');

    let balanceRef = null;
    let balanceSnap = null;

    // Try primary expected doc ID and alias doc IDs first
    for (const typeCandidate of aliases) {
      const candidateId = `${applicantUid}_${typeCandidate}_${appYear}`;
      const ref = db.collection('leave_balances').doc(candidateId);
      const snap = await transaction.get(ref);
      if (snap && snap.exists) {
        balanceRef = ref;
        balanceSnap = snap;
        break;
      }
    }

    if (!balanceSnap || !balanceSnap.exists) {
      // Query fallback across all aliases
      for (const typeCandidate of aliases) {
        const querySnap = await db.collection('leave_balances')
          .where('userUid', '==', applicantUid)
          .where('leaveTypeId', '==', typeCandidate)
          .limit(1)
          .get();

        if (!querySnap.empty) {
          balanceRef = querySnap.docs[0].ref;
          balanceSnap = await transaction.get(balanceRef);
          break;
        }
      }

      if (!balanceSnap || !balanceSnap.exists) {
        // Balance doc not found
        transaction.update(appRef, {
          balanceDeductionError: 'No leave balance record found for user and leave type.',
          updatedAt: FieldValue.serverTimestamp(),
        });

        await logAuditEvent({
          actorUid: currentApp.registrarUid || 'system',
          actorRole: 'system',
          action: 'LEAVE_DEDUCTION_FAILED',
          targetType: 'leave_application',
          targetId: applicationId,
          relatedApplicationId: applicationId,
          details: { reason: 'No balance document found', leaveTypeId, appYear },
          transaction,
        });

        return {
          success: false,
          message: `No leave balance document found for user ${applicantUid} (${leaveTypeId}).`,
        };
      }
    }

    const balanceData = balanceSnap.data();
    const totalAllotted = Number(balanceData.totalAllotted) || 0;
    const currentUsed = Number(balanceData.used) || 0;
    const remaining = totalAllotted - currentUsed;

    // 4. Policy Validation: Prevent Negative Balance
    if (remaining < totalDays) {
      transaction.update(appRef, {
        balanceDeductionError: `Insufficient leave balance. Available: ${remaining}, Requested: ${totalDays}.`,
        updatedAt: FieldValue.serverTimestamp(),
      });

      await logAuditEvent({
        actorUid: currentApp.registrarUid || 'system',
        actorRole: 'system',
        action: 'LEAVE_DEDUCTION_FAILED_INSUFFICIENT_BALANCE',
        targetType: 'leave_balance',
        targetId: balanceRef.id,
        relatedApplicationId: applicationId,
        details: {
          remaining,
          requested: totalDays,
          applicantUid,
          leaveTypeId,
        },
        transaction,
      });

      return {
        success: false,
        message: `Insufficient leave balance (available ${remaining}, requested ${totalDays}).`,
      };
    }

    // 5. Atomic balance update
    const newUsed = currentUsed + totalDays;
    transaction.update(balanceRef, {
      used: newUsed,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // 6. Stamp application document as deducted (Idempotency flag)
    transaction.update(appRef, {
      balanceDeducted: true,
      deductedDays: totalDays,
      balanceDocumentId: balanceRef.id,
      deductedAt: FieldValue.serverTimestamp(),
    });

    // 7. Atomic Audit Log record
    await logAuditEvent({
      actorUid: currentApp.registrarUid || 'system',
      actorRole: 'system',
      action: 'LEAVE_BALANCE_DEDUCTION',
      targetType: 'leave_balance',
      targetId: balanceRef.id,
      relatedApplicationId: applicationId,
      details: {
        applicantUid,
        leaveTypeId,
        deductedDays: totalDays,
        previousUsed: currentUsed,
        newUsed,
        remainingAfterDeduction: totalAllotted - newUsed,
      },
      transaction,
    });

    return {
      success: true,
      deductedDays: totalDays,
      newUsed,
      remaining: totalAllotted - newUsed,
      message: `Successfully deducted ${totalDays} days from leave balance.`,
    };
  });
}

/**
 * Firestore OnUpdate Trigger Handler for `leave_applications/{applicationId}`
 * Dispatches audit events across stages and executes atomic leave deductions on final approval.
 */
async function onLeaveApplicationUpdateHandler(change, context) {
  const before = change.before.data();
  const after = change.after.data();
  const applicationId = context.params.applicationId;

  if (!before || !after) return null;

  // 1. Department Head Forwarded
  if (before.status === 'pending' && after.status === 'forwarded') {
    await logAuditEvent({
      actorUid: after.headUid || 'unknown_head',
      actorRole: 'department_head',
      action: 'HEAD_FORWARD_LEAVE',
      targetType: 'leave_application',
      targetId: applicationId,
      relatedApplicationId: applicationId,
      details: {
        applicantUid: after.applicantUid,
        departmentId: after.departmentId,
        headComment: after.headComment || null,
      },
    });

    // Notify all active Registrars
    const applicantName = after.applicantName || 'Faculty member';
    await sendPushNotificationToRegistrars(
      {
        title: 'Leave Application Forwarded',
        body: `Leave request for ${applicantName} has been recommended and forwarded by Department Head.`,
        type: 'leave_forwarded',
        relatedApplicationId: applicationId,
        data: {
          applicationId,
          departmentId: after.departmentId || '',
        },
      },
      { idempotencyKey: `forward_${applicationId}` }
    );

    // Authoritative notification to applicant that application was endorsed
    if (after.applicantUid) {
      const leaveTypeName = after.leaveTypeName || 'Leave';
      await sendPushNotificationToUser(
        after.applicantUid,
        {
          title: 'Application Forwarded',
          body: `Your ${leaveTypeName} application was endorsed by Department Head.`,
          type: 'status_update',
          relatedApplicationId: applicationId,
          data: {
            applicationId,
            status: 'forwarded',
          },
        },
        { idempotencyKey: `forward_applicant_${applicationId}` }
      );
    }
  }

  // 2. Department Head Rejected
  if (before.status === 'pending' && after.status === 'rejected') {
    await logAuditEvent({
      actorUid: after.headUid || 'unknown_head',
      actorRole: 'department_head',
      action: 'HEAD_REJECT_LEAVE',
      targetType: 'leave_application',
      targetId: applicationId,
      relatedApplicationId: applicationId,
      details: {
        applicantUid: after.applicantUid,
        departmentId: after.departmentId,
        headComment: after.headComment || null,
      },
    });

    // Notify Faculty applicant
    const leaveTypeName = after.leaveTypeName || 'leave';
    const comment = after.headComment ? ` Comment: "${after.headComment}"` : '';
    await sendPushNotificationToUser(
      after.applicantUid,
      {
        title: 'Leave Application Rejected',
        body: `Your ${leaveTypeName} request was rejected by Department Head.${comment}`,
        type: 'leave_rejected',
        relatedApplicationId: applicationId,
        data: {
          applicationId,
          status: 'rejected',
        },
      },
      { idempotencyKey: `head_reject_${applicationId}` }
    );
  }

  // 3. Registrar Final Approval -> Triggers Atomic Leave Deduction
  if (before.status === 'forwarded' && after.status === 'approved') {
    await logAuditEvent({
      actorUid: after.registrarUid || 'unknown_registrar',
      actorRole: 'registrar',
      action: 'REGISTRAR_APPROVE_LEAVE',
      targetType: 'leave_application',
      targetId: applicationId,
      relatedApplicationId: applicationId,
      details: {
        applicantUid: after.applicantUid,
        totalDays: after.totalDays,
        registrarComment: after.registrarComment || null,
      },
    });

    // Execute atomic and idempotent deduction
    await processLeaveDeductionTransaction(applicationId, after);

    // Notify Faculty applicant of final approval
    const leaveTypeName = after.leaveTypeName || 'leave';
    await sendPushNotificationToUser(
      after.applicantUid,
      {
        title: 'Leave Application Approved!',
        body: `Your ${leaveTypeName} request has received final approval from the Registrar.`,
        type: 'leave_approved',
        relatedApplicationId: applicationId,
        data: {
          applicationId,
          status: 'approved',
        },
      },
      { idempotencyKey: `reg_approve_${applicationId}` }
    );
  }

  // 4. Registrar Final Rejection
  if (before.status === 'forwarded' && after.status === 'rejected') {
    await logAuditEvent({
      actorUid: after.registrarUid || 'unknown_registrar',
      actorRole: 'registrar',
      action: 'REGISTRAR_REJECT_LEAVE',
      targetType: 'leave_application',
      targetId: applicationId,
      relatedApplicationId: applicationId,
      details: {
        applicantUid: after.applicantUid,
        totalDays: after.totalDays,
        registrarComment: after.registrarComment || null,
      },
    });

    // Notify Faculty applicant of registrar rejection
    const leaveTypeName = after.leaveTypeName || 'leave';
    const comment = after.registrarComment ? ` Comment: "${after.registrarComment}"` : '';
    await sendPushNotificationToUser(
      after.applicantUid,
      {
        title: 'Leave Application Rejected',
        body: `Your ${leaveTypeName} request was rejected by the Registrar.${comment}`,
        type: 'leave_rejected',
        relatedApplicationId: applicationId,
        data: {
          applicationId,
          status: 'rejected',
        },
      },
      { idempotencyKey: `reg_reject_${applicationId}` }
    );
  }

  // 5. Faculty Applicant Cancelled
  if (before.status === 'pending' && after.status === 'cancelled') {
    await logAuditEvent({
      actorUid: after.applicantUid || 'unknown_applicant',
      actorRole: 'faculty',
      action: 'FACULTY_CANCEL_LEAVE',
      targetType: 'leave_application',
      targetId: applicationId,
      relatedApplicationId: applicationId,
      details: {
        applicantUid: after.applicantUid,
        departmentId: after.departmentId,
        cancelReason: after.cancelReason || null,
        totalDays: after.totalDays,
      },
    });

    // Notify Department Head that leave application was cancelled by faculty
    if (after.departmentId) {
      const applicantName = after.applicantName || 'A faculty member';
      const leaveTypeName = after.leaveTypeName || 'leave';
      await sendPushNotificationToDepartmentHead(
        after.departmentId,
        {
          title: 'Leave Application Cancelled',
          body: `${applicantName} has cancelled their ${leaveTypeName} application.`,
          type: 'leave_cancelled',
          relatedApplicationId: applicationId,
          data: {
            applicationId,
            departmentId: after.departmentId,
            status: 'cancelled',
          },
        },
        { idempotencyKey: `cancel_${applicationId}` }
      );
    }
  }

  return null;
}

/**
 * Triggered on creation of a new leave application.
 * Notifies the active Department Head(s) of the applicant's department.
 */
async function onLeaveApplicationCreateHandler(snap, context) {
  const applicationData = snap.data();
  const applicationId = context.params.applicationId;
  if (!applicationData) return null;

  const departmentId = applicationData.departmentId;
  const applicantName = applicationData.applicantName || 'A faculty member';
  const leaveTypeName = applicationData.leaveTypeName || 'leave';
  const totalDays = applicationData.totalDays || 1;

  if (departmentId) {
    await sendPushNotificationToDepartmentHead(
      departmentId,
      {
        title: 'New Leave Request Submitted',
        body: `${applicantName} submitted a ${leaveTypeName} application for ${totalDays} day(s).`,
        type: 'leave_submitted',
        relatedApplicationId: applicationId,
        data: {
          applicationId,
          departmentId,
          applicantUid: applicationData.applicantUid || '',
        },
      },
      { idempotencyKey: `submit_${applicationId}` }
    );
  }

  // Authoritative notification to applicant confirming submission
  if (applicationData.applicantUid) {
    await sendPushNotificationToUser(
      applicationData.applicantUid,
      {
        title: 'Leave Application Submitted',
        body: `Your ${leaveTypeName} application for ${totalDays} day(s) was submitted for approval.`,
        type: 'submission',
        relatedApplicationId: applicationId,
        data: {
          applicationId,
          status: 'pending',
        },
      },
      { idempotencyKey: `submit_applicant_${applicationId}` }
    );
  }

  return null;
}

module.exports = {
  processLeaveDeductionTransaction,
  onLeaveApplicationUpdateHandler,
  onLeaveApplicationCreateHandler,
};
