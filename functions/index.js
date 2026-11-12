// ─────────────────────────────────────────────────────────────────────────────
//  index.js  –  Leavexa Firebase Cloud Functions Entry Point
// ─────────────────────────────────────────────────────────────────────────────

const functions = require('firebase-functions');
const {
  provisionInitialAdminHandler,
  createStaffAccountHandler,
  setUserActiveHandler,
  syncUserCustomClaimsHandler,
  provisionFixedStaffAccountsHandler,
  transferFacultyDepartmentHandler,
} = require('./src/roles');

const {
  syncUniversityInfoHandler,
} = require('./src/university_sync');

const {
  approveFacultyRegistrationHandler,
  rejectFacultyRegistrationHandler,
  onUserCreateHandler,
} = require('./src/approvals');

const {
  submitLeaveApplicationHandler,
  onLeaveApplicationUpdateHandler,
  onLeaveApplicationCreateHandler,
  processLeaveDeductionTransaction,
} = require('./src/leaves');

const {
  sendPushNotificationToUser,
  sendPushNotificationToDepartmentHead,
  sendPushNotificationToRegistrars,
  sendPushNotificationToAdmins,
  processPendingNotificationRetries,
} = require('./src/notifications');

const { checkEmployeeIdAvailability } = require('./src/employee');

// ── Role Provisioning & Admin Management ────────────────────────────────────

/**
 * Provisions the initial system administrator.
 * Insecure public execution blocked: only succeeds if zero admins exist in database.
 */
exports.provisionInitialAdmin = functions.https.onCall(async (data, context) => {
  return await provisionInitialAdminHandler(data, context);
});

/**
 * Creates Department Head or Registrar accounts (Admin-only).
 * Assigns custom claims and provisions Firestore profile.
 */
exports.createStaffAccount = functions.https.onCall(async (data, context) => {
  return await createStaffAccountHandler(data, context);
});

/**
 * Activates or deactivates an account (Admin-only).
 */
exports.setUserActive = functions.https.onCall(async (data, context) => {
  return await setUserActiveHandler(data, context);
});

/**
 * Synchronizes Firebase Auth Custom Claims with verified Firestore profile.
 */
exports.syncUserCustomClaims = functions.https.onCall(async (data, context) => {
  return await syncUserCustomClaimsHandler(data, context);
});

/**
 * Provisions or synchronizes designated fixed staff accounts (Admin / Bootstrap).
 */
exports.provisionFixedStaffAccounts = functions.https.onCall(async (data, context) => {
  return await provisionFixedStaffAccountsHandler(data, context);
});

/**
 * Transfers a Faculty member to another verified department (Admin-only).
 * Historical leave applications keep their original departmentId snapshot.
 */
exports.transferFacultyDepartment = functions.https.onCall(async (data, context) => {
  return await transferFacultyDepartmentHandler(data, context);
});

/**
 * Trusted server-side leave submission verifying faculty status & department assignment.
 */
exports.submitLeaveApplication = functions.https.onCall(async (data, context) => {
  return await submitLeaveApplicationHandler(data, context);
});

/**
 * Synchronizes official university public info from https://lus.ac.bd/ (Admin-only).
 */
exports.syncUniversityInfo = functions.https.onCall(async (data, context) => {
  return await syncUniversityInfoHandler(data, context);
});

// ── Faculty Approval Workflow ───────────────────────────────────────────────

/**
 * Approves a pending Faculty registration (Admin-only).
 * Updates approval status, sets custom claims, provisions initial balances, and dispatches notification.
 */
exports.approveFacultyRegistration = functions.https.onCall(async (data, context) => {
  return await approveFacultyRegistrationHandler(data, context);
});

/**
 * Rejects a pending Faculty registration (Admin-only).
 */
exports.rejectFacultyRegistration = functions.https.onCall(async (data, context) => {
  return await rejectFacultyRegistrationHandler(data, context);
});

// ── Employee ID Availability Check ──────────────────────────────────────────

/**
 * Pre-checks Employee ID availability against internal registry.
 */
exports.checkEmployeeId = functions.https.onCall(async (data, context) => {
  return await checkEmployeeIdAvailability(data.employeeId);
});

// ── Lifecycle Event Triggers (Push Notifications & Business Logic) ─────────

/**
 * Triggered on any update to a leave application.
 * Executes atomic, idempotent leave balance deductions on final Registrar approval
 * and dispatches role-based push notifications for lifecycle transitions.
 */
exports.onLeaveApplicationUpdate = functions.firestore
  .document('leave_applications/{applicationId}')
  .onUpdate(async (change, context) => {
    return await onLeaveApplicationUpdateHandler(change, context);
  });

/**
 * Triggered on creation of a new leave application.
 * Dispatches push notification to active Department Head(s).
 */
exports.onLeaveApplicationCreate = functions.firestore
  .document('leave_applications/{applicationId}')
  .onCreate(async (snap, context) => {
    return await onLeaveApplicationCreateHandler(snap, context);
  });

/**
 * Triggered on creation of a new user profile.
 * Dispatches push notification to active Administrators for pending faculty vetting.
 */
exports.onUserCreate = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap, context) => {
    return await onUserCreateHandler(snap, context);
  });

// ── Background Notification Retry & Retention Worker ───────────────────────

/**
 * Scheduled background worker executing every 5 minutes.
 * Automatically retries failed notification events with exponential backoff
 * and prunes historical notification events past the 30-day retention window.
 */
exports.processNotificationRetries = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    return await processPendingNotificationRetries();
  });

// ── Exported Core Handlers for Testing ───────────────────────────────────────
exports._internal = {
  submitLeaveApplicationHandler,
  transferFacultyDepartmentHandler,
  processLeaveDeductionTransaction,
  sendPushNotificationToUser,
  sendPushNotificationToDepartmentHead,
  sendPushNotificationToRegistrars,
  sendPushNotificationToAdmins,
  processPendingNotificationRetries,
  onLeaveApplicationCreateHandler,
  onLeaveApplicationUpdateHandler,
  onUserCreateHandler,
};
