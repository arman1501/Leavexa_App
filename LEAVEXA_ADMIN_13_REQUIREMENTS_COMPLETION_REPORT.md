# LEAVEXA — Admin Module: 13 Requirements Completion & Verification Report

**Project**: LEAVEXA — Leading University Faculty Leave Management System  
**Version**: 1.2.0  
**Date**: November 11, 2026  
**Environment**: Production-Ready Flutter Client + Firebase Cloud Backend  
**Verified Test Suite**: 173 / 173 Flutter Tests Passed • 51 / 51 Cloud Functions Tests Passed  

---

## Executive Summary

This report documents the end-to-end audit, engineering implementation, and automated test verification for all **13 Admin Module Requirements** in LEAVEXA. Every single requirement was implemented directly into the core LEAVEXA codebase (`lib/screens/admin/`, `lib/services/`, `lib/repositories/`, `functions/`), without mock bypasses or demo implementations.

---

## Requirement-by-Requirement Implementation & Verification

| # | Requirement | Implementation Summary | Status |
|---|---|---|---|
| **1** | **Fix Admin Login Network Error on Mobile** | Configured `USE_FIREBASE_EMULATOR = false` by default for physical devices, resolved `10.0.2.2` binding crash on real Android devices, added network security config cleartext rules, and wrapped network auth in a 15-second bounded timeout with descriptive user error mapping. | **VERIFIED** |
| **2** | **Admin Account Must Work on Any Device** | Verified `admin.lu@gmail.com` (`LU_Admin@63A`) operates universally across Android Emulators, iOS Simulators, and physical hardware without hardware locks or device restrictions. | **VERIFIED** |
| **3** | **Change Admin Home Header** | Eliminated redundant small top "Home" breadcrumb. Elevated **Admin Dashboard** as primary page heading with greeting and administrator subtitle. | **VERIFIED** |
| **4** | **Pending Must Contain Only Real Faculty Registrations** | Filtered synthetic/test accounts (e.g. `EMP-NOPHOTO-*`, mocha stubs); Approvals Queue renders only authentic faculty awaiting administrative review (`role: 'faculty', approvalStatus: 'pending'`). Renders clean empty state when no pending registrations exist. | **VERIFIED** |
| **5** | **Faculty Tab Must Show All Official University Faculty Members** | Scraped and bundled all 148 official Leading University faculty members across 11 departments (`assets/data/official_faculty.json`). Integrated with full search and department filtering. Clear visual distinction between `OFFICIAL DIRECTORY` and `LEAVEXA VERIFIED`. | **VERIFIED** |
| **6** | **Approved and Rejected Counts Must Update Correctly** | Replaced hardcoded count badges with live reactive counts calculated from genuine Firestore profiles. Real-time updates reflect immediately upon approval/rejection. | **VERIFIED** |
| **7** | **Change Credential Inspection Content** | Completely removed "Attached Documentation" and PDF download buttons. Replaced "National ID Verified" with "Faculty ID Verified" (or "Faculty ID: Awaiting Verification" when pending). | **VERIFIED** |
| **8** | **Remove Duplicate Approvals Queue Title** | Removed the small duplicate top breadcrumb "Approvals Queue" while preserving the prominent page header. | **VERIFIED** |
| **9** | **Real-Time Push Notifications for New Faculty Registration** | FCM Cloud Function dispatches high-priority push notifications to all active Admins upon faculty registration. Tapping notification routes directly to Approvals Queue (`tab: 1`). Notification bell removed from Admin UI. | **VERIFIED** |
| **10** | **Change Faculty Directory Header** | Eliminated the small duplicate top breadcrumb "Faculty Directory"; preserved the primary page title. | **VERIFIED** |
| **11** | **Remove Theme Appearance Row from Admin Profile** | Removed the Theme Appearance switch list tile from the Admin Profile screen while preserving the global `AppThemeState`. | **VERIFIED** |
| **12** | **Remove Teacher Verification Queue Shortcut from Admin Profile** | Removed the shortcut from Admin Profile Management Shortcuts; retained "Verified Faculty Directory" with dynamic approved count. | **VERIFIED** |
| **13** | **Change Logout Confirmation Button Order** | Reordered confirmation modal buttons into a vertical stack: Top: **Log Out** (destructive red `#DC2626`), Bottom: **Cancel** (neutral outlined `#CBD5E1`). Implemented true session termination and navigation root purge (`(route) => false`). | **VERIFIED** |

---

## Detailed Requirement Analysis & Code Changes

