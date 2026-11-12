import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Push Notification Platform Configuration', () {
    test('AndroidManifest and MainActivity define and register leavexa_high_importance_channel', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('com.google.firebase.messaging.default_notification_channel_id'));
      expect(manifest, contains('leavexa_high_importance_channel'));

      final mainActivity = File(
        'android/app/src/main/kotlin/com/leavexa/leavexa/MainActivity.kt',
      ).readAsStringSync();
      expect(mainActivity, contains('leavexa_high_importance_channel'));
      expect(mainActivity, contains('NotificationManager.IMPORTANCE_HIGH'));
      expect(mainActivity, contains('getNotificationChannel(DEFAULT_NOTIFICATION_CHANNEL_ID)'));
      expect(mainActivity, contains('createNotificationChannel(channel)'));
    });

    test('iOS Info.plist and Runner.entitlements include remote-notification and aps-environment', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist, contains('UIBackgroundModes'));
      expect(infoPlist, contains('remote-notification'));

      final entitlements = File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(entitlements, contains('aps-environment'));
    });
  });
}
