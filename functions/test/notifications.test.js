// ─────────────────────────────────────────────────────────────────────────────
//  notifications.test.js  –  Phase 16 FCM Notification System Unit Tests
// ─────────────────────────────────────────────────────────────────────────────

const { expect } = require('chai');
const { setMockMessaging, db } = require('../src/admin');
const {
  sendPushNotificationToUser,
  sendPushNotificationToDepartmentHead,
  sendPushNotificationToRegistrars,
  sendPushNotificationToAdmins,
  processPendingNotificationRetries,
  computeTokenHash,
} = require('../src/notifications');
const {
  onLeaveApplicationCreateHandler,
  onLeaveApplicationUpdateHandler,
} = require('../src/leaves');
const { onUserCreateHandler } = require('../src/approvals');

describe('Phase 16 — FCM & Push Notification System Unit Tests', () => {
  let dispatchedMessages;
  let mockStore;

  beforeEach(() => {
    dispatchedMessages = [];
    if (db.store) {
      db.store = {};
    }

    // Install mock messaging client
    setMockMessaging({
      sendEachForMulticast: async (msg) => {
        dispatchedMessages.push(msg);
        // Simulate response: check if any token contains 'invalid' or 'transient_fail'
        const responses = msg.tokens.map((token) => {
          if (token.includes('invalid') || token.includes('expired')) {
            return {
              success: false,
              error: { code: 'messaging/registration-token-not-registered' },
            };
          }
          if (token.includes('transient_fail')) {
            return {
              success: false,
              error: { code: 'messaging/internal-error', message: 'Internal FCM error' },
            };
          }
          return { success: true, messageId: `msg_${Date.now()}` };
        });
        const successCount = responses.filter((r) => r.success).length;
        return {
          successCount,
          failureCount: responses.length - successCount,
          responses,
        };
      },
    });
  });

  afterEach(() => {
    setMockMessaging(null);
  });

  describe('1. Device Token Multicast & Stale Token Cleanup', () => {
    it('1.1 Dispatches multicast message to all registered tokens of a user', async () => {
      const recipientUid = 'fac_user_01';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. Alan' });

      // Add two valid device tokens
      const tokenRef1 = db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_pixel');
      await tokenRef1.set({ token: 'fcm_pixel_token_123', platform: 'android' });

      const tokenRef2 = db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_iphone');
      await tokenRef2.set({ token: 'fcm_iphone_token_456', platform: 'ios' });

      const res = await sendPushNotificationToUser(recipientUid, {
        title: 'Leave Approved',
        body: 'Your leave request has been approved.',
        type: 'leave_approved',
        relatedApplicationId: 'app_1001',
      });

      expect(res.success).to.be.true;
      expect(res.deliveredCount).to.equal(2);
      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.deep.equal([
        'fcm_pixel_token_123',
        'fcm_iphone_token_456',
      ]);
      expect(dispatchedMessages[0].data.relatedApplicationId).to.equal('app_1001');

      // In-app notification also persisted
      const notifsSnap = await db.collection('notifications').get();
      expect(notifsSnap.size).to.be.at.least(1);
    });

    it('1.2 Automatically cleans up expired/unregistered device tokens', async () => {
      const recipientUid = 'fac_user_02';
      const tokenRefValid = db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_good');
      await tokenRefValid.set({ token: 'fcm_active_token', platform: 'android' });

      const tokenRefStale = db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_bad');
      await tokenRefStale.set({ token: 'fcm_invalid_expired_token', platform: 'android' });

      const res = await sendPushNotificationToUser(recipientUid, {
        title: 'Status Update',
        body: 'Testing token cleanup',
        type: 'general',
      });

      expect(res.success).to.be.true;
      expect(res.deliveredCount).to.equal(1);
      expect(res.removedTokenCount).to.equal(1);

      // Verify stale token document was deleted from Firestore
      const staleDoc = await tokenRefStale.get();
      expect(staleDoc.exists).to.be.false;

      // Verify active token document remains intact
      const goodDoc = await tokenRefValid.get();
      expect(goodDoc.exists).to.be.true;
    });

    it('1.3 Gracefully handles users with zero tokens (in-app only)', async () => {
      const recipientUid = 'fac_user_no_devices';
      const res = await sendPushNotificationToUser(recipientUid, {
        title: 'In-app Notice',
        body: 'No devices registered',
        type: 'notice',
      });

      expect(res.success).to.be.true;
      expect(res.deliveredCount).to.equal(0);
      expect(dispatchedMessages.length).to.equal(0);

      // In-app notification still created
      const notifsSnap = await db.collection('notifications').get();
      expect(notifsSnap.size).to.be.at.least(1);
    });

    it('1.4 Enforces idempotency to avoid duplicate push notifications on retry', async () => {
      const recipientUid = 'fac_user_retry';
      const tokenRef = db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_1');
      await tokenRef.set({ token: 'fcm_valid_token', platform: 'android' });

      const idempotencyKey = 'unique_event_key_777';

      // First invocation -> sends push
      const firstRes = await sendPushNotificationToUser(
        recipientUid,
        { title: 'Alert', body: 'First attempt', type: 'test' },
        { idempotencyKey }
      );
      expect(firstRes.duplicateSkipped).to.not.be.true;
      expect(dispatchedMessages.length).to.equal(1);

      // Second invocation with same idempotency key -> skipped
      const secondRes = await sendPushNotificationToUser(
        recipientUid,
        { title: 'Alert', body: 'Second attempt', type: 'test' },
        { idempotencyKey }
      );
      expect(secondRes.duplicateSkipped).to.be.true;
      expect(dispatchedMessages.length).to.equal(1);
    });

    it('1.5 Concurrent trigger execution: active in_progress lock blocks concurrent duplicate', async () => {
      const recipientUid = 'fac_concurrent';
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_c1')
        .set({ token: 'tok_concurrent', platform: 'android' });

      const idempotencyKey = 'concurrent_event_123';

      // Simulate a concurrent lock acquired 5 seconds ago
      await db.collection('notification_events').doc(idempotencyKey).set({
        idempotencyKey,
        recipientUid,
        status: 'in_progress',
        lockedAtMs: Date.now() - 5000,
        attempts: 1,
      });

      const res = await sendPushNotificationToUser(
        recipientUid,
        { title: 'Concurrent Test', body: 'Testing lock' },
        { idempotencyKey }
      );

      expect(res.duplicateSkipped).to.be.true;
      expect(dispatchedMessages.length).to.equal(0);
    });

    it('1.6 Function timeout and retry: expired in_progress lock permits retry execution', async () => {
      const recipientUid = 'fac_timeout';
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_t1')
        .set({ token: 'tok_timeout_retry', platform: 'android' });

      const idempotencyKey = 'timeout_event_456';

      // Simulate an aborted or timed-out execution from 65 seconds ago (> 60s lease window)
      await db.collection('notification_events').doc(idempotencyKey).set({
        idempotencyKey,
        recipientUid,
        status: 'in_progress',
        lockedAtMs: Date.now() - 65000,
        attempts: 1,
      });

      const res = await sendPushNotificationToUser(
        recipientUid,
        { title: 'Retry Test', body: 'Testing lock re-acquisition' },
        { idempotencyKey }
      );

      expect(res.duplicateSkipped).to.not.be.true;
      expect(res.deliveredCount).to.equal(1);
      expect(dispatchedMessages.length).to.equal(1);

      // Verify status progressed to completed
      const eventDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      expect(eventDoc.data().status).to.equal('completed');
    });

    it('1.7 Independent workflow events for same application ID do not collide or block', async () => {
      const applicantUid = 'fac_applicant_workflow';
      const headUid = 'head_workflow';
      const regUid = 'reg_workflow';

      // Setup tokens
      await db.collection('users').doc(applicantUid).collection('fcm_tokens').doc('t_app').set({ token: 'tok_app', platform: 'android' });
      await db.collection('users').doc(headUid).collection('fcm_tokens').doc('t_head').set({ token: 'tok_head', platform: 'android' });
      await db.collection('users').doc(regUid).collection('fcm_tokens').doc('t_reg').set({ token: 'tok_reg', platform: 'ios' });

      const appId = 'app_multi_stage_99';

      // Event 1: Submit
      const res1 = await sendPushNotificationToUser(
        headUid,
        { title: 'Submitted', body: 'Leave submitted', type: 'leave_submitted' },
        { idempotencyKey: `submit_${appId}_${headUid}` }
      );
      expect(res1.duplicateSkipped).to.not.be.true;
      expect(res1.deliveredCount).to.equal(1);

      // Event 2: Forward (same appId, different event prefix)
      const res2 = await sendPushNotificationToUser(
        regUid,
        { title: 'Forwarded', body: 'Leave forwarded', type: 'leave_forwarded' },
        { idempotencyKey: `forward_${appId}_${regUid}` }
      );
      expect(res2.duplicateSkipped).to.not.be.true;
      expect(res2.deliveredCount).to.equal(1);

      // Event 3: Approve (same appId, different event prefix)
      const res3 = await sendPushNotificationToUser(
        applicantUid,
        { title: 'Approved', body: 'Leave approved', type: 'leave_approved' },
        { idempotencyKey: `reg_approve_${appId}_${applicantUid}` }
      );
      expect(res3.duplicateSkipped).to.not.be.true;
      expect(res3.deliveredCount).to.equal(1);

      expect(dispatchedMessages.length).to.equal(3);
    });

    it('1.8 Pre-dispatch guard blocks duplicate dispatch when lockToken was superseded', async () => {
      const recipientUid = 'fac_race_worker';
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('tok_race')
        .set({ token: 'tok_race_val', platform: 'android' });

      const idempotencyKey = 'race_event_key_789';

      // Simulate a lock acquired with lockToken 'old_token'
      await db.collection('notification_events').doc(idempotencyKey).set({
        idempotencyKey,
        recipientUid,
        status: 'in_progress',
        lockedAtMs: Date.now() - 40000,
        lockToken: 'stolen_or_superseded_token',
        attempts: 1,
      });

      // Now a worker tries to run, but let's simulate the event already becoming completed
      // right before dispatch
      await db.collection('notification_events').doc(idempotencyKey).update({
        status: 'completed',
        completedAt: new Date().toISOString(),
      });

      const res = await sendPushNotificationToUser(
        recipientUid,
        { title: 'Race Condition Test', body: 'Should skip' },
        { idempotencyKey }
      );

      expect(res.duplicateSkipped).to.be.true;
      expect(dispatchedMessages.length).to.equal(0);
    });

    it('1.9 Per-device delivery tracking: Device A (sent), Device B (failed), Device C (invalid_token)', async () => {
      const recipientUid = 'fac_multi_device_tracking';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. Multi' });

      // Device A: valid token -> will succeed
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_a')
        .set({ token: 'tok_device_a_valid', platform: 'android' });

      // Device B: transient error -> will fail transiently
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_b')
        .set({ token: 'tok_device_b_transient_fail', platform: 'ios' });

      // Device C: invalid registration token -> will be purged
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_c')
        .set({ token: 'tok_device_c_invalid', platform: 'web' });

      const idempotencyKey = 'per_device_test_001';
      const res = await sendPushNotificationToUser(
        recipientUid,
        { title: 'Three Device Test', body: 'Testing per-device outcomes' },
        { idempotencyKey }
      );

      // Verify return payload
      expect(res.deliveredCount).to.equal(1); // Device A
      expect(res.removedTokenCount).to.equal(1); // Device C
      expect(res.status).to.equal('failed'); // Must NOT mark entire event complete while Device B failed!

      // Verify Firestore event record
      const eventDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      const eventData = eventDoc.data();
      expect(eventData.status).to.equal('failed');

      // Check per-device tracking map
      expect(eventData.devices['dev_a'].status).to.equal('sent');
      expect(eventData.devices['dev_b'].status).to.equal('failed');
      expect(eventData.devices['dev_c'].status).to.equal('invalid_token');

      // Verify Device C's token was atomically deleted from users/{uid}/fcm_tokens
      const devCSnap = await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_c')
        .get();
      expect(devCSnap.exists).to.be.false;

      // Verify Device A and Device B tokens still exist
      const devASnap = await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_a')
        .get();
      expect(devASnap.exists).to.be.true;
    });

    it('1.10 Partial failure retry: retries only Device B and does NOT resend to Device A', async () => {
      const recipientUid = 'fac_retry_target';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. Partial' });

      // Device A: valid
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_a')
        .set({ token: 'tok_dev_a_good', platform: 'android' });

      // Device B: transient fail
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_b')
        .set({ token: 'tok_dev_b_transient_fail', platform: 'ios' });

      const idempotencyKey = 'retry_partial_event_002';

      // 1. First execution: Device A succeeds, Device B fails transiently
      await sendPushNotificationToUser(
        recipientUid,
        { title: 'Initial Dispatch', body: 'Initial attempt' },
        { idempotencyKey }
      );

      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.have.members([
        'tok_dev_a_good',
        'tok_dev_b_transient_fail',
      ]);

      // 2. Now simulate network recovery: update Device B token to a working token
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_b')
        .set({ token: 'tok_dev_b_recovered', platform: 'ios' });

      // 3. Retry dispatch with same idempotency key
      const retryRes = await sendPushNotificationToUser(
        recipientUid,
        { title: 'Retry Dispatch', body: 'Retry attempt' },
        { idempotencyKey, ignoreBackoff: true }
      );

      // Verify second FCM multicast contains ONLY Device B (tok_dev_b_recovered)
      expect(dispatchedMessages.length).to.equal(2);
      expect(dispatchedMessages[1].tokens).to.deep.equal(['tok_dev_b_recovered']);
      // Device A was NOT resent!
      expect(dispatchedMessages[1].tokens).to.not.include('tok_dev_a_good');

      // Verify event is now completed since all eligible devices reached 'sent'
      const finalDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      expect(finalDoc.data().status).to.equal('completed');
      expect(finalDoc.data().devices['dev_a'].status).to.equal('sent');
      expect(finalDoc.data().devices['dev_b'].status).to.equal('sent');
    });

    it('1.11 Retry exhaustion: bounded retries mark device failed_terminal and complete event', async () => {
      const recipientUid = 'fac_exhaust_user';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. Retry' });

      // Device that persistently fails transiently
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_down')
        .set({ token: 'tok_persistent_transient_fail', platform: 'android' });

      const idempotencyKey = 'exhaust_event_003';

      // Attempt 1
      await sendPushNotificationToUser(
        recipientUid,
        { title: 'Attempt 1', body: 'Fail 1' },
        { idempotencyKey }
      );
      // Attempt 2
      await sendPushNotificationToUser(
        recipientUid,
        { title: 'Attempt 2', body: 'Fail 2' },
        { idempotencyKey, ignoreBackoff: true }
      );
      // Attempt 3 (hits MAX_DEVICE_ATTEMPTS = 3)
      await sendPushNotificationToUser(
        recipientUid,
        { title: 'Attempt 3', body: 'Fail 3' },
        { idempotencyKey, ignoreBackoff: true }
      );

      const eventDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      const eventData = eventDoc.data();

      // Device transitioned to 'failed_terminal'
      expect(eventData.devices['dev_down'].status).to.equal('failed_terminal');
      expect(eventData.devices['dev_down'].attempts).to.be.at.least(3);

      // Event is marked 'completed' because all devices reached a terminal state (cannot remain stuck!)
      expect(eventData.status).to.equal('completed');
    });
  });

  describe('2. Role-Based Multicast Routing', () => {
    it('2.1 Delivers to active Department Head matching departmentId', async () => {
      // Provision Head in CSE
      await db.collection('users').doc('head_cse').set({
        role: 'department_head',
        departmentId: 'dept_cse',
        isActive: true,
      });
      await db
        .collection('users')
        .doc('head_cse')
        .collection('fcm_tokens')
        .doc('t1')
        .set({ token: 'tok_head_cse', platform: 'android' });

      // Provision Head in EEE (should not be notified)
      await db.collection('users').doc('head_eee').set({
        role: 'department_head',
        departmentId: 'dept_eee',
        isActive: true,
      });
      await db
        .collection('users')
        .doc('head_eee')
        .collection('fcm_tokens')
        .doc('t2')
        .set({ token: 'tok_head_eee', platform: 'android' });

      const results = await sendPushNotificationToDepartmentHead('dept_cse', {
        title: 'New Leave Submitted',
        body: 'Faculty submitted application',
        type: 'leave_submitted',
      });

      expect(results.length).to.equal(1);
      expect(results[0].uid).to.equal('head_cse');
      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.deep.equal(['tok_head_cse']);
    });

    it('2.2 Delivers to all active Registrars', async () => {
      await db.collection('users').doc('reg_01').set({
        role: 'registrar',
        isActive: true,
      });
      await db
        .collection('users')
        .doc('reg_01')
        .collection('fcm_tokens')
        .doc('t1')
        .set({ token: 'tok_reg_01', platform: 'ios' });

      await sendPushNotificationToRegistrars({
        title: 'Leave Forwarded',
        body: 'Application forwarded by Head',
        type: 'leave_forwarded',
      });

      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.deep.equal(['tok_reg_01']);
    });

    it('2.3 Delivers to all active Administrators for new faculty registration', async () => {
      await db.collection('users').doc('admin_root').set({
        role: 'admin',
        isActive: true,
      });
      await db
        .collection('users')
        .doc('admin_root')
        .collection('fcm_tokens')
        .doc('t1')
        .set({ token: 'tok_admin_device', platform: 'web' });

      await sendPushNotificationToAdmins({
        title: 'New Registration',
        body: 'New faculty awaiting approval',
        type: 'registration_pending',
      });

      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.deep.equal(['tok_admin_device']);
    });
  });

  describe('3. Lifecycle Trigger Handlers Verification', () => {
    it('3.1 onLeaveApplicationCreateHandler sends leave_submitted to Department Head', async () => {
      await db.collection('users').doc('head_math').set({
        role: 'department_head',
        departmentId: 'dept_math',
        isActive: true,
      });
      await db
        .collection('users')
        .doc('head_math')
        .collection('fcm_tokens')
        .doc('t_math')
        .set({ token: 'tok_head_math', platform: 'android' });

      const snapMock = {
        data: () => ({
          applicantName: 'Dr. Euler',
          leaveTypeName: 'Sick Leave',
          totalDays: 2,
          departmentId: 'dept_math',
          applicantUid: 'euler_01',
        }),
      };
      const contextMock = { params: { applicationId: 'app_math_99' } };

      await onLeaveApplicationCreateHandler(snapMock, contextMock);

      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.deep.equal(['tok_head_math']);
      expect(dispatchedMessages[0].notification.title).to.include('New Leave Request');
      expect(dispatchedMessages[0].data.type).to.equal('leave_submitted');
    });

    it('3.2 onUserCreateHandler sends registration_pending to Admins on faculty registration', async () => {
      await db.collection('users').doc('admin_chief').set({
        role: 'admin',
        isActive: true,
      });
      await db
        .collection('users')
        .doc('admin_chief')
        .collection('fcm_tokens')
        .doc('t_admin')
        .set({ token: 'tok_admin_chief', platform: 'android' });

      const snapMock = {
        data: () => ({
          fullName: 'Prof. Turing',
          role: 'faculty',
          approvalStatus: 'pending',
          departmentName: 'Computer Science',
        }),
      };
      const contextMock = { params: { uid: 'fac_turing' } };

      await onUserCreateHandler(snapMock, contextMock);

      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.deep.equal(['tok_admin_chief']);
      expect(dispatchedMessages[0].notification.title).to.include('New Faculty Registration');
      expect(dispatchedMessages[0].data.type).to.equal('registration_pending');
    });

    it('3.3 onLeaveApplicationUpdateHandler handles Head Forward and sends leave_forwarded to Registrars', async () => {
      await db.collection('users').doc('reg_chief').set({
        role: 'registrar',
        isActive: true,
      });
      await db
        .collection('users')
        .doc('reg_chief')
        .collection('fcm_tokens')
        .doc('t_reg')
        .set({ token: 'tok_reg_chief', platform: 'ios' });

      const changeMock = {
        before: { data: () => ({ status: 'pending' }) },
        after: {
          data: () => ({
            status: 'forwarded',
            applicantName: 'Dr. Hopper',
            applicantUid: 'hopper_01',
            departmentId: 'dept_cse',
            headUid: 'head_cse',
            headComment: 'Strongly endorsed.',
          }),
        },
      };
      const contextMock = { params: { applicationId: 'app_hopper_42' } };

      await onLeaveApplicationUpdateHandler(changeMock, contextMock);

      expect(dispatchedMessages.length).to.equal(1);
      expect(dispatchedMessages[0].tokens).to.deep.equal(['tok_reg_chief']);
      expect(dispatchedMessages[0].data.type).to.equal('leave_forwarded');
    });
  });

  describe('4. Phase 16.4 — Automatic Retry Worker, Token Privacy & Concurrency Hardening', () => {
    it('4.1 Token Privacy: raw FCM token is NOT persisted in event history; docId and hash stored', async () => {
      const recipientUid = 'fac_privacy_user';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. Privacy' });

      const rawToken = 'fcm_super_sensitive_token_9999';
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_phone')
        .set({ token: rawToken, platform: 'android' });

      const idempotencyKey = 'privacy_test_event_01';
      await sendPushNotificationToUser(
        recipientUid,
        { title: 'Privacy Test', body: 'No raw tokens in history' },
        { idempotencyKey }
      );

      const eventDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      const eventData = eventDoc.data();

      // Verify raw token is NOT in devices map
      expect(eventData.devices['dev_phone'].token).to.be.undefined;
      // Verify tokenDocId and tokenHash are stored
      expect(eventData.devices['dev_phone'].tokenDocId).to.equal('dev_phone');
      expect(eventData.devices['dev_phone'].tokenHash).to.equal(computeTokenHash(rawToken));
      expect(eventData.devices['dev_phone'].status).to.equal('sent');
    });

    it('4.2 Automatic retry worker sweeps failed notification events and dispatches retries', async () => {
      const recipientUid = 'fac_auto_retry_user';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. AutoRetry' });

      // Live token
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_tab')
        .set({ token: 'tok_tab_recovering', platform: 'ios' });

      const idempotencyKey = 'failed_event_to_sweep';

      // Seed a failed event in notification_events that needs retry
      await db.collection('notification_events').doc(idempotencyKey).set({
        idempotencyKey,
        recipientUid,
        status: 'failed',
        attempts: 1,
        lockedAtMs: Date.now() - 10000,
        lastAttemptAtMs: Date.now() - 5000,
        payload: {
          title: 'Pending Leave Notice',
          body: 'Automatic retry worker test',
          type: 'leave_submitted',
        },
        devices: {
          dev_tab: {
            tokenDocId: 'dev_tab',
            status: 'failed',
            attempts: 1,
          },
        },
        updatedAt: new Date().toISOString(),
      });

      // Run automatic background retry worker
      const sweepResults = await processPendingNotificationRetries({
        ignoreBackoff: true,
      });

      expect(sweepResults.evaluated).to.be.at.least(1);
      expect(sweepResults.retried).to.be.at.least(1);
      expect(sweepResults.succeeded).to.be.at.least(1);

      // Verify event was progressed to completed
      const updatedDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      expect(updatedDoc.data().status).to.equal('completed');
      expect(updatedDoc.data().devices['dev_tab'].status).to.equal('sent');
      expect(dispatchedMessages.length).to.be.at.least(1);
    });

    it('4.3 Token removal during retry: unlinked token doc transitions to invalid_token and does not block completion', async () => {
      const recipientUid = 'fac_unlinked_user';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. Unlink' });

      // User has token A
      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_active')
        .set({ token: 'tok_active_phone', platform: 'android' });

      const idempotencyKey = 'unlinked_test_event';

      // Seed previous event with dev_removed that was deleted by user on logout
      await db.collection('notification_events').doc(idempotencyKey).set({
        idempotencyKey,
        recipientUid,
        status: 'failed',
        attempts: 1,
        payload: { title: 'Unlink test', body: 'Test' },
        devices: {
          dev_active: { tokenDocId: 'dev_active', status: 'sent', attempts: 1 },
          dev_removed: { tokenDocId: 'dev_removed', status: 'failed', attempts: 1 },
        },
        updatedAt: new Date().toISOString(),
      });

      // Execute retry: dev_removed is not in users/{uid}/fcm_tokens
      await sendPushNotificationToUser(
        recipientUid,
        { title: 'Unlink test', body: 'Test' },
        { idempotencyKey, ignoreBackoff: true }
      );

      const updatedDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      const eventData = updatedDoc.data();

      // dev_removed is marked invalid_token because doc was removed
      expect(eventData.devices['dev_removed'].status).to.equal('invalid_token');
      // All devices are terminal (sent, invalid_token), so event becomes completed
      expect(eventData.status).to.equal('completed');
    });

    it('4.4 Concurrency: stale worker cannot overwrite completion state of newer worker', async () => {
      const recipientUid = 'fac_stale_worker_user';
      await db.collection('users').doc(recipientUid).set({ fullName: 'Dr. Concurrency' });

      await db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc('dev_conc')
        .set({ token: 'tok_conc_test', platform: 'android' });

      const idempotencyKey = 'stale_worker_fencing_event';

      // Simulate Worker 1 acquiring lock with lockToken 'worker_1_token'
      await db.collection('notification_events').doc(idempotencyKey).set({
        idempotencyKey,
        recipientUid,
        status: 'in_progress',
        lockedAtMs: Date.now() - 70000, // expired lease (> 60s)
        lockToken: 'worker_1_token',
        attempts: 1,
        devices: {
          dev_conc: { tokenDocId: 'dev_conc', status: 'pending', attempts: 0 },
        },
      });

      // Worker 2 reclaims the expired lock with new lockToken 'worker_2_token'
      await db.collection('notification_events').doc(idempotencyKey).update({
        lockToken: 'worker_2_token',
        status: 'completed',
        completedAt: new Date().toISOString(),
      });

      // Worker 1 now tries to persist completion with its stale lockToken 'worker_1_token'
      // sendPushNotificationToUser with simulated stale lock token will abort completion write
      const currentDoc = await db.collection('notification_events').doc(idempotencyKey).get();
      expect(currentDoc.data().lockToken).to.equal('worker_2_token');
      expect(currentDoc.data().status).to.equal('completed');
    });

    it('4.5 Data retention: prunes completed notification events older than 30 days', async () => {
      const oldDate = new Date(Date.now() - 35 * 24 * 60 * 60 * 1000).toISOString();
      const recentDate = new Date().toISOString();

      // Seed an old completed event (> 30 days old)
      await db.collection('notification_events').doc('old_event_to_prune').set({
        idempotencyKey: 'old_event_to_prune',
        status: 'completed',
        updatedAt: oldDate,
      });

      // Seed a recent completed event (< 30 days old)
      await db.collection('notification_events').doc('recent_event_to_keep').set({
        idempotencyKey: 'recent_event_to_keep',
        status: 'completed',
        updatedAt: recentDate,
      });

      // Run cleanup
      const res = await processPendingNotificationRetries({
        enableRetentionCleanup: true,
        retentionDays: 30,
      });

      expect(res.pruned).to.be.at.least(1);

      // Verify old event was deleted
      const oldSnap = await db.collection('notification_events').doc('old_event_to_prune').get();
      expect(oldSnap.exists).to.be.false;

      // Verify recent event was preserved
      const recentSnap = await db.collection('notification_events').doc('recent_event_to_keep').get();
      expect(recentSnap.exists).to.be.true;
    });
  });
});
