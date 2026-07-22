import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

enum ThrottledAction { like, report, imageFlag, post }

class ActionThrottleService {
  const ActionThrottleService();

  /// Claims a server rate-limit slot.
  ///
  /// Hard-fails only on true quota (`resource-exhausted`). App Check / network
  /// / config failures fail open so Save still publishes during closed testing.
  Future<void> claim(ThrottledAction action) async {
    if (!FirebaseBootstrap.ready) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('claimActionThrottle')
          .call<Map<String, dynamic>>({'action': _name(action)});
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        throw StateError('Too many attempts. Try again later.');
      }
      debugPrint('Action throttle skipped (${error.code}): ${error.message}');
    } catch (error) {
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
