import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Client-side 10 / 30s throttle mirrored by callable `checkFeedThrottle`.
class FeedFetchThrottle {
  FeedFetchThrottle({
    this.maxHits = 10,
    this.window = const Duration(seconds: 30),
  });

  final int maxHits;
  final Duration window;
  final List<DateTime> _hits = <DateTime>[];
  DateTime? lockedUntil;

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  Future<bool> allow({bool callRemote = true}) async {
    final now = DateTime.now();
    if (isLocked) return false;
    _hits.removeWhere((hit) => now.difference(hit) > window);
    if (_hits.length >= maxHits) {
      lockedUntil = now.add(window);
      return false;
    }
    _hits.add(now);
    if (callRemote && FirebaseBootstrap.ready) {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('checkFeedThrottle')
            .call<Map<String, dynamic>>();
        final data = result.data;
        final allowed = data['allowed'] == true;
        final lockedMs = data['lockedUntilMs'];
        if (lockedMs is num && lockedMs > 0) {
          lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedMs.toInt());
        }
        return allowed;
      } catch (error) {
        if (kDebugMode) debugPrint('Feed throttle remote skipped: $error');
      }
    }
    return true;
  }
}
