import 'package:cloud_functions/cloud_functions.dart';
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
      await FirebaseFunctions.instance
          .httpsCallable('claimActionThrottle')
          .call<Map<String, dynamic>>({'action': _name(action)});
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        throw StateError('Too many attempts. Try again later.');
      }
      if (_failClosed) {
        throw StateError('Could not verify action limit. Try again.');
      }
      debugPrint('Action throttle skipped (${error.code}): ${error.message}');
    } catch (error) {
      if (_failClosed) {
        throw StateError('Could not verify action limit. Try again.');
      }
      debugPrint('Action throttle skipped: $error');
    }
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
