// ─────────────────────────────────────────────────────────────────────────────
//  storage_service_test.dart  –  Unit Tests for Centralized StorageService
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/services/storage_service.dart';

void main() {
  group('StorageService Unit Tests', () {
    late StorageService storageService;
    late Directory tempDir;

    setUp(() async {
      storageService = StorageService();
      tempDir = await Directory.systemTemp.createTemp('storage_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Constants match specification requirements', () {
      expect(StorageService.maxDocumentSizeBytes, equals(10 * 1024 * 1024));
      expect(StorageService.maxProfileImageSizeBytes, equals(5 * 1024 * 1024));
      expect(
        StorageService.allowedDocumentExtensions,
        containsAll(['.pdf', '.png', '.jpg', '.jpeg']),
      );
      expect(
        StorageService.allowedImageExtensions,
        containsAll(['.jpg', '.jpeg', '.png', '.webp']),
      );
    });

    test('uploadLeaveDocument throws StorageValidationException for invalid extension', () async {
      final invalidFile = File('${tempDir.path}/proposal.docx');
      await invalidFile.writeAsString('Word doc dummy');

      expect(
        () => storageService.uploadLeaveDocument(
          uid: 'test_uid',
          applicationId: 'test_app_id',
          file: invalidFile,
        ),
        throwsA(
          isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('Invalid document format'),
          ),
        ),
      );
    });

    test('uploadLeaveDocument throws StorageValidationException for oversized file (> 10MB)', () async {
      final largeFile = File('${tempDir.path}/large_report.pdf');
      final raf = await largeFile.open(mode: FileMode.write);
      await raf.truncate(10 * 1024 * 1024 + 1024); // 10MB + 1KB
      await raf.close();

      expect(
        () => storageService.uploadLeaveDocument(
          uid: 'test_uid',
          applicationId: 'test_app_id',
          file: largeFile,
        ),
        throwsA(
          isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the maximum limit of 10 MB'),
          ),
        ),
      );
    });

    test('detectRealMimeType detects genuine PDF, PNG, JPEG, WEBP magic signatures', () async {
      // PDF
      final pdfFile = File('${tempDir.path}/doc.pdf');
      await pdfFile.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35]);
      expect(await StorageService.detectRealMimeType(pdfFile), equals('application/pdf'));

      // PNG
      final pngFile = File('${tempDir.path}/image.png');
      await pngFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
      expect(await StorageService.detectRealMimeType(pngFile), equals('image/png'));

      // JPEG
      final jpgFile = File('${tempDir.path}/photo.jpg');
      await jpgFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      expect(await StorageService.detectRealMimeType(jpgFile), equals('image/jpeg'));

      // WEBP
      final webpFile = File('${tempDir.path}/avatar.webp');
      await webpFile.writeAsBytes([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00,
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(await StorageService.detectRealMimeType(webpFile), equals('image/webp'));
    });

    test('uploadLeaveDocument rejects disguised executables and scripts with .pdf extension', () async {
      // Disguised shell script
      final scriptFile = File('${tempDir.path}/malware.pdf');
      await scriptFile.writeAsString('#!/bin/bash\necho "exploit"');

      expect(
        () => storageService.uploadLeaveDocument(
          uid: 'test_uid',
          applicationId: 'test_app_id',
          file: scriptFile,
        ),
        throwsA(
          isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('File signature does not match any accepted document or image type'),
          ),
        ),
      );

      // Disguised Windows PE Executable
      final exeFile = File('${tempDir.path}/trojan.pdf');
      await exeFile.writeAsBytes([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]);

      expect(
        () => storageService.uploadLeaveDocument(
          uid: 'test_uid',
          applicationId: 'test_app_id',
          file: exeFile,
        ),
        throwsA(
          isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('File signature does not match any accepted document or image type'),
          ),
        ),
      );
    });

    test('uploadLeaveDocument rejects mismatch between extension and actual binary format', () async {
      // PNG binary content named with .pdf extension
      final mismatchFile = File('${tempDir.path}/sneaky.pdf');
      await mismatchFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      expect(
        () => storageService.uploadLeaveDocument(
          uid: 'test_uid',
          applicationId: 'test_app_id',
          file: mismatchFile,
        ),
        throwsA(
          isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('File extension (.pdf) does not match actual PNG content'),
          ),
        ),
      );
    });

    test('uploadProfileImage throws StorageValidationException for non-image extension', () async {
      final invalidFile = File('${tempDir.path}/resume.pdf');
      await invalidFile.writeAsString('%PDF-1.4');

      expect(
        () => storageService.uploadProfileImage(
          uid: 'test_uid',
          file: invalidFile,
        ),
        throwsA(
          isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('Invalid image format'),
          ),
        ),
      );
    });

    test('uploadProfileImage throws StorageValidationException for oversized image (> 5MB)', () async {
      final largeImage = File('${tempDir.path}/heavy_photo.png');
      final raf = await largeImage.open(mode: FileMode.write);
      await raf.truncate(5 * 1024 * 1024 + 1024); // 5MB + 1KB
      await raf.close();

      expect(
        () => storageService.uploadProfileImage(
          uid: 'test_uid',
          file: largeImage,
        ),
        throwsA(
          isA<StorageValidationException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the maximum limit of 5 MB'),
          ),
        ),
      );
    });

    test('UploadResult model instantiates correctly', () {
      const result = UploadResult(
        downloadUrl: 'https://storage.googleapis.com/test-bucket/doc.pdf',
        storagePath: 'leave_documents/u1/app1/doc.pdf',
        fileName: 'doc.pdf',
        fileSize: 2048,
        contentType: 'application/pdf',
      );

      expect(result.downloadUrl, contains('test-bucket'));
      expect(result.storagePath, equals('leave_documents/u1/app1/doc.pdf'));
      expect(result.fileName, equals('doc.pdf'));
      expect(result.fileSize, equals(2048));
      expect(result.contentType, equals('application/pdf'));
    });
  });
}
