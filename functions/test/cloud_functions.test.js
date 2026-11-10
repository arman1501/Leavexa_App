// ─────────────────────────────────────────────────────────────────────────────
//  cloud_functions.test.js  –  Phase 12 Cloud Functions Comprehensive Test Suite
// ─────────────────────────────────────────────────────────────────────────────

const { expect } = require('chai');

// Create In-Memory Mock of Firebase Admin SDK
class MockFirestoreCollection {
  constructor(name, db) {
    this.name = name;
    this.db = db;
  }

  doc(id) {
    const docId = id || `auto_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return new MockFirestoreDocRef(this.name, docId, this.db);
  }

  where(field, op, value) {
    return new MockFirestoreQuery(this.name, this.db, [{ field, op, value }]);
  }

  async get() {
    const colData = this.db.store[this.name] || {};
    const docs = Object.entries(colData).map(([id, data]) => ({
      id,
      data: () => ({ ...data }),
      exists: true,
      ref: new MockFirestoreDocRef(this.name, id, this.db),
    }));
    return {
      empty: docs.length === 0,
      size: docs.length,
      docs,
    };
  }
}

class MockFirestoreQuery {
  constructor(name, db, filters = [], limitCount = null) {
    this.name = name;
    this.db = db;
    this.filters = filters;
    this.limitCount = limitCount;
  }

  where(field, op, value) {
    return new MockFirestoreQuery(this.name, this.db, [...this.filters, { field, op, value }], this.limitCount);
  }

  limit(count) {
    return new MockFirestoreQuery(this.name, this.db, this.filters, count);
  }

  async get() {
    const colData = this.db.store[this.name] || {};
    let docs = Object.entries(colData).map(([id, data]) => ({
      id,
      data: () => ({ ...data }),
      exists: true,
      ref: new MockFirestoreDocRef(this.name, id, this.db),
    }));

    for (const filter of this.filters) {
      docs = docs.filter((d) => {
        const val = d.data()[filter.field];
        if (filter.op === '==') return val === filter.value;
        if (filter.op === '<') return val < filter.value;
        if (filter.op === '<=') return val <= filter.value;
        if (filter.op === '>') return val > filter.value;
        if (filter.op === '>=') return val >= filter.value;
        return true;
      });
    }

    if (this.limitCount !== null) {
      docs = docs.slice(0, this.limitCount);
    }

    return {
      empty: docs.length === 0,
      size: docs.length,
      docs,
    };
  }
}

class MockFirestoreDocRef {
  constructor(colName, docId, db) {
    this.colName = colName;
    this.id = docId;
    this.db = db;
  }

  async get() {
    const colData = this.db.store[this.colName] || {};
    const data = colData[this.id];
    return {
      id: this.id,
      exists: data !== undefined,
      data: () => (data !== undefined ? { ...data } : undefined),
      ref: this,
    };
  }

  async set(data, options = {}) {
    this.db.store[this.colName] = this.db.store[this.colName] || {};
    if (options.merge && this.db.store[this.colName][this.id]) {
      this.db.store[this.colName][this.id] = {
        ...this.db.store[this.colName][this.id],
        ...data,
      };
    } else {
      this.db.store[this.colName][this.id] = { ...data };
    }
  }

  async update(data) {
    this.db.store[this.colName] = this.db.store[this.colName] || {};
    if (!this.db.store[this.colName][this.id]) {
      throw new Error(`Doc ${this.id} does not exist in ${this.colName}`);
    }
    this.db.store[this.colName][this.id] = {
      ...this.db.store[this.colName][this.id],
      ...data,
    };
  }

  async delete() {
    if (this.db.store[this.colName]) {
      delete this.db.store[this.colName][this.id];
    }
  }

  collection(subColName) {
    const fullPath = `${this.colName}/${this.id}/${subColName}`;
    return new MockFirestoreCollection(fullPath, this.db);
  }
}

class MockBatch {
  constructor(db) {
    this.db = db;
    this.ops = [];
  }

  set(docRef, data, options = {}) {
    this.ops.push(() => docRef.set(data, options));
  }

  update(docRef, data) {
    this.ops.push(() => docRef.update(data));
  }

  delete(docRef) {
    this.ops.push(() => docRef.delete());
  }

  async commit() {
    for (const op of this.ops) {
      await op();
    }
  }
}

class MockFirestore {
  constructor() {
    this.store = {};
  }

  collection(name) {
    return new MockFirestoreCollection(name, this);
  }

  batch() {
    return new MockBatch(this);
  }

  async runTransaction(updateFunction) {
    // Transaction mock: records reads and applies updates
    const self = this;
    const tx = {
      async get(docRef) {
        return await docRef.get();
      },
      set(docRef, data, options = {}) {
        docRef.set(data, options);
      },
      update(docRef, data) {
        docRef.update(data);
      },
      delete(docRef) {
        docRef.delete();
      },
    };
    return await updateFunction(tx);
  }
}

class MockAuth {
  constructor() {
    this.users = {};
    this.customClaims = {};
  }

  async createUser(props) {
    const uid = props.uid || `user_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    this.users[uid] = {
      uid,
      email: props.email,
      displayName: props.displayName,
      disabled: false,
    };
    return this.users[uid];
  }

