# Firebase Storage API Specification

## 1. Overview

The Leavexa Storage API provides secure, validated object storage for academic leave attachments and faculty profile photos. It is implemented in [`lib/services/storage_service.dart`](file:///Users/Arman/Desktop/leavexa/lib/services/storage_service.dart) and enforced by [`storage.rules`](file:///Users/Arman/Desktop/leavexa/storage.rules).

---

## 2. Storage Path Hierarchy

```
/b/{default-bucket}/o/
├── leave_documents/
│   └── {applicantUid}/
│       └── {applicationId}/
│           └── {sanitized_filename}.(pdf|png|jpg|jpeg)
│
└── profile_images/
    └── {uid}/
        └── avatar_{timestamp}.(jpg|jpeg|png|webp)
```

---

## 3. Storage Operations: [`StorageService`](file:///Users/Arman/Desktop/leavexa/lib/services/storage_service.dart)

### A. Upload Leave Document: `uploadLeaveDocument`

Uploads a supporting document for an academic leave application with client-side magic number validation and progress tracking.

- **Dart Interface**:
  ```dart
  Future<UploadResult> uploadLeaveDocument({
    required String uid,
    required String applicationId,
    required File file,
    void Function(double progress)? onProgress,
  })
  ```
- **Validation Pipeline**:
  1. Extension check: Must be in `['.pdf', '.png', '.jpg', '.jpeg']`.
  2. Size check: File size must be $\le 10 \text{ MB}$ (`10 * 1024 * 1024` bytes).
  3. Binary magic number detection via `detectRealMimeType(file)`.
  4. Consistency check: Binary format must match extension (e.g. rejecting executable or shell script disguised with `.pdf` extension).
- **Target Storage Path**: `leave_documents/{uid}/{applicationId}/{safeFileName}`
- **Metadata Tagging**: `SettableMetadata(contentType, customMetadata: {'uploadedBy', 'applicationId', 'originalName', 'size'})`
- **Output ([`UploadResult`](file:///Users/Arman/Desktop/leavexa/lib/services/storage_service.dart))**:
  - `downloadUrl`: Direct HTTPS download URL with access token.
  - `storagePath`: Bucket storage path.
  - `fileName`: Original file name.
  - `fileSize`: File length in bytes.
  - `contentType`: Validated MIME type (`application/pdf`, `image/png`, `image/jpeg`).
- **Exceptions**: Throws `StorageValidationException` if validation fails.

---

### B. Upload Profile Image: `uploadProfileImage`

Uploads a faculty profile avatar with automatic cleanup of previous images.

- **Dart Interface**:
  ```dart
  Future<String> uploadProfileImage({
    required String uid,
    required File file,
    String? previousPhotoUrl,
    void Function(double progress)? onProgress,
  })
  ```
- **Validation Pipeline**:
  1. Extension check: Must be in `['.jpg', '.jpeg', '.png', '.webp']`.
  2. Size check: File size must be $\le 5 \text{ MB}$ (`5 * 1024 * 1024` bytes).
  3. Binary magic number detection via `detectRealMimeType(file)`. Must begin with `image/`.
- **Target Storage Path**: `profile_images/{uid}/avatar_{timestamp}.{ext}`
- **Automatic Cleanup**: If `previousPhotoUrl` contains `'profile_images'`, deletes the previous avatar object to prevent orphaned storage accumulation.
- **Output**: Returns the new download URL string.

---

### C. Magic Number Sniffing: `detectRealMimeType`

Reads the leading 16 bytes of a file via `RandomAccessFile.read(16)` to determine its true binary signature, preventing executable masquerading or extension spoofing:
- **Minimum file size check**: Requires at least 3 bytes; smaller files throw `StorageValidationException('File is corrupted or too small to verify.')`.
- **PDF**: Inspects the first 5 bytes (`bytes.length >= 5`).
  - Expected signature: `[0x25, 0x50, 0x44, 0x46, 0x2D]` (`%PDF-`).
  - Returns: `'application/pdf'`.
- **PNG**: Inspects the first 8 bytes (`bytes.length >= 8`).
  - Expected signature: `[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]` (`\x89PNG\r\n\x1a\n`).
  - Returns: `'image/png'`.
- **JPEG**: Inspects the first 3 bytes (`bytes.length >= 3`).
  - Expected signature: `[0xFF, 0xD8, 0xFF]`.
  - Returns: `'image/jpeg'`.
- **WEBP**: Inspects 12 bytes (`bytes.length >= 12`).
  - Bytes `0..3`: `[0x52, 0x49, 0x46, 0x46]` (`RIFF`).
  - Bytes `4..7`: 4-byte little-endian container file length (skipped).
  - Bytes `8..11`: `[0x57, 0x45, 0x42, 0x50]` (`WEBP`).
  - Returns: `'image/webp'`.
- **Exception**: Throws `StorageValidationException` if the binary signature does not match any of the four accepted MIME formats.
- **Allowed Extension Envelopes**:
  - `uploadLeaveDocument`: Validates extension against `allowedDocumentExtensions` (`['.pdf', '.png', '.jpg', '.jpeg']`), max size 10 MB.
  - `uploadProfileImage`: Validates extension against `allowedImageExtensions` (`['.jpg', '.jpeg', '.png', '.webp']`), max size 5 MB, and requires detected MIME type to start with `image/`.

---

### D. Safe Object Deletion: `deleteByUrl` & `deleteByPath`

- **By URL**: `Future<void> deleteByUrl(String downloadUrl)`
- **By Path**: `Future<void> deleteByPath(String storagePath)`
- Best-effort execution; catches and silences not-found errors during cleanup.

---

## 4. Storage Security Rules Enforcement ([`storage.rules`](file:///Users/Arman/Desktop/leavexa/storage.rules))

| Resource | Operation | Permissions & Rules |
| :--- | :---: | :--- |
| **`leave_documents/`** | **Read** | • Applicant faculty (`isOwner(applicantUid)`)<br>• Registrar & Admin (university-wide)<br>• Department Head **only** if holding a valid non-empty `departmentId` claim matching the application's Firestore `departmentId`. |
| | **Create** | • Applicant only (`isOwner(applicantUid)`)<br>• `resource == null` (prevent overwriting)<br>• Size $\le 10 \text{ MB}$ (`isUnder10MB()`)<br>• `contentType` matches PDF or JPEG/PNG (`isValidDocumentType()`). |
| | **Update** | ❌ Denied (`allow update: if false;`) to prevent retroactive tampering. |
| | **Delete** | • Admin (for administrative cleanup)<br>• Applicant **only** if application is not yet submitted or in `draft` / `cancelled` state. **Blocked once submitted** (`pending`, `forwarded`, `approved`, `rejected`). |
| **`profile_images/`** | **Read** | Authenticated university users (`request.auth != null`). |
| | **Create/Update**| Owner user or Admin, size $\le 5 \text{ MB}$ (`isUnder5MB()`), image MIME type (`isValidImageType()`). |
| | **Delete** | Owner user or Admin. |
| **All Other Paths** | **All** | ❌ Denied by default (`allow read, write: if false;`). |

---

## 5. File Security Limitations & Recommended Antivirus Architecture

### Current Client-Side & Security Rule Guarantees
- The client application checks magic number signatures across the leading 16 bytes, preventing simple executable renaming attacks (e.g. uploading a `.exe` or `.sh` script disguised with a `.pdf` extension).
- `storage.rules` validates declared MIME types and enforces strict file size boundaries (10 MB for attachments, 5 MB for avatars).

### Inherent Limitation
- Client-side sniffing and declarative Storage Security Rules cannot execute deep payload inspection, heuristic malware scanning, or macro detection (e.g., weaponized embedded JavaScript inside PDF streams or malicious steganography inside image bitstreams).
- **Correction Note**: *Google Cloud Web Risk API* is a URL reputation and web threat intelligence service designed for screening web links against social engineering and malware distribution lists; it is **not** an antivirus engine for inspecting binary document uploads.

### Recommended Production Server-Side Scanning Architecture
To achieve enterprise-grade malware defense without degrading client upload latency:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│              RECOMMENDED ASYNCHRONOUS STORAGE SCANNING ARCHITECTURE              │
└─────────────────────────────────────────────────────────────────────────────────┘
  1. Client Upload       ──>  Upload to quarantine bucket: gs://leavexa-quarantine/
  2. Cloud Storage Event ──>  Eventarc triggers Cloud Run onObjectFinalized event
  3. Antivirus Engine    ──>  Cloud Run container running ClamAV daemon (freshclam signatures)
                              or VirusTotal File Scan API v3
  4. Inspection Outcome  ──>  • CLEAN: Moves object to gs://leavexa-prod/
                                Marks Firestore leave_application.documentScan = 'CLEAN'
                              • INFECTED: Deletes quarantine object
                                Writes security incident log to audit_logs
                                Updates leave_application with SCAN_FAILED_INFECTED
```

- **Alternative (Managed)**: Deploy the official Firebase Extension **`firebase/storage-clamav`** (Virus Scanning with ClamAV), which automatically isolates infected files and manages scanning pipelines using Cloud Run and Eventarc.
