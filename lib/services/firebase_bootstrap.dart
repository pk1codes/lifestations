import 'dart:async';

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
  static final Completer<void> _readyCompleter = Completer<void>();
  static bool _initializeStarted = false;

  /// Completes when [initialize] finishes (success or failure).
  /// If [initialize] was never called, returns immediately (`ready` stays false).
  static Future<void> waitUntilReady() {
    if (_readyCompleter.isCompleted) return _readyCompleter.future;
    if (!_initializeStarted) return Future<void>.value();
    return _readyCompleter.future;
  }

  static Future<void> initialize() async {
    _initializeStarted = true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 15 * 1024 * 1024,
      );
      const webSiteKey = String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');
      if (kIsWeb) {
        // Web App Check: use v3 provider with the site key from dart-defines.
        // (Enterprise provider + a v3 key produces invalid tokens → Storage denies.)
        if (webSiteKey.isNotEmpty) {
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaV3Provider(webSiteKey),
          );
          await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestProvider(),
        );
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      }
      // Sync with web auth init (initializeApp already waits for persisted auth).
      // Do not sign in anonymously here — that can clobber a restored session on
      // refresh and orphan likes under a previous uid.
      await FirebaseAuth.instance.authStateChanges().first;
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
    } finally {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    }
  }

  /// Waits for a persisted auth session to restore. Never creates a new user.
  static Future<User?> waitForRestoredUser({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final auth = FirebaseAuth.instance;
    final immediate = auth.currentUser;
    if (immediate != null) return immediate;
    try {
      final restored = await auth
          .authStateChanges()
          .where((user) => user != null)
          .cast<User>()
          .first
          .timeout(timeout);
      return restored;
    } on TimeoutException {
      return auth.currentUser;
    } catch (_) {
      return auth.currentUser;
    }
  }

  /// Prefer a restored session; create anonymous only when the user acts.
  static Future<User> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    final restored = await waitForRestoredUser();
    if (restored != null) return restored;
    try {
      final cred = await auth.signInAnonymously();
      final user = cred.user;
      if (user != null) return user;
    } on FirebaseAuthException catch (error) {
      if (kDebugMode) {
        debugPrint('Anonymous sign-in unavailable: ${error.code}');
      }
    }
    throw StateError('Sign-in needed before continuing.');
  }
}