  async updateUser(uid, props) {
    if (!this.users[uid]) {
      this.users[uid] = { uid };
    }
    this.users[uid] = { ...this.users[uid], ...props };
    return this.users[uid];
  }

  async setCustomUserClaims(uid, claims) {
    this.customClaims[uid] = { ...claims };
  }

  async getCustomUserClaims(uid) {
    return this.customClaims[uid] || {};
  }
}

// Intercept admin.js module export before loading functions
const adminModule = require('../src/admin');
const mockDb = new MockFirestore();
const mockAuth = new MockAuth();

// Monkey-patch mock instances for unit testing
adminModule.db = mockDb;
adminModule.auth = mockAuth;
adminModule.FieldValue = {
  serverTimestamp: () => new Date().toISOString(),
};
adminModule.admin = {
  firestore: {
    FieldValue: {
      serverTimestamp: () => new Date().toISOString(),
    },
  },
};

const {
  provisionInitialAdminHandler,
  createStaffAccountHandler,
  setUserActiveHandler,
  syncUserCustomClaimsHandler,
} = require('../src/roles');

const {
  approveFacultyRegistrationHandler,
  rejectFacultyRegistrationHandler,
} = require('../src/approvals');

const {
  processLeaveDeductionTransaction,
  onLeaveApplicationUpdateHandler,
} = require('../src/leaves');

const { checkEmployeeIdAvailability } = require('../src/employee');

