const assert = require('assert');
const admin = require('firebase-admin');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, writeBatch } = require('firebase/firestore');

const {
  INSTITUTIONAL_ACCOUNTS,
  runProvisioning,
} = require('../../functions/scripts/provision_fixed_staff');

const PROJECT_ID = 'leavexa';
const AUTH_HOST = 'http://127.0.0.1:9099';
const FUNCTIONS_HOST = 'http://127.0.0.1:5001';

async function authSignIn(email, password) {
  const res = await fetch(
    `${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  return { status: res.status, data: await res.json() };
}

async function authSignUp(email, password) {
  const res = await fetch(
    `${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  return { status: res.status, data: await res.json() };
}

async function callFunction(name, idToken, data) {
  const res = await fetch(
    `${FUNCTIONS_HOST}/${PROJECT_ID}/us-central1/${name}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({ data }),
    }
  );
  const json = await res.json();
  return { status: res.status, json };
}

async function waitFor(predicate, timeoutMs = 6000, intervalMs = 150) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const val = await predicate();
    if (val) return val;
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  return null;
}

describe('LEAVEXA — Complete Local End-to-End Emulator Workflow', function () {
  this.timeout(25000);

  let testEnv;
  let adminAuth;
  let adminDb;

  before(async () => {
    if (!admin.apps.length) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    adminAuth = admin.auth();
    adminDb = admin.firestore();

    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { host: '127.0.0.1', port: 8088 },
      storage: { host: '127.0.0.1', port: 9199 },
    });
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  it('Runs full E2E: 12-account provision -> Faculty registration -> Admin approval -> Leave submit -> Head forward -> Registrar approve -> Balance deduction -> Idempotency -> Dept transfer', async () => {
    // 1. Provision all 12 institutional accounts using .env.institutional
    const provisioned = await runProvisioning({ auth: adminAuth, db: adminDb });
    assert.strictEqual(provisioned.length, 12);
    assert.strictEqual(
      provisioned.filter((r) => r.status === 'ACTIVE_AND_APPROVED').length,
      12
    );

    const adminSignIn = await authSignIn(
      'admin.lu@gmail.com',
      process.env.STAFF_ADMIN_PASSWORD
    );
    assert.strictEqual(adminSignIn.status, 200);
    const adminToken = adminSignIn.data.idToken;

    // 2. Faculty self-registration in Auth + Firestore (pending, inactive)
    const facEmail = `e2e.faculty.${Date.now()}@gmail.com`;
    const facPass = 'FacultyE2E@2026';
    const facSignUp = await authSignUp(facEmail, facPass);
    assert.strictEqual(facSignUp.status, 200);
    const facUid = facSignUp.data.localId;
    const facTokenPending = facSignUp.data.idToken;

    const facDb = testEnv.authenticatedContext(facUid, {
      email: facEmail,
    }).firestore();

    const regBatch = writeBatch(facDb);
    regBatch.set(doc(facDb, 'employee_ids', 'CSE-E2E-101'), {
      uid: facUid,
      employeeId: 'CSE-E2E-101',
    });
    regBatch.set(doc(facDb, 'users', facUid), {
      uid: facUid,
      email: facEmail,
      fullName: 'Dr. E2E Faculty',
      employeeId: 'CSE-E2E-101',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Assistant Professor',
      role: 'faculty',
      approvalStatus: 'pending',
      isActive: false,
    });
    await assertSucceeds(regBatch.commit());

    // Pending faculty cannot submit leave via trusted callable
    const blockedSubmit = await callFunction(
      'submitLeaveApplication',
      facTokenPending,
      {
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        startDate: '2026-12-01T00:00:00.000Z',
        endDate: '2026-12-03T00:00:00.000Z',
        totalDays: 3,
        reason: 'Pending should fail',
      }
    );
    assert.notStrictEqual(blockedSubmit.status, 200);

    // 3. Admin approves Faculty via approveFacultyRegistration callable
    const approveRes = await callFunction('approveFacultyRegistration', adminToken, {
      targetUid: facUid,
    });
    assert.strictEqual(approveRes.status, 200, JSON.stringify(approveRes.json));
    assert.strictEqual(approveRes.json.result.success, true);

    const currentYear = new Date().getFullYear();
    const balId = `${facUid}_casual_${currentYear}`;
    const balSnap = await adminDb.collection('leave_balances').doc(balId).get();
    assert.strictEqual(balSnap.exists, true);
    assert.strictEqual(balSnap.data().totalAllotted, 10);
    assert.strictEqual(balSnap.data().used, 0);

    // Refresh Faculty token to pick up approved claims
    const facApprovedSignIn = await authSignIn(facEmail, facPass);
    assert.strictEqual(facApprovedSignIn.status, 200);
    const facToken = facApprovedSignIn.data.idToken;

    // 4. Approved Faculty uploads attachment using pre-allocated synchronized applicationId,
    // then submits via submitLeaveApplication (spoofing dept_eee -> server enforces dept_cse)
    const syncedAppId = `e2eApp${Date.now()}Sync`;
    const facStorage = testEnv.authenticatedContext(facUid, {
      email: facEmail,
      role: 'faculty',
      departmentId: 'dept_cse',
    }).storage();
    await assertSucceeds(
      facStorage
        .ref(`leave_documents/${facUid}/${syncedAppId}/proof.pdf`)
        .put(Buffer.from('%PDF-1.4\n%test'), { contentType: 'application/pdf' })
    );

    const submitRes = await callFunction('submitLeaveApplication', facToken, {
      applicationId: syncedAppId,
      departmentId: 'dept_eee',
      leaveTypeId: 'casual',
      leaveTypeName: 'Casual Leave',
      startDate: '2026-12-01T00:00:00.000Z',
      endDate: '2026-12-03T00:00:00.000Z',
      totalDays: 3,
      reason: 'Academic conference leave',
    });
    assert.strictEqual(submitRes.status, 200, JSON.stringify(submitRes.json));
    const appId = submitRes.json.result.applicationId;
    assert.strictEqual(appId, syncedAppId);

    // Duplicate/overwrite of existing applicationId is rejected
    const overwriteRes = await callFunction('submitLeaveApplication', facToken, {
      applicationId: syncedAppId,
      leaveTypeId: 'casual',
      leaveTypeName: 'Casual Leave',
      startDate: '2026-12-01T00:00:00.000Z',
      endDate: '2026-12-03T00:00:00.000Z',
      totalDays: 3,
      reason: 'Duplicate ID overwrite attempt',
    });
    assert.notStrictEqual(overwriteRes.status, 200);

    const appSnapAfterSubmit = await adminDb
      .collection('leave_applications')
      .doc(appId)
      .get();
    assert.strictEqual(appSnapAfterSubmit.data().departmentId, 'dept_cse');
    assert.strictEqual(appSnapAfterSubmit.data().status, 'pending');

    // 5. Department Head isolation (Firestore + Storage attachment) + Forward
    const headCse = provisioned.find((a) => a.departmentId === 'dept_cse');
    const headEee = provisioned.find((a) => a.departmentId === 'dept_eee');
    const headEeeCtx = testEnv.authenticatedContext(headEee.uid, {
      email: 'head.eee.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_eee',
    });
    await assertFails(getDoc(doc(headEeeCtx.firestore(), 'leave_applications', appId)));
    await assertFails(
      headEeeCtx
        .storage()
        .ref(`leave_documents/${facUid}/${appId}/proof.pdf`)
        .getDownloadURL()
    );

    const headCseCtx = testEnv.authenticatedContext(headCse.uid, {
      email: 'head.cse.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_cse',
    });
    await assertSucceeds(
      headCseCtx
        .storage()
        .ref(`leave_documents/${facUid}/${appId}/proof.pdf`)
        .getDownloadURL()
    );
    const headCseDb = headCseCtx.firestore();
    await assertSucceeds(
      updateDoc(doc(headCseDb, 'leave_applications', appId), {
        status: 'forwarded',
        headUid: headCse.uid,
        headComment: 'Forwarded by CSE Head',
        headActionAt: new Date().toISOString(),
      })
    );

    // 6. Registrar Final Approval -> triggers onLeaveApplicationUpdate -> atomic balance deduction
    const registrar = provisioned.find((a) => a.role === 'registrar');
    const regDb = testEnv.authenticatedContext(registrar.uid, {
      email: 'registrar.lu@gmail.com',
      role: 'registrar',
    }).firestore();
    await assertSucceeds(
      updateDoc(doc(regDb, 'leave_applications', appId), {
        status: 'approved',
        registrarUid: registrar.uid,
        registrarComment: 'Approved by Registrar',
        registrarActionAt: new Date().toISOString(),
      })
    );

    // Wait for Functions Emulator onLeaveApplicationUpdate trigger to complete deduction
    const deductedApp = await waitFor(async () => {
      const s = await adminDb.collection('leave_applications').doc(appId).get();
      return s.exists && s.data().balanceDeducted === true ? s.data() : null;
    });
    assert.ok(deductedApp, 'Expected onLeaveApplicationUpdate to stamp balanceDeducted: true');

    const balAfter = await adminDb.collection('leave_balances').doc(balId).get();
    assert.strictEqual(balAfter.data().used, 3);

    // 7. Duplicate deduction protection: trigger another update on same approved doc -> used stays 3
    await adminDb.collection('leave_applications').doc(appId).update({
      updatedAt: new Date().toISOString(),
    });
    await new Promise((r) => setTimeout(r, 800));
    const balAfterRetry = await adminDb.collection('leave_balances').doc(balId).get();
    assert.strictEqual(balAfterRetry.data().used, 3);

    // 8. Admin transfers Faculty to dept_eee -> historical app stays dept_cse
    const transferRes = await callFunction('transferFacultyDepartment', adminToken, {
      targetUid: facUid,
      newDepartmentId: 'dept_eee',
      reason: 'Inter-department transfer E2E test',
    });
    assert.strictEqual(transferRes.status, 200, JSON.stringify(transferRes.json));
    const userAfterTransfer = await adminDb.collection('users').doc(facUid).get();
    assert.strictEqual(userAfterTransfer.data().departmentId, 'dept_eee');
    const oldAppSnap = await adminDb.collection('leave_applications').doc(appId).get();
    assert.strictEqual(oldAppSnap.data().departmentId, 'dept_cse');
  });
});
