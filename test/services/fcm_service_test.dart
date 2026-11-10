// ─────────────────────────────────────────────────────────────────────────────
//  fcm_service_test.dart  –  Unit Tests for FcmService & Push Notification Routing
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/models/notification_model.dart';
import 'package:leavexa/services/fcm_service.dart';

void main() {
  group('FcmService Unit & Navigation Tests', () {
    test('tokenDocId produces deterministic 32-char SHA-256 hash', () {
      const sampleToken = 'fcm_token_sample_device_1234567890';
      final id1 = FcmService.tokenDocId(sampleToken);
      final id2 = FcmService.tokenDocId(sampleToken);

      expect(id1, equals(id2));
      expect(id1.length, equals(32));
      expect(id1, isNot(equals(FcmService.tokenDocId('different_token'))));
    });

    testWidgets('handleNotificationNavigation routes leave_submitted to leaveRequestDetails',
        (tester) async {
      String? navigatedRoute;
      Object? navigatedArgs;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Home')),
            AppRoutes.leaveRequestDetails: (context) {
              navigatedRoute = AppRoutes.leaveRequestDetails;
              navigatedArgs = ModalRoute.of(context)?.settings.arguments;
              return const Scaffold(body: Text('Leave Request Details'));
            },
          },
        ),
      );

      final fcmService = FcmService();
      fcmService.handleNotificationNavigation({
        'type': 'leave_submitted',
        'applicationId': 'app_cse_1001',
      });

      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(AppRoutes.leaveRequestDetails));
      expect(navigatedArgs, equals('app_cse_1001'));
    });

    testWidgets('handleNotificationNavigation routes leave_forwarded to finalApproval',
        (tester) async {
      String? navigatedRoute;
      Object? navigatedArgs;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Home')),
            AppRoutes.finalApproval: (context) {
              navigatedRoute = AppRoutes.finalApproval;
              navigatedArgs = ModalRoute.of(context)?.settings.arguments;
              return const Scaffold(body: Text('Final Approval'));
            },
          },
        ),
      );

      final fcmService = FcmService();
      fcmService.handleNotificationNavigation({
        'type': 'leave_forwarded',
        'applicationId': 'app_cse_1002',
      });

      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(AppRoutes.finalApproval));
      expect(navigatedArgs, equals('app_cse_1002'));
    });

    testWidgets('handleNotificationNavigation routes leave_approved to leaveDetails',
        (tester) async {
      String? navigatedRoute;
      Object? navigatedArgs;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Home')),
            AppRoutes.leaveDetails: (context) {
              navigatedRoute = AppRoutes.leaveDetails;
              navigatedArgs = ModalRoute.of(context)?.settings.arguments;
              return const Scaffold(body: Text('Leave Details'));
            },
          },
        ),
      );

      final fcmService = FcmService();
      fcmService.handleNotificationNavigation({
        'type': 'leave_approved',
        'relatedApplicationId': 'app_cse_1003',
      });

      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(AppRoutes.leaveDetails));
      expect(navigatedArgs, equals('app_cse_1003'));
    });

    testWidgets('handleNotificationNavigation routes registration_pending to adminDashboard',
        (tester) async {
      String? navigatedRoute;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Home')),
            AppRoutes.adminDashboard: (_) {
              navigatedRoute = AppRoutes.adminDashboard;
              return const Scaffold(body: Text('Admin Dashboard'));
            },
          },
        ),
      );

      final fcmService = FcmService();
      fcmService.handleNotificationNavigation({
        'type': 'registration_pending',
        'targetUid': 'faculty_new_123',
      });

      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(AppRoutes.adminDashboard));
    });

    testWidgets('handleNotificationNavigation routes faculty_approved to facultyDashboard',
        (tester) async {
      String? navigatedRoute;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Home')),
            AppRoutes.facultyDashboard: (_) {
              navigatedRoute = AppRoutes.facultyDashboard;
              return const Scaffold(body: Text('Faculty Dashboard'));
            },
          },
        ),
      );

      final fcmService = FcmService();
      fcmService.handleNotificationNavigation({
        'type': 'faculty_approved',
      });

      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(AppRoutes.facultyDashboard));
    });

    testWidgets('handleNotificationNavigation routes unknown type to notifications screen',
        (tester) async {
      String? navigatedRoute;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Home')),
            AppRoutes.notifications: (_) {
              navigatedRoute = AppRoutes.notifications;
              return const Scaffold(body: Text('Notifications'));
            },
          },
        ),
      );

      final fcmService = FcmService();
      fcmService.handleNotificationNavigation({
        'type': 'unknown_event_alert',
      });

      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(AppRoutes.notifications));
    });
  });

  group('NotificationModel Regression & Robust Parsing', () {
    test('parses ISO8601 string createdAt properly', () {
      final now = DateTime.now();
      final map = {
        'id': 'notif_001',
        'recipientUid': 'user_1',
        'title': 'Test Title',
        'body': 'Test Body',
        'type': 'leave_approved',
        'relatedApplicationId': 'app_1',
        'isRead': false,
        'createdAt': now.toIso8601String(),
      };

      final model = NotificationModel.fromMap(map);
      expect(model.id, equals('notif_001'));
      expect(model.recipientUid, equals('user_1'));
      expect(model.title, equals('Test Title'));
      expect(model.isRead, isFalse);
      expect(model.createdAt.year, equals(now.year));
    });

    test('copyWith updates isRead state cleanly', () {
      final model = NotificationModel(
        id: 'n1',
        recipientUid: 'u1',
        title: 'Title',
        body: 'Body',
        type: 'leave_applied',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final updated = model.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.id, equals('n1'));
    });

    test('activeUid tracks current user account cleanly', () {
      final fcm = FcmService();
      expect(fcm.activeUid, isNull);
    });
  });
}
