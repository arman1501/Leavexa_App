// ─────────────────────────────────────────────────────────────────────────────
//  firestore_rules_emulator_test.js  –  Firebase Emulator Security Rules Tests
// ─────────────────────────────────────────────────────────────────────────────

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { setDoc, getDoc, updateDoc, deleteDoc, doc, collection, addDoc, writeBatch } = require('@firebase/firestore');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'leavexa-test-project';
const RULES_PATH = path.join(__dirname, '../../firestore.rules');

describe('Leavexa Firestore Security Rules - Actual Emulator Suite', function () {
  this.timeout(15000);

  let testEnv;

  before(async () => {
    const rules = fs.readFileSync(RULES_PATH, 'utf8');
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
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

  beforeEach(async () => {
    await testEnv.clearFirestore();

    // Seed initial system fixtures using Admin context (bypasses security rules)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // Seed Users
      await setDoc(doc(db, 'users', 'admin_1'), {
        uid: 'admin_1',
        fullName: 'System Administrator',
        role: 'admin',
        approvalStatus: 'approved',
        isActive: true,
      });

      await setDoc(doc(db, 'users', 'registrar_1'), {
        uid: 'registrar_1',
        fullName: 'Academic Registrar',
        role: 'registrar',
        approvalStatus: 'approved',
        isActive: true,
      });

      await setDoc(doc(db, 'users', 'head_cse'), {
        uid: 'head_cse',
        fullName: 'Head of CSE',
        role: 'department_head',
        departmentId: 'dept_cse',
        approvalStatus: 'approved',
        isActive: true,
      });

      await setDoc(doc(db, 'users', 'head_eee'), {
        uid: 'head_eee',
        fullName: 'Head of EEE',
        role: 'department_head',
        departmentId: 'dept_eee',
        approvalStatus: 'approved',
        isActive: true,
      });

      await setDoc(doc(db, 'users', 'faculty_cse'), {
        uid: 'faculty_cse',
        fullName: 'CSE Faculty Member',
        role: 'faculty',
        departmentId: 'dept_cse',
        employeeId: 'CSE-101',
        approvalStatus: 'approved',
        isActive: true,
        email: 'faculty.cse@leavexa.edu',
      });

      await setDoc(doc(db, 'users', 'faculty_eee'), {
        uid: 'faculty_eee',
        fullName: 'EEE Faculty Member',
        role: 'faculty',
        departmentId: 'dept_eee',
        employeeId: 'EEE-202',
        approvalStatus: 'approved',
        isActive: true,
        email: 'faculty.eee@leavexa.edu',
      });

      await setDoc(doc(db, 'users', 'faculty_pending'), {
        uid: 'faculty_pending',
        fullName: 'Pending Faculty Member',
        role: 'faculty',
        departmentId: 'dept_cse',
        employeeId: 'CSE-999',
        approvalStatus: 'pending',
        isActive: false,
        email: 'pending@leavexa.edu',
      });

      // Seed an existing employee ID
      await setDoc(doc(db, 'employee_ids', 'CSE-101'), {
        uid: 'faculty_cse',
      });
    });
  });

  // ── 1. Unauthenticated Access ───────────────────────────────────────────────
  it('1. Unauthenticated access is denied on all collections', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(unauthedDb, 'users', 'faculty_cse')));
    await assertFails(getDoc(doc(unauthedDb, 'leave_applications', 'app_1')));
    await assertFails(getDoc(doc(unauthedDb, 'notifications', 'notif_1')));
  });

  // ── 2. Faculty Self-Registration ───────────────────────────────────────────
  it('2. Faculty self-registration as pending/inactive with matching Employee ID is allowed', async () => {
    const newUid = 'new_faculty_uid';
    const newDb = testEnv.authenticatedContext(newUid).firestore();
    const batch = writeBatch(newDb);

    batch.set(doc(newDb, 'employee_ids', 'NEW-555'), {
      uid: newUid,
    });

    batch.set(doc(newDb, 'users', newUid), {
      uid: newUid,
      fullName: 'New Lecturer',
      email: 'new@leavexa.edu',
      employeeId: 'NEW-555',
      departmentId: 'dept_cse',
      designation: 'Lecturer',
      role: 'faculty',
      approvalStatus: 'pending',
      isActive: false,
    });

    await assertSucceeds(batch.commit());
  });

  // ── 3. Faculty Role Escalation Attempts ─────────────────────────────────────
  it('3. Faculty role escalation attempt during self-registration is denied', async () => {
    const hackerUid = 'hacker_uid';
    const hackerDb = testEnv.authenticatedContext(hackerUid).firestore();

    await assertFails(
      setDoc(doc(hackerDb, 'users', hackerUid), {
        uid: hackerUid,
        fullName: 'Hacker User',
        email: 'hacker@leavexa.edu',
        employeeId: 'HACK-001',
        role: 'admin', // Escalation!
        approvalStatus: 'approved',
        isActive: true,
      }),
    );
  });

  // ── 4. Employee ID Reservation & Duplicate Prevention ──────────────────────
  it('4. Reserving an already reserved Employee ID is denied', async () => {
    const userDb = testEnv.authenticatedContext('faculty_eee').firestore();

    // CSE-101 was seeded in beforeEach for faculty_cse
    await assertFails(
      setDoc(doc(userDb, 'employee_ids', 'CSE-101'), {
        uid: 'faculty_eee',
      }),
    );
  });

  // ── 5. Cross-Department Data Access ────────────────────────────────────────
  it('5. Department Head accessing another department leave application is denied', async () => {
    // Seed an EEE leave application
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'leave_applications', 'eee_app_1'), {
        id: 'eee_app_1',
        applicantUid: 'faculty_eee',
        departmentId: 'dept_eee',
        status: 'pending',
      });
    });

    const headCseDb = testEnv.authenticatedContext('head_cse').firestore();
    await assertFails(getDoc(doc(headCseDb, 'leave_applications', 'eee_app_1')));
  });

  // ── 6. Faculty Accessing Only Own Applications ─────────────────────────────
  it('6. Faculty accessing another faculty leave application is denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'leave_applications', 'cse_app_1'), {
        id: 'cse_app_1',
        applicantUid: 'faculty_cse',
        departmentId: 'dept_cse',
        status: 'pending',
      });
    });

    const facultyEeeDb = testEnv.authenticatedContext('faculty_eee').firestore();
    await assertFails(getDoc(doc(facultyEeeDb, 'leave_applications', 'cse_app_1')));
  });

  // ── 7. Department Head Reviewing Own Department Applications ───────────────
  it('7. Department Head reviewing own department application is allowed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'leave_applications', 'cse_app_1'), {
        id: 'cse_app_1',
        applicantUid: 'faculty_cse',
        departmentId: 'dept_cse',
        status: 'pending',
      });
    });

    const headCseDb = testEnv.authenticatedContext('head_cse').firestore();
    await assertSucceeds(getDoc(doc(headCseDb, 'leave_applications', 'cse_app_1')));

    // Forwarding with allowed keys
    await assertSucceeds(
      updateDoc(doc(headCseDb, 'leave_applications', 'cse_app_1'), {
        status: 'forwarded',
        headUid: 'head_cse',
        headComment: 'Recommended by Head.',
        headActionAt: new Date().toISOString(),
      }),
    );
  });

  // ── 8. Department Head Modifying Protected Fields ──────────────────────────
  it('8. Department Head attempting to modify protected fields is denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'leave_applications', 'cse_app_2'), {
        id: 'cse_app_2',
        applicantUid: 'faculty_cse',
        departmentId: 'dept_cse',
        totalDays: 3,
        status: 'pending',
      });
    });

    const headCseDb = testEnv.authenticatedContext('head_cse').firestore();

    // Trying to alter totalDays
    await assertFails(
      updateDoc(doc(headCseDb, 'leave_applications', 'cse_app_2'), {
        status: 'forwarded',
        headUid: 'head_cse',
        headComment: 'Tampering days',
        headActionAt: new Date().toISOString(),
        totalDays: 10,
      }),
    );
  });

  // ── 9. Registrar Approving Only Forwarded Applications ──────────────────────
  it('9. Registrar approving a pending application without Head forwarding is denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'leave_applications', 'cse_app_pending'), {
        id: 'cse_app_pending',
        applicantUid: 'faculty_cse',
        departmentId: 'dept_cse',
        status: 'pending', // Not forwarded!
      });
    });

    const regDb = testEnv.authenticatedContext('registrar_1').firestore();

    await assertFails(
      updateDoc(doc(regDb, 'leave_applications', 'cse_app_pending'), {
        status: 'approved',
        registrarUid: 'registrar_1',
        registrarComment: 'Direct approval bypass',
        registrarActionAt: new Date().toISOString(),
      }),
    );
  });

  // ── 10. Registrar Modifying Head Review Fields ──────────────────────────────
  it('10. Registrar modifying Head review fields is denied by diff keys lock', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'leave_applications', 'cse_app_fwd'), {
        id: 'cse_app_fwd',
        applicantUid: 'faculty_cse',
        departmentId: 'dept_cse',
        status: 'forwarded',
        headUid: 'head_cse',
        headComment: 'Original Head Comment',
        headActionAt: '2025-01-01T00:00:00Z',
      });
    });

    const regDb = testEnv.authenticatedContext('registrar_1').firestore();

    await assertFails(
      updateDoc(doc(regDb, 'leave_applications', 'cse_app_fwd'), {
        status: 'approved',
        registrarUid: 'registrar_1',
        registrarComment: 'Approved',
        registrarActionAt: new Date().toISOString(),
        headComment: 'Tampered Head Comment by Registrar',
      }),
    );
  });

  // ── 11. Unauthorized Notification Creation ─────────────────────────────────
  it('11. Ordinary faculty sending notifications to another user is denied', async () => {
    const facultyDb = testEnv.authenticatedContext('faculty_cse').firestore();

    await assertFails(
      setDoc(doc(facultyDb, 'notifications', 'spam_1'), {
        id: 'spam_1',
        recipientUid: 'faculty_eee',
        title: 'Spam',
        body: 'Hello',
        isRead: false,
      }),
    );
  });

  // ── 12. Notification Recipient Privacy ─────────────────────────────────────
  it('12. User reading another user notification is denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'notifications', 'private_notif'), {
        id: 'private_notif',
        recipientUid: 'faculty_cse',
        title: 'Confidential',
        isRead: false,
      });
    });

    const facultyEeeDb = testEnv.authenticatedContext('faculty_eee').firestore();
    await assertFails(getDoc(doc(facultyEeeDb, 'notifications', 'private_notif')));
  });

  // ── 13. Unauthorized Leave Balance Modification ────────────────────────────
  it('13. Ordinary faculty modifying leave balances is denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'leave_balances', 'bal_cse'), {
        id: 'bal_cse',
        userUid: 'faculty_cse',
        totalAllotted: 10,
        used: 2,
      });
    });

    const facultyDb = testEnv.authenticatedContext('faculty_cse').firestore();
    await assertFails(
      updateDoc(doc(facultyDb, 'leave_balances', 'bal_cse'), {
        used: 0,
      }),
    );
  });

  // ── 14. Audit Log Client Write Restrictions ────────────────────────────────
  it('14. Client write to audit logs is strictly denied for all clients', async () => {
    const adminDb = testEnv.authenticatedContext('admin_1').firestore();
    const facultyDb = testEnv.authenticatedContext('faculty_cse').firestore();

    await assertFails(
      setDoc(doc(facultyDb, 'audit_logs', 'log_1'), {
        event: 'faculty_action',
      }),
    );

    await assertFails(
      setDoc(doc(adminDb, 'audit_logs', 'log_2'), {
        event: 'admin_action',
      }),
    );
  });

  // ── 15. Admin Permissions ──────────────────────────────────────────────────
  it('15. Admin has full administrative update authority on user approval', async () => {
    const adminDb = testEnv.authenticatedContext('admin_1').firestore();

    await assertSucceeds(
      updateDoc(doc(adminDb, 'users', 'faculty_pending'), {
        approvalStatus: 'approved',
        isActive: true,
      }),
    );
  });

  // ── 16. System Config Client Write Restrictions ────────────────────────────
  it('16. Client write to system_config is strictly denied, read allowed for Admin', async () => {
    const adminDb = testEnv.authenticatedContext('admin_1').firestore();
    const facultyDb = testEnv.authenticatedContext('faculty_cse').firestore();

    // Client writes denied
    await assertFails(
      setDoc(doc(facultyDb, 'system_config', 'bootstrap'), {
        isBootstrapped: true,
      }),
    );
    await assertFails(
      setDoc(doc(adminDb, 'system_config', 'bootstrap'), {
        isBootstrapped: false,
      }),
    );

    // Faculty read denied
    await assertFails(
      getDoc(doc(facultyDb, 'system_config', 'bootstrap')),
    );

    // Admin read allowed
    await assertSucceeds(
      getDoc(doc(adminDb, 'system_config', 'bootstrap')),
    );
  });

  // ── 17. FCM Device Tokens Security ─────────────────────────────────────────
  it('17. FCM device tokens subcollection security: user can manage only own tokens, cross-user and unauthenticated access denied', async () => {
    const facultyDb = testEnv.authenticatedContext('faculty_cse').firestore();
    const otherDb = testEnv.authenticatedContext('other_user').firestore();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    const ownTokenRef = doc(facultyDb, 'users', 'faculty_cse', 'fcm_tokens', 'token_android_1');
    const otherTokenRef = doc(otherDb, 'users', 'faculty_cse', 'fcm_tokens', 'token_android_1');
    const unauthTokenRef = doc(unauthDb, 'users', 'faculty_cse', 'fcm_tokens', 'token_android_1');

    // 1. User registers their own token -> succeeds
    await assertSucceeds(
      setDoc(ownTokenRef, {
        token: 'fcm_token_xyz_123',
        platform: 'android',
        deviceModel: 'Pixel 8 Pro',
        createdAt: new Date().toISOString(),
        lastSeenAt: new Date().toISOString(),
      }),
    );

    // 2. User reads their own token -> succeeds
    await assertSucceeds(getDoc(ownTokenRef));

    // 3. User deletes their own token (logout) -> succeeds
    await assertSucceeds(deleteDoc(ownTokenRef));

    // 4. Other user writing to faculty_cse's tokens -> denied
    await assertFails(
      setDoc(otherTokenRef, {
        token: 'malicious_token',
        platform: 'android',
      }),
    );

    // 5. Other user reading faculty_cse's tokens -> denied
    await assertFails(getDoc(otherTokenRef));

    // 6. Unauthenticated write/read -> denied
    await assertFails(
      setDoc(unauthTokenRef, {
        token: 'unauth_token',
      }),
    );
    await assertFails(getDoc(unauthTokenRef));
  });

  // ── 18. Notification Events Security ────────────────────────────────────────
  it('18. Notification events collection security: ordinary clients cannot read or write notification_events (default deny)', async () => {
    const facultyDb = testEnv.authenticatedContext('faculty_cse').firestore();
    const adminDb = testEnv.authenticatedContext('admin_1', { role: 'admin' }).firestore();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    const eventRefFaculty = doc(facultyDb, 'notification_events', 'event_123');
    const eventRefAdmin = doc(adminDb, 'notification_events', 'event_123');
    const eventRefUnauth = doc(unauthDb, 'notification_events', 'event_123');

    // 1. Client write attempts must fail (client cannot tamper with idempotency locks)
    await assertFails(setDoc(eventRefFaculty, { status: 'completed' }));
    await assertFails(setDoc(eventRefAdmin, { status: 'completed' }));
    await assertFails(setDoc(eventRefUnauth, { status: 'completed' }));

    // 2. Client read attempts must fail
    await assertFails(getDoc(eventRefFaculty));
    await assertFails(getDoc(eventRefAdmin));
    await assertFails(getDoc(eventRefUnauth));
  });

  // ── 19. Faculty Leave Cancellation Security ────────────────────────────────
  it('19. Faculty can cancel their own pending leave application', async () => {
    // Seed pending application for faculty_cse
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'leave_applications', 'app_cancel_success'), {
        applicantUid: 'faculty_cse',
        departmentId: 'dept_cse',
        status: 'pending',
        leaveTypeId: 'casual',
        totalDays: 2,
      });
    });

    const facultyDb = testEnv.authenticatedContext('faculty_cse').firestore();
    const appRef = doc(facultyDb, 'leave_applications', 'app_cancel_success');

    // Faculty cancels their own pending application
    await assertSucceeds(
      updateDoc(appRef, {
        status: 'cancelled',
        cancelledAt: new Date().toISOString(),
        cancelReason: 'Emergency resolved',
      }),
    );
  });

  // ── 20. Leave Cancellation Restrictions ─────────────────────────────────────
  it('20. Faculty cannot cancel an already forwarded application, and other users cannot cancel', async () => {
    // Seed forwarded application for faculty_cse
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'leave_applications', 'app_forwarded_locked'), {
        applicantUid: 'faculty_cse',
        departmentId: 'dept_cse',
        status: 'forwarded',
        leaveTypeId: 'casual',
        totalDays: 2,
      });

      await setDoc(doc(db, 'leave_applications', 'app_other_pending'), {
        applicantUid: 'faculty_eee',
        departmentId: 'dept_eee',
        status: 'pending',
        leaveTypeId: 'casual',
        totalDays: 2,
      });
    });

    const facultyCseDb = testEnv.authenticatedContext('faculty_cse').firestore();

    // 1. Cannot cancel after being forwarded
    await assertFails(
      updateDoc(doc(facultyCseDb, 'leave_applications', 'app_forwarded_locked'), {
        status: 'cancelled',
        cancelledAt: new Date().toISOString(),
      }),
    );

    // 2. Cannot cancel another faculty member's application
    await assertFails(
      updateDoc(doc(facultyCseDb, 'leave_applications', 'app_other_pending'), {
        status: 'cancelled',
        cancelledAt: new Date().toISOString(),
      }),
    );
  });

  // ── 21. Partial Registration Recovery ───────────────────────────────────────
  it('21. Partial registration recovery succeeds when employee_ids was already reserved by the same UID', async () => {
    const recoveryUid = 'faculty_recovery_uid';
    const recoveryEmpId = 'REC-777';

    // Seed prior reserved employee_id for recoveryUid (simulating interrupted registration)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'employee_ids', recoveryEmpId), {
        uid: recoveryUid,
      });
    });

    const recoveryDb = testEnv.authenticatedContext(recoveryUid).firestore();

    // The user creates their profile using the already-reserved employeeId
    await assertSucceeds(
      setDoc(doc(recoveryDb, 'users', recoveryUid), {
        uid: recoveryUid,
        fullName: 'Recovered Faculty',
        email: 'recovery@leavexa.edu',
        employeeId: recoveryEmpId,
        departmentId: 'dept_cse',
        designation: 'Lecturer',
        role: 'faculty',
        approvalStatus: 'pending',
        isActive: false,
      }),
    );
  });

  // ── 22. Incomplete Registration Retry & Update Ownership ───────────────────
  it('22. Incomplete registration retry: same user can re-assert employee_ids reservation, but other users are rejected', async () => {
    const retryUid = 'faculty_retry_uid';
    const otherUid = 'faculty_other_uid';
    const empId = 'RTRY-888';

    // Seed prior employee_id
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'employee_ids', empId), {
        uid: retryUid,
      });
    });

    const retryDb = testEnv.authenticatedContext(retryUid).firestore();
    const otherDb = testEnv.authenticatedContext(otherUid).firestore();

    // Owner can re-set/update their own employee_id reservation
    await assertSucceeds(
      setDoc(doc(retryDb, 'employee_ids', empId), {
        uid: retryUid,
      }),
    );

    // Another user cannot overwrite it
    await assertFails(
      setDoc(doc(otherDb, 'employee_ids', empId), {
        uid: otherUid,
      }),
    );
  });
});
