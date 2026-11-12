/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  institutional_12_accounts_emulator_test.js
 *  Full Firebase Auth + Firestore + Storage Emulator Integration & Isolation Suite
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Covers:
 * 1. Idempotent provisioning & reconciliation of all 12 institutional accounts
 *    (1 Admin preserving existing UID, 1 Registrar, 10 Department Heads).
 * 2. Mismatch detection requiring explicit authorization before reconciliation.
 * 3. Blocking self-registration with any of the 12 reserved staff emails.
 * 4. Real Firebase Auth sign-in (valid, wrong password, unknown email,
 *    multi-device concurrent sessions & independent FCM token cleanup, refresh).
 * 5. Full 10x10 cross-department isolation matrix in Firestore & Storage Rules.
 * 6. Missing / mismatched custom claim denial in Firestore & Storage Rules.
 * 7. Registrar workflow isolation & Faculty department transfer history snapshot.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const assert = require('assert');
const admin = require('firebase-admin');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  collection,
  getDocs,
  query,
  where,
} = require('@firebase/firestore');
const {
  ref,
  uploadBytes,
  getBytes,
} = require('@firebase/storage');

process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';

const PROJECT_ID = 'leavexa';
const FIRESTORE_RULES_PATH = path.join(__dirname, '../../firestore.rules');
const STORAGE_RULES_PATH = path.join(__dirname, '../../storage.rules');

const {
  DEPARTMENT_HEAD_DEFINITIONS,
  INSTITUTIONAL_ACCOUNTS,
  provisionAccount,
  runProvisioning,
} = require('../../functions/scripts/provision_fixed_staff');

function authRestRequest(endpoint, body) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 9099,
        path: `/identitytoolkit.googleapis.com/v1/${endpoint}?key=fake-emulator-api-key`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(data || '{}') });
          } catch (_) {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function tokenRefreshRequest(refreshToken) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    });
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 9099,
        path: '/securetoken.googleapis.com/v1/token?key=fake-emulator-api-key',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(data || '{}') });
          } catch (_) {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function clearAuthEmulator() {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 9099,
        path: `/emulator/v1/projects/${PROJECT_ID}/accounts`,
        method: 'DELETE',
      },
      (res) => {
        res.on('data', () => {});
        res.on('end', resolve);
      }
    );
    req.on('error', reject);
    req.end();
  });
}

