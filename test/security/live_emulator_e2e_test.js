// ─────────────────────────────────────────────────────────────────────────────
//  live_emulator_e2e_test.js  –  Phase 12.1 Real Emulator Integration Suite
// ─────────────────────────────────────────────────────────────────────────────

const assert = require('assert');
const path = require('path');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const admin = require(path.join(__dirname, '../../functions/node_modules/firebase-admin'));

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'leavexa';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();
const auth = admin.auth();

const FUNCTIONS_ORIGIN = `http://127.0.0.1:5001/${PROJECT_ID}/us-central1`;

async function callFunction(name, data, token = null) {
  const url = `${FUNCTIONS_ORIGIN}/${name}`;
  const headers = { 'Content-Type': 'application/json' };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data }),
  });

  const body = await res.json();
  return { status: res.status, body };
}

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function runLiveE2ETests() {
  console.log('🚀 Starting Live Emulator End-to-End Integration Suite...\n');

  // ── 1. Create a candidate user in Auth Emulator ───────────────────────────
  console.log('[Step 1: Auth Emulator User Creation]');
  const adminEmail = `root_admin_${Date.now()}@leavexa.edu`;
  const adminUser = await auth.createUser({
    email: adminEmail,
    password: 'SuperAdminPass123!',
    displayName: 'Root Administrator',
  });
  console.log(`  ✓ Created user in Auth Emulator: ${adminUser.uid} (${adminEmail})`);

  // Create custom token and exchange for ID token if needed, or use Admin SDK
  const customToken = await auth.createCustomToken(adminUser.uid);
  // To get an ID token from Auth Emulator:
  const tokenRes = await fetch(
    `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    }
  );
  const tokenData = await tokenRes.json();
  const idToken = tokenData.idToken;
  assert(idToken, 'Failed to obtain ID token from Auth Emulator');
  console.log('  ✓ Successfully exchanged for ID token with Auth Emulator');

  // ── 2. Call callable function: provisionInitialAdmin ─────────────────────
  console.log('\n[Step 2: Callable Cloud Function provisionInitialAdmin]');
  const provRes = await callFunction(
    'provisionInitialAdmin',
    { fullName: 'Primary Root Admin', employeeId: 'EMP-ADM-99' },
    idToken
  );
  console.log('  Response:', provRes.body);
  assert.strictEqual(provRes.status, 200, `Expected 200, got ${provRes.status}`);
  assert.strictEqual(provRes.body.result.success, true);
  console.log('  ✓ provisionInitialAdmin succeeded');

  // Verify Custom Claims in Auth Emulator
  const refreshedUser = await auth.getUser(adminUser.uid);
  console.log('  Assigned Custom Claims:', refreshedUser.customClaims);
  assert.strictEqual(refreshedUser.customClaims.role, 'admin');
  assert.strictEqual(refreshedUser.customClaims.approvalStatus, 'approved');
  console.log('  ✓ Verified Firebase Auth Custom Claims { role: "admin", approvalStatus: "approved" }');

  // Verify system_config/bootstrap lock document in Firestore Emulator
  const bootstrapSnap = await db.collection('system_config').doc('bootstrap').get();
  assert(bootstrapSnap.exists, 'system_config/bootstrap document was not created');
  assert.strictEqual(bootstrapSnap.data().isBootstrapped, true);
  console.log('  ✓ Verified system_config/bootstrap mutex locked in Firestore Emulator');

  // ── 3. Test One-Time Bootstrap Security: Second call must be rejected ─────
  console.log('\n[Step 3: Initial Admin Security - Second Bootstrap Rejection]');
  const secondUser = await auth.createUser({
    email: `rogue_${Date.now()}@hacker.io`,
    password: 'Password123!',
  });
  const rogueCustomToken = await auth.createCustomToken(secondUser.uid);
  const rogueTokenRes = await fetch(
    `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: rogueCustomToken, returnSecureToken: true }),
    }
  );
  const rogueTokenData = await rogueTokenRes.json();
  const rogueIdToken = rogueTokenData.idToken;

  const secondProv = await callFunction('provisionInitialAdmin', {}, rogueIdToken);
  console.log('  Second bootstrap response status:', secondProv.status, secondProv.body);
  assert(
    secondProv.status >= 400 || secondProv.body.error,
    'Second bootstrap MUST fail with error'
  );
  console.log('  ✓ Second bootstrap request rejected successfully (Bootstrap can happen only once)');

  // ── 4. Callable Function: checkEmployeeId ─────────────────────────────────
  console.log('\n[Step 4: Callable Cloud Function checkEmployeeId]');
  const checkTaken = await callFunction('checkEmployeeId', { employeeId: 'EMP-ADM-99' }, idToken);
  assert.strictEqual(checkTaken.body.result.isAvailable, false);
  console.log('  ✓ Correctly reported EMP-ADM-99 is already registered');

  const checkFree = await callFunction('checkEmployeeId', { employeeId: 'EMP-AVAILABLE-123' }, idToken);
  assert.strictEqual(checkFree.body.result.isAvailable, true);
  console.log('  ✓ Correctly reported EMP-AVAILABLE-123 is available with limitation notice');

  // ── 5. Full Workflow & Firestore Trigger onLeaveApplicationUpdate ─────────
  console.log('\n[Step 5: Full Workflow & onLeaveApplicationUpdate Trigger]');
  // Setup test faculty & initial balance in Firestore Emulator
  const facultyUid = `faculty_${Date.now()}`;
  const currentYear = new Date().getFullYear();
  const balanceDocId = `${facultyUid}_annual_${currentYear}`;

  await db.collection('leave_balances').doc(balanceDocId).set({
    id: balanceDocId,
    userUid: facultyUid,
    leaveTypeId: 'annual',
    leaveTypeName: 'Annual Leave',
    totalAllotted: 20,
    used: 2, // 18 days remaining
    year: currentYear,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`  ✓ Seeded initial leave balance: 20 total, 2 used (18 remaining)`);

  const appId = `leave_app_${Date.now()}`;
  const appRef = db.collection('leave_applications').doc(appId);

  // Faculty applies (status: pending)
  await appRef.set({
    id: appId,
    applicantUid: facultyUid,
    applicantName: 'Prof. Test Faculty',
    applicantEmployeeId: 'EMP-FAC-01',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science',
    leaveTypeId: 'annual',
    leaveTypeName: 'Annual Leave',
    startDate: new Date(),
    endDate: new Date(Date.now() + 5 * 86400000),
    totalDays: 5,
    reason: 'Academic Conference',
    status: 'pending',
    appliedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('  ✓ Step 5.1: Faculty submitted leave application (status: pending)');

  // Department Head forwards (status: forwarded)
  await appRef.update({
    status: 'forwarded',
    headUid: 'dept_head_101',
    headComment: 'Strongly recommended by Head',
    headActionAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('  ✓ Step 5.2: Department Head forwarded leave (status: forwarded)');

  // Wait for background trigger to process Head Forward
  await sleep(1500);

  const auditForward = await db.collection('audit_logs')
    .where('relatedApplicationId', '==', appId)
    .where('action', '==', 'HEAD_FORWARD_LEAVE')
    .get();
  assert(!auditForward.empty, 'HEAD_FORWARD_LEAVE audit log was not created by trigger');
  console.log('  ✓ Verified: onLeaveApplicationUpdate created HEAD_FORWARD_LEAVE audit log');

  // Registrar approves (status: approved)
  await appRef.update({
    status: 'approved',
    registrarUid: 'registrar_999',
    registrarComment: 'Final approval sanctioned by Registrar',
    registrarActionAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('  ✓ Step 5.3: Registrar approved leave application (status: approved)');

  // Wait for background trigger to execute atomic leave balance deduction
  console.log('  Waiting for Cloud Functions trigger to execute deduction...');
  let deductionCompleted = false;
  for (let i = 0; i < 15; i++) {
    await sleep(1000);
    const updatedApp = await appRef.get();
    if (updatedApp.data().balanceDeducted === true) {
      deductionCompleted = true;
      break;
    }
  }

  assert(deductionCompleted, 'balanceDeducted flag was not stamped by trigger within timeout');
  console.log('  ✓ Verified: Application document stamped with balanceDeducted: true');

  // Verify that balance was atomically deducted from 2 -> 7
  const updatedBalance = await db.collection('leave_balances').doc(balanceDocId).get();
  const newUsed = updatedBalance.data().used;
  console.log(`  Updated balance used: ${newUsed} (expected 7)`);
  assert.strictEqual(newUsed, 7, `Expected used days to be 7, got ${newUsed}`);
  console.log('  ✓ Verified: Balance used atomically incremented by exactly 5 days (2 + 5 = 7)');

  // Verify LEAVE_BALANCE_DEDUCTION audit record
  const auditDeduction = await db.collection('audit_logs')
    .where('relatedApplicationId', '==', appId)
    .where('action', '==', 'LEAVE_BALANCE_DEDUCTION')
    .get();
  assert(!auditDeduction.empty, 'LEAVE_BALANCE_DEDUCTION audit log was not found');
  console.log('  ✓ Verified: LEAVE_BALANCE_DEDUCTION audit record created in audit_logs');

  // ── 6. Idempotency & Safe Retry Check on Live Trigger ─────────────────────
  console.log('\n[Step 6: Idempotency & Duplicate Deduction Prevention]');
  // Simulate duplicate update or retry event on approved document
  await appRef.update({
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await sleep(1500);

  // Balance used MUST STILL BE 7 (NOT 12)
  const balanceAfterRetry = await db.collection('leave_balances').doc(balanceDocId).get();
  assert.strictEqual(balanceAfterRetry.data().used, 7, 'Balance was erroneously deducted twice!');
  console.log('  ✓ Verified: Trigger retry / duplicate update did NOT duplicate deduction (used is still 7)');

  console.log('\n🎉 ALL LIVE EMULATOR INTEGRATION TESTS PASSED CLEANLY!\n');
}

runLiveE2ETests().catch((err) => {
  console.error('\n❌ Live E2E Test Failed:\n', err);
  process.exit(1);
});
