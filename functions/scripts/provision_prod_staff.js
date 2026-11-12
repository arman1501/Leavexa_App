const fs = require('fs');
const https = require('https');
const os = require('os');

// Read Firebase CLI token
const configPath = os.homedir() + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const token = config.tokens.access_token;
const PROJECT_ID = 'leavexa';

function makeRequest(url, options, postData) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });
    req.on('error', reject);
    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

const STAFF = [
  {
    role: 'admin',
    email: 'admin.lu@gmail.com',
    password: process.env.STAFF_ADMIN_PASSWORD || 'LU_Admin@63A',
    fullName: 'System Administrator',
    employeeId: 'ADMIN-001',
    departmentId: 'admin_office',
    departmentName: 'Office of the Administrator',
    designation: 'System Administrator',
    phone: '+8801700000003',
  },
  {
    role: 'department_head',
    email: 'department.head.lu@gmail.com',
    password: process.env.STAFF_HEAD_PASSWORD || 'LU_Head@63A',
    fullName: 'Department Head (CSE)',
    employeeId: 'HEAD-CSE-001',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science & Engineering',
    designation: 'Department Head',
    phone: '+8801700000001',
  },
  {
    role: 'registrar',
    email: 'registrar.lu@gmail.com',
    password: process.env.STAFF_REGISTRAR_PASSWORD || 'LU_Register@63A',
    fullName: 'Office of the Registrar',
    employeeId: 'REG-001',
    departmentId: 'registrar_office',
    departmentName: 'Office of the Registrar',
    designation: 'Registrar',
    phone: '+8801700000002',
  }
];

async function run() {
  console.log('=== Provisioning Staff Accounts in Production Firebase (' + PROJECT_ID + ') ===');

  for (const staff of STAFF) {
    console.log(`\n--- Provisioning ${staff.role}: ${staff.email} ---`);

    // 1. Create or lookup user in Auth
    let uid;
    const lookup = await makeRequest(
      `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:lookup`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      },
      { email: [staff.email] }
    );

    if (lookup.data && lookup.data.users && lookup.data.users.length > 0) {
      uid = lookup.data.users[0].localId;
      console.log(`[AUTH] User already exists with UID: ${uid}`);
      await makeRequest(
        `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:update`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        },
        {
          localId: uid,
          password: staff.password,
          emailVerified: true
        }
      );
    } else {
      const createRes = await makeRequest(
        `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        },
        {
          email: staff.email,
          password: staff.password,
          emailVerified: true,
          displayName: staff.fullName
        }
      );

      if (createRes.status !== 200 || !createRes.data.localId) {
        console.error(`[ERROR] Failed to create ${staff.email}:`, createRes);
        continue;
      }
      uid = createRes.data.localId;
      console.log(`[AUTH] Created Auth user with UID: ${uid}`);
    }

    // 2. Set Custom Claims
    const customAttributes = JSON.stringify({
      role: staff.role,
      approvalStatus: 'approved',
      departmentId: staff.departmentId
    });

    const claimsRes = await makeRequest(
      `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:update`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      },
      {
        localId: uid,
        customAttributes: customAttributes
      }
    );
    console.log(`[CLAIMS] Custom claims set. Status: ${claimsRes.status}`);

    // 3. Set Firestore Profile
    const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`;
    const profileFields = {
      uid: { stringValue: uid },
      email: { stringValue: staff.email },
      fullName: { stringValue: staff.fullName },
      employeeId: { stringValue: staff.employeeId },
      role: { stringValue: staff.role },
      departmentId: { stringValue: staff.departmentId },
      departmentName: { stringValue: staff.departmentName },
      designation: { stringValue: staff.designation },
      phone: { stringValue: staff.phone },
      approvalStatus: { stringValue: 'approved' },
      isActive: { booleanValue: true },
      createdAt: { timestampValue: new Date().toISOString() },
      updatedAt: { timestampValue: new Date().toISOString() }
    };

    const docRes = await makeRequest(
      firestoreUrl,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      },
      { fields: profileFields }
    );
    console.log(`[FIRESTORE] User profile created at users/${uid}. Status: ${docRes.status}`);

    // 4. Set employee_ids reservation index
    const empIdUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/employee_ids/${staff.employeeId}`;
    const empIdFields = {
      employeeId: { stringValue: staff.employeeId },
      uid: { stringValue: uid },
      departmentId: { stringValue: staff.departmentId },
      role: { stringValue: staff.role },
      assignedAt: { timestampValue: new Date().toISOString() }
    };

    const empRes = await makeRequest(
      empIdUrl,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      },
      { fields: empIdFields }
    );
    console.log(`[FIRESTORE] Employee ID index set at employee_ids/${staff.employeeId}. Status: ${empRes.status}`);
  }

  console.log('\n=== Staff Provisioning Complete ===');
}

run().catch(console.error);
