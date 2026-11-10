import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set background messaging handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Optional: Connect to local Firebase Emulator Suite in development/testing
  // Set USE_FIREBASE_EMULATOR=true via --dart-define when running against local emulators.
  // Defaults to false so real devices and standard debug runs connect directly to trusted Firebase backend.
  const bool useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  const String customEmulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '',
  );

  if (useEmulator) {
    final host = customEmulatorHost.isNotEmpty
        ? customEmulatorHost
        : (defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : 'localhost');
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8088);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }

  // System UI Configuration
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Portrait Orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const LeavexaApp());
}