describe('Phase 12 — Cloud Functions & Trusted Backend Verification', () => {
  beforeEach(() => {
    mockDb.store = {};
    mockAuth.users = {};
    mockAuth.customClaims = {};
  });

  describe('Task 2: Secure Role Provisioning & Admin Management', () => {
    it('2.1 Rejects unauthenticated calls to provisionInitialAdmin', async () => {
      try {
        await provisionInitialAdminHandler({}, {});
        expect.fail('Should have thrown an unauthenticated error');
      } catch (err) {
        expect(err.code).to.equal('unauthenticated');
      }
    });

    it('2.2 Provisions initial admin when no active admin exists, assigning Custom Claims', async () => {
      const context = {
        auth: {
          uid: 'admin_initial_uid',
          token: { email: 'first.admin@leavexa.edu' },
        },
      };

      const result = await provisionInitialAdminHandler(
        { fullName: 'Primary Admin', employeeId: 'EMP-ADM-01' },
        context
      );

      expect(result.success).to.be.true;
      expect(result.uid).to.equal('admin_initial_uid');

      // Verify Auth Custom Claims
      const claims = await mockAuth.getCustomUserClaims('admin_initial_uid');
      expect(claims.role).to.equal('admin');
      expect(claims.approvalStatus).to.equal('approved');

      // Verify Firestore profile
      const userDoc = mockDb.store.users['admin_initial_uid'];
      expect(userDoc.role).to.equal('admin');
      expect(userDoc.isActive).to.be.true;

      // Verify system_config/bootstrap lock
      const bootstrapDoc = mockDb.store.system_config['bootstrap'];
      expect(bootstrapDoc).to.exist;
      expect(bootstrapDoc.isBootstrapped).to.be.true;

      // Verify Audit Log
      const auditDocs = Object.values(mockDb.store.audit_logs || {});
      expect(auditDocs.length).to.be.at.least(1);
      expect(auditDocs[0].action).to.equal('ADMIN_INITIAL_PROVISION');
    });

    it('2.3 Prevents rogue public admin provisioning once an admin already exists', async () => {
      // Seed existing admin
      mockDb.store.users = {
        existing_admin: {
          uid: 'existing_admin',
          role: 'admin',
          isActive: true,
        },
      };

      const context = {
        auth: {
          uid: 'attacker_uid',
          token: { email: 'attacker@hacker.io' },
        },
      };

      try {
        await provisionInitialAdminHandler({}, context);
        expect.fail('Should have rejected second admin creation');
      } catch (err) {
        expect(err.code).to.equal('already-exists');
      }
    });

    it('2.3.1 Prevents bootstrap when system_config/bootstrap is already locked', async () => {
      mockDb.store.system_config = {
        bootstrap: {
          isBootstrapped: true,
          bootstrappedBy: 'prior_admin',
        },
      };

      const context = {
        auth: {
          uid: 'new_applicant',
          token: { email: 'new@leavexa.edu' },
        },
      };

      try {
        await provisionInitialAdminHandler({}, context);
        expect.fail('Should have rejected bootstrap on locked system_config');
      } catch (err) {
        expect(err.code).to.equal('already-exists');
      }
    });

    it('2.3.2 Enforces server-side bootstrap secret when LEAVEXA_BOOTSTRAP_SECRET is configured', async () => {
      process.env.LEAVEXA_BOOTSTRAP_SECRET = 'SuperSecret123!';
      const context = {
        auth: {
          uid: 'admin_candidate',
          token: { email: 'candidate@leavexa.edu' },
        },
      };

      try {
        // Without secret -> rejected
        try {
          await provisionInitialAdminHandler({ bootstrapKey: 'wrong' }, context);
          expect.fail('Should reject wrong bootstrap key');
        } catch (err) {
          expect(err.code).to.equal('permission-denied');
        }

        // With valid secret -> succeeds
        const res = await provisionInitialAdminHandler({ bootstrapKey: 'SuperSecret123!' }, context);
        expect(res.success).to.be.true;
      } finally {
        delete process.env.LEAVEXA_BOOTSTRAP_SECRET;
      }
    });

    it('2.4 Restricts staff account creation to Admins only', async () => {
      // Calling as faculty user
      const context = {
        auth: {
          uid: 'faculty_uid',
          token: { role: 'faculty' },
        },
      };

      try {
        await createStaffAccountHandler(
          {
            email: 'head@leavexa.edu',
            password: 'Password123!',
            fullName: 'Dr. Head',
            employeeId: 'EMP-HEAD-01',
            role: 'department_head',
            departmentId: 'dept_cse',
            departmentName: 'Computer Science',
          },
          context
        );
        expect.fail('Should have rejected non-admin caller');
      } catch (err) {
        expect(err.code).to.equal('permission-denied');
      }
    });

    it('2.5 Allows Admin to provision Department Head with custom claims and departmentId', async () => {
      const context = {
        auth: {
          uid: 'admin_uid',
          token: { role: 'admin' },
        },
      };

      const result = await createStaffAccountHandler(
        {
          email: 'head.cse@leavexa.edu',
          password: 'SafePassword123!',
          fullName: 'Prof. CSE Head',
          employeeId: 'EMP-HEAD-CSE',
          role: 'department_head',
          departmentId: 'dept_cse',
          departmentName: 'Computer Science',
        },
        context
      );

      expect(result.success).to.be.true;
      const newUid = result.uid;

      // Verify Custom Claims
      const claims = await mockAuth.getCustomUserClaims(newUid);
      expect(claims.role).to.equal('department_head');
      expect(claims.departmentId).to.equal('dept_cse');

      // Verify Profile
      const profile = mockDb.store.users[newUid];
      expect(profile.role).to.equal('department_head');
      expect(profile.departmentId).to.equal('dept_cse');
      expect(profile.approvalStatus).to.equal('approved');

      // Verify Employee ID reservation
      expect(mockDb.store.employee_ids['EMP-HEAD-CSE']).to.exist;
      expect(mockDb.store.employee_ids['EMP-HEAD-CSE'].uid).to.equal(newUid);
    });

    it('2.6 Allows Admin to provision Registrar with custom claims', async () => {
      const context = {
        auth: {
          uid: 'admin_uid',
          token: { role: 'admin' },
        },
      };

      const result = await createStaffAccountHandler(
        {
          email: 'registrar@leavexa.edu',
          password: 'SafePassword123!',
          fullName: 'University Registrar',
          employeeId: 'EMP-REG-01',
          role: 'registrar',
        },
        context
      );

      expect(result.success).to.be.true;
      const claims = await mockAuth.getCustomUserClaims(result.uid);
      expect(claims.role).to.equal('registrar');
      expect(mockDb.store.users[result.uid].role).to.equal('registrar');
    });

    it('2.7 Allows Admin to activate and deactivate accounts, preventing self-deactivation', async () => {
      const context = {
        auth: {
          uid: 'admin_uid',
          token: { role: 'admin' },
        },
      };

      mockDb.store.users = {
        target_fac: { uid: 'target_fac', role: 'faculty', isActive: true },
      };

      // Admin tries to deactivate self -> blocked
      try {
        await setUserActiveHandler({ targetUid: 'admin_uid', isActive: false }, context);
        expect.fail('Should prevent self-deactivation');
      } catch (err) {
        expect(err.code).to.equal('failed-precondition');
      }

      // Admin deactivates faculty
      const res = await setUserActiveHandler({ targetUid: 'target_fac', isActive: false }, context);
      expect(res.isActive).to.be.false;
      expect(mockDb.store.users['target_fac'].isActive).to.be.false;
      expect(mockAuth.users['target_fac'].disabled).to.be.true;
    });

    it('2.8 syncUserCustomClaims aligns Auth Claims with Firestore profile', async () => {
      mockDb.store.users = {
        user_123: {
          uid: 'user_123',
          role: 'department_head',
          departmentId: 'dept_eee',
          approvalStatus: 'approved',
        },
      };

      const context = {
        auth: { uid: 'user_123', token: {} },
      };

      const result = await syncUserCustomClaimsHandler({ targetUid: 'user_123' }, context);
      expect(result.claims.role).to.equal('department_head');
      expect(result.claims.departmentId).to.equal('dept_eee');
      expect(result.claims.approvalStatus).to.equal('approved');
    });
  });

  describe('Task 3: Faculty Approval Workflow', () => {
    it('3.1 Rejects non-admin attempts to approve faculty', async () => {
      const context = {
        auth: { uid: 'rogue_faculty', token: { role: 'faculty' } },
      };

      try {
        await approveFacultyRegistrationHandler({ targetUid: 'any_uid' }, context);
        expect.fail('Should reject non-admin');
      } catch (err) {
        expect(err.code).to.equal('permission-denied');
      }
    });

    it('3.2 Approving faculty updates profile, sets Custom Claims, initializes balances, and sends notification', async () => {
      const facultyUid = 'fac_pending_01';
      mockDb.store.users = {
        [facultyUid]: {
          uid: facultyUid,
          fullName: 'Dr. Sarah Connor',
          email: 'sarah@leavexa.edu',
          employeeId: 'EMP-7711',
          departmentId: 'dept_math',
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        },
      };

      const context = {
        auth: { uid: 'admin_uid', token: { role: 'admin' } },
      };

      const res = await approveFacultyRegistrationHandler({ targetUid: facultyUid }, context);
      expect(res.success).to.be.true;

      // 1. Profile updated
      const user = mockDb.store.users[facultyUid];
      expect(user.approvalStatus).to.equal('approved');
      expect(user.isActive).to.be.true;
      expect(user.approvedBy).to.equal('admin_uid');

      // 2. Custom Claims set
      const claims = await mockAuth.getCustomUserClaims(facultyUid);
      expect(claims.role).to.equal('faculty');
      expect(claims.approvalStatus).to.equal('approved');

      // 3. Leave balances provisioned (Casual 10, Sick 14, Earned 30)
      const currentYear = new Date().getFullYear();
      const casualBal = mockDb.store.leave_balances[`${facultyUid}_casual_${currentYear}`];
      expect(casualBal).to.exist;
      expect(casualBal.totalAllotted).to.equal(10);
      expect(casualBal.used).to.equal(0);

      const sickBal = mockDb.store.leave_balances[`${facultyUid}_sick_${currentYear}`];
      expect(sickBal).to.exist;
      expect(sickBal.totalAllotted).to.equal(14);

      const earnedBal = mockDb.store.leave_balances[`${facultyUid}_earned_${currentYear}`];
      expect(earnedBal).to.exist;
      expect(earnedBal.totalAllotted).to.equal(30);

      // 4. Notification dispatched
      const notifs = Object.values(mockDb.store.notifications || {});
      expect(notifs.length).to.equal(1);
      expect(notifs[0].recipientUid).to.equal(facultyUid);
      expect(notifs[0].type).to.equal('approval');

      // 5. Audit log created
      const audit = Object.values(mockDb.store.audit_logs || {});
      const appLog = audit.find((a) => a.action === 'FACULTY_APPROVE');
      expect(appLog).to.exist;
      expect(appLog.targetId).to.equal(facultyUid);
    });

    it('3.3 Rejecting faculty sets approvalStatus to rejected, records reason, and disables account', async () => {
      const facultyUid = 'fac_reject_01';
      mockDb.store.users = {
        [facultyUid]: {
          uid: facultyUid,
          fullName: 'Applicant Incomplete',
          email: 'incomplete@leavexa.edu',
          employeeId: 'EMP-9900',
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        },
      };

      const context = {
        auth: { uid: 'admin_uid', token: { role: 'admin' } },
      };

      const res = await rejectFacultyRegistrationHandler(
        { targetUid: facultyUid, reason: 'NID documents unverified' },
        context
      );
      expect(res.success).to.be.true;

      const user = mockDb.store.users[facultyUid];
      expect(user.approvalStatus).to.equal('rejected');
      expect(user.isActive).to.be.false;
      expect(user.rejectionReason).to.equal('NID documents unverified');

      // Auth user disabled
      expect(mockAuth.users[facultyUid].disabled).to.be.true;

      // Rejection notification sent
      const notifs = Object.values(mockDb.store.notifications || {});
      expect(notifs[0].type).to.equal('rejection');
      expect(notifs[0].body).to.include('NID documents unverified');
    });
  });

  describe('Task 4 & 5: Leave Balance Management & Audit Logging', () => {
    it('4.1 Atomically deducts leave balance on final approval and stamps balanceDeducted: true', async () => {
      const currentYear = new Date().getFullYear();
      const applicantUid = 'prof_alice';
      const balanceId = `${applicantUid}_annual_${currentYear}`;

      mockDb.store.leave_balances = {
        [balanceId]: {
          id: balanceId,
          userUid: applicantUid,
          leaveTypeId: 'annual',
          totalAllotted: 20,
          used: 2,
        },
      };

      mockDb.store.leave_applications = {
        app_valid: {
          id: 'app_valid',
          applicantUid,
          leaveTypeId: 'annual',
          totalDays: 5,
          status: 'approved',
          registrarUid: 'reg_officer',
          startDate: { toDate: () => new Date() },
        },
      };

      const result = await processLeaveDeductionTransaction(
        'app_valid',
        mockDb.store.leave_applications['app_valid']
      );

      expect(result.success).to.be.true;
      expect(result.deductedDays).to.equal(5);
      expect(result.newUsed).to.equal(7);
      expect(result.remaining).to.equal(13);

      // Verify balance in database
      expect(mockDb.store.leave_balances[balanceId].used).to.equal(7);

      // Verify application stamped
      expect(mockDb.store.leave_applications['app_valid'].balanceDeducted).to.be.true;
      expect(mockDb.store.leave_applications['app_valid'].deductedDays).to.equal(5);

      // Verify Audit Log
      const auditDocs = Object.values(mockDb.store.audit_logs || {});
      const dedLog = auditDocs.find((a) => a.action === 'LEAVE_BALANCE_DEDUCTION');
      expect(dedLog).to.exist;
      expect(dedLog.details.deductedDays).to.equal(5);
    });

    it('4.2 Prevents duplicate deduction when balanceDeducted is already true (Idempotency)', async () => {
      const currentYear = new Date().getFullYear();
      const balanceId = `prof_alice_annual_${currentYear}`;

      mockDb.store.leave_balances = {
        [balanceId]: {
          id: balanceId,
          userUid: 'prof_alice',
          leaveTypeId: 'annual',
          totalAllotted: 20,
          used: 7, // Already used 7
        },
      };

      // Already processed application
      mockDb.store.leave_applications = {
        app_already_deducted: {
          id: 'app_already_deducted',
          applicantUid: 'prof_alice',
          leaveTypeId: 'annual',
          totalDays: 5,
          status: 'approved',
          balanceDeducted: true, // ALREADY DEDUCTED
        },
      };

      const result = await processLeaveDeductionTransaction(
        'app_already_deducted',
        mockDb.store.leave_applications['app_already_deducted']
      );

      expect(result.success).to.be.true;
      expect(result.alreadyProcessed).to.be.true;

      // Balance MUST remain unchanged (7, not 12)
      expect(mockDb.store.leave_balances[balanceId].used).to.equal(7);
    });

    it('4.3 Prevents negative leave balances when requested days exceed remaining', async () => {
      const currentYear = new Date().getFullYear();
      const balanceId = `prof_bob_sick_${currentYear}`;

      mockDb.store.leave_balances = {
        [balanceId]: {
          id: balanceId,
          userUid: 'prof_bob',
          leaveTypeId: 'sick',
          totalAllotted: 10,
          used: 8, // Remaining = 2 days
        },
      };

      mockDb.store.leave_applications = {
        app_excess: {
          id: 'app_excess',
          applicantUid: 'prof_bob',
          leaveTypeId: 'sick',
          totalDays: 5, // Exceeds remaining 2 days
          status: 'approved',
        },
      };

      const result = await processLeaveDeductionTransaction(
        'app_excess',
        mockDb.store.leave_applications['app_excess']
      );

      expect(result.success).to.be.false;
      expect(result.message).to.include('Insufficient leave balance');

      // Balance was NOT deducted
      expect(mockDb.store.leave_balances[balanceId].used).to.equal(8);

      // Application marked with error
      expect(mockDb.store.leave_applications['app_excess'].balanceDeducted).to.not.be.true;
      expect(mockDb.store.leave_applications['app_excess'].balanceDeductionError).to.include('Insufficient');

      // Failure Audit Log recorded
      const auditDocs = Object.values(mockDb.store.audit_logs || {});
      const failLog = auditDocs.find((a) => a.action === 'LEAVE_DEDUCTION_FAILED_INSUFFICIENT_BALANCE');
      expect(failLog).to.exist;
    });

    it('4.4 onLeaveApplicationUpdate trigger handles lifecycle transitions and records audit logs', async () => {
      const changeForward = {
        before: { data: () => ({ status: 'pending' }) },
        after: {
          data: () => ({
            status: 'forwarded',
            headUid: 'head_cse',
            departmentId: 'dept_cse',
            headComment: 'Recommended for approval',
          }),
        },
      };

      await onLeaveApplicationUpdateHandler(changeForward, { params: { applicationId: 'app_101' } });

      const auditDocs = Object.values(mockDb.store.audit_logs || {});
      const forwardLog = auditDocs.find((a) => a.action === 'HEAD_FORWARD_LEAVE');
      expect(forwardLog).to.exist;
      expect(forwardLog.actorUid).to.equal('head_cse');
      expect(forwardLog.relatedApplicationId).to.equal('app_101');
    });

    it('4.5 Safe trigger retry: re-executing deduction on already deducted application preserves balance', async () => {
      const currentYear = new Date().getFullYear();
      const balanceId = `prof_carol_casual_${currentYear}`;

      mockDb.store.leave_balances = {
        [balanceId]: {
          id: balanceId,
          userUid: 'prof_carol',
          leaveTypeId: 'casual',
          totalAllotted: 10,
          used: 0,
        },
      };

      mockDb.store.leave_applications = {
        app_retry: {
          id: 'app_retry',
          applicantUid: 'prof_carol',
          leaveTypeId: 'casual',
          totalDays: 2,
          status: 'approved',
          startDate: { toDate: () => new Date() },
        },
      };

      // 1st execution
      const res1 = await processLeaveDeductionTransaction('app_retry', mockDb.store.leave_applications['app_retry']);
      expect(res1.success).to.be.true;
      expect(mockDb.store.leave_balances[balanceId].used).to.equal(2);

      // 2nd execution (retry)
      const res2 = await processLeaveDeductionTransaction('app_retry', mockDb.store.leave_applications['app_retry']);
      expect(res2.success).to.be.true;
      expect(res2.alreadyProcessed).to.be.true;
      // Used days MUST remain 2 (no double deduction)
      expect(mockDb.store.leave_balances[balanceId].used).to.equal(2);
    });

    it('4.6 Validates totalDays: rejects non-positive totalDays', async () => {
      mockDb.store.leave_applications = {
        app_invalid_days: {
          id: 'app_invalid_days',
          applicantUid: 'prof_carol',
          leaveTypeId: 'casual',
          totalDays: 0,
          status: 'approved',
        },
      };

      try {
        await processLeaveDeductionTransaction('app_invalid_days', mockDb.store.leave_applications['app_invalid_days']);
        expect.fail('Should reject non-positive totalDays');
      } catch (err) {
        expect(err.message).to.include('Invalid totalDays value');
      }
    });

    it('4.7 Resolves medical vs sick alias: medical application successfully deducts from legacy sick balance', async () => {
      const currentYear = new Date().getFullYear();
      const applicantUid = 'prof_medical_alias';
      const balanceId = `${applicantUid}_sick_${currentYear}`;

      mockDb.store.leave_balances = {
        [balanceId]: {
          id: balanceId,
          userUid: applicantUid,
          leaveTypeId: 'sick',
          totalAllotted: 14,
          used: 2, // Remaining = 12 days
        },
      };

      mockDb.store.leave_applications = {
        app_medical_alias: {
          id: 'app_medical_alias',
          applicantUid: applicantUid,
          leaveTypeId: 'medical', // Applied as medical
          totalDays: 3,
          status: 'approved',
        },
      };

      const result = await processLeaveDeductionTransaction(
        'app_medical_alias',
        mockDb.store.leave_applications['app_medical_alias']
      );

      expect(result.success).to.be.true;
      expect(mockDb.store.leave_balances[balanceId].used).to.equal(5);
      expect(mockDb.store.leave_applications['app_medical_alias'].balanceDeducted).to.be.true;
    });

    it('4.8 onLeaveApplicationUpdate handles Faculty cancellation and records FACULTY_CANCEL_LEAVE audit log', async () => {
      const changeCancel = {
        before: {
          data: () => ({
            id: 'app_cancel_event',
            applicantUid: 'faculty_cancel_uid',
            departmentId: 'dept_math',
            status: 'pending',
            leaveTypeName: 'Casual Leave',
            totalDays: 2,
          }),
        },
        after: {
          data: () => ({
            id: 'app_cancel_event',
            applicantUid: 'faculty_cancel_uid',
            departmentId: 'dept_math',
            status: 'cancelled',
            leaveTypeName: 'Casual Leave',
            totalDays: 2,
            cancelReason: 'Personal emergency resolved',
          }),
        },
      };

      await onLeaveApplicationUpdateHandler(changeCancel, { params: { applicationId: 'app_cancel_event' } });

      const auditDocs = Object.values(mockDb.store.audit_logs || {});
      const cancelLog = auditDocs.find((a) => a.action === 'FACULTY_CANCEL_LEAVE');
      expect(cancelLog).to.exist;
      expect(cancelLog.actorUid).to.equal('faculty_cancel_uid');
      expect(cancelLog.details.cancelReason).to.equal('Personal emergency resolved');
    });
  });

  describe('Task 6: Employee ID Validation', () => {
    it('6.1 Reports availability and documents authoritative HR limitation', async () => {
      mockDb.store.employee_ids = {
        'EMP-TAKEN': { uid: 'user_xyz' },
      };

      const resTaken = await checkEmployeeIdAvailability('EMP-TAKEN');
      expect(resTaken.isAvailable).to.be.false;

      const resAvailable = await checkEmployeeIdAvailability('EMP-FREE');
      expect(resAvailable.isAvailable).to.be.true;
      expect(resAvailable.limitationNotice).to.include('not validated against external university HR records');
    });
  });
});