describe('LEAVEXA — 12 Institutional Accounts & 10-Department Isolation Emulator Suite', function () {
  this.timeout(45000);

  let testEnv;
  let adminApp;
  let adminAuth;
  let adminDb;

  // Ephemeral runtime-only emulator test passwords (never persisted or logged)
  const runtimePasswords = {};
  for (let i = 0; i < INSTITUTIONAL_ACCOUNTS.length; i++) {
    runtimePasswords[INSTITUTIONAL_ACCOUNTS[i].email] = `EmuTest!${100 + i}#Zx`;
  }

  before(async () => {
    if (!admin.apps.length) {
      adminApp = admin.initializeApp({ projectId: PROJECT_ID });
    } else {
      adminApp = admin.app();
    }
    adminAuth = adminApp.auth();
    adminDb = adminApp.firestore();

    const firestoreRules = fs.readFileSync(FIRESTORE_RULES_PATH, 'utf8');
    const storageRules = fs.readFileSync(STORAGE_RULES_PATH, 'utf8');

    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: firestoreRules,
        host: '127.0.0.1',
        port: 8088,
      },
      storage: {
        rules: storageRules,
        host: '127.0.0.1',
        port: 9199,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await clearAuthEmulator();
  });

  // ── 1. Institutional Provisioning, Admin UID Preservation & Reconciliation ─
  it('1. Provisions all 12 institutional accounts idempotently, preserves existing Admin UID, and blocks self-registration', async () => {
    // Pre-create Admin in Firebase Auth Emulator with a specific existing UID
    const preservedAdminUid = 'existing_prod_admin_uid_001';
    await adminAuth.createUser({
      uid: preservedAdminUid,
      email: 'admin.lu@gmail.com',
      password: runtimePasswords['admin.lu@gmail.com'],
      displayName: 'System Administrator',
      emailVerified: true,
    });

    const firstRun = await runProvisioning({
      auth: adminAuth,
      db: adminDb,
      passwordsByEmail: runtimePasswords,
    });

    assert.strictEqual(firstRun.length, 12);
    for (const res of firstRun) {
      assert.strictEqual(res.status, 'ACTIVE_AND_APPROVED', `Failed for ${res.email}: ${res.error}`);
      assert.ok(res.uid);
    }

    // Existing Admin UID MUST be preserved
    const adminResult = firstRun.find((r) => r.email === 'admin.lu@gmail.com');
    assert.strictEqual(adminResult.uid, preservedAdminUid);
    assert.strictEqual(adminResult.isNewAuth, false);

    // Repeat provisioning: MUST create zero duplicate Auth accounts and preserve all UIDs
    const secondRun = await runProvisioning({
      auth: adminAuth,
      db: adminDb,
      passwordsByEmail: runtimePasswords,
    });
    for (let i = 0; i < 12; i++) {
      assert.strictEqual(secondRun[i].uid, firstRun[i].uid);
      assert.strictEqual(secondRun[i].isNewAuth, false);
    }

    // Verify Auth listUsers has exactly 12 accounts (0 duplicates) & valid Custom Claims
    const authList = await adminAuth.listUsers(100);
    assert.strictEqual(authList.users.length, 12);

    // Verify Firestore profiles & zero plaintext password fields & none marked pending faculty
    const usersSnap = await adminDb.collection('users').get();
    assert.strictEqual(usersSnap.size, 12);
    for (const docSnap of usersSnap.docs) {
      const data = docSnap.data();
      assert.strictEqual(data.approvalStatus, 'approved');
      assert.strictEqual(data.isActive, true);
      assert.notStrictEqual(data.role, 'faculty');
      assert.strictEqual(data.password, undefined);
      assert.strictEqual(data.defaultPassword, undefined);

      const authRec = await adminAuth.getUser(docSnap.id);
      assert.strictEqual(authRec.customClaims.role, data.role);
      if (data.role === 'department_head') {
        assert.strictEqual(authRec.customClaims.departmentId, data.departmentId);
      }
    }

    // Self-registration attempt using any of the 12 reserved emails MUST be rejected
    for (const acc of INSTITUTIONAL_ACCOUNTS) {
      const rogueUid = `rogue_${acc.employeeId}`;
      const rogueDb = testEnv.authenticatedContext(rogueUid).firestore();
      const batch = writeBatch(rogueDb);
      batch.set(doc(rogueDb, 'employee_ids', `EMP-${acc.employeeId}`), { uid: rogueUid });
      batch.set(doc(rogueDb, 'users', rogueUid), {
        uid: rogueUid,
        fullName: 'Rogue SignUp',
        email: acc.email,
        employeeId: `EMP-${acc.employeeId}`,
        departmentId: 'dept_cse',
        role: 'faculty',
        approvalStatus: 'pending',
        isActive: false,
      });
      await assertFails(batch.commit());
    }
  });

  // ── 2. Account Mismatch Guard ──────────────────────────────────────────────
  it('2. Detects role/department mismatch without overwriting silently unless authorized', async () => {
    const eeeAcc = INSTITUTIONAL_ACCOUNTS.find((a) => a.email === 'head.eee.lu@gmail.com');
    const created = await adminAuth.createUser({
      email: eeeAcc.email,
      password: runtimePasswords[eeeAcc.email],
    });
    // Existing mismatched Firestore profile (assigned to wrong department dept_cse)
    await adminDb.collection('users').doc(created.uid).set({
      uid: created.uid,
      email: eeeAcc.email,
      role: 'department_head',
      departmentId: 'dept_cse',
      approvalStatus: 'approved',
      isActive: true,
    });

    const deniedRes = await provisionAccount(eeeAcc, {
      auth: adminAuth,
      db: adminDb,
      passwordsByEmail: runtimePasswords,
      authorizeReconciliation: false,
    });
    assert.strictEqual(deniedRes.status, 'MISMATCH_REQUIRES_AUTHORIZATION');
    assert.strictEqual(deniedRes.existingDepartmentId, 'dept_cse');
    assert.strictEqual(deniedRes.expectedDepartmentId, 'dept_eee');

    // Profile must remain unchanged when not authorized
    const afterDeniedSnap = await adminDb.collection('users').doc(created.uid).get();
    assert.strictEqual(afterDeniedSnap.data().departmentId, 'dept_cse');

    // Explicit authorization reconciles it cleanly
    const authRes = await provisionAccount(eeeAcc, {
      auth: adminAuth,
      db: adminDb,
      passwordsByEmail: runtimePasswords,
      authorizeReconciliation: true,
    });
    assert.strictEqual(authRes.status, 'ACTIVE_AND_APPROVED');
    const afterAuthSnap = await adminDb.collection('users').doc(created.uid).get();
    assert.strictEqual(afterAuthSnap.data().departmentId, 'dept_eee');
  });

  // ── 3. Common Auth Login, Failures, Multi-Device & Session Refresh ────────
  it('3. Authenticates institutional accounts, rejects bad credentials, supports concurrent multi-device sessions & token isolation', async () => {
    await runProvisioning({
      auth: adminAuth,
      db: adminDb,
      passwordsByEmail: runtimePasswords,
    });

    // Valid logins: Admin, Registrar, CSE Head
    for (const email of ['admin.lu@gmail.com', 'registrar.lu@gmail.com', 'head.cse.lu@gmail.com']) {
      const login = await authRestRequest('accounts:signInWithPassword', {
        email,
        password: runtimePasswords[email],
        returnSecureToken: true,
      });
      assert.strictEqual(login.status, 200, `Login failed for ${email}`);
      assert.ok(login.data.idToken);
      assert.ok(login.data.refreshToken);
    }

    // Wrong password rejected
    const wrongPass = await authRestRequest('accounts:signInWithPassword', {
      email: 'head.cse.lu@gmail.com',
      password: 'WrongPassword999!',
      returnSecureToken: true,
    });
    assert.notStrictEqual(wrongPass.status, 200);

    // Unknown email rejected
    const unknownEmail = await authRestRequest('accounts:signInWithPassword', {
      email: 'nonexistent.user@gmail.com',
      password: runtimePasswords['head.cse.lu@gmail.com'],
      returnSecureToken: true,
    });
    assert.notStrictEqual(unknownEmail.status, 200);

    // Concurrent Multi-Device Login (Device A & Device B sign into head.eee.lu@gmail.com)
    const devA = await authRestRequest('accounts:signInWithPassword', {
      email: 'head.eee.lu@gmail.com',
      password: runtimePasswords['head.eee.lu@gmail.com'],
      returnSecureToken: true,
    });
    const devB = await authRestRequest('accounts:signInWithPassword', {
      email: 'head.eee.lu@gmail.com',
      password: runtimePasswords['head.eee.lu@gmail.com'],
      returnSecureToken: true,
    });
    assert.strictEqual(devA.status, 200);
    assert.strictEqual(devB.status, 200);
    assert.strictEqual(devA.data.localId, devB.data.localId);

    const headEeeUid = devA.data.localId;
    const headEeeDb = testEnv.authenticatedContext(headEeeUid, {
      role: 'department_head',
      departmentId: 'dept_eee',
      approvalStatus: 'approved',
    }).firestore();

    // Each device manages its own independent fcm_tokens document
    await assertSucceeds(
      setDoc(doc(headEeeDb, `users/${headEeeUid}/fcm_tokens/device_a_hash`), {
        token: 'fcm_token_device_a',
        platform: 'android',
      })
    );
    await assertSucceeds(
      setDoc(doc(headEeeDb, `users/${headEeeUid}/fcm_tokens/device_b_hash`), {
        token: 'fcm_token_device_b',
        platform: 'android',
      })
    );

    // Logging out Device A deletes ONLY Device A token; Device B token & refresh remain active
    await assertSucceeds(
      deleteDoc(doc(headEeeDb, `users/${headEeeUid}/fcm_tokens/device_a_hash`))
    );
    const devBToken = await getDoc(doc(headEeeDb, `users/${headEeeUid}/fcm_tokens/device_b_hash`));
    assert.strictEqual(devBToken.exists(), true);

    const refreshB = await tokenRefreshRequest(devB.data.refreshToken);
    assert.strictEqual(refreshB.status, 200);
    assert.ok(refreshB.data.id_token);
  });

  // ── 4. Full 10x10 Department Isolation Matrix (Firestore + Storage) ────────
  it('4. Enforces strict 10-department isolation across Firestore applications, user queries, and Storage attachments', async () => {
    const provisioned = await runProvisioning({
      auth: adminAuth,
      db: adminDb,
      passwordsByEmail: runtimePasswords,
    });

    const headByDept = {};
    for (const acc of provisioned) {
      if (acc.role === 'department_head') {
        headByDept[acc.departmentId] = acc;
      }
    }

    // Seed 1 approved faculty, 1 pending leave application, and 1 PDF attachment for ALL 10 departments
    const samplePdf = Buffer.from('%PDF-1.4 department isolation evidence');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const dept of DEPARTMENT_HEAD_DEFINITIONS) {
        const facUid = `fac_${dept.departmentId}`;
        const appId = `app_${dept.departmentId}`;

        await setDoc(doc(db, 'users', facUid), {
          uid: facUid,
          fullName: `Faculty ${dept.code}`,
          email: `faculty.${dept.code.toLowerCase()}@leavexa.edu`,
          employeeId: `FAC-${dept.code}-01`,
          departmentId: dept.departmentId,
          departmentName: dept.departmentName,
          role: 'faculty',
          approvalStatus: 'approved',
          isActive: true,
        });

        await setDoc(doc(db, 'leave_applications', appId), {
          id: appId,
          applicantUid: facUid,
          applicantName: `Faculty ${dept.code}`,
          departmentId: dept.departmentId,
          departmentName: dept.departmentName,
          leaveTypeId: 'casual',
          leaveTypeName: 'Casual Leave',
          totalDays: 2,
          status: 'pending',
        });

        await uploadBytes(
          ref(ctx.storage(), `leave_documents/${facUid}/${appId}/attachment.pdf`),
          samplePdf,
          { contentType: 'application/pdf' }
        );
      }
    });

    // Exhaustive 10 x 10 cross-department isolation matrix
    for (const viewerDept of DEPARTMENT_HEAD_DEFINITIONS) {
      const viewerHead = headByDept[viewerDept.departmentId];
      const viewerCtx = testEnv.authenticatedContext(viewerHead.uid, {
        role: 'department_head',
        departmentId: viewerDept.departmentId,
        approvalStatus: 'approved',
      });
      const vDb = viewerCtx.firestore();
      const vStorage = viewerCtx.storage();

      for (const targetDept of DEPARTMENT_HEAD_DEFINITIONS) {
        const targetFacUid = `fac_${targetDept.departmentId}`;
        const targetAppId = `app_${targetDept.departmentId}`;
        const appRef = doc(vDb, 'leave_applications', targetAppId);
        const fileRef = ref(vStorage, `leave_documents/${targetFacUid}/${targetAppId}/attachment.pdf`);

        if (viewerDept.departmentId === targetDept.departmentId) {
          // Own department MUST succeed
          await assertSucceeds(getDoc(appRef));
          await assertSucceeds(getBytes(fileRef));
          // Department-scoped Firestore query succeeds
          await assertSucceeds(
            getDocs(
              query(
                collection(vDb, 'leave_applications'),
                where('departmentId', '==', viewerDept.departmentId)
              )
            )
          );
        } else {
          // Cross-department MUST fail (Firestore read, Firestore update, Storage read)
          await assertFails(getDoc(appRef));
          await assertFails(
            updateDoc(appRef, {
              status: 'forwarded',
              headUid: viewerHead.uid,
              headComment: 'Cross-dept attempt',
              headActionAt: new Date().toISOString(),
            })
          );
          await assertFails(getBytes(fileRef));
        }
      }

      // Permitted own-department Head review action succeeds (checked for each of the 10 Heads)
      await assertSucceeds(
        updateDoc(doc(vDb, 'leave_applications', `app_${viewerDept.departmentId}`), {
          status: 'forwarded',
          headUid: viewerHead.uid,
          headComment: `Endorsed by ${viewerDept.code} Head`,
          headActionAt: new Date().toISOString(),
        })
      );
    }
  });

  // ── 5. Missing/Mismatched Claims, Spoofing, Registrar & Historical Transfer ─
  it('5. Denies missing/mismatched department claims, blocks client spoofing, isolates Registrar, and preserves historical transfer snapshots', async () => {
    const provisioned = await runProvisioning({
      auth: adminAuth,
      db: adminDb,
      passwordsByEmail: runtimePasswords,
    });
    const cseHead = provisioned.find((a) => a.departmentId === 'dept_cse');
    const registrar = provisioned.find((a) => a.role === 'registrar');

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', 'fac_transfer_1'), {
        uid: 'fac_transfer_1',
        fullName: 'Dr. Transfer Faculty',
        employeeId: 'FAC-TRF-01',
        role: 'faculty',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        approvalStatus: 'approved',
        isActive: true,
      });
      await setDoc(doc(db, 'leave_applications', 'app_pending_cse'), {
        id: 'app_pending_cse',
        applicantUid: 'fac_transfer_1',
        departmentId: 'dept_cse',
        totalDays: 2,
        status: 'pending',
      });
      await setDoc(doc(db, 'leave_applications', 'app_fwd_cse'), {
        id: 'app_fwd_cse',
        applicantUid: 'fac_transfer_1',
        departmentId: 'dept_cse',
        totalDays: 2,
        status: 'forwarded',
        headUid: cseHead.uid,
        headComment: 'Endorsed',
        headActionAt: '2026-11-12T00:00:00Z',
      });
      await uploadBytes(
        ref(ctx.storage(), 'leave_documents/fac_transfer_1/app_pending_cse/doc.pdf'),
        Buffer.from('%PDF-1.4 transfer doc'),
        { contentType: 'application/pdf' }
      );
    });

    // (a) Head token missing departmentId claim -> DENIED in Firestore & Storage
    const missingClaimCtx = testEnv.authenticatedContext(cseHead.uid, {
      role: 'department_head',
    });
    await assertFails(getDoc(doc(missingClaimCtx.firestore(), 'leave_applications', 'app_pending_cse')));
    await assertFails(
      getBytes(ref(missingClaimCtx.storage(), 'leave_documents/fac_transfer_1/app_pending_cse/doc.pdf'))
    );

    // (b) Head token mismatched with Firestore profile (claim dept_eee vs Firestore dept_cse) -> DENIED everywhere
    const mismatchedClaimCtx = testEnv.authenticatedContext(cseHead.uid, {
      role: 'department_head',
      departmentId: 'dept_eee',
    });
    await assertFails(getDoc(doc(mismatchedClaimCtx.firestore(), 'leave_applications', 'app_pending_cse')));
    await assertFails(
      getBytes(ref(mismatchedClaimCtx.storage(), 'leave_documents/fac_transfer_1/app_pending_cse/doc.pdf'))
    );

    // (c) Faculty cannot modify own role/departmentId or submit leave for another department
    const facCseDb = testEnv.authenticatedContext('fac_transfer_1', {
      role: 'faculty',
      departmentId: 'dept_cse',
    }).firestore();
    await assertFails(updateDoc(doc(facCseDb, 'users', 'fac_transfer_1'), { departmentId: 'dept_eee' }));
    await assertFails(updateDoc(doc(facCseDb, 'users', 'fac_transfer_1'), { role: 'admin' }));
    await assertFails(
      setDoc(doc(facCseDb, 'leave_applications', 'spoof_dept_app'), {
        applicantUid: 'fac_transfer_1',
        departmentId: 'dept_eee', // Spoofed!
        status: 'pending',
      })
    );

    // (d) Head cannot alter applicantUid or departmentId
    const validCseHeadDb = testEnv.authenticatedContext(cseHead.uid, {
      role: 'department_head',
      departmentId: 'dept_cse',
    }).firestore();
    await assertFails(
      updateDoc(doc(validCseHeadDb, 'leave_applications', 'app_pending_cse'), {
        status: 'forwarded',
        headUid: cseHead.uid,
        headComment: 'Spoofing',
        headActionAt: new Date().toISOString(),
        departmentId: 'dept_eee',
      })
    );

    // (e) Registrar CANNOT read unforwarded pending app, CAN finalize forwarded app, CANNOT assume admin privileges
    const regDb = testEnv.authenticatedContext(registrar.uid, { role: 'registrar' }).firestore();
    await assertFails(getDoc(doc(regDb, 'leave_applications', 'app_pending_cse')));
    await assertSucceeds(getDoc(doc(regDb, 'leave_applications', 'app_fwd_cse')));
    await assertSucceeds(
      updateDoc(doc(regDb, 'leave_applications', 'app_fwd_cse'), {
        status: 'approved',
        registrarUid: registrar.uid,
        registrarComment: 'Approved by Registrar',
        registrarActionAt: new Date().toISOString(),
      })
    );
    await assertFails(setDoc(doc(regDb, 'audit_logs', 'forged'), { action: 'FORGE' }));
    await assertFails(updateDoc(doc(regDb, 'users', registrar.uid), { role: 'admin' }));

    // (f) Historical department snapshot after Admin transfers faculty to dept_eee
    await adminDb.collection('users').doc('fac_transfer_1').update({
      departmentId: 'dept_eee',
      departmentName: 'Electrical & Electronic Engineering',
    });
    // Old CSE application keeps dept_cse and remains readable by CSE Head (not EEE Head)
    const oldSnap = await adminDb.collection('leave_applications').doc('app_pending_cse').get();
    assert.strictEqual(oldSnap.data().departmentId, 'dept_cse');
    await assertSucceeds(getDoc(doc(validCseHeadDb, 'leave_applications', 'app_pending_cse')));

    const eeeHead = provisioned.find((a) => a.departmentId === 'dept_eee');
    const eeeHeadDb = testEnv.authenticatedContext(eeeHead.uid, {
      role: 'department_head',
      departmentId: 'dept_eee',
    }).firestore();
    await assertFails(getDoc(doc(eeeHeadDb, 'leave_applications', 'app_pending_cse')));

    // New leave application post-transfer uses dept_eee
    const facEeeDb = testEnv.authenticatedContext('fac_transfer_1', {
      role: 'faculty',
      departmentId: 'dept_eee',
    }).firestore();
    await assertSucceeds(
      setDoc(doc(facEeeDb, 'leave_applications', 'app_post_transfer_eee'), {
        applicantUid: 'fac_transfer_1',
        departmentId: 'dept_eee',
        status: 'pending',
        headUid: null,
        headComment: null,
        headActionAt: null,
        registrarUid: null,
        registrarComment: null,
        registrarActionAt: null,
      })
    );
    await assertSucceeds(getDoc(doc(eeeHeadDb, 'leave_applications', 'app_post_transfer_eee')));
    await assertFails(getDoc(doc(validCseHeadDb, 'leave_applications', 'app_post_transfer_eee')));
  });

  // ── 6. Strict Institutional Email Allowlist Enforcement in Rules ───────────
  it('6. Denies unknown Gmail even with forged admin/registrar/head claims in Firestore & Storage rules', async () => {
    await adminDb.collection('users').doc('fac_target').set({
      uid: 'fac_target',
      email: 'faculty@gmail.com',
      role: 'faculty',
      departmentId: 'dept_cse',
      approvalStatus: 'approved',
      isActive: true,
    });
    await adminDb.collection('leave_applications').doc('app_target').set({
      applicantUid: 'fac_target',
      departmentId: 'dept_cse',
      status: 'forwarded',
    });

    const rogueAdminCtx = testEnv.authenticatedContext('rogue_admin', {
      email: 'rogue.admin@gmail.com',
      role: 'admin',
    });
    await assertFails(getDoc(doc(rogueAdminCtx.firestore(), 'users', 'fac_target')));
    await assertFails(
      rogueAdminCtx.storage().ref('leave_attachments/fac_target/app_target/doc.pdf').getDownloadURL()
    );

    const rogueRegistrarCtx = testEnv.authenticatedContext('rogue_registrar', {
      email: 'rogue.registrar@gmail.com',
      role: 'registrar',
    });
    await assertFails(
      getDoc(doc(rogueRegistrarCtx.firestore(), 'leave_applications', 'app_target'))
    );

    const rogueHeadCtx = testEnv.authenticatedContext('rogue_head', {
      email: 'rogue.head@gmail.com',
      role: 'department_head',
      departmentId: 'dept_cse',
    });
    await assertFails(
      getDoc(doc(rogueHeadCtx.firestore(), 'leave_applications', 'app_target'))
    );
  });
});
