import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

enum ThrottledAction { like, report, imageFlag, post }

class ActionThrottleService {
  const ActionThrottleService();

  Future<void> claim(ThrottledAction action) async {
    if (!FirebaseBootstrap.ready) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('claimActionThrottle')
          .call<Map<String, dynamic>>({'action': _name(action)});
    } on FirebaseFunctionsException catch (error) {
      final message = error.code == 'resource-exhausted'
          ? 'Too many attempts. Try again later.'
          : 'Please try again later.';
      throw StateError(message);
    } catch (error) {
      if (kDebugMode) debugPrint('Action throttle skipped: $error');
      rethrow;
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
