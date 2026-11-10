// ─────────────────────────────────────────────────────────────────────────────
//  storage_service.dart  –  Firebase Storage Centralized Document Service
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class UploadResult {
  final String downloadUrl;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String contentType;

  const UploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.contentType,
  });
}

class StorageValidationException implements Exception {
  final String message;
  const StorageValidationException(this.message);

  @override
  String toString() => message;
}

class StorageService {
  final FirebaseStorage? _storage;

  StorageService({FirebaseStorage? storage}) : _storage = storage;

  FirebaseStorage get _storageInstance => _storage ?? FirebaseStorage.instance;

  static const int maxDocumentSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxProfileImageSizeBytes = 5 * 1024 * 1024; // 5 MB

  static const List<String> allowedDocumentExtensions = [
    '.pdf',
    '.png',
    '.jpg',
    '.jpeg',
  ];

  static const List<String> allowedImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  ];

  // ── Real Binary MIME Detection & Magic Header Validation ──────────────────

  /// Inspects the file's binary header (magic numbers) to determine the true MIME type.
  /// Does not trust the file extension or client-provided header alone.
  static Future<String> detectRealMimeType(File file) async {
    List<int> bytes;
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        bytes = await raf.read(16);
      } finally {
        await raf.close();
      }
    } catch (e) {
      throw StorageValidationException('Failed to inspect file header: $e');
    }

    if (bytes.length < 3) {
      throw const StorageValidationException(
        'File is corrupted or too small to verify.',
      );
    }

    // 1. PDF signature: %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D) {
      return 'application/pdf';
    }

    // 2. PNG signature: \x89PNG\r\n\x1a\n
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    // 3. JPEG signature: \xFF\xD8\xFF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // 4. WEBP signature: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50) { // P
      return 'image/webp';
    }

    throw const StorageValidationException(
      'File signature does not match any accepted document or image type (PDF, PNG, JPEG, WEBP).',
    );
  }

  // ── Document Upload ────────────────────────────────────────────────────────

  /// Uploads a leave application attachment to Firebase Storage with validation.
  ///
  /// Target Path: `leave_documents/{uid}/{applicationId}/{filename}`
  Future<UploadResult> uploadLeaveDocument({
    required String uid,
    required String applicationId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = p.basename(file.path);
    final ext = p.extension(file.path).toLowerCase();
    final fileSize = await file.length();

    // 1. Validation: Extension
    if (!allowedDocumentExtensions.contains(ext)) {
      throw StorageValidationException(
        'Invalid document format ($ext). Allowed: PDF, JPG, JPEG, PNG.',
      );
    }

    // 2. Validation: File size (<= 10MB)
    if (fileSize > maxDocumentSizeBytes) {
      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      throw StorageValidationException(
        'Document size ($sizeMb MB) exceeds the maximum limit of 10 MB.',
      );
    }

    // 3. Validation: Real binary MIME type detection (magic numbers)
    final realMime = await detectRealMimeType(file);

    // Verify consistency between extension and actual binary format
    if (realMime == 'application/pdf' && ext != '.pdf') {
      throw StorageValidationException(
        'File extension ($ext) does not match actual PDF content.',
      );
    }
    if (realMime == 'image/png' && ext != '.png') {
      throw StorageValidationException(
        'File extension ($ext) does not match actual PNG content.',
      );
    }
    if (realMime == 'image/jpeg' && ext != '.jpg' && ext != '.jpeg') {
      throw StorageValidationException(
        'File extension ($ext) does not match actual JPEG content.',
      );
    }
    if (realMime == 'image/webp') {
      throw const StorageValidationException(
        'WEBP format is not allowed for official leave documents. Allowed: PDF, PNG, JPG, JPEG.',
      );
    }

    // Sanitize filename
    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'leave_documents/$uid/$applicationId/$safeFileName';
    final ref = _storageInstance.ref(storagePath);

    final metadata = SettableMetadata(
      contentType: realMime,
      customMetadata: {
        'uploadedBy': uid,
        'applicationId': applicationId,
        'originalName': fileName,
        'size': fileSize.toString(),
      },
    );

    final uploadTask = ref.putFile(file, metadata);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return UploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      fileName: fileName,
      fileSize: fileSize,
      contentType: realMime,
    );
  }

  // ── Profile Photo Upload ───────────────────────────────────────────────────

  /// Uploads a user profile image to Firebase Storage with validation.
  ///
  /// Target Path: `profile_images/{uid}/avatar_{timestamp}.{ext}`
  Future<String> uploadProfileImage({
    required String uid,
    required File file,
    String? previousPhotoUrl,
    void Function(double progress)? onProgress,
  }) async {
    final ext = p.extension(file.path).toLowerCase();
    final fileSize = await file.length();

    // 1. Validation: Extension
    if (!allowedImageExtensions.contains(ext)) {
      throw StorageValidationException(
        'Invalid image format ($ext). Allowed: JPG, JPEG, PNG, WEBP.',
      );
    }

    // 2. Validation: File size (<= 5MB)
    if (fileSize > maxProfileImageSizeBytes) {
      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      throw StorageValidationException(
        'Profile image ($sizeMb MB) exceeds the maximum limit of 5 MB.',
      );
    }

    // 3. Validation: Real binary MIME type detection (magic numbers)
    final realMime = await detectRealMimeType(file);
    if (!realMime.startsWith('image/')) {
      throw StorageValidationException(
        'Invalid file type ($realMime). Profile photo must be an image (JPEG, PNG, WEBP).',
      );
    }

    // Verify consistency between extension and actual binary format
    if (realMime == 'image/png' && ext != '.png') {
      throw StorageValidationException(
        'File extension ($ext) does not match actual PNG content.',
      );
    }
    if (realMime == 'image/jpeg' && ext != '.jpg' && ext != '.jpeg') {
      throw StorageValidationException(
        'File extension ($ext) does not match actual JPEG content.',
      );
    }
    if (realMime == 'image/webp' && ext != '.webp') {
      throw StorageValidationException(
        'File extension ($ext) does not match actual WEBP content.',
      );
    }

    final storagePath =
        'profile_images/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
    final ref = _storageInstance.ref(storagePath);

    final metadata = SettableMetadata(
      contentType: realMime,
      customMetadata: {
        'uploadedBy': uid,
      },
    );

    final uploadTask = ref.putFile(file, metadata);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // Safely cleanup previous profile image if it exists in Firebase Storage
    if (previousPhotoUrl != null && previousPhotoUrl.contains('profile_images')) {
      try {
        await deleteByUrl(previousPhotoUrl);
      } catch (_) {
        // Best-effort cleanup, do not fail upload if deletion fails
      }
    }

    return downloadUrl;
  }

  // ── Deletion Helpers ───────────────────────────────────────────────────────

  /// Deletes a file by its direct download URL.
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storageInstance.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {}
  }

  /// Deletes a file by its storage path.
  Future<void> deleteByPath(String storagePath) async {
    try {
      final ref = _storageInstance.ref(storagePath);
      await ref.delete();
    } catch (_) {}
  }
}
