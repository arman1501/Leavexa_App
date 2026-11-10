// ─────────────────────────────────────────────────────────────────────────────
//  fcm_service.dart  –  Firebase Cloud Messaging (FCM) Push Notification Service
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';

/// Top-level background message handler required by Firebase Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized if running in an isolated background isolate
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  debugPrint('Handling background FCM message: ${message.messageId}');
}

class FcmService {
  final FirebaseMessaging? _messaging;
  final FirebaseFirestore? _firestore;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  FcmService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging,
        _firestore = firestore;

  FirebaseMessaging get _messagingInstance =>
      _messaging ?? FirebaseMessaging.instance;

  FirebaseFirestore get _firestoreInstance =>
      _firestore ?? FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSub;

  String? _currentToken;
  String? get currentToken => _currentToken;
  String? _activeUid;
  String? get activeUid => _activeUid;

  /// Generate a deterministic document ID for a token within a user's subcollection.
  static String tokenDocId(String token) {
    return sha256.convert(utf8.encode(token)).toString().substring(0, 32);
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Initialize FCM permissions, channels, token listeners, and navigation hooks.
  Future<void> initialize({
    String? currentUid,
    void Function(RemoteMessage message)? onForegroundMessage,
  }) async {
    // 1. Request notification permissions (iOS & Android 13+)
    await requestNotificationPermissions();

    // 2. Set presentation options for iOS foreground alerts
    try {
      await _messagingInstance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Error setting foreground presentation options: $e');
    }

    // 3. Retrieve initial FCM device token
    try {
      _currentToken = await _messagingInstance.getToken();
      if (_currentToken != null && currentUid != null) {
        await registerDeviceToken(currentUid, _currentToken!);
      }
    } catch (e) {
      debugPrint('Error retrieving initial FCM token: $e');
    }

    // 4. Listen for token refreshes
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messagingInstance.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      if (currentUid != null) {
        await registerDeviceToken(currentUid, newToken);
      }
    });

    // 5. Listen for foreground notifications
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground FCM received: ${message.notification?.title}');
      if (onForegroundMessage != null) {
        onForegroundMessage(message);
      }
    });

    // 6. Handle notification click when app is in background
    _messageOpenedAppSub?.cancel();
    _messageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background via notification: ${message.data}');
      handleNotificationNavigation(message.data);
    });

    // 7. Check if app was opened from terminated state via a notification tap
    try {
      final initialMessage = await _messagingInstance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            'App opened from terminated state via notification: ${initialMessage.data}');
        handleNotificationNavigation(initialMessage.data);
      }
    } catch (e) {
      debugPrint('Error checking initial FCM message: $e');
    }
  }

  /// Request permissions for alerts, badges, and sounds.
  Future<NotificationSettings> requestNotificationPermissions() async {
    return await _messagingInstance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  // ── Device Token Registration & Cleanup ────────────────────────────────────

  /// Register or refresh an FCM device token in the user's private subcollection.
  /// Automatically purges the token from any previously active account on this device.
  ///
  /// Target: `users/{uid}/fcm_tokens/{tokenId}`
  Future<void> registerDeviceToken(
    String uid,
    String token, {
    String? platform,
    String? deviceModel,
  }) async {
    if (uid.isEmpty || token.isEmpty) return;

    // Account switching protection: if switching accounts on same device,
    // ensure token is purged from old account
    if (_activeUid != null && _activeUid != uid) {
      await unregisterDeviceToken(_activeUid!, token);
    }
    _activeUid = uid;

    final docId = tokenDocId(token);
    final docRef = _firestoreInstance
        .collection('users')
        .doc(uid)
        .collection('fcm_tokens')
        .doc(docId);

    final resolvedPlatform = platform ?? _detectPlatform();

    await docRef.set({
      'token': token,
      'platform': resolvedPlatform,
      'deviceModel': deviceModel ?? 'unknown',
      'lastSeenAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Unregister and delete the device token from Firestore upon logout.
  Future<void> unregisterDeviceToken(String uid, [String? token]) async {
    final tokenToDelete = token ?? _currentToken;
    if (uid.isEmpty || tokenToDelete == null || tokenToDelete.isEmpty) return;

    try {
      final docId = tokenDocId(tokenToDelete);
      await _firestoreInstance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(docId)
          .delete();

      if (_activeUid == uid) {
        _activeUid = null;
      }
    } catch (e) {
      debugPrint('Error unregistering device token: $e');
    }
  }

  // ── Notification Tap Navigation Dispatcher ────────────────────────────────

  /// Determines the appropriate screen and navigates based on payload metadata.
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    final applicationId = data['relatedApplicationId'] ?? data['applicationId'];
    final nav = navigatorKey.currentState;

    if (nav == null) {
      debugPrint('Navigator state not yet attached; queuing navigation for $type');
      return;
    }

    switch (type) {
      case 'leave_applied':
      case 'leave_submitted':
        if (applicationId != null && applicationId.toString().isNotEmpty) {
          nav.pushNamed(
            AppRoutes.leaveRequestDetails,
            arguments: applicationId.toString(),
          );
        } else {
          nav.pushNamed(AppRoutes.headRequests);
        }
        break;

      case 'leave_forwarded':
        if (applicationId != null && applicationId.toString().isNotEmpty) {
          nav.pushNamed(
            AppRoutes.finalApproval,
            arguments: applicationId.toString(),
          );
        } else {
          nav.pushNamed(AppRoutes.allLeaveRequests);
        }
        break;

      case 'leave_approved':
      case 'leave_rejected':
        if (applicationId != null && applicationId.toString().isNotEmpty) {
          nav.pushNamed(
            AppRoutes.leaveDetails,
            arguments: applicationId.toString(),
          );
        } else {
          nav.pushNamed(AppRoutes.myLeaves);
        }
        break;

      case 'registration_pending':
        nav.pushNamed(AppRoutes.adminDashboard, arguments: {'tab': 1});
        break;

      case 'faculty_approved':
        nav.pushNamed(AppRoutes.facultyDashboard);
        break;

      case 'faculty_rejected':
        nav.pushNamed(AppRoutes.login);
        break;

      default:
        nav.pushNamed(AppRoutes.notifications);
        break;
    }
  }

  String _detectPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _messageOpenedAppSub?.cancel();
  }
}
