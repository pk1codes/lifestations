import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;
  static Object? initializationError;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 15 * 1024 * 1024,
      );
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleAppAttestProvider(),
        providerWeb: ReCaptchaV3Provider(
          const String.fromEnvironment('RECAPTCHA_V3_SITE_KEY'),
        ),
      );
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      try {
        await FirebaseAnalytics.instance.logAppOpen();
      } catch (_) {}
      if (!kIsWeb && !kDebugMode) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      }
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          !kDebugMode,
        );
      }
      ready = true;
    } catch (error) {
      initializationError = error;
      ready = false;
      if (kDebugMode) debugPrint('Firebase unavailable; using local data.');
    }
  }
}
