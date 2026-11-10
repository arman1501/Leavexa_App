// ─────────────────────────────────────────────────────────────────────────────
//  notifications.js  –  Role-Based FCM Push & In-App Notification Engine
// ─────────────────────────────────────────────────────────────────────────────

const crypto = require('crypto');
const { db, getMessaging } = require('./admin');

const LOCK_TIMEOUT_MS = 60000; // 60s lease window (aligned with default Cloud Function timeout)
const MAX_EVENT_ATTEMPTS = 5; // Maximum retry attempts for an event
const MAX_DEVICE_ATTEMPTS = 3; // Maximum retry attempts per individual device token

/**
 * Computes a secure, stable hash of an FCM device token.
 * Prevents raw token exposure in notification event logs and history.
 */
function computeTokenHash(token) {
  if (!token) return 'unknown';
  return crypto.createHash('sha256').update(String(token)).digest('hex').substring(0, 16);
}

/**
 * Sends a push notification and writes an in-app alert to a specific user.
 * Implements fine-grained per-device delivery tracking (pending, sending, sent,
 * failed, invalid_token, failed_terminal) with bounded retries and exponential backoff.
 * Ensures partial multicast failures retry ONLY the failed devices without duplicate
 * sends to previously successful devices.
 * Raw device tokens are scrubbed from event history, storing only stable hashes and doc IDs.
 *
 * @param {string} recipientUid
 * @param {Object} payload { title, body, type, relatedApplicationId, data }
 * @param {Object} [options] { idempotencyKey, notificationId, lockTimeoutMs, ignoreBackoff }
 * @returns {Promise<{success: boolean, status: string, deliveredCount: number, removedTokenCount: number, duplicateSkipped?: boolean, devices?: Object}>}
 */
