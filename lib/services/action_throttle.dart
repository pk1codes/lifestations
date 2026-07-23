import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

enum ThrottledAction { like, report, imageFlag, post }

class ActionThrottleService {
  const ActionThrottleService({this.failClosed});

  /// When true, non-quota callable failures block the action.
  /// Defaults to [kReleaseMode] so debug can still proceed locally.
  final bool? failClosed;

  bool get _failClosed => failClosed ?? kReleaseMode;

  /// Claims a server rate-limit slot.
  ///
  /// Always hard-fails on true quota (`resource-exhausted`).
  /// App Check / attestation failures never block — phone Auth is enough for
  /// throttles (web/incognito and sideload often lack a valid App Check token).
  Future<void> claim(ThrottledAction action) async {
    if (!FirebaseBootstrap.ready) {
      if (_failClosed) {
        throw StateError('Not connected. Try again.');
      }
      return;
    }
    try {
      await FirebaseBootstrap.ensureSignedIn();
      // Keep callable auth fresh (multi-tab phone switches can leave a stale token).
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {
      if (_failClosed) {
        throw StateError('Sign in required. Try again.');
      }
      return;
    }
    try {
      // Best-effort only — never gate the action on App Check here.
      if (!kIsWeb) {
        try {
          await FirebaseAppCheck.instance.getToken(true);
        } catch (error) {
          if (kDebugMode) debugPrint('App Check warm skipped: $error');
        }
      }
      await FirebaseFunctions.instance
          .httpsCallable('claimActionThrottle')
          .call(<String, dynamic>{'action': _name(action)});
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        throw StateError('Too many attempts. Try again later.');
      }
      if (_isAppCheckInfrastructureFailure(error)) {
        // Project/console App Check can still reject callables before our
        // function runs. Do not block post/like — Auth + local flow continue.
        if (kDebugMode) {
          debugPrint('Action throttle App Check bypassed: ${error.code}');
        }
        return;
      }
      if (_failClosed) {
        throw StateError(_friendlyThrottleError(error));
      }
      debugPrint('Action throttle skipped (${error.code}): ${error.message}');
    } catch (error) {
      if (error is StateError) rethrow;
      if (_failClosed) {
        throw StateError('Could not verify action limit. Try again.');
      }
      debugPrint('Action throttle skipped: $error');
    }
  }

  /// App Check rejects often surface as failed-precondition before the handler.
  static bool _isAppCheckInfrastructureFailure(FirebaseFunctionsException error) {
    final blob = '${error.code} ${error.message ?? ''}'.toLowerCase();
    if (blob.contains('app check') ||
        blob.contains('app-check') ||
        blob.contains('attestation') ||
        blob.contains('firebase-app-check')) {
      return true;
    }
    // Callable App Check enforcement uses this code when the token is missing.
    return error.code == 'failed-precondition';
  }

  String _friendlyThrottleError(FirebaseFunctionsException error) {
    final code = error.code.toLowerCase();
    if (code == 'unauthenticated') {
      return 'Sign in required. Try again.';
    }
    return 'Could not verify action limit. Try again.';
  }

  String _name(ThrottledAction action) {
    switch (action) {
      case ThrottledAction.like:
        return 'like';
      case ThrottledAction.report:
        return 'report';
      case ThrottledAction.imageFlag:
        return 'image_flag';
      case ThrottledAction.post:
        return 'post';
    }
  }
}
