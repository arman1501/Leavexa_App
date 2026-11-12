/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  staff_and_university_sync.test.js  –  Staff Accounts & University Website Sync Tests
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const assert = require('assert');
const {
  parseOverviewAndContact,
  parseDepartments,
  parsePolicies,
  parseNotices,
} = require('../src/university_sync');

describe('Fixed Staff Account & University Website Integration Suite', () => {
  describe('1. Fixed 12 Institutional Accounts Configuration & Role Constraints', () => {
    it('1.1 Verifies all 12 designated accounts (1 Admin, 1 Registrar, 10 Department Heads) and department mappings', () => {
      const { INSTITUTIONAL_ACCOUNTS, DEPARTMENT_HEAD_DEFINITIONS } = require('../scripts/provision_fixed_staff');
      assert.strictEqual(INSTITUTIONAL_ACCOUNTS.length, 12);
      assert.strictEqual(DEPARTMENT_HEAD_DEFINITIONS.length, 10);

      const adminAcc = INSTITUTIONAL_ACCOUNTS.find((a) => a.role === 'admin');
      assert.ok(adminAcc);
      assert.strictEqual(adminAcc.email, 'admin.lu@gmail.com');
      assert.strictEqual(adminAcc.departmentId, 'admin_office');

      const registrarAcc = INSTITUTIONAL_ACCOUNTS.find((a) => a.role === 'registrar');
      assert.ok(registrarAcc);
      assert.strictEqual(registrarAcc.email, 'registrar.lu@gmail.com');
      assert.strictEqual(registrarAcc.departmentId, 'registrar_office');

      const expectedHeads = [
        ['head.cse.lu@gmail.com', 'dept_cse'],
        ['head.eee.lu@gmail.com', 'dept_eee'],
        ['head.bba.lu@gmail.com', 'dept_bba'],
        ['head.ce.lu@gmail.com', 'dept_civil'],
        ['head.law.lu@gmail.com', 'dept_law'],
        ['head.arch.lu@gmail.com', 'dept_arch'],
        ['head.ph.lu@gmail.com', 'dept_public_health'],
        ['head.thm.lu@gmail.com', 'dept_thm'],
        ['head.islamic.lu@gmail.com', 'dept_islamic_studies'],
        ['head.english.lu@gmail.com', 'dept_english'],
      ];
      for (const [email, deptId] of expectedHeads) {
        const match = INSTITUTIONAL_ACCOUNTS.find((a) => a.email === email);
        assert.ok(match, `Missing head config for ${email}`);
        assert.strictEqual(match.role, 'department_head');
        assert.strictEqual(match.departmentId, deptId);
      }
    });

    it('1.2 No plaintext passwords are embedded in account definitions or Firestore payloads', () => {
      const { INSTITUTIONAL_ACCOUNTS } = require('../scripts/provision_fixed_staff');
      for (const acc of INSTITUTIONAL_ACCOUNTS) {
        assert.strictEqual(acc.defaultPassword, undefined, 'Must never embed defaultPassword string');
        assert.strictEqual(acc.password, undefined, 'Must never embed password string');
        assert.ok(!acc.passwordInFirestore, 'Password must never be part of firestore payload');
        assert.ok(acc.passwordEnvVar && acc.passwordEnvVar.startsWith('STAFF_'));
      }
    });

    it('1.3 Refuses to invent passwords for missing Auth accounts when secret is absent', async () => {
      const { INSTITUTIONAL_ACCOUNTS, provisionAccount } = require('../scripts/provision_fixed_staff');
      const prevEnv = process.env[INSTITUTIONAL_ACCOUNTS[2].passwordEnvVar];
      delete process.env[INSTITUTIONAL_ACCOUNTS[2].passwordEnvVar];
      try {
        const fakeAuth = {
          getUserByEmail: async () => {
            const err = new Error('not found');
            err.code = 'auth/user-not-found';
            throw err;
          },
          createUser: async () => {
            throw new Error('createUser must not be called without a supplied password');
          },
        };
        const fakeDb = { collection: () => ({ doc: () => ({}) }) };
        const res = await provisionAccount(INSTITUTIONAL_ACCOUNTS[2], { auth: fakeAuth, db: fakeDb });
        assert.strictEqual(res.status, 'MISSING_INITIAL_PASSWORD');
        assert.strictEqual(res.uid, null);
      } finally {
        if (prevEnv !== undefined) {
          process.env[INSTITUTIONAL_ACCOUNTS[2].passwordEnvVar] = prevEnv;
        }
      }
    });
  });

  describe('2. University Website Information Parsing & Data Accuracy', () => {
    it('2.1 Parses Contact Info and University Overview accurately from official metadata', () => {
      const dummyHtml = '<div>Contact: registrar@lus.ac.bd, info@lus.ac.bd, itadmin@lus.ac.bd</div>';
      const overview = parseOverviewAndContact(dummyHtml, 'https://lus.ac.bd/contact/');

      assert.strictEqual(overview.universityName, 'Leading University');
      assert.strictEqual(overview.pabx, '01313084499');
      assert.strictEqual(overview.generalEmail, 'info@lus.ac.bd');
      assert.ok(overview.campusAddress.includes('Ragibnagar'));
      assert.ok(overview.keyOffices.some((o) => o.extension === '130' && o.email === 'registrar@lus.ac.bd'));
      assert.ok(overview.keyOffices.some((o) => o.extension === '120' && o.email === 'treasurer@lus.ac.bd'));
      assert.ok(overview.keyOffices.some((o) => o.extension === '150' && o.email === 'controller@lus.ac.bd'));
    });

    it('2.2 Parses official faculties and 11 canonical departments with matching database IDs', () => {
      const depts = parseDepartments('', 'https://lus.ac.bd/faculty/');

      assert.strictEqual(depts.totalDepartments, 11);
      assert.ok(depts.faculties.includes('Faculty of Modern Science'));
      assert.ok(depts.faculties.includes('Faculty of Business Administration'));
      assert.ok(depts.faculties.includes('Faculty of Arts and Modern Language'));
      assert.ok(depts.faculties.includes('Faculty of Social Science'));

      const cse = depts.departments.find((d) => d.id === 'dept_cse');
      assert.ok(cse);
      assert.strictEqual(cse.name, 'Computer Science & Engineering');
      assert.strictEqual(cse.code, 'CSE');

      const eee = depts.departments.find((d) => d.id === 'dept_eee');
      assert.ok(eee);
      assert.strictEqual(eee.code, 'EEE');

      const bangla = depts.departments.find((d) => d.id === 'dept_bangla');
      assert.ok(bangla);
      assert.strictEqual(bangla.code, 'BNG');
    });

    it('2.3 Strictly marks Study Leave as VERIFIED and other leave types as unverified (requiring Admin config)', () => {
      const policies = parsePolicies('', 'https://lus.ac.bd/about-us/rules-policies/');

      // Verified Study Leave
      const study = policies.leavePolicies.study_leave;
      assert.ok(study);
      assert.strictEqual(study.status, 'VERIFIED');
      assert.strictEqual(study.isPubliclyVerified, true);
      assert.strictEqual(study.maximumDurationYears, 5);
      assert.strictEqual(study.automatedApprovalAllowed, false);
      assert.strictEqual(study.adminConfigurationRequired, false);
      assert.ok(study.sourceUrl.endsWith('Study-Leave-Policy.pdf'));

      // Unverified leaves (Casual, Medical, Earned, Duty, Station)
      const unverifiedKeys = ['casual_leave', 'medical_leave', 'earned_leave', 'duty_leave', 'station_leave'];
      for (const key of unverifiedKeys) {
        const policy = policies.leavePolicies[key];
        assert.ok(policy, `Policy ${key} must exist`);
        assert.strictEqual(policy.status, 'Not verified – Admin configuration required');
        assert.strictEqual(policy.isPubliclyVerified, false);
        assert.strictEqual(policy.automatedApprovalAllowed, false);
        assert.strictEqual(policy.adminConfigurationRequired, true);
      }
    });

    it('2.4 Parses Notice Board items safely and strips HTML tags', () => {
      const noticeHtml = `
        <a href="https://lus.ac.bd/notice/annual-convocation-notice/">Annual Convocation Notice <strong>2026</strong> Read More »</a>
        <a href="https://lus.ac.bd/notice/holiday-schedule/">Holiday Schedule for Eid</a>
      `;
      const result = parseNotices(noticeHtml, 'https://lus.ac.bd/notice/');
      assert.strictEqual(result.totalRetrieved, 2);
      assert.strictEqual(result.notices[0].title, 'Annual Convocation Notice 2026');
      assert.strictEqual(result.notices[0].url, 'https://lus.ac.bd/notice/annual-convocation-notice/');
      assert.strictEqual(result.notices[1].title, 'Holiday Schedule for Eid');
    });
  });

  describe('3. Untrusted Domain Rejection', () => {
    it('3.1 Rejects any request to non-official domains', async () => {
      const { fetchHtml } = require('../src/university_sync');
      await assert.rejects(
        fetchHtml('https://evil-hacker.com/malicious.html'),
        /Untrusted host forbidden/
      );
    });
  });
});