async function sendPushNotificationToUser(recipientUid, payload, options = {}) {
  if (!recipientUid) {
    throw new Error('recipientUid is required to send notification.');
  }

  const idempotencyKey =
    options.idempotencyKey ||
    `event_${Date.now()}_${recipientUid}_${Math.random().toString(36).substring(2, 7)}`;

  const lockToken = Math.random().toString(36).substring(2, 10);
  const notifId = options.notificationId || `notif_${idempotencyKey}`;
  const eventRef = db.collection('notification_events').doc(idempotencyKey);
  const notifRef = db.collection('notifications').doc(notifId);

  // ── 1. Atomic Idempotency Check & Lock Acquisition ─────────────────────────
  const shouldProceed = await db.runTransaction(async (transaction) => {
    const eventDoc = await transaction.get(eventRef);
    let attempts = 1;
    let existingDevices = {};

    if (eventDoc.exists) {
      const data = eventDoc.data() || {};
      existingDevices = data.devices || {};

      if (data.status === 'completed') {
        return false; // Event has already completed successfully across all devices
      }

      // Check max attempts across all retries
      if ((data.attempts || 0) >= MAX_EVENT_ATTEMPTS) {
        transaction.set(
          eventRef,
          {
            status: 'completed',
            reason: 'max_attempts_exceeded',
            exhausted: true,
            updatedAt: new Date().toISOString(),
          },
          { merge: true }
        );
        return false;
      }

      // If currently in_progress, check lock lease expiration
      if (data.status === 'in_progress') {
        const lockAge = Date.now() - (data.lockedAtMs || 0);
        const lockTimeout = options.lockTimeoutMs || LOCK_TIMEOUT_MS;
        if (lockAge < lockTimeout) {
          return false; // Concurrent worker active within lease duration
        }
      }

      // Exponential backoff check if retrying after transient failure
      if (data.status === 'failed' && data.lastAttemptAtMs && !options.ignoreBackoff) {
        const backoffDelay = Math.min(1000 * Math.pow(2, (data.attempts || 1) - 1), 30000);
        if (Date.now() - data.lastAttemptAtMs < backoffDelay) {
          return false; // Wait for exponential backoff window
        }
      }

      attempts = (data.attempts || 0) + 1;
    }

    // Acquire or renew in-progress lock with fresh lockToken
    transaction.set(
      eventRef,
      {
        idempotencyKey,
        recipientUid,
        type: payload.type || 'general',
        payload: {
          title: payload.title,
          body: payload.body,
          type: payload.type || 'general',
          relatedApplicationId: payload.relatedApplicationId || null,
          data: payload.data || null,
        },
        status: 'in_progress',
        lockedAtMs: Date.now(),
        lastAttemptAtMs: Date.now(),
        lockToken,
        attempts,
        devices: existingDevices,
        updatedAt: new Date().toISOString(),
      },
      { merge: true }
    );
    return true;
  });

  if (!shouldProceed) {
    return {
      success: true,
      deliveredCount: 0,
      removedTokenCount: 0,
      duplicateSkipped: true,
      message: `Notification event ${idempotencyKey} already completed, backoff active, or concurrently in progress.`,
    };
  }

  // ── 2. Persist In-App Notification Document ─────────────────────────────────
  const inAppData = {
    id: notifId,
    recipientUid,
    title: payload.title,
    body: payload.body,
    type: payload.type || 'general',
    relatedApplicationId: payload.relatedApplicationId || null,
    isRead: false,
    createdAt: new Date().toISOString(),
    fcmDispatched: true,
  };
  await notifRef.set(inAppData, { merge: true });

  // ── 3. Fetch User's Registered Device Tokens ───────────────────────────────
  const tokensSnap = await db
    .collection('users')
    .doc(recipientUid)
    .collection('fcm_tokens')
    .get();

  if (tokensSnap.empty) {
    await eventRef.update({
      status: 'completed',
      deliveredCount: 0,
      failureCount: 0,
      reason: 'no_registered_tokens',
      completedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    return {
      success: true,
      status: 'completed',
      deliveredCount: 0,
      removedTokenCount: 0,
      message: `User ${recipientUid} has no registered FCM tokens; in-app notification recorded.`,
    };
  }

  const tokenDocs = tokensSnap.docs;

  // ── 4. Per-Device Delivery State Evaluation ─────────────────────────────────
  // Inspect previous delivery outcomes for each token:
  // - 'sent': ALREADY accepted by FCM; skip to prevent duplicate notifications!
  // - 'invalid_token': Already detected as dead or unlinked; skip!
  // - 'failed_terminal': Max retries exceeded; skip!
  // - 'failed' or 'pending' or new: Eligible for dispatch attempt.
  const currentEventSnap = await eventRef.get();
  const currentEventData = currentEventSnap.data() || {};
  const devices = currentEventData.devices || {};

  // Detect any devices recorded previously whose token document was unlinked/deleted by user
  const activeDocIdSet = new Set(tokenDocs.map((d) => d.id));
  for (const [recordedDocId, dev] of Object.entries(devices)) {
    if (!activeDocIdSet.has(recordedDocId) && dev.status !== 'invalid_token') {
      dev.status = 'invalid_token';
      dev.lastError = 'token_document_unregistered_or_removed';
      dev.updatedAt = new Date().toISOString();
      devices[recordedDocId] = dev;
    }
  }

  const eligibleTokens = [];

  for (const doc of tokenDocs) {
    const docId = doc.id;
    const tokenData = doc.data() || {};
    const token = tokenData.token;
    if (!token) continue;

    const tokenHash = computeTokenHash(token);

    const devState = devices[docId] || {
      tokenDocId: docId,
      tokenHash,
      status: 'pending',
      attempts: 0,
      platform: tokenData.platform || 'unknown',
    };

    // Ensure raw token is NEVER persisted in event history
    delete devState.token;
    devState.tokenDocId = docId;
    devState.tokenHash = tokenHash;

    // Skip devices that previously succeeded or reached invalid terminal state
    if (devState.status === 'sent' || devState.status === 'invalid_token') {
      devices[docId] = devState;
      continue;
    }

    // Skip devices that exhausted individual retry limits
    if ((devState.attempts || 0) >= MAX_DEVICE_ATTEMPTS) {
      devState.status = 'failed_terminal';
      devState.lastError = 'max_device_attempts_exceeded';
      devices[docId] = devState;
      continue;
    }

    // Mark as in-flight sending
    devState.status = 'sending';
    devState.lastAttemptAt = new Date().toISOString();
    devices[docId] = devState;
    eligibleTokens.push({
      docId,
      token,
      tokenHash,
      platform: tokenData.platform || 'unknown',
    });
  }

  // If no tokens need delivery, check if all reached terminal status
  if (eligibleTokens.length === 0) {
    const allTerminal = Object.values(devices).every((d) =>
      ['sent', 'invalid_token', 'failed_terminal'].includes(d.status)
    );
    const hasAnySent = Object.values(devices).some((d) => d.status === 'sent');
    const finalStatus = allTerminal ? 'completed' : 'failed';

    await eventRef.update({
      status: finalStatus,
      devices,
      updatedAt: new Date().toISOString(),
      ...(finalStatus === 'completed' ? { completedAt: new Date().toISOString() } : {}),
    });

    return {
      success: hasAnySent || finalStatus === 'completed',
      status: finalStatus,
      deliveredCount: 0,
      removedTokenCount: 0,
      duplicateSkipped: true,
      message: `No eligible device tokens pending dispatch for event ${idempotencyKey}.`,
      devices,
    };
  }

  // Persist sending state before external I/O
  await eventRef.update({
    devices,
    updatedAt: new Date().toISOString(),
  });

  // ── 5. Pre-Dispatch Guard: Prevent Avoidable Stale-Lock Duplicates ──────────
  // If another worker completed the send or reclaimed the lock, abort before invoking FCM.
  const preDispatchSnap = await eventRef.get();
  if (preDispatchSnap.exists) {
    const preData = preDispatchSnap.data() || {};
    if (preData.status === 'completed') {
      return {
        success: true,
        status: 'completed',
        deliveredCount: 0,
        removedTokenCount: 0,
        duplicateSkipped: true,
        message: `Notification event ${idempotencyKey} was completed by another worker prior to FCM dispatch.`,
        devices: preData.devices || devices,
      };
    }
    if (preData.lockToken && preData.lockToken !== lockToken) {
      return {
        success: true,
        status: 'in_progress',
        deliveredCount: 0,
        removedTokenCount: 0,
        duplicateSkipped: true,
        message: `Notification event ${idempotencyKey} lock was reclaimed by a newer worker.`,
        devices: preData.devices || devices,
      };
    }
  }

  // ── 6. Construct FCM Multicast Message for Eligible Tokens Only ─────────────
  const message = {
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: {
      type: String(payload.type || 'general'),
      relatedApplicationId: String(payload.relatedApplicationId || ''),
      recipientUid: String(recipientUid),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      timestamp: new Date().toISOString(),
      ...(payload.data
        ? Object.fromEntries(
            Object.entries(payload.data).map(([k, v]) => [k, String(v ?? '')])
          )
        : {}),
    },
    tokens: eligibleTokens.map((d) => d.token),
  };

  // ── 7. Dispatch via Firebase Admin Messaging ───────────────────────────────
  let response;
  try {
    const messaging = getMessaging();
    if (typeof messaging.sendEachForMulticast === 'function') {
      response = await messaging.sendEachForMulticast(message);
    } else if (typeof messaging.sendMulticast === 'function') {
      response = await messaging.sendMulticast(message);
    } else {
      response = { successCount: eligibleTokens.length, failureCount: 0, responses: [] };
    }
  } catch (err) {
    console.error(`FCM dispatch error for user ${recipientUid}:`, err);
    // Mark in-flight devices as failed to permit future retry
    eligibleTokens.forEach((dev) => {
      const devAttempts = (devices[dev.docId]?.attempts || 0) + 1;
      const isTerminal = devAttempts >= MAX_DEVICE_ATTEMPTS;
      devices[dev.docId] = {
        tokenDocId: dev.docId,
        tokenHash: dev.tokenHash,
        platform: dev.platform,
        status: isTerminal ? 'failed_terminal' : 'failed',
        lastError: err.message,
        attempts: devAttempts,
        updatedAt: new Date().toISOString(),
      };
    });

    await eventRef.update({
      status: 'failed',
      devices,
      lastError: err.message,
      failedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    return {
      success: false,
      status: 'failed',
      deliveredCount: 0,
      removedTokenCount: 0,
      error: err.message,
      devices,
    };
  }

  // ── 8. Process Per-Device Delivery Results ──────────────────────────────────
  const invalidDocIds = [];
  let newlyDeliveredCount = 0;

  if (response.responses && Array.isArray(response.responses)) {
    response.responses.forEach((resp, idx) => {
      const dev = eligibleTokens[idx];
      if (!dev) return;

      const currentAttempts = (devices[dev.docId]?.attempts || 0) + 1;

      if (resp.success) {
        newlyDeliveredCount++;
        devices[dev.docId] = {
          tokenDocId: dev.docId,
          tokenHash: dev.tokenHash,
          platform: dev.platform,
          status: 'sent', // Signifies FCM accepted the message (not confirmed user receipt)
          messageId: resp.messageId || `msg_${Date.now()}`,
          attempts: currentAttempts,
          sentAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
      } else {
        const error = resp.error || {};
        const code = error.code || 'unknown';
        const isInvalid =
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/mismatched-credential';

        if (isInvalid) {
          invalidDocIds.push(dev.docId);
          devices[dev.docId] = {
            tokenDocId: dev.docId,
            tokenHash: dev.tokenHash,
            platform: dev.platform,
            status: 'invalid_token',
            errorCode: code,
            lastError: error.message || code,
            attempts: currentAttempts,
            updatedAt: new Date().toISOString(),
          };
        } else {
          // Transient failure (e.g. timeout, internal-error, server-unavailable)
          const isTerminal = currentAttempts >= MAX_DEVICE_ATTEMPTS;
          devices[dev.docId] = {
            tokenDocId: dev.docId,
            tokenHash: dev.tokenHash,
            platform: dev.platform,
            status: isTerminal ? 'failed_terminal' : 'failed',
            errorCode: code,
            lastError: error.message || code,
            attempts: currentAttempts,
            updatedAt: new Date().toISOString(),
          };
        }
      }
    });
  } else {
    newlyDeliveredCount = response.successCount || 0;
    eligibleTokens.forEach((dev) => {
      devices[dev.docId] = {
        tokenDocId: dev.docId,
        tokenHash: dev.tokenHash,
        platform: dev.platform,
        status: 'sent',
        attempts: (devices[dev.docId]?.attempts || 0) + 1,
        updatedAt: new Date().toISOString(),
      };
    });
  }

  // ── 9. Atomic Cleanup of Invalid Device Tokens ──────────────────────────────
  if (invalidDocIds.length > 0) {
    const batch = db.batch();
    invalidDocIds.forEach((docId) => {
      const ref = db
        .collection('users')
        .doc(recipientUid)
        .collection('fcm_tokens')
        .doc(docId);
      batch.delete(ref);
    });
    await batch.commit();
  }

  // ── 10. LockToken Fencing & Event Terminal State Persistence ────────────────
  // An event is marked 'completed' ONLY when all registered devices reach a terminal state
  // (sent, invalid_token, or failed_terminal).
  // If ANY device is still in 'failed' (transient), the event status is 'failed' to permit
  // the background retry worker to retry ONLY the failed device!
  const allDevices = Object.values(devices);
  const hasTransientFailures = allDevices.some((d) => d.status === 'failed');
  const allTerminal = allDevices.every((d) =>
    ['sent', 'invalid_token', 'failed_terminal'].includes(d.status)
  );

  const finalEventStatus = (allTerminal && !hasTransientFailures) ? 'completed' : 'failed';
  const totalDelivered = allDevices.filter((d) => d.status === 'sent').length;
  const totalFailed = allDevices.filter((d) => d.status === 'failed' || d.status === 'failed_terminal').length;

  // Stale worker protection: verify lockToken before committing completion
  await db.runTransaction(async (transaction) => {
    const currentSnap = await transaction.get(eventRef);
    if (!currentSnap.exists) return;
    const currentData = currentSnap.data() || {};

    if (currentData.lockToken && currentData.lockToken !== lockToken) {
      console.warn(
        `Worker with lockToken ${lockToken} was superseded by ${currentData.lockToken}; aborting completion write.`
      );
      return;
    }

    transaction.update(eventRef, {
      status: finalEventStatus,
      devices,
      deliveredCount: totalDelivered,
      failureCount: totalFailed,
      removedTokenCount: invalidDocIds.length,
      updatedAt: new Date().toISOString(),
      ...(finalEventStatus === 'completed' ? { completedAt: new Date().toISOString() } : {}),
      ...(finalEventStatus === 'failed' ? { failedAt: new Date().toISOString() } : {}),
    });
  });

  return {
    success: finalEventStatus === 'completed' || newlyDeliveredCount > 0,
    status: finalEventStatus,
    deliveredCount: newlyDeliveredCount,
    totalDelivered,
    removedTokenCount: invalidDocIds.length,
    devices,
  };
}

/**
 * Background retry worker processing pending/failed notification events.
 * Respects exponential backoff, maximum retry thresholds, and prunes
 * historical records past the data retention window.
 *
 * @param {Object} [options] { maxEvents, retentionDays, ignoreBackoff, enableRetentionCleanup }
 * @returns {Promise<{evaluated: number, retried: number, succeeded: number, exhausted: number, pruned: number}>}
 */
async function processPendingNotificationRetries(options = {}) {
  const now = Date.now();
  const maxRetries = options.maxEvents || 25;
  const retentionDays = options.retentionDays || 30;
  const retentionThreshold = new Date(now - retentionDays * 24 * 60 * 60 * 1000).toISOString();

  // 1. Query failed notification events
  const failedEventsSnap = await db
    .collection('notification_events')
    .where('status', '==', 'failed')
    .limit(maxRetries)
    .get();

  const results = {
    evaluated: failedEventsSnap.size,
    retried: 0,
    succeeded: 0,
    exhausted: 0,
    pruned: 0,
  };

  for (const doc of failedEventsSnap.docs) {
    const event = doc.data();
    const attempts = event.attempts || 1;

    // Check if event already reached max attempts
    if (attempts >= MAX_EVENT_ATTEMPTS) {
      await doc.ref.update({
        status: 'completed',
        exhausted: true,
        reason: 'max_event_attempts_reached',
        updatedAt: new Date().toISOString(),
      });
      results.exhausted++;
      continue;
    }

    // Check exponential backoff
    const lastAttemptAtMs = event.lastAttemptAtMs || 0;
    const backoffDelay = Math.min(1000 * Math.pow(2, attempts - 1), 30000);
    if (now - lastAttemptAtMs < backoffDelay && !options.ignoreBackoff) {
      continue; // Skip until backoff window passes
    }

    // Execute retry
    results.retried++;
    try {
      const payload = event.payload || {
        title: 'Leavexa Notification',
        body: 'Update regarding your account or leave application.',
        type: event.type || 'general',
      };

      const retryResult = await sendPushNotificationToUser(
        event.recipientUid,
        payload,
        {
          idempotencyKey: event.idempotencyKey,
          ignoreBackoff: options.ignoreBackoff,
        }
      );
      if (retryResult.success && retryResult.status === 'completed') {
        results.succeeded++;
      }
    } catch (err) {
      console.error(`Error retrying notification event ${event.idempotencyKey}:`, err);
    }
  }

  // 2. Data Retention Cleanup: Prune completed/exhausted events older than retention period
  if (options.enableRetentionCleanup !== false) {
    const oldEventsSnap = await db
      .collection('notification_events')
      .where('status', '==', 'completed')
      .where('updatedAt', '<', retentionThreshold)
      .limit(50)
      .get();

    if (!oldEventsSnap.empty) {
      const batch = db.batch();
      oldEventsSnap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      results.pruned = oldEventsSnap.size;
    }
  }

  return results;
}

/**
 * Sends notification to active Department Head(s) of a given department.
 */
async function sendPushNotificationToDepartmentHead(departmentId, payload, options = {}) {
  if (!departmentId) return [];

  const headsSnap = await db
    .collection('users')
    .where('role', '==', 'department_head')
    .where('departmentId', '==', departmentId)
    .where('isActive', '==', true)
    .get();

  const results = [];
  for (const doc of headsSnap.docs) {
    const res = await sendPushNotificationToUser(doc.id, payload, {
      ...options,
      idempotencyKey: options.idempotencyKey
        ? `${options.idempotencyKey}_${doc.id}`
        : undefined,
    });
    results.push({ uid: doc.id, ...res });
  }
  return results;
}

/**
 * Sends notification to all active Registrars.
 */
async function sendPushNotificationToRegistrars(payload, options = {}) {
  const registrarsSnap = await db
    .collection('users')
    .where('role', '==', 'registrar')
    .where('isActive', '==', true)
    .get();

  const results = [];
  for (const doc of registrarsSnap.docs) {
    const res = await sendPushNotificationToUser(doc.id, payload, {
      ...options,
      idempotencyKey: options.idempotencyKey
        ? `${options.idempotencyKey}_${doc.id}`
        : undefined,
    });
    results.push({ uid: doc.id, ...res });
  }
  return results;
}

/**
 * Sends notification to all active Administrators.
 */
async function sendPushNotificationToAdmins(payload, options = {}) {
  const adminsSnap = await db
    .collection('users')
    .where('role', '==', 'admin')
    .where('isActive', '==', true)
    .get();

  const results = [];
  for (const doc of adminsSnap.docs) {
    const res = await sendPushNotificationToUser(doc.id, payload, {
      ...options,
      idempotencyKey: options.idempotencyKey
        ? `${options.idempotencyKey}_${doc.id}`
        : undefined,
    });
    results.push({ uid: doc.id, ...res });
  }
  return results;
}

module.exports = {
  sendPushNotificationToUser,
  sendPushNotificationToDepartmentHead,
  sendPushNotificationToRegistrars,
  sendPushNotificationToAdmins,
  processPendingNotificationRetries,
  computeTokenHash,
};
