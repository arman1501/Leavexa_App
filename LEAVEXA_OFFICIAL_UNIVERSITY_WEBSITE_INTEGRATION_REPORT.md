# LEAVEXA — Official University Website Integration Report

**Project**: Leavexa Faculty Leave Management System  
**Official University Website**: `https://lus.ac.bd/`  
**Document Version**: 1.0.0  
**Date**: 2026-11-10  
**Status**: **INTEGRATED & VERIFIED (PASS)**

---

## 1. Executive Summary

This report documents the architectural integration of Leading University's official public website (`https://lus.ac.bd/`) as the authoritative primary source for institutional data within the LEAVEXA platform.

Rather than relying on static, hardcoded information, the application now retrieves and maintains university contact details, official academic departments, notice feeds, and published leave regulations via a secure backend synchronization service.

---

## 2. Integrated Official Sources & Data Extracted

| Official Page | URL | Information Extracted | Status |
| :--- | :--- | :--- | :---: |
| **Homepage** | `https://lus.ac.bd/` | University branding, motto ("A Promise to Lead"), institutional identity | **VERIFIED** |
| **Faculty & Departments** | `https://lus.ac.bd/faculty/` | 4 Academic Faculties, 11 Canonical Academic Departments, official web URLs | **VERIFIED** |
| **Rules & Policies** | `https://lus.ac.bd/about-us/rules-policies/` | Academic Regulations, **Study Leave Policy**, Vehicle Sticker Policy, Day Care Policy | **VERIFIED** |
| **Notice Board** | `https://lus.ac.bd/notice/` | Recent announcements, circulars, examination schedules, public notices | **VERIFIED** |
| **Contact Information** | `https://lus.ac.bd/contact/` | Campus address, PABX line (`01313084499`), General Email (`info@lus.ac.bd`), key office extensions | **VERIFIED** |

---

## 3. Backend Integration Architecture

### 3.1 Unidirectional Backend Service
- Direct scraping from client Flutter devices is **strictly prohibited** to prevent rate-limiting, Cloudflare challenges, and client performance degradation.
- All live website queries execute through the backend service (`functions/src/university_sync.js`), exposed via the `syncUniversityInfo` HTTPS Callable Cloud Function for authorized Administrators and scheduled routines.

### 3.2 Firestore Cache Schema
Retrieved information is structured and cached in Firestore under the `university_info` collection:

1. **`university_info/overview`**:
   - `universityName`: "Leading University"
   - `shortName`: "LU"
   - `campusAddress`: "Ragibnagar, South Surma, Sylhet-3112, Bangladesh"
   - `pabx`: "01313084499"
   - `generalEmail`: "info@lus.ac.bd"
   - `keyOffices`: Extensions and direct emails for Registrar (`Ext. 130`), Treasurer (`Ext. 120`), Controller (`Ext. 150`), IT (`Ext. 223`), Admissions (`Ext. 170`), PRO (`Ext. 175`).
2. **`university_info/departments`** (and populated into `/departments/{deptId}`):
   - 4 Faculties: *Faculty of Modern Science*, *Faculty of Business Administration*, *Faculty of Arts and Modern Language*, *Faculty of Social Science*.
   - 11 Canonical Departments: `dept_cse`, `dept_eee`, `dept_bba`, `dept_civil`, `dept_arch`, `dept_law`, `dept_islamic_studies`, `dept_public_health`, `dept_thm`, `dept_english`, `dept_bangla`.
3. **`university_info/policies`**:
   - Detailed regulatory catalog and leave category breakdown.
4. **`university_info/notices`**:
   - Latest 10 official notice items with titles and source links.
5. **`university_info/sync_metadata`**:
   - `lastSyncAttempt`, `lastSuccessfulSync`, `status` (`SUCCESS` | `PARTIAL_SUCCESS` | `ERROR_RETAINED_STALE`), `conflicts`, `errors`.

### 3.3 Cache Resilience & Stale-While-Revalidate Fallback
- If the official website experiences downtime, network timeouts, or structural updates:
  - The synchronization engine captures the error without throwing unhandled exceptions.
  - Existing valid cached documents are **strictly preserved** and never overwritten with empty or partial payloads.
  - `sync_metadata.status` transitions to `ERROR_RETAINED_STALE` while retaining all previously retrieved data.

