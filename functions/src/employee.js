// ─────────────────────────────────────────────────────────────────────────────
//  employee.js  –  Employee ID Validation & University HR Verification Analysis
// ─────────────────────────────────────────────────────────────────────────────

const { db } = require('./admin');

/**
 * Status representation for Employee ID verification.
 * Because Leavexa is not currently connected to an external enterprise HR API
 * (e.g., Ellucian Banner, SAP SuccessFactors, or PeopleSoft), we must NOT
 * falsely claim that an Employee ID has been verified by the university registrar's payroll database.
 */
const HR_INTEGRATION_STATUS = {
  HR_ENDPOINT_CONFIGURED: false,
  AUTHORITATIVE_SOURCE: 'INTERNAL_FIRESTORE_REGISTRY',
  DUPLICATE_PREVENTION_ENFORCED: true,
  LIMITATION_NOTE: 'Employee IDs are checked for system uniqueness and atomic reservation, but not validated against external university HR records.',
};

/**
 * Verifies if an Employee ID is available for registration in the internal registry.
 *
 * @param {string} employeeId
 * @returns {Promise<{isAvailable: boolean, message: string}>}
 */
async function checkEmployeeIdAvailability(employeeId) {
  if (!employeeId || typeof employeeId !== 'string') {
    return { isAvailable: false, message: 'Invalid employee ID format.' };
  }

  const normalized = employeeId.trim().toUpperCase();
  const empSnap = await db.collection('employee_ids').doc(normalized).get();

  if (empSnap.exists) {
    return {
      isAvailable: false,
      message: `Employee ID ${normalized} is already registered to a user.`,
    };
  }

  return {
    isAvailable: true,
    message: `Employee ID ${normalized} is available for reservation.`,
    limitationNotice: HR_INTEGRATION_STATUS.LIMITATION_NOTE,
  };
}

module.exports = {
  HR_INTEGRATION_STATUS,
  checkEmployeeIdAvailability,
};
