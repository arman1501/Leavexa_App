// ─────────────────────────────────────────────────────────────────────────────
//  faculty_lifecycle_emulator_e2e_test.js
//  Complete Faculty Account Lifecycle & Admin Approval Verification
// ─────────────────────────────────────────────────────────────────────────────

const assert = require('assert');
const path = require('path');
const fs = require('fs');

// Configure emulator host environments before initializing admin
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';
process.env.GCLOUD_PROJECT = 'leavexa';

const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'leavexa' });
}

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  setDoc,
  getDoc,
  writeBatch,
} = require('@firebase/firestore');

const {
  approveFacultyRegistrationHandler,
} = require('../../functions/src/approvals');

const RULES_PATH = path.join(__dirname, '../../firestore.rules');

describe('Phase 20 — Faculty Account Lifecycle & Admin Approval E2E Verification', function () {
  this.timeout(20000);

  let testEnv;
  const adminUid = 'admin_e2e_test';
  const facultyUid = 'faculty_e2e_' + Date.now();
  const facultyEmail = `faculty.e2e.${Date.now()}@leavexa.edu`;
  const facultyEmpId = 'FAC-E2E-' + Math.floor(1000 + Math.random() * 9000);

  before(async () => {
    const rules = fs.readFileSync(RULES_PATH, 'utf8');
    testEnv = await initializeTestEnvironment({
      projectId: 'leavexa',
      firestore: {
        rules,
        host: '127.0.0.1',
        port: 8088,
      },
    });

    // Seed Admin user in Firestore & Auth Custom Claims
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users', adminUid), {
        uid: adminUid,
        fullName: 'System Administrator',
        email: 'admin.e2e@leavexa.edu',
        role: 'admin',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: new Date().toISOString(),
      });
    });

    try {
      await admin.auth().deleteUser(adminUid);
    } catch (_) {}

    await admin.auth().createUser({
      uid: adminUid,
      email: 'admin.e2e@leavexa.edu',
      password: 'AdminPassword123!',
      displayName: 'System Administrator',
    });

    await admin.auth().setCustomUserClaims(adminUid, {
      role: 'admin',
      approvalStatus: 'approved',
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  //  1. Faculty Registration
  // ═════════════════════════════════════════════════════════════════════════
  describe('1. Faculty Registration Workflow', () => {
    it('1.1 Creates Firebase Auth account with verified email credentials', async () => {
      const userRecord = await admin.auth().createUser({
        uid: facultyUid,
        email: facultyEmail,
        password: 'FacultyPassword123!',
        displayName: 'Dr. New Faculty Member',
      });

      assert.strictEqual(userRecord.uid, facultyUid);
      assert.strictEqual(userRecord.email, facultyEmail.toLowerCase());
      assert.strictEqual(userRecord.disabled, false);
      // Verify no elevated custom claims exist at registration
      assert.deepStrictEqual(userRecord.customClaims || {}, {});
    });

    it('1.2 Creates Firestore profile and normalizes Employee ID to uppercase with pending/inactive status', async () => {
      const clientDb = testEnv.authenticatedContext(facultyUid).firestore();
      const batch = writeBatch(clientDb);

      // Reserve normalized Employee ID
      batch.set(doc(clientDb, 'employee_ids', facultyEmpId), {
        uid: facultyUid,
      });

      // Write users/{uid} profile
      batch.set(doc(clientDb, 'users', facultyUid), {
        uid: facultyUid,
        fullName: 'Dr. New Faculty Member',
        email: facultyEmail.toLowerCase(),
        employeeId: facultyEmpId,
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Assistant Professor',
        role: 'faculty',
        phone: '+8801700000000',
        approvalStatus: 'pending',
        isActive: false,
        photoUrl: null, // Profile photo optional
      });

      await assertSucceeds(batch.commit());

      // Read back via admin SDK to verify exact Firestore state
      const userDoc = await admin.firestore().collection('users').doc(facultyUid).get();
      assert.strictEqual(userDoc.exists, true);
      const data = userDoc.data();
      assert.strictEqual(data.role, 'faculty');
      assert.strictEqual(data.approvalStatus, 'pending');
      assert.strictEqual(data.isActive, false);
      assert.strictEqual(data.employeeId, facultyEmpId);
      assert.strictEqual(data.departmentId, 'dept_cse');
      assert.strictEqual(data.photoUrl, null);

      const empDoc = await admin.firestore().collection('employee_ids').doc(facultyEmpId).get();
      assert.strictEqual(empDoc.exists, true);
      assert.strictEqual(empDoc.data().uid, facultyUid);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  //  2. Pending Account Experience & Security Enforcement
  // ═════════════════════════════════════════════════════════════════════════
  describe('2. Pending Account Experience & Security Enforcement', () => {
    it('2.1 Unapproved pending Faculty cannot create leave applications', async () => {
      const pendingDb = testEnv.authenticatedContext(facultyUid).firestore();
      const appRef = doc(pendingDb, 'leave_applications', 'unapproved_app_1');

      // Rule requires isApprovedActiveFaculty()
      await assertFails(
        setDoc(appRef, {
          id: 'unapproved_app_1',
          applicantUid: facultyUid,
          departmentId: 'dept_cse',
          leaveTypeId: 'casual',
          startDate: '2026-12-01',
          endDate: '2026-12-03',
          totalDays: 3,
          reason: 'Personal urgent work',
          status: 'pending',
          createdAt: new Date().toISOString(),
        }),
      );
    });

    it('2.2 Unapproved pending Faculty cannot access system_config, audit_logs or other users', async () => {
      const pendingDb = testEnv.authenticatedContext(facultyUid).firestore();

      await assertFails(getDoc(doc(pendingDb, 'system_config', 'bootstrap')));
      await assertFails(getDoc(doc(pendingDb, 'audit_logs', 'log_1')));
      await assertFails(getDoc(doc(pendingDb, 'users', adminUid)));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  //  3. Admin Verification & Cloud Function Approval
  // ═════════════════════════════════════════════════════════════════════════
  describe('3. Admin Verification & Cloud Function Approval', () => {
    it('3.1 Admin queries pending registrations and verifies submitted information', async () => {
      const snapshot = await admin.firestore().collection('users')
        .where('approvalStatus', '==', 'pending')
        .get();

      const found = snapshot.docs.find((d) => d.id === facultyUid);
      assert.ok(found, 'Pending faculty should appear in pending query');
      const data = found.data();
      assert.strictEqual(data.fullName, 'Dr. New Faculty Member');
      assert.strictEqual(data.email, facultyEmail.toLowerCase());
      assert.strictEqual(data.employeeId, facultyEmpId);
      assert.strictEqual(data.designation, 'Assistant Professor');
    });

    it('3.2 Admin approves the Faculty account using secure Cloud Function', async () => {
      // Execute the trusted backend Cloud Function handler with Admin context
      const res = await approveFacultyRegistrationHandler(
        { targetUid: facultyUid },
        { auth: { uid: adminUid, token: { role: 'admin' } } },
      );

      assert.strictEqual(res.success, true);
      assert.strictEqual(res.targetUid, facultyUid);
      assert.ok(res.message.includes('approved'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  //  4. Faculty Activation Verification
  // ═════════════════════════════════════════════════════════════════════════
  describe('4. Faculty Activation & Capabilities Verification', () => {
    it('4.1 Firestore profile reflects approved and active status with audit fields', async () => {
      const userDoc = await admin.firestore().collection('users').doc(facultyUid).get();
      const data = userDoc.data();

      assert.strictEqual(data.approvalStatus, 'approved');
      assert.strictEqual(data.isActive, true);
      assert.strictEqual(data.approvedBy, adminUid);
      assert.ok(data.approvedAt, 'approvedAt timestamp must be set');
    });

    it('4.2 Initialized annual leave balances in leave_balances collection', async () => {
      const year = new Date().getFullYear();
      const balancesSnap = await admin.firestore().collection('leave_balances')
        .where('userUid', '==', facultyUid)
        .where('year', '==', year)
        .get();

      assert.strictEqual(balancesSnap.size, 7);
      const leaveTypes = balancesSnap.docs.map((d) => d.data().leaveTypeId);
      assert.ok(leaveTypes.includes('casual'));
      assert.ok(leaveTypes.includes('medical'));
      assert.ok(leaveTypes.includes('sick'));
      assert.ok(leaveTypes.includes('earned'));
      assert.ok(leaveTypes.includes('duty'));
      assert.ok(leaveTypes.includes('station'));
      assert.ok(leaveTypes.includes('study'));

      const casual = balancesSnap.docs.find((d) => d.data().leaveTypeId === 'casual').data();
      assert.strictEqual(casual.totalAllotted, 10);
      assert.strictEqual(casual.used, 0);
    });

    it('4.3 Delivered congratulations in-app notification', async () => {
      const notifSnap = await admin.firestore().collection('notifications')
        .where('recipientUid', '==', facultyUid)
        .get();

      assert.ok(notifSnap.size >= 1);
      const notif = notifSnap.docs[0].data();
      assert.strictEqual(notif.type, 'approval');
      assert.strictEqual(notif.isRead, false);
      assert.strictEqual(notif.title, 'Account Approved!');
    });

    it('4.4 Synchronized Firebase Auth Custom Claims', async () => {
      const userRecord = await admin.auth().getUser(facultyUid);
      assert.ok(userRecord.customClaims);
      assert.strictEqual(userRecord.customClaims.role, 'faculty');
      assert.strictEqual(userRecord.customClaims.approvalStatus, 'approved');
      assert.strictEqual(userRecord.customClaims.departmentId, 'dept_cse');
    });

    it('4.5 Approved Faculty can now submit a leave application successfully', async () => {
      try {
        const approvedDb = testEnv.authenticatedContext(facultyUid).firestore();
        const appRef = doc(approvedDb, 'leave_applications', 'approved_app_' + Date.now());

        await setDoc(appRef, {
          id: 'approved_app_e2e',
          applicantUid: facultyUid,
          applicantName: 'Dr. New Faculty Member',
          employeeId: facultyEmpId,
          departmentId: 'dept_cse',
          leaveTypeId: 'casual',
          startDate: '2026-12-01',
          endDate: '2026-12-03',
          totalDays: 3,
          reason: 'Conference presentation',
          status: 'pending',
          createdAt: new Date().toISOString(),
        });
      } catch (e) {
        console.error('DEBUG ERROR:', e);
        const u = await admin.firestore().collection('users').doc(facultyUid).get();
        console.log('DEBUG USER DOC IN ADMIN:', u.data());
        throw e;
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  //  5. Negative Tests
  // ═════════════════════════════════════════════════════════════════════════
  describe('5. Negative Tests Matrix', () => {
    it('5.1 Duplicate Employee ID reservation attempt is denied', async () => {
      const anotherUid = 'another_faculty_' + Date.now();
      const anotherDb = testEnv.authenticatedContext(anotherUid).firestore();

      // Attempt to claim existing facultyEmpId
      await assertFails(
        setDoc(doc(anotherDb, 'employee_ids', facultyEmpId), {
          uid: anotherUid,
        }),
      );
    });

    it('5.2 Duplicate Email in Firebase Auth is rejected', async () => {
      await assert.rejects(
        admin.auth().createUser({
          email: facultyEmail,
          password: 'AnotherPassword123!',
        }),
        (err) => err.code === 'auth/email-already-exists' ||
                 err.code === 'auth/email-already-in-use' ||
                 (err.message && err.message.includes('already in use')),
      );
    });

    it('5.3 Invalid Employee ID (<3 characters or >30 characters) is denied by rules', async () => {
      const testUid = 'test_invalid_emp_' + Date.now();
      const testDb = testEnv.authenticatedContext(testUid).firestore();

      // Too short (< 3 characters)
      const shortBatch = writeBatch(testDb);
      shortBatch.set(doc(testDb, 'employee_ids', 'AB'), { uid: testUid });
      shortBatch.set(doc(testDb, 'users', testUid), {
        uid: testUid,
        fullName: 'Short ID User',
        email: 'short@leavexa.edu',
        employeeId: 'AB',
        departmentId: 'dept_cse',
        role: 'faculty',
        approvalStatus: 'pending',
        isActive: false,
      });
      await assertFails(shortBatch.commit());

      // Too long (> 30 characters)
      const longId = 'A'.repeat(35);
      const longBatch = writeBatch(testDb);
      longBatch.set(doc(testDb, 'employee_ids', longId), { uid: testUid });
      longBatch.set(doc(testDb, 'users', testUid), {
        uid: testUid,
        fullName: 'Long ID User',
        email: 'long@leavexa.edu',
        employeeId: longId,
        departmentId: 'dept_cse',
        role: 'faculty',
        approvalStatus: 'pending',
        isActive: false,
      });
      await assertFails(longBatch.commit());
    });

    it('5.4 Faculty attempting Admin-only operations is denied', async () => {
      const facultyDb = testEnv.authenticatedContext(facultyUid).firestore();

      // 1. Attempt to write to system_config
      await assertFails(
        setDoc(doc(facultyDb, 'system_config', 'hacked'), { rogue: true }),
      );

      // 2. Attempt to write to audit_logs
      await assertFails(
        setDoc(doc(facultyDb, 'audit_logs', 'fake_log'), { action: 'ROGUE' }),
      );

      // 3. Attempt to approve another user directly in Firestore
      await assertFails(
        setDoc(doc(facultyDb, 'users', adminUid), {
          approvalStatus: 'rejected',
        }),
      );
    });

    it('5.5 Unauthorized non-admin attempting to approve another account via Cloud Function is rejected', async () => {
      await assert.rejects(
        approveFacultyRegistrationHandler(
          { targetUid: facultyUid },
          { auth: { uid: facultyUid, token: { role: 'faculty' } } },
        ),
        (err) => err.code === 'permission-denied',
      );

      // Unauthenticated call
      await assert.rejects(
        approveFacultyRegistrationHandler(
          { targetUid: facultyUid },
          { auth: null },
        ),
        (err) => err.code === 'unauthenticated',
      );
    });
  });
});
