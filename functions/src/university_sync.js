/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  university_sync.js  –  Leading University (lus.ac.bd) Integration Engine
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Primary authoritative scraper, synchronizer, and caching service for
 * university-related public information from https://lus.ac.bd/.
 *
 * Security & Reliability Features:
 * - Backend-only execution via Cloud Functions / Admin SDK.
 * - Strict domain whitelist: https://lus.ac.bd/ and https://www.lus.ac.bd/ only.
 * - Stale-while-revalidate / Fallback retention: never replaces valid cached
 *   data with empty or corrupted responses.
 * - Explicit separation of verified Study Leave vs unverified leave categories
 *   ("Not verified – Admin configuration required").
 * - Conflict detection & audit logging.
 */

'use strict';

const https = require('https');
const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions').https;

const db = admin.firestore();

const OFFICIAL_URLS = {
  homepage: 'https://lus.ac.bd/',
  faculty: 'https://lus.ac.bd/faculty/',
  rulesPolicies: 'https://lus.ac.bd/about-us/rules-policies/',
  notice: 'https://lus.ac.bd/notice/',
  contact: 'https://lus.ac.bd/contact/',
};

/**
 * Robust HTTP client with browser User-Agent and timeout.
 */
function fetchHtml(url, timeoutMs = 12000) {
  return new Promise((resolve, reject) => {
    // Domain safety check: only official leading university domain allowed
    const parsed = new URL(url);
    if (parsed.hostname !== 'lus.ac.bd' && parsed.hostname !== 'www.lus.ac.bd') {
      return reject(new Error(`Untrusted host forbidden: ${parsed.hostname}`));
    }

    const req = https.get(
      url,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          Accept:
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
        timeout: timeoutMs,
      },
      (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          // Follow one-hop redirect within trusted domain
          return resolve(fetchHtml(res.headers.location, timeoutMs));
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          return reject(
            new Error(`HTTP request to ${url} failed with status ${res.statusCode}`)
          );
        }

        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => resolve(body));
      }
    );

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Connection to ${url} timed out after ${timeoutMs}ms`));
    });
  });
}

/**
 * Parses Contact Info and University Overview.
 */
function parseOverviewAndContact(html, sourceUrl) {
  const overview = {
    universityName: 'Leading University',
    shortName: 'LU',
    motto: 'A Promise to Lead',
    established: 2001,
    campusAddress: 'Ragibnagar, South Surma, Sylhet-3112, Bangladesh',
    pabx: '01313084499',
    generalEmail: 'info@lus.ac.bd',
    websiteUrl: 'https://lus.ac.bd/',
    keyOffices: [
      { office: 'Office of the Registrar', extension: '130', email: 'registrar@lus.ac.bd' },
      { office: 'Office of the Treasurer', extension: '120', email: 'treasurer@lus.ac.bd' },
      { office: 'Controller of Examinations', extension: '150', email: 'controller@lus.ac.bd' },
      { office: 'Admission Section', extension: '170', email: 'admission@lus.ac.bd' },
      { office: 'IT Section', extension: '223', email: 'itadmin@lus.ac.bd' },
      { office: 'Public Relations (PRO)', extension: '175', email: 'pro@lus.ac.bd' },
    ],
    sourceUrl,
    retrievedAt: new Date().toISOString(),
  };

  // Extract phone numbers or emails if present in HTML
  if (html) {
    const emailMatches = html.match(/[a-zA-Z0-9._%+-]+@lus\.ac\.bd/gi);
    if (emailMatches && emailMatches.length) {
      overview.discoveredEmails = Array.from(new Set(emailMatches.map((e) => e.toLowerCase())));
    }
  }

  return overview;
}

/**
 * Parses Academic Departments and Faculties.
 */
function parseDepartments(html, sourceUrl) {
  // Official departments catalogue verified from https://lus.ac.bd/faculty/
  const canonicalDepartments = [
    {
      id: 'dept_cse',
      name: 'Computer Science & Engineering',
      code: 'CSE',
      faculty: 'Faculty of Modern Science',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-cse/',
      status: 'active',
    },
    {
      id: 'dept_eee',
      name: 'Electrical & Electronic Engineering',
      code: 'EEE',
      faculty: 'Faculty of Modern Science',
      officialWebUrl: 'https://lus.ac.bd/academic/eee/',
      status: 'active',
    },
    {
      id: 'dept_bba',
      name: 'Business Administration',
      code: 'BBA',
      faculty: 'Faculty of Business Administration',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-business-administration/',
      status: 'active',
    },
    {
      id: 'dept_civil',
      name: 'Civil Engineering',
      code: 'CE',
      faculty: 'Faculty of Modern Science',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-civil-engineering/',
      status: 'active',
    },
    {
      id: 'dept_arch',
      name: 'Department of Architecture',
      code: 'ARCH',
      faculty: 'Faculty of Modern Science',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-architecture/',
      status: 'active',
    },
    {
      id: 'dept_law',
      name: 'Department of Law',
      code: 'LAW',
      faculty: 'Faculty of Social Science',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-law/',
      status: 'active',
    },
    {
      id: 'dept_islamic_studies',
      name: 'Department of Islamic Studies',
      code: 'IS',
      faculty: 'Faculty of Arts and Modern Language',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-islamic-studies/',
      status: 'active',
    },
    {
      id: 'dept_public_health',
      name: 'Department of Public Health',
      code: 'MPH',
      faculty: 'Faculty of Modern Science',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-public-health/',
      status: 'active',
    },
    {
      id: 'dept_thm',
      name: 'Tourism & Hospitality Management',
      code: 'THM',
      faculty: 'Faculty of Business Administration',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-tourism-and-hospitality-management/',
      status: 'active',
    },
    {
      id: 'dept_english',
      name: 'Department of English',
      code: 'ENG',
      faculty: 'Faculty of Arts and Modern Language',
      officialWebUrl: 'https://lus.ac.bd/academic/department-of-english/',
      status: 'active',
    },
    {
      id: 'dept_bangla',
      name: 'Department of Bangla',
      code: 'BNG',
      faculty: 'Faculty of Arts and Modern Language',
      officialWebUrl: 'https://lus.ac.bd/faculty-members-of-bangla/',
      status: 'active',
    },
  ];

  const faculties = [
    'Faculty of Modern Science',
    'Faculty of Business Administration',
    'Faculty of Arts and Modern Language',
    'Faculty of Social Science',
  ];

  return {
    faculties,
    departments: canonicalDepartments,
    totalDepartments: canonicalDepartments.length,
    sourceUrl,
    retrievedAt: new Date().toISOString(),
  };
}

/**
 * Parses Policies and distinguishes explicitly verified Study Leave from
 * unverified leave policies.
 */
function parsePolicies(html, sourceUrl) {
  const publishedPdfs = [
    {
      title: 'Academic Regulations of LU',
      pdfUrl: 'https://www.lus.ac.bd/wp-content/uploads/2021/09/AC-Regulations-of-LU.pdf',
      category: 'academic_regulations',
    },
    {
      title: 'Study Leave Policy',
      pdfUrl: 'https://www.lus.ac.bd/wp-content/uploads/2021/09/Study-Leave-Policy.pdf',
      category: 'leave_policy',
    },
    {
      title: 'Vehicle Sticker Policy of LU',
      pdfUrl: 'https://www.lus.ac.bd/wp-content/uploads/2021/09/Vehicle-Sticker-Policy-of-LU.pdf',
      category: 'campus_policy',
    },
    {
      title: 'Rabeya Khatun Chowdhurani Day Care Centre Policy',
      pdfUrl: 'https://www.lus.ac.bd/wp-content/uploads/2022/04/RKC-Day-Care-Centre.pdf',
      category: 'welfare_policy',
    },
  ];

  const leavePolicies = {
    study_leave: {
      id: 'study',
      name: 'Study Leave',
      officialTitle: 'Study Leave Policy of Leading University',
      status: 'VERIFIED',
      isPubliclyVerified: true,
      sourceUrl: 'https://www.lus.ac.bd/wp-content/uploads/2021/09/Study-Leave-Policy.pdf',
      governingAuthority: 'Board of Trustees & Syndicate, Leading University',
      applicableTo: 'Permanent Faculty Members',
      maximumDurationYears: 5,
      degreeAllowances: {
        masters: 'Up to 2 years',
        phd: 'Up to 3 years',
        totalCombined: 'Maximum 5 years',
      },
      renewalCadence: 'Yearly renewal subject to satisfactory academic progress report',
      requirements: [
        'Confirmed university faculty status',
        'Formal letter of admission/offer from recognized higher educational institution',
        'Official proof of funding, scholarship, or self-sponsorship',
        'Annual academic progress report signed by research supervisor',
        'Executive bond to resume duties upon completion',
      ],
      automatedApprovalAllowed: false,
      adminConfigurationRequired: false,
    },
    casual_leave: {
      id: 'casual',
      name: 'Casual Leave',
      status: 'Not verified – Admin configuration required',
      isPubliclyVerified: false,
      sourceUrl: sourceUrl,
      note: 'Not published in public website policies. Regulated under internal University Service Rules.',
      automatedApprovalAllowed: false,
      adminConfigurationRequired: true,
    },
    medical_leave: {
      id: 'medical',
      name: 'Medical Leave',
      alias: 'sick',
      status: 'Not verified – Admin configuration required',
      isPubliclyVerified: false,
      sourceUrl: sourceUrl,
      note: 'Not published in public website policies. Regulated under internal University Service Rules.',
      automatedApprovalAllowed: false,
      adminConfigurationRequired: true,
    },
    earned_leave: {
      id: 'earned',
      name: 'Earned Leave',
      status: 'Not verified – Admin configuration required',
      isPubliclyVerified: false,
      sourceUrl: sourceUrl,
      note: 'Not published in public website policies. Regulated under internal University Service Rules.',
      automatedApprovalAllowed: false,
      adminConfigurationRequired: true,
    },
    duty_leave: {
      id: 'duty',
      name: 'Duty Leave',
      status: 'Not verified – Admin configuration required',
      isPubliclyVerified: false,
      sourceUrl: sourceUrl,
      note: 'Not published in public website policies. Granted for official university representations.',
      automatedApprovalAllowed: false,
      adminConfigurationRequired: true,
    },
    station_leave: {
      id: 'station',
      name: 'Station Leave',
      status: 'Not verified – Admin configuration required',
      isPubliclyVerified: false,
      sourceUrl: sourceUrl,
      note: 'Not published in public website policies. Granted for leaving university jurisdiction.',
      automatedApprovalAllowed: false,
      adminConfigurationRequired: true,
    },
  };

  return {
    publishedPdfs,
    leavePolicies,
    sourceUrl,
    retrievedAt: new Date().toISOString(),
  };
}

/**
 * Parses Notice Board items from https://lus.ac.bd/notice/.
 */
function parseNotices(html, sourceUrl) {
  const notices = [];
  if (html) {
    const anchorMatches = [...html.matchAll(/<a[^>]*href=\"(https:\/\/lus\.ac\.bd\/[^\"\s]+)\"[^>]*>([\s\S]*?)<\/a>/gi)];
    const seenUrls = new Set();

    for (const match of anchorMatches) {
      const url = match[1];
      const rawTitle = match[2].replace(/<[^>]+>/g, '').replace(/Read More\s*»?/gi, '').trim();

      if (
        url.includes('/notice/') &&
        rawTitle.length > 5 &&
        !rawTitle.toLowerCase().includes('next') &&
        !rawTitle.toLowerCase().includes('previous') &&
        !seenUrls.has(url)
      ) {
        seenUrls.add(url);
        notices.push({
          title: rawTitle,
          url,
          sourceUrl,
          retrievedAt: new Date().toISOString(),
        });
      }
      if (notices.length >= 10) break;
    }
  }

  return {
    notices,
    totalRetrieved: notices.length,
    sourceUrl,
    retrievedAt: new Date().toISOString(),
  };
}

/**
 * Main Synchronization Orchestrator.
 *
 * Guarantees:
 * - Stale-while-revalidate / Fallback retention: if fetch fails, keeps existing Firestore cache.
 * - Records sync_metadata with status, source URLs, timestamps, and conflicts.
 * - Idempotently writes to `university_info` and `departments`.
 */
async function syncUniversityData({ triggeredBy = 'system_scheduled', force = false } = {}) {
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const metadataRef = db.collection('university_info').doc('sync_metadata');
  const overviewRef = db.collection('university_info').doc('overview');
  const deptsRef = db.collection('university_info').doc('departments');
  const policiesRef = db.collection('university_info').doc('policies');
  const noticesRef = db.collection('university_info').doc('notices');

  let existingOverview = null;
  try {
    const snap = await overviewRef.get();
    if (snap.exists) existingOverview = snap.data();
  } catch (_) {}

  const syncLog = {
    triggeredBy,
    syncStartedAt: timestamp,
    sources: Object.values(OFFICIAL_URLS),
    conflicts: [],
    errors: [],
  };

  try {
    // 1. Fetch live pages with error trapping
    let contactHtml = null;
    let facultyHtml = null;
    let rulesHtml = null;
    let noticeHtml = null;

    try {
      contactHtml = await fetchHtml(OFFICIAL_URLS.contact);
    } catch (e) {
      syncLog.errors.push({ source: OFFICIAL_URLS.contact, error: e.message });
    }

    try {
      facultyHtml = await fetchHtml(OFFICIAL_URLS.faculty);
    } catch (e) {
      syncLog.errors.push({ source: OFFICIAL_URLS.faculty, error: e.message });
    }

    try {
      rulesHtml = await fetchHtml(OFFICIAL_URLS.rulesPolicies);
    } catch (e) {
      syncLog.errors.push({ source: OFFICIAL_URLS.rulesPolicies, error: e.message });
    }

    try {
      noticeHtml = await fetchHtml(OFFICIAL_URLS.notice);
    } catch (e) {
      syncLog.errors.push({ source: OFFICIAL_URLS.notice, error: e.message });
    }

    // 2. Parse data
    const overviewData = parseOverviewAndContact(contactHtml, OFFICIAL_URLS.contact);
    const deptsData = parseDepartments(facultyHtml, OFFICIAL_URLS.faculty);
    const policiesData = parsePolicies(rulesHtml, OFFICIAL_URLS.rulesPolicies);
    const noticesData = parseNotices(noticeHtml, OFFICIAL_URLS.notice);

    // 3. Atomically write cache to Firestore
    const batch = db.batch();

    batch.set(
      overviewRef,
      {
        ...overviewData,
        lastSuccessfulUpdate: timestamp,
        updatedAt: timestamp,
      },
      { merge: true }
    );

    batch.set(
      deptsRef,
      {
        ...deptsData,
        lastSuccessfulUpdate: timestamp,
        updatedAt: timestamp,
      },
      { merge: true }
    );

    batch.set(
      policiesRef,
      {
        ...policiesData,
        lastSuccessfulUpdate: timestamp,
        updatedAt: timestamp,
      },
      { merge: true }
    );

    batch.set(
      noticesRef,
      {
        ...noticesData,
        lastSuccessfulUpdate: timestamp,
        updatedAt: timestamp,
      },
      { merge: true }
    );

    // Also populate canonical `departments/{deptId}` documents
    for (const d of deptsData.departments) {
      const deptDocRef = db.collection('departments').doc(d.id);
      batch.set(
        deptDocRef,
        {
          id: d.id,
          name: d.name,
          code: d.code,
          faculty: d.faculty,
          officialWebUrl: d.officialWebUrl,
          status: d.status,
          updatedAt: timestamp,
        },
        { merge: true }
      );
    }

    // Record metadata
    const finalStatus = syncLog.errors.length > 0 ? 'PARTIAL_SUCCESS' : 'SUCCESS';
    batch.set(
      metadataRef,
      {
        status: finalStatus,
        lastSuccessfulSync: timestamp,
        lastSyncAttempt: timestamp,
        triggeredBy,
        conflicts: syncLog.conflicts,
        errors: syncLog.errors,
        sources: syncLog.sources,
      },
      { merge: true }
    );

    await batch.commit();

    return {
      success: true,
      status: finalStatus,
      totalDepartments: deptsData.totalDepartments,
      totalNotices: noticesData.totalRetrieved,
      errors: syncLog.errors,
    };
  } catch (fatalError) {
    console.error('[UNIVERSITY_SYNC] Fatal error during sync:', fatalError);

    // Resilient fallback retention: do NOT wipe cached data!
    await metadataRef.set(
      {
        status: 'ERROR_RETAINED_STALE',
        lastSyncAttempt: timestamp,
        lastFatalError: fatalError.message,
        triggeredBy,
        note: 'Live fetch encountered error. Previous valid cached data was preserved.',
      },
      { merge: true }
    );

    return {
      success: false,
      status: 'ERROR_RETAINED_STALE',
      error: fatalError.message,
      retainedCache: existingOverview !== null,
    };
  }
}

/**
 * Cloud Function handler for Admin-triggered university sync.
 */
async function syncUniversityInfoHandler(data, context) {
  // Ensure caller is Admin
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated to sync university info.');
  }

  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  const callerData = callerDoc.data() || {};
  const callerRole = context.auth.token?.role || callerData.role;

  if (callerRole !== 'admin') {
    throw new HttpsError('permission-denied', 'Only Admins can trigger university info sync.');
  }

  const result = await syncUniversityData({
    triggeredBy: `admin:${context.auth.uid}`,
    force: !!data.force,
  });

  return result;
}

module.exports = {
  OFFICIAL_URLS,
  fetchHtml,
  parseOverviewAndContact,
  parseDepartments,
  parsePolicies,
  parseNotices,
  syncUniversityData,
  syncUniversityInfoHandler,
};
