import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

enum ThrottledAction { like, report, imageFlag, post }

class ActionThrottleService {
  const ActionThrottleService({this.failClosed});

  /// When true, non-quota callable failures block the action.
  /// Defaults to [kReleaseMode] so debug/closed testing can still proceed.
  final bool? failClosed;

  bool get _failClosed => failClosed ?? kReleaseMode;

  /// Claims a server rate-limit slot.
  ///
  /// Always hard-fails on true quota (`resource-exhausted`).
  /// In release, other callable failures also hard-fail (no bot bypass).
  Future<void> claim(ThrottledAction action) async {
    if (!FirebaseBootstrap.ready) {
      if (_failClosed) {
        throw StateError('Not connected. Try again.');
      }
      return;
    }
    try {
      await FirebaseBootstrap.ensureSignedIn();
    } catch (_) {
      if (_failClosed) {
        throw StateError('Sign in required. Try again.');
      }
      return;
    }
    try {
      // Attestation must exist before enforceAppCheck callables.
      try {
        await FirebaseAppCheck.instance.getToken(true);
      } catch (error) {
        if (kDebugMode) debugPrint('App Check warm skipped: $error');
      }
      // Avoid typed Map cast — Functions may return Map<Object?, Object?>.
      await FirebaseFunctions.instance
          .httpsCallable('claimActionThrottle')
          .call(<String, dynamic>{'action': _name(action)});
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        throw StateError('Too many attempts. Try again later.');
      }
      if (_failClosed) {
        throw StateError(_friendlyThrottleError(error));
      }
      debugPrint('Action throttle skipped (${error.code}): ${error.message}');
    } catch (error) {
      if (_failClosed) {
        throw StateError('Could not verify action limit. Try again.');
      }
      debugPrint('Action throttle skipped: $error');
    }
  }

  String _friendlyThrottleError(FirebaseFunctionsException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    if (code == 'unauthenticated') {
      return 'Sign in required. Try again.';
    }
    if (code == 'failed-precondition' ||
        message.contains('app check') ||
        message.contains('attestation') ||
        message.contains('unauthenticated')) {
      return 'App verification failed. Install from Play or try again.';
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
