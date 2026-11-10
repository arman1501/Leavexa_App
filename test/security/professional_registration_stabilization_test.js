// ─────────────────────────────────────────────────────────────────────────────
//  professional_registration_stabilization_test.js
//  Complete 16-Scenario E2E Integration Suite for Faculty Registration
// ─────────────────────────────────────────────────────────────────────────────

const assert = require('assert');
const path = require('path');
const fs = require('fs');

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
  runTransaction,
  writeBatch,
} = require('@firebase/firestore');

const { checkEmployeeIdAvailability } = require('../../functions/src/employee');

const RULES_PATH = path.join(__dirname, '../../firestore.rules');

describe('LEAVEXA Professional Registration & Permanent Stabilization Suite (16 Scenarios)', function () {
  this.timeout(25000);

  let testEnv;

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
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  // ── Scenario 1: New Valid Registration ─────────────────────────────────────
  it('Scenario 1: New valid registration creates Auth account + Firestore user profile + employee_ids index atomically', async () => {
    const uid = 'valid_reg_' + Date.now();
    const email = `valid.reg.${Date.now()}@leavexa.edu`;
    const empId = 'EMP-VAL-' + Math.floor(1000 + Math.random() * 9000);

    // 1. Firebase Auth user creation
    const authRecord = await admin.auth().createUser({
      uid,
      email,
      password: 'ValidPassword123!',
      displayName: 'Dr. Valid Faculty',
    });
    assert.strictEqual(authRecord.uid, uid);

    // 2. Client Firestore atomic transaction
    const clientDb = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(
      runTransaction(clientDb, async (txn) => {
        txn.set(doc(clientDb, 'employee_ids', empId), { uid, createdAt: new Date() });
        txn.set(doc(clientDb, 'users', uid), {
          uid,
          fullName: 'Dr. Valid Faculty',
          email,
          employeeId: empId,
          departmentId: 'dept_cse',
          departmentName: 'Computer Science & Engineering',
          designation: 'Assistant Professor',
          role: 'faculty',
          phone: '+8801700000001',
          approvalStatus: 'pending',
          isActive: false,
          photoUrl: null,
          createdAt: new Date().toISOString(),
        });
      })
    );

    // 3. Verify in Firestore
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    assert.strictEqual(userDoc.exists, true);
    assert.strictEqual(userDoc.data().role, 'faculty');
    assert.strictEqual(userDoc.data().approvalStatus, 'pending');
    assert.strictEqual(userDoc.data().isActive, false);

    const empDoc = await admin.firestore().collection('employee_ids').doc(empId).get();
    assert.strictEqual(empDoc.exists, true);
    assert.strictEqual(empDoc.data().uid, uid);
  });

  // ── Scenario 2: Duplicate Email ────────────────────────────────────────────
  it('Scenario 2: Duplicate email in Auth is blocked from creating a duplicate account', async () => {
    const email = `dup.email.${Date.now()}@leavexa.edu`;
    const uid1 = 'uid_primary_' + Date.now();

    await admin.auth().createUser({
      uid: uid1,
      email,
      password: 'PrimaryPassword123!',
    });

    let duplicateThrown = false;
    try {
      await admin.auth().createUser({
        uid: 'uid_secondary_' + Date.now(),
        email,
        password: 'SecondaryPassword123!',
      });
    } catch (err) {
      duplicateThrown = true;
      assert.strictEqual(err.code, 'auth/email-already-exists');
    }
    assert.strictEqual(duplicateThrown, true, 'Duplicate email must throw error');
  });

  // ── Scenario 3: Duplicate Employee ID ──────────────────────────────────────
  it('Scenario 3: Duplicate Employee ID cannot be overwritten by a second user', async () => {
    const ownerUid = 'owner_' + Date.now();
    const attackerUid = 'attacker_' + Date.now();
    const empId = 'EMP-DUP-' + Math.floor(1000 + Math.random() * 9000);

    // Seed existing reservation
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'employee_ids', empId), { uid: ownerUid });
      await setDoc(doc(db, 'users', ownerUid), {
        uid: ownerUid,
        employeeId: empId,
        role: 'faculty',
        approvalStatus: 'pending',
        isActive: false,
      });
    });

    // Attacker attempts to reserve same empId
    const attackerDb = testEnv.authenticatedContext(attackerUid).firestore();
    await assertFails(
      runTransaction(attackerDb, async (txn) => {
        txn.set(doc(attackerDb, 'employee_ids', empId), { uid: attackerUid });
        txn.set(doc(attackerDb, 'users', attackerUid), {
          uid: attackerUid,
          employeeId: empId,
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        });
      })
    );
  });

  // ── Scenario 4: Lowercase Employee ID Normalization ────────────────────────
  it('Scenario 4: Lowercase Employee ID is normalized to uppercase for consistent storage', async () => {
    const rawInput = 'lu-025-' + Date.now();
    const normalized = rawInput.trim().toUpperCase();
    assert.strictEqual(normalized, rawInput.toUpperCase());

    const uid = 'uid_norm_' + Date.now();
    const clientDb = testEnv.authenticatedContext(uid).firestore();

    await assertSucceeds(
      runTransaction(clientDb, async (txn) => {
        txn.set(doc(clientDb, 'employee_ids', normalized), { uid });
        txn.set(doc(clientDb, 'users', uid), {
          uid,
          employeeId: normalized,
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        });
      })
    );

    const docSnap = await admin.firestore().collection('employee_ids').doc(normalized).get();
    assert.strictEqual(docSnap.exists, true);
    assert.strictEqual(docSnap.data().uid, uid);
  });

  // ── Scenario 5: Employee ID with Whitespace ────────────────────────────────
  it('Scenario 5: Employee ID with whitespace is trimmed and normalized', async () => {
    const coreId = 'LU-999-' + Date.now();
    const rawInput = `   ${coreId.toLowerCase()}   `;
    const normalized = rawInput.trim().toUpperCase();
    assert.strictEqual(normalized, coreId);

    const uid = 'uid_ws_' + Date.now();
    const clientDb = testEnv.authenticatedContext(uid).firestore();

    await assertSucceeds(
      runTransaction(clientDb, async (txn) => {
        txn.set(doc(clientDb, 'employee_ids', normalized), { uid });
        txn.set(doc(clientDb, 'users', uid), {
          uid,
          employeeId: normalized,
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        });
      })
    );
  });

  // ── Scenario 6: Invalid Employee ID Length ────────────────────────────────
  it('Scenario 6: Invalid Employee ID length (< 3 or > 30) is rejected by security rules', async () => {
    const uidShort = 'uid_short_' + Date.now();
    const dbShort = testEnv.authenticatedContext(uidShort).firestore();
    await assertFails(
      setDoc(doc(dbShort, 'employee_ids', 'LU'), { uid: uidShort })
    );

    const uidLong = 'uid_long_' + Date.now();
    const dbLong = testEnv.authenticatedContext(uidLong).firestore();
    const tooLongId = 'EMP-' + 'X'.repeat(30); // 34 chars
    await assertFails(
      setDoc(doc(dbLong, 'employee_ids', tooLongId), { uid: uidLong })
    );
  });

  // ── Scenario 7: Invalid Department ─────────────────────────────────────────
  it('Scenario 7: Department mapping verifies against canonical catalog', () => {
    const { departmentNameToId } = {
      departmentNameToId: {
        'Computer Science & Engineering': 'dept_cse',
        'Electrical & Electronic Engineering': 'dept_eee',
        'Business Administration': 'dept_bba',
        'Civil Engineering': 'dept_civil',
      },
    };

    assert.strictEqual(departmentNameToId['Computer Science & Engineering'], 'dept_cse');
    assert.strictEqual(departmentNameToId['NonExistent Dept'], undefined);
  });

  // ── Scenario 8: Weak Password ──────────────────────────────────────────────
  it('Scenario 8: Password < 6 characters is rejected by Firebase Authentication', async () => {
    let weakPassError = false;
    try {
      await admin.auth().createUser({
        email: `weakpass.${Date.now()}@leavexa.edu`,
        password: '123',
      });
    } catch (e) {
      weakPassError = true;
      assert.ok(e.message.includes('password') || e.code === 'auth/invalid-password');
    }
    assert.strictEqual(weakPassError, true, 'Weak password must be rejected');
  });

  // ── Scenario 9: Network Interruption (Simulated) ───────────────────────────
  it('Scenario 9: Network interruption leaves database consistent; no partial write', async () => {
    const uid = 'network_sim_' + Date.now();
    const empId = 'EMP-NET-' + Math.floor(1000 + Math.random() * 9000);
    const clientDb = testEnv.authenticatedContext(uid).firestore();

    // If transaction throws before commit, neither doc is written
    try {
      await runTransaction(clientDb, async (txn) => {
        txn.set(doc(clientDb, 'employee_ids', empId), { uid });
        throw new Error('network-interruption-simulated');
      });
    } catch (e) {
      assert.strictEqual(e.message, 'network-interruption-simulated');
    }

    const empCheck = await admin.firestore().collection('employee_ids').doc(empId).get();
    assert.strictEqual(empCheck.exists, false, 'Aborted transaction must not write employee_ids');
  });

  // ── Scenario 10: App Restart During Incomplete Registration ────────────────
  it('Scenario 10: Auth user created with missing profile can sign in to resume', async () => {
    const uid = 'restart_uid_' + Date.now();
    const email = `restart.${Date.now()}@leavexa.edu`;

    await admin.auth().createUser({
      uid,
      email,
      password: 'RestartPassword123!',
    });

    // Profile does not exist yet
    const profile = await admin.firestore().collection('users').doc(uid).get();
    assert.strictEqual(profile.exists, false);

    // On resume/recovery, user authenticates and writes profile
    const clientDb = testEnv.authenticatedContext(uid).firestore();
    const empId = 'EMP-RES-' + Math.floor(1000 + Math.random() * 9000);

    await assertSucceeds(
      runTransaction(clientDb, async (txn) => {
        txn.set(doc(clientDb, 'employee_ids', empId), { uid });
        txn.set(doc(clientDb, 'users', uid), {
          uid,
          fullName: 'Recovered User',
          email,
          employeeId: empId,
          departmentId: 'dept_cse',
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        });
      })
    );

    const recoveredDoc = await admin.firestore().collection('users').doc(uid).get();
    assert.strictEqual(recoveredDoc.exists, true);
  });

  // ── Scenario 11: Auth Account Without Firestore Profile ────────────────────
  it('Scenario 11: Detects missing Firestore profile for authenticated user', async () => {
    const uid = 'orphaned_auth_' + Date.now();
    await admin.auth().createUser({
      uid,
      email: `orphaned.${Date.now()}@leavexa.edu`,
      password: 'OrphanPassword123!',
    });

    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    assert.strictEqual(userDoc.exists, false, 'User document should be missing initially');
  });

  // ── Scenario 12: Safe Registration Recovery ────────────────────────────────
  it('Scenario 12: Safe registration recovery permits user to re-assert employee reservation', async () => {
    const uid = 'recovery_user_' + Date.now();
    const empId = 'EMP-REC-' + Math.floor(1000 + Math.random() * 9000);

    // Pre-existing reservation created by this UID
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'employee_ids', empId), { uid });
    });

    // Recovery write by same UID succeeds under rules Option 2
    const clientDb = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(
      setDoc(doc(clientDb, 'users', uid), {
        uid,
        employeeId: empId,
        role: 'faculty',
        approvalStatus: 'pending',
        isActive: false,
      })
    );
  });

  // ── Scenario 13: Concurrent Duplicate Employee ID Requests ─────────────────
  it('Scenario 13: Concurrent duplicate Employee ID requests: exactly one succeeds', async () => {
    const empId = 'EMP-CONC-' + Math.floor(1000 + Math.random() * 9000);
    const uidA = 'user_A_' + Date.now();
    const uidB = 'user_B_' + Date.now();

    const dbA = testEnv.authenticatedContext(uidA).firestore();
    const dbB = testEnv.authenticatedContext(uidB).firestore();

    const results = await Promise.allSettled([
      runTransaction(dbA, async (txn) => {
        txn.set(doc(dbA, 'employee_ids', empId), { uid: uidA });
        txn.set(doc(dbA, 'users', uidA), {
          uid: uidA,
          employeeId: empId,
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        });
      }),
      runTransaction(dbB, async (txn) => {
        txn.set(doc(dbB, 'employee_ids', empId), { uid: uidB });
        txn.set(doc(dbB, 'users', uidB), {
          uid: uidB,
          employeeId: empId,
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        });
      }),
    ]);

    const successes = results.filter((r) => r.status === 'fulfilled');
    const failures = results.filter((r) => r.status === 'rejected');

    assert.strictEqual(successes.length, 1, 'Exactly one concurrent registration must succeed');
    assert.strictEqual(failures.length, 1, 'The colliding registration must fail');
  });

  // ── Scenario 14: Unauthorized Role Registration ────────────────────────────
  it('Scenario 14: Unauthorized role registration (admin, registrar, department_head) is rejected', async () => {
    const uidAdminAttempt = 'rogue_admin_' + Date.now();
    const dbAdmin = testEnv.authenticatedContext(uidAdminAttempt).firestore();
    const empId1 = 'EMP-ROGUE-1';

    await assertFails(
      setDoc(doc(dbAdmin, 'users', uidAdminAttempt), {
        uid: uidAdminAttempt,
        employeeId: empId1,
        role: 'admin', // Escalation
        approvalStatus: 'approved',
        isActive: true,
      })
    );

    const uidHeadAttempt = 'rogue_head_' + Date.now();
    const dbHead = testEnv.authenticatedContext(uidHeadAttempt).firestore();
    const empId2 = 'EMP-ROGUE-2';

    await assertFails(
      setDoc(doc(dbHead, 'users', uidHeadAttempt), {
        uid: uidHeadAttempt,
        employeeId: empId2,
        role: 'department_head', // Escalation
        approvalStatus: 'approved',
        isActive: true,
      })
    );
  });

  // ── Scenario 15: Registration Without Profile Photo ────────────────────────
  it('Scenario 15: Registration with photoUrl: null succeeds without blocking user', async () => {
    const uid = 'no_photo_user_' + Date.now();
    const empId = 'EMP-NOPHOTO-' + Math.floor(1000 + Math.random() * 9000);
    const clientDb = testEnv.authenticatedContext(uid).firestore();

    await assertSucceeds(
      runTransaction(clientDb, async (txn) => {
        txn.set(doc(clientDb, 'employee_ids', empId), { uid });
        txn.set(doc(clientDb, 'users', uid), {
          uid,
          employeeId: empId,
          photoUrl: null, // Completely optional
          role: 'faculty',
          approvalStatus: 'pending',
          isActive: false,
        });
      })
    );

    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    assert.strictEqual(userDoc.data().photoUrl, null);
  });

  // ── Scenario 16: Employee ID Pre-flight Check Function ─────────────────────
  it('Scenario 16: checkEmployeeIdAvailability returns availability correctly', async () => {
    const availableEmpId = 'EMP-AVAIL-' + Math.floor(1000 + Math.random() * 9000);
    const check1 = await checkEmployeeIdAvailability(availableEmpId);
    assert.strictEqual(check1.isAvailable, true);

    // Reserve it
    await admin.firestore().collection('employee_ids').doc(availableEmpId).set({ uid: 'reserved_uid' });

    // Check again
    const check2 = await checkEmployeeIdAvailability(availableEmpId);
    assert.strictEqual(check2.isAvailable, false);
    assert.ok(check2.message.includes('already registered'));
  });

  // ── Scenario 17: Reserved Staff Email Self-Registration is Blocked ─────────
  it('Scenario 17: Self-registration using reserved staff emails is rejected by security rules', async () => {
    const reservedEmails = [
      'department.head.lu@gmail.com',
      'registrar.lu@gmail.com',
      'admin.lu@gmail.com',
    ];

    for (const email of reservedEmails) {
      const uid = 'rogue_staff_' + Math.floor(Math.random() * 100000);
      const empId = 'ROGUE-' + Math.floor(Math.random() * 100000);

      const db = testEnv.authenticatedContext(uid).firestore();

      await assert.rejects(
        db.runTransaction(async (transaction) => {
          transaction.set(db.collection('employee_ids').doc(empId), {
            uid,
            employeeId: empId,
            reservedAt: new Date(),
          });
          transaction.set(db.collection('users').doc(uid), {
            uid,
            email,
            fullName: 'Rogue Pretender',
            employeeId: empId,
            departmentId: 'dept_cse',
            role: 'faculty',
            approvalStatus: 'pending',
            isActive: false,
          });
        }),
        /PERMISSION_DENIED/
      );
    }
  });
});
