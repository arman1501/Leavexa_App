// ─────────────────────────────────────────────────────────────────────────────
//  audit.js  –  Trusted Server-Side Audit Logging Service
// ─────────────────────────────────────────────────────────────────────────────

const { admin, db, FieldValue } = require('./admin');

/**
 * Appends an immutable audit log entry to the `audit_logs` collection.
 * Clients cannot write to this collection per Firestore Security Rules (allow write: if false;).
 *
 * @param {Object} entry
 * @param {string} entry.actorUid - UID of the user or 'system' performing the action
 * @param {string} entry.actorRole - Role of the actor ('admin', 'registrar', 'department_head', 'system')
 * @param {string} entry.action - Standard action verb (e.g. 'FACULTY_APPROVE', 'LEAVE_BALANCE_DEDUCTION')
 * @param {string} entry.targetType - Type of resource ('user', 'leave_application', 'leave_balance', 'system')
 * @param {string} entry.targetId - ID of the target resource
 * @param {string} [entry.relatedApplicationId] - Optional linked application ID
 * @param {Object} [entry.details] - Arbitrary JSON metadata for forensic audit
 * @param {admin.firestore.Transaction} [entry.transaction] - Optional Firestore transaction for atomic commits
 * @returns {Promise<string>} Created document ID
 */
async function logAuditEvent({
  actorUid,
  actorRole = 'system',
  action,
  targetType,
  targetId,
  relatedApplicationId = null,
  details = {},
  transaction = null,
}) {
  const auditRef = db.collection('audit_logs').doc();
  const logData = {
    id: auditRef.id,
    actorUid: actorUid || 'system',
    actorRole: actorRole || 'system',
    action,
    targetType,
    targetId: targetId || null,
    relatedApplicationId: relatedApplicationId || null,
    details: details || {},
    timestamp: FieldValue.serverTimestamp(),
  };

  if (transaction) {
    transaction.set(auditRef, logData);
  } else {
    await auditRef.set(logData);
  }

  return auditRef.id;
}

module.exports = {
  logAuditEvent,
};