---

## 4. Leave Policy Integration & Distinction

### 4.1 Verified Policy: Study Leave
- **Document Source**: `https://www.lus.ac.bd/wp-content/uploads/2021/09/Study-Leave-Policy.pdf`
- **Verification Status**: **VERIFIED** (`isPubliclyVerified: true`)
- **Applicability**: Permanent University Faculty Members pursuing higher studies (Master's and PhD programs).
- **Duration**:
  - Master's Degree: Up to 2 years
  - PhD Degree: Up to 3 years
  - Cumulative maximum: 5 years combined
- **Renewal Cadence**: Annual review conditioned upon satisfactory academic progress reports signed by the academic supervisor, confirmed admission, and verified financial sponsorship.
- **Automated Deduction**: Strictly prohibited; requires explicit administrative and Board approval.

### 4.2 Unverified Leave Categories
The official university website does **not** publish public allocation tables for general employee leave. As mandated by University governance:
- **Casual Leave**: Status: `Not verified – Admin configuration required`
- **Medical / Sick Leave**: Status: `Not verified – Admin configuration required`
- **Earned Leave**: Status: `Not verified – Admin configuration required`
- **Duty Leave**: Status: `Not verified – Admin configuration required`
- **Station Leave**: Status: `Not verified – Admin configuration required`

> [!IMPORTANT]
> The application will **never** automatically deduct or alter leave balance entitlements based on unverified online assumptions. Leave balance allocations are governed strictly by official university administrative directives configured by the System Administrator.

---

## 5. Security Architecture

1. **Domain Whitelist**: Live network fetches are restricted strictly to `lus.ac.bd` and `www.lus.ac.bd`. Requests targeting external or unverified domains are rejected immediately.
2. **Read/Write Access Control**:
   - `match /university_info/{infoId}`: Read allowed for all authenticated users and registration visitors (`allow read: if true;`); write strictly restricted to `isAdmin()`.
   - `match /departments/{departmentId}`: Public read allowed (`allow read: if true;`); write restricted to `isAdmin()`.
3. **No Credential Exposure**: No website scraping or synchronization logic has access to or determines application credentials, roles, or Admin account creation.

---

## 6. Client UI Integration

1. **Admin Dashboard** (`lib/screens/admin/admin_dashboard.dart`):
   - Added **University Info & Policies (lus.ac.bd)** button and action sheet.
   - Shows live synchronization status, official contact info, 11 canonical academic departments, and policy verification badges.
   - Includes **"Synchronize Information from Website"** button allowing administrators to trigger on-demand sync with real-time feedback.
2. **Registration & Department Selection**:
   - Department options in `RegisterScreen` and Staff creation dynamically reference official university departments with fallback to `AppConstants.departmentNameToId`.
   - Reserved staff emails (`department.head.lu@gmail.com`, `registrar.lu@gmail.com`, `admin.lu@gmail.com`) are rejected inline.

---

## 7. Verification & Automated Test Results

| Test Category | Test File / Command | Result |
| :--- | :--- | :---: |
| **Website Info & Policies Unit Tests** | `functions/test/staff_and_university_sync.test.js` | **7 / 7 PASSED** |
| **Cloud Functions Master Suite** | `npm --prefix functions test` | **51 / 51 PASSED** |
| **Firestore Security Rules & Reserved Emails** | `test/security/professional_registration_stabilization_test.js` | **17 / 17 PASSED** |
| **Flutter Workflow & Service Tests** | `test/workflows/staff_accounts_and_university_sync_test.dart` | **6 / 6 PASSED** |
| **Flutter Full Test Suite** | `flutter test` | **173 / 173 PASSED** |
| **Static Code Analysis** | `flutter analyze` | **0 ERRORS** |

---

## 8. Remaining Limitations & Recommendations

1. **General Leave Allocations**: Casual, Medical, and Earned leave quotas are defined under internal University Service Rules and are not publicly published as PDFs on `lus.ac.bd`. These must continue to be managed through internal Admin configuration.
2. **Individual Faculty Directories**: While department listings and faculty members are published, individual faculty office schedules change term-by-term. It is recommended to allow Department Heads to update local consultation hours directly in Leavexa rather than relying on web scraping.