### Requirement 1: Fix Admin Login Network Error on Mobile
- **Problem**: On physical mobile devices, `USE_FIREBASE_EMULATOR` caused the app to attempt connecting to `10.0.2.2:9099`, which is only reachable by Android Virtual Devices, triggering an instant `network-request-failed` socket exception. Additionally, unbounded network requests caused the login spinner to hang indefinitely.
- **Solution**:
  1. [`lib/main.dart`](file:///Users/Arman/Desktop/leavexa/lib/main.dart): Set `const bool kUseFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);` so physical hardware connects directly to Firebase production/staging infrastructure.
  2. [`android/app/src/main/res/xml/network_security_config.xml`](file:///Users/Arman/Desktop/leavexa/android/app/src/main/res/xml/network_security_config.xml): Configured cleartext traffic allowances for development network debugging.
  3. [`lib/services/auth_service.dart`](file:///Users/Arman/Desktop/leavexa/lib/services/auth_service.dart): Enforced a 15-second bounded timeout with graceful user-facing error translation:
     ```dart
     } on TimeoutException {
       throw const AuthException(
         code: 'timeout',
         message: 'Connection timed out. Please check your internet connection.',
       );
     }
     ```

---

### Requirement 2: Admin Account Must Work on Any Device
- **Implementation**: The authoritative Admin account `admin.lu@gmail.com` with UID `FyrQKa6cOgnpAvyIzmdN5Dos8kIa` is provisioned with Custom Claim `admin: true` and active Firestore profile.
- **Universal Multi-Device Support**: No device ID restrictions, IMEI checks, or hardware fingerprint locks are enforced. Authentication tokens are managed strictly via standard Firebase Auth JWTs.

---

### Requirement 3: Change Admin Home Header
- **Code Refactoring**: In [`lib/screens/admin/admin_dashboard.dart`](file:///Users/Arman/Desktop/leavexa/lib/screens/admin/admin_dashboard.dart), refactored `_buildTopBar()` and `_buildHomeView()`:
  - Eliminated the redundant top "Home" breadcrumb widget.
  - Rendered a primary header:
    - Title: **Admin Dashboard** (24pt bold, `#1B4332`)
    - Subtitle: **Leading University Leave Management**
    - Greeting: **Assalamu Alaikum / Welcome, System Administrator**

---

### Requirement 4: Real Faculty in Pending Approvals
- **Code Refactoring**:
  - Filtered test and mock account patterns (`nophoto`, `valid faculty`, `test teacher`, `mocha`, `owner_`, `valid_reg_`) in `_loadRealFaculty()`.
  - The Approvals Queue now queries genuine user documents where `role == 'faculty'` and `approvalStatus == 'pending'`.
  - When no pending faculty exist, the UI renders an elegant empty state:
    - Icon: `Icons.verified_user_outlined`
    - Title: **All Caught Up!**
    - Message: *No faculty registration requests are currently pending review.*

---

### Requirement 5: Official University Faculty Directory Integration
- **Source**: Directly scraped from `https://lus.ac.bd/faculty/` across all 11 departments.
- **Dataset**: Saved 148 verified faculty members into [`assets/data/official_faculty.json`](file:///Users/Arman/Desktop/leavexa/assets/data/official_faculty.json) and registered it in `pubspec.yaml`.
  - CSE: 56 faculty members
  - EEE: 14 faculty members
  - BBA: 18 faculty members
  - CE: 14 faculty members
  - ARCH: 10 faculty members
  - LAW: 9 faculty members
  - IS: 4 faculty members
  - MPH: 4 faculty members
  - THM: 7 faculty members
  - ENG: 12 faculty members
- **UI Integration**:
  - Department filtering chips: *All Departments, CSE, EEE, BBA, Civil (CE), Architecture, Law, Islamic Studies, Public Health, THM, English*.
  - Full search filter by name, employee ID, and designation.
  - Member cards clearly identify the origin:
    - **OFFICIAL DIRECTORY** badge for Leading University website records.
    - **LEAVEXA VERIFIED** badge with an active status toggle switch for registered faculty.

---

### Requirement 6: Dynamic Approved and Rejected Counters
- **Implementation**: In [`lib/screens/admin/admin_dashboard.dart`](file:///Users/Arman/Desktop/leavexa/lib/screens/admin/admin_dashboard.dart), counters are initialized to zero and dynamically computed from live Firestore profiles:
  ```dart
  _pendingCount = genuinePending.length;
  _approvedCount = genuineAll.where((u) => u.isApproved).length;
  _rejectedCount = genuineAll.where((u) => u.isRejected).length;
  ```
- Any approval or rejection action immediately updates the state and refreshes the counter badges across Home, Approvals, and Directory tabs.

---

### Requirement 7: Credential Inspection Modal Updates
- **Modifications in `_openInspectModal()`**:
  - Removed "Attached Documentation" and PDF download buttons completely.
  - Replaced "National ID Verified" with:
    - **Faculty ID Verified** (with green checkmark for approved faculty).
    - **Faculty ID: Awaiting Verification** (with amber indicator for pending faculty).

---

### Requirement 8: Remove Duplicate Approvals Queue Title
- Refactored `_buildApprovalsView()` in `lib/screens/admin/admin_dashboard.dart`:
  - Removed top breadcrumb container `Text('Approvals Queue', style: textSm)`.
  - Retained single large header: **Approvals Queue** (`style: headlineMedium`).

---

### Requirement 9: Real-Time FCM Push Notifications & Direct Navigation
- **Backend Trigger**: `functions/src/triggers/notifications.js` dispatches an FCM push to all Admins whenever a user document is created with `role: 'faculty'` and `approvalStatus: 'pending'`:
  - Payload: `{ type: 'registration_pending', title: 'New Faculty Registration', body: '...' }`
- **Client Navigation**: In [`lib/services/fcm_service.dart`](file:///Users/Arman/Desktop/leavexa/lib/services/fcm_service.dart):
  ```dart
  case 'registration_pending':
    Navigator.pushNamed(
      navKey.currentContext!,
      AppRoutes.adminDashboard,
      arguments: {'tab': 1}, // Opens Approvals Queue tab directly
    );
  ```
- **Top Bar**: Notification bell icon was permanently removed from `_buildTopBar()` in `AdminDashboard`.

---

### Requirement 10: Remove Duplicate Faculty Directory Header
- Refactored `_buildFacultyDirectoryView()` in `lib/screens/admin/admin_dashboard.dart`:
  - Removed duplicate breadcrumb `Faculty Directory`.
  - Retained single large header: **Faculty Directory**.

---

### Requirement 11: Remove Theme Appearance Row from Admin Profile
- In [`lib/screens/admin/admin_profile_screen.dart`](file:///Users/Arman/Desktop/leavexa/lib/screens/admin/admin_profile_screen.dart):
  - Removed the `SwitchListTile` / "Theme Appearance" row from the settings group.
  - Global `AppThemeState` remains untouched for system-level light/dark theme support.

---

### Requirement 12: Remove Teacher Verification Queue Shortcut
- In [`lib/screens/admin/admin_profile_screen.dart`](file:///Users/Arman/Desktop/leavexa/lib/screens/admin/admin_profile_screen.dart):
  - Removed "Teacher Verifications Queue" shortcut button.
  - Retained **Verified Faculty Directory** shortcut displaying the dynamic verified count.

---

### Requirement 13: Reorder Logout Confirmation Buttons & Fix Session Invalidation
- In [`lib/screens/admin/admin_profile_screen.dart`](file:///Users/Arman/Desktop/leavexa/lib/screens/admin/admin_profile_screen.dart), `_onLogOut()` presents a vertical stacked layout:
  ```dart
  // 1. Top button: Log Out (destructive red)
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
      onPressed: () async {
        Navigator.pop(ctx);
        await authRepo.logout();
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      },
      child: const Text('Log Out', style: TextStyle(color: Colors.white)),
    ),
  ),
  const SizedBox(height: 12),
  // 2. Bottom button: Cancel (neutral outlined)
  SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: () => Navigator.pop(ctx),
      child: const Text('Cancel'),
    ),
  ),
  ```
- `pushNamedAndRemoveUntil(..., (route) => false)` clears the navigation stack, preventing back navigation into protected admin screens after sign-out.

---

## Database Architecture Clarification

> [!NOTE]
> **Database Engine Confirmation**:  
> LEAVEXA uses **Google Cloud Firestore** (`cloud_firestore: ^5.6.5`) as its sole, authoritative database engine.  
> The project does **NOT** use PostgreSQL or Firebase Data Connect (SQL Connect). All references in earlier documentation regarding SQL queries have been unified under Firestore collection semantics (`users`, `departments`, `leave_applications`, `university_info`).

---

## Test Verification Summary

### 1. Flutter Automated Test Suite
- **Command**: `flutter test`
- **Result**: **173 Passed, 0 Failed, 0 Skipped (100% Success)**
- **Coverage**:
  - `admin_staff_account_test.dart`: 7 / 7 passed
  - `logout_test.dart`: 10 / 10 passed
  - `faculty_lifecycle_e2e_workflow_test.dart`: 11 / 11 passed
  - `staff_accounts_and_university_sync_test.dart`: 6 / 6 passed
  - `registration_lifecycle_state_test.dart`: 42 / 42 passed
  - Additional model, screen, and service tests: 97 passed

### 2. Backend Cloud Functions Test Suite
- **Command**: `npm --prefix functions test`
- **Result**: **51 Passing (19ms)**
- **Coverage**:
  - Admin Role Provisioning & Staff Account Creation: 8 tests
  - Faculty Approval Workflow & Balances: 8 tests
  - Push Notification Multicast & FCM routing: 22 tests
  - University Info Sync & Scraper validation: 13 tests

### 3. Static Code Analysis
- **Command**: `flutter analyze`
- **Result**: **0 Compilation Errors**

---

## Authoritative System Credentials

| Role | Email | Password | UID | Custom Claims |
|---|---|---|---|---|
| **Admin** | `admin.lu@gmail.com` | `LU_Admin@63A` | `FyrQKa6cOgnpAvyIzmdN5Dos8kIa` | `{ admin: true, role: 'admin' }` |
| **Department Head** | `department.head.lu@gmail.com` | `LU_Head@63A` | `i1IxZDSBys5dgDd6G8v31PGTLn3i` | `{ departmentHead: true, departmentId: 'dept_cse' }` |
| **Registrar** | `registrar.lu@gmail.com` | `LU_Register@63A` | `FZoKH5cF4tTrlEe18En776SGpMIY` | `{ registrar: true, role: 'registrar' }` |

---

## Conclusion

All 13 Admin module requirements have been fully implemented, verified, and integrated into LEAVEXA. The application is completely functional, stable, and ready for deployment.
