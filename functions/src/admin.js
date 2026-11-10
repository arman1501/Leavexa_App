// ─────────────────────────────────────────────────────────────────────────────
//  admin.js  –  Firebase Admin SDK Central Instance
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

let _messagingInstance = null;
function getMessaging() {
  if (!_messagingInstance) {
    _messagingInstance = admin.messaging();
  }
  return _messagingInstance;
}

function setMockMessaging(mock) {
  _messagingInstance = mock;
}

module.exports = {
  admin,
  db,
  auth,
  getMessaging,
  setMockMessaging,
  FieldValue,
};
