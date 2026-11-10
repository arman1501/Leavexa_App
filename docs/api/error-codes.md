# Error Codes & Exception Taxonomy

## 1. Overview

Leavexa enforces structured, typed error handling across all client layers and backend services. Raw, cryptic exception strings are mapped into standardized error codes that provide clear diagnostic feedback while preserving institutional security (e.g., preventing email enumeration).

---

## 2. Authentication Errors: [`AuthErrorCode`](file:///Users/Arman/Desktop/leavexa/lib/services/auth_exception.dart)

Surfaced to the Flutter UI as typed [`AuthException`](file:///Users/Arman/Desktop/leavexa/lib/services/auth_exception.dart) instances:

| Error Code | HTTP Equivalent | Trigger Scenario | User-Facing SnackBar Message |
| :--- | :---: | :--- | :--- |
| `invalid-credentials` | 401 | Incorrect password or malformed login. | "Invalid email or password. Please try again." |
| `user-not-found` | 404 | Account does not exist in Firebase Auth. | "No account found with this email." |
| `email-already-in-use` | 409 | Attempting to register an already taken email. | "An account already exists for this email address." |
| `duplicate-employee-id`| 409 | Proposed Employee ID is already reserved in `employee_ids`. | "This Employee ID is already registered." |
| `weak-password` | 400 | Registration password is $< 6$ characters. | "Password is too weak. Please use at least 6 characters." |
| `pending-approval` | 403 | Faculty credentials are valid, but registration is pending admin review. | "Your account is pending admin approval. Please wait for approval." |
| `account-rejected` | 403 | Faculty registration was formally rejected by Administrator. | "Your account has been rejected. Please contact the administrator." |
| `account-inactive` | 403 | Account has been deactivated by Administrator. | "Your account is currently inactive. Please contact the administrator." |
| `missing-profile` | 404 | Firebase Auth succeeded, but no Firestore `users/{uid}` document exists. | "Your account profile was not found. Please contact the administrator." |
| `invalid-role` | 403 | User document contains an unrecognized role string. | "Your account has an invalid role. Please contact the administrator." |
| `google-no-account` | 404 | Google sign-in succeeded, but user has not registered in Leavexa. | "No account found for this Google identity. Please register first." |
| `google-sign-in-cancelled`| 499 | User closed the Google account picker dialog. | (Silent: dismissed without error snackbar) |
| `google-sign-in-failed`| 500 | Native Google Play Services or OAuth token exchange failed. | "Google Sign-In failed. Please try again." |
| `missing-id-token` | 400 | Google credential returned without an ID token. | "Failed to obtain ID token from Google." |
| `too-many-requests` | 429 | IP blocked temporarily due to brute-force attempts. | "Too many failed attempts. Please try again later." |
| `network-error` | 503 | Device offline or network connectivity lost. | "Network error. Please check your internet connection." |
| `unknown` | 500 | Unhandled internal exception. | "An unexpected error occurred. Please try again." |

---

## 3. Cloud Functions Errors (`HttpsError`)

Functions throw standard `firebase-functions/v2/https` `HttpsError` objects:

| HttpsError Code | HTTP Status | Originating Functions | Description |
| :--- | :---: | :--- | :--- |
| `unauthenticated` | 401 | All callable functions | Caller omitted a valid Firebase Auth bearer token. |
| `permission-denied` | 403 | `assertIsAdmin`, `provisionInitialAdmin` | Caller lacks `admin` privileges or supplied invalid bootstrap key. |
| `already-exists` | 409 | `provisionInitialAdmin`, `createStaffAccount` | System is already bootstrapped, or Employee ID is already in use. |
| `not-found` | 404 | `approveFacultyRegistration`, `rejectFacultyRegistration` | Target user profile does not exist in `users/{targetUid}`. |
| `invalid-argument` | 400 | `createStaffAccount`, `setUserActive` | Required input parameters are missing, malformed, or of invalid type. |
| `failed-precondition` | 412 | `setUserActive`, `approveFacultyRegistration` | Precondition failed (e.g. Admin deactivating self, or approving non-faculty). |
| `aborted` | 409 | `leaves.js` deduction transaction | Concurrency contention or retry race condition. |

---

## 4. Firebase Storage Validation Errors: [`StorageValidationException`](file:///Users/Arman/Desktop/leavexa/lib/services/storage_service.dart)

Thrown synchronously before network upload by `StorageService`:

| Exception Message Pattern | Cause |
| :--- | :--- |
| `"Invalid document format (.{ext}). Allowed: PDF, JPG, JPEG, PNG."` | Extension is not in approved leave document whitelist. |
| `"Document size ({size} MB) exceeds the maximum limit of 10 MB."` | File size $> 10 \times 1024 \times 1024$ bytes. |
| `"File signature does not match any accepted document or image type..."` | Binary magic number inspection detected disguised executable (`MZ`) or script (`#!/`). |
| `"File extension ({ext}) does not match actual {type} content."` | Extension mismatch (e.g., PNG binary data renamed with `.pdf` extension). |
| `"Invalid image format (.{ext}). Allowed: JPG, JPEG, PNG, WEBP."` | Profile photo extension is not an accepted image format. |
| `"Profile image ({size} MB) exceeds the maximum limit of 5 MB."` | Avatar image size $> 5 \times 1024 \times 1024$ bytes. |
| `"File is corrupted or too small to verify."` | Selected file has fewer than 3 bytes. |

---

## 5. Security Rules Rejections: `PERMISSION_DENIED`

Triggered by Firestore or Cloud Storage security rules engines when an unauthorized client read/write is evaluated:
- **Code**: `cloud_firestore/permission-denied` (gRPC Code 7)
- **Common Triggers**:
  - Faculty attempting to read another faculty member's application or balance.
  - Department Head attempting to review an application belonging to another department.
  - Registrar attempting to approve an application that is still in `pending` status.
  - Client attempting to write directly to `audit_logs`, `system_config`, or `leave_balances`.
  - Faculty attempting to delete an attachment after its leave application has been submitted.
