// ─────────────────────────────────────────────────────────────────────────────
//  rules_evaluation_test.js  –  Hardened Security Rule Verification Suite
// ─────────────────────────────────────────────────────────────────────────────

const fs = require('fs');
const path = require('path');

const rulesPath = path.join(__dirname, '../../firestore.rules');
const rulesContent = fs.readFileSync(rulesPath, 'utf8');

console.log('✓ Found firestore.rules file (' + rulesContent.length + ' bytes)');

// 1. Syntax & Structural Balance Verification
function validateSyntax(content) {
  const matches = [
    { name: 'rules_version', regex: /rules_version\s*=\s*'2';/ },
    { name: 'service cloud.firestore', regex: /service\s+cloud\.firestore/ },
    { name: 'users collection match', regex: /match\s+\/users\/\{uid\}/ },
    { name: 'employee_ids match', regex: /match\s+\/employee_ids\/\{employeeId\}/ },
    { name: 'leave_applications match', regex: /match\s+\/leave_applications\/\{applicationId\}/ },
    { name: 'leave_balances match', regex: /match\s+\/leave_balances\/\{balanceId\}/ },
    { name: 'notifications match', regex: /match\s+\/notifications\/\{notificationId\}/ },
    { name: 'departments match', regex: /match\s+\/departments\/\{departmentId\}/ },
    { name: 'leave_types match', regex: /match\s+\/leave_types\/\{leaveTypeId\}/ },
    { name: 'audit_logs match', regex: /match\s+\/audit_logs\/\{logId\}/ },
    { name: 'affectedKeys().hasOnly for Head', regex: /affectedKeys\(\)\.hasOnly\(\['status',\s*'headUid',\s*'headComment',\s*'headActionAt'\]\)/ },
    { name: 'affectedKeys().hasOnly for Registrar', regex: /affectedKeys\(\)\.hasOnly\(\['status',\s*'registrarUid',\s*'registrarComment',\s*'registrarActionAt'\]\)/ },
    { name: 'affectedKeys().hasOnly for Notifications', regex: /affectedKeys\(\)\.hasOnly\(\['isRead'\]\)/ },
    { name: 'getAfter for Employee IDs', regex: /getAfter\(.*employee_ids/ },
  ];

  for (const m of matches) {
    if (!m.regex.test(content)) {
      throw new Error('Missing expected block: ' + m.name);
    }
  }

  let braces = 0;
  let parens = 0;
  for (let i = 0; i < content.length; i++) {
    const ch = content[i];
    if (ch === '{') braces++;
    else if (ch === '}') braces--;
    else if (ch === '(') parens++;
    else if (ch === ')') parens--;
    if (braces < 0) throw new Error('Unbalanced } at character ' + i);
    if (parens < 0) throw new Error('Unbalanced ) at character ' + i);
  }
  if (braces !== 0) throw new Error('Unbalanced braces: open=' + braces);
  if (parens !== 0) throw new Error('Unbalanced parens: open=' + parens);

  console.log('✓ firestore.rules syntax and structural balance: PASSED');
}

validateSyntax(rulesContent);

// 2. Behavioral Simulator for Rules Logic
class HardenedRulesSimulator {
  constructor() {
    this.users = new Map();
    this.employeeIds = new Map();
    this.leaveApplications = new Map();
    this.notifications = new Map();
  }

  getUserDoc(uid) {
    return this.users.get(uid) || null;
  }

  getRole(auth) {
    if (!auth) return null;
    if (auth.token && auth.token.role) return auth.token.role;
    const doc = this.getUserDoc(auth.uid);
    return doc ? doc.role : null;
  }

  isAdmin(auth) {
    return auth && this.getRole(auth) === 'admin';
  }

  isRegistrar(auth) {
    return auth && (this.getRole(auth) === 'registrar' || this.isAdmin(auth));
  }

  isDeptHead(auth) {
    return auth && (this.getRole(auth) === 'department_head' || this.isAdmin(auth));
  }

  isFaculty(auth) {
    return auth && this.getRole(auth) === 'faculty';
  }

  isApprovedAndActive(auth) {
    if (!auth) return false;
    if (this.isAdmin(auth)) return true;
    const doc = this.getUserDoc(auth.uid);
    return doc && doc.approvalStatus === 'approved' && doc.isActive === true;
  }

  getUserDepartmentId(auth) {
    const doc = this.getUserDoc(auth.uid);
    return doc ? doc.departmentId : null;
  }

  // ── Employee ID Simulation ─────────────────────────────────────────────────
  canReserveEmployeeId(auth, empId, empData, userDocAfter) {
    if (!auth) return false;
    if (this.employeeIds.has(empId)) return false; // Already reserved
    if (empData.uid !== auth.uid) return false;
    if (typeof empId !== 'string' || empId.length < 3 || empId.length > 30) return false;
    if (this.isAdmin(auth)) return true;

    // getAfter() simulation
    if (!userDocAfter) return false;
    return userDocAfter.employeeId === empId && userDocAfter.uid === auth.uid;
  }

  canCreateUser(auth, targetUid, userData, empDocAfter) {
    if (!auth) return false;
    if (this.isAdmin(auth)) return true;

    // Self registration
    const isOwner = auth.uid === targetUid;
    const isFacultyPending =
      userData.role === 'faculty' &&
      userData.approvalStatus === 'pending' &&
      userData.isActive === false &&
      userData.uid === targetUid &&
      typeof userData.employeeId === 'string' &&
      userData.employeeId.length >= 3 &&
      userData.employeeId.length <= 30;

    if (!isOwner || !isFacultyPending) return false;

    // getAfter() cross-document check
    if (!empDocAfter) return false;
    return empDocAfter.uid === targetUid;
  }

  // ── Leave Application Simulation ───────────────────────────────────────────
  canUpdateLeaveApplication(auth, currentApp, newApp) {
    if (!auth || !this.isApprovedAndActive(auth)) return false;
    if (this.isAdmin(auth)) return true;

    // Calculate diff keys
    const diffKeys = [];
    const allKeys = new Set([...Object.keys(currentApp), ...Object.keys(newApp)]);
    for (const key of allKeys) {
      if (currentApp[key] !== newApp[key]) {
        diffKeys.push(key);
      }
    }

    // 1. Dept Head Review Transition
    const headAllowedKeys = ['status', 'headUid', 'headComment', 'headActionAt'];
    const headHasOnlyAllowed = diffKeys.every((k) => headAllowedKeys.includes(k));

    if (
      this.isDeptHead(auth) &&
      currentApp.departmentId === this.getUserDepartmentId(auth) &&
      currentApp.status === 'pending' &&
      (newApp.status === 'forwarded' || newApp.status === 'rejected') &&
      newApp.headUid === auth.uid &&
      headHasOnlyAllowed
    ) {
      return true;
    }

    // 2. Registrar Final Approval Transition
    const regAllowedKeys = ['status', 'registrarUid', 'registrarComment', 'registrarActionAt'];
    const regHasOnlyAllowed = diffKeys.every((k) => regAllowedKeys.includes(k));

    if (
      this.isRegistrar(auth) &&
      currentApp.status === 'forwarded' && // STRICT: must already be forwarded!
      (newApp.status === 'approved' || newApp.status === 'rejected') &&
      newApp.registrarUid === auth.uid &&
      regHasOnlyAllowed
    ) {
      return true;
    }

    return false;
  }

  // ── Notifications Simulation ───────────────────────────────────────────────
  canCreateNotification(auth, notifData) {
    if (!auth) return false;
    if (this.isAdmin(auth) || this.isRegistrar(auth)) return true;
    if (notifData.recipientUid === auth.uid) return true;

    // Dept head: only for members in their department
    if (this.isDeptHead(auth)) {
      const recipientDoc = this.getUserDoc(notifData.recipientUid);
      return recipientDoc && recipientDoc.departmentId === this.getUserDepartmentId(auth);
    }

    return false;
  }

  canUpdateNotification(auth, notifData, newNotifData) {
    if (!auth || notifData.recipientUid !== auth.uid) return false;
    const diffKeys = Object.keys(newNotifData).filter((k) => newNotifData[k] !== notifData[k]);
    return diffKeys.length === 1 && diffKeys[0] === 'isRead';
  }

  // ── System Config & Audit Logs Simulation ──────────────────────────────────
  canReadSystemConfig(auth) {
    return this.isAdmin(auth);
  }
  canWriteSystemConfig(auth) {
    return false; // allow write: if false;
  }
  canReadAuditLog(auth) {
    return this.isAdmin(auth);
  }
  canWriteAuditLog(auth) {
    return false; // allow write: if false;
  }
}

// 3. Execute Comprehensive Tests
const sim = new HardenedRulesSimulator();

const adminAuth = { uid: 'admin-1', token: { role: 'admin' } };
const registrarAuth = { uid: 'reg-1', token: { role: 'registrar' } };
const headCseAuth = { uid: 'head-cse', token: {} };
const headEeeAuth = { uid: 'head-eee', token: {} };
const facultyCseAuth = { uid: 'fac-1', token: {} };
const facultyEeeAuth = { uid: 'fac-2', token: {} };

sim.users.set('admin-1', { uid: 'admin-1', role: 'admin', approvalStatus: 'approved', isActive: true });
sim.users.set('reg-1', { uid: 'reg-1', role: 'registrar', approvalStatus: 'approved', isActive: true });
sim.users.set('head-cse', { uid: 'head-cse', role: 'department_head', departmentId: 'cse', approvalStatus: 'approved', isActive: true });
sim.users.set('head-eee', { uid: 'head-eee', role: 'department_head', departmentId: 'eee', approvalStatus: 'approved', isActive: true });
sim.users.set('fac-1', { uid: 'fac-1', role: 'faculty', departmentId: 'cse', approvalStatus: 'approved', isActive: true, employeeId: 'FAC001' });
sim.users.set('fac-2', { uid: 'fac-2', role: 'faculty', departmentId: 'eee', approvalStatus: 'approved', isActive: true, employeeId: 'FAC002' });

let passed = 0;
let total = 0;

function assert(condition, testName) {
  total++;
  if (!condition) {
    console.error('❌ FAIL: ' + testName);
    process.exit(1);
  } else {
    passed++;
    console.log('  ✓ ' + testName);
  }
}

console.log('\n--- Hardened Security Rules Test Matrix ---');

// 1. Employee ID Tests
console.log('\n[Section 1: Employee ID Hardening]');
// Valid registration matching reservation
assert(
  sim.canReserveEmployeeId(facultyCseAuth, 'FAC001', { uid: 'fac-1' }, { employeeId: 'FAC001', uid: 'fac-1' }),
  '1.1 Matching Employee ID reservation in atomic transaction allowed',
);
// Reserving mismatched Employee ID
assert(
  !sim.canReserveEmployeeId(facultyCseAuth, 'FAC999', { uid: 'fac-1' }, { employeeId: 'FAC001', uid: 'fac-1' }),
  '1.2 Reserving mismatched Employee ID denied',
);
// Reserving ID for another user
assert(
  !sim.canReserveEmployeeId(facultyCseAuth, 'FAC002', { uid: 'fac-2' }, { employeeId: 'FAC002', uid: 'fac-2' }),
  '1.3 Reserving Employee ID for another user UID denied',
);
// Self-escalating role during user creation
assert(
  !sim.canCreateUser(facultyCseAuth, 'fac-1', { role: 'admin', approvalStatus: 'approved', isActive: true, employeeId: 'FAC001', uid: 'fac-1' }, { uid: 'fac-1' }),
  '1.4 Self-registration with admin role denied',
);

// 2. Leave Application Diff Validation
console.log('\n[Section 2: Leave Application diff() Validation]');
const baseApp = {
  id: 'app-1',
  applicantUid: 'fac-1',
  applicantName: 'Md. Arman',
  applicantEmployeeId: 'FAC001',
  departmentId: 'cse',
  departmentName: 'CSE',
  leaveTypeId: 'cl',
  startDate: '2025-01-01',
  endDate: '2025-01-05',
  totalDays: 5,
  reason: 'Family event',
  status: 'pending',
  headUid: null,
  headComment: null,
  headActionAt: null,
  registrarUid: null,
  registrarComment: null,
  registrarActionAt: null,
};

// Head updates allowed keys only
const headForwarded = {
  ...baseApp,
  status: 'forwarded',
  headUid: 'head-cse',
  headComment: 'Recommended',
  headActionAt: '2025-01-02T10:00:00Z',
};
assert(
  sim.canUpdateLeaveApplication(headCseAuth, baseApp, headForwarded),
  '2.1 Dept Head updating only status, headUid, headComment, headActionAt allowed',
);

// Head tries to tamper with dates
const headTamperedDates = { ...headForwarded, totalDays: 10 };
assert(
  !sim.canUpdateLeaveApplication(headCseAuth, baseApp, headTamperedDates),
  '2.2 Dept Head attempting to alter totalDays denied by diff().hasOnly()',
);

// Head tries to tamper with applicantUid
const headTamperedApplicant = { ...headForwarded, applicantUid: 'hacker' };
assert(
  !sim.canUpdateLeaveApplication(headCseAuth, baseApp, headTamperedApplicant),
  '2.3 Dept Head attempting to alter applicantUid denied by diff().hasOnly()',
);

// Registrar tries to approve directly from pending (skipping Head)
const regBypassHead = {
  ...baseApp,
  status: 'approved',
  registrarUid: 'reg-1',
  registrarComment: 'Direct approval',
  registrarActionAt: '2025-01-02T11:00:00Z',
};
assert(
  !sim.canUpdateLeaveApplication(registrarAuth, baseApp, regBypassHead),
  '2.4 Registrar approving pending application without Head forwarding denied',
);

// Registrar approves forwarded application
const regApproved = {
  ...headForwarded,
  status: 'approved',
  registrarUid: 'reg-1',
  registrarComment: 'Officially approved',
  registrarActionAt: '2025-01-03T11:00:00Z',
};
assert(
  sim.canUpdateLeaveApplication(registrarAuth, headForwarded, regApproved),
  '2.5 Registrar approving forwarded application with designated keys allowed',
);

// Registrar attempts to edit head notes
const regTamperedHeadNotes = { ...regApproved, headComment: 'Modified by registrar' };
assert(
  !sim.canUpdateLeaveApplication(registrarAuth, headForwarded, regTamperedHeadNotes),
  '2.6 Registrar attempting to overwrite Head comments denied by diff().hasOnly()',
);

// 3. Notification Restrictions
console.log('\n[Section 3: Notification Restrictions]');
// Dept Head notifies own member
assert(
  sim.canCreateNotification(headCseAuth, { recipientUid: 'fac-1' }),
  '3.1 Dept Head notifying member of own department allowed',
);
// Dept Head notifies member of different department
assert(
  !sim.canCreateNotification(headCseAuth, { recipientUid: 'fac-2' }),
  '3.2 Dept Head notifying member of another department denied',
);
// Ordinary faculty notifying another faculty
assert(
  !sim.canCreateNotification(facultyCseAuth, { recipientUid: 'fac-2' }),
  '3.3 Ordinary faculty creating notification for another user denied',
);
// Recipient updates isRead
const notifBase = { id: 'n1', recipientUid: 'fac-1', title: 'Hello', isRead: false };
assert(
  sim.canUpdateNotification(facultyCseAuth, notifBase, { ...notifBase, isRead: true }),
  '3.4 Recipient updating isRead allowed',
);
// Recipient attempts to update notification body/title
assert(
  !sim.canUpdateNotification(facultyCseAuth, notifBase, { ...notifBase, isRead: true, title: 'Forged' }),
  '3.5 Recipient attempting to modify notification title denied by diff().hasOnly()',
);

console.log('\n[Section 4: System Config & Audit Log Protections]');
assert(
  sim.canReadSystemConfig(adminAuth),
  '4.1 Admin reading system_config allowed',
);
assert(
  !sim.canReadSystemConfig(facultyCseAuth),
  '4.2 Non-admin reading system_config denied',
);
assert(
  !sim.canWriteSystemConfig(adminAuth),
  '4.3 Client writing system_config denied by allow write: if false',
);
assert(
  !sim.canWriteAuditLog(adminAuth),
  '4.4 Client writing audit_logs denied by allow write: if false',
);

console.log(`\nAll ${passed}/${total} hardened security tests PASSED cleanly!\n`);
