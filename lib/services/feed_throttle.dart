import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Client-side 10 / 30s throttle mirrored by callable `checkFeedThrottle`.
class FeedFetchThrottle {
  FeedFetchThrottle({
    this.maxHits = 10,
    this.window = const Duration(seconds: 30),
    this.failClosed,
  });

  final int maxHits;
  final Duration window;

  /// When true, remote callable failures deny the fetch.
  /// Defaults to [kReleaseMode].
  final bool? failClosed;

  final List<DateTime> _hits = <DateTime>[];
  DateTime? lockedUntil;

  bool get _failClosed => failClosed ?? kReleaseMode;

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
        if (!kIsWeb) {
          try {
            await FirebaseAppCheck.instance.getToken(true);
          } catch (error) {
            if (kDebugMode) debugPrint('Feed App Check warm skipped: $error');
          }
        }
        final result = await FirebaseFunctions.instance
            .httpsCallable('checkFeedThrottle')
            .call();
        final data = result.data;
        final map = data is Map
            ? data.map((key, value) => MapEntry('$key', value))
            : const <String, dynamic>{};
        final allowed = map['allowed'] == true;
        final lockedMs = map['lockedUntilMs'];
        if (lockedMs is num && lockedMs > 0) {
          lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedMs.toInt());
        }
        if (!allowed) {
          _hits.removeLast();
        }
        return allowed;
      } on FirebaseFunctionsException catch (error) {
        final blob = '${error.code} ${error.message ?? ''}'.toLowerCase();
        final appCheck = blob.contains('app check') ||
            blob.contains('app-check') ||
            blob.contains('attestation') ||
            error.code == 'failed-precondition';
        if (appCheck) {
          // Same as action throttle: Auth is enough; don't block Browse.
          if (kDebugMode) {
            debugPrint('Feed throttle App Check bypassed: ${error.code}');
          }
          return true;
        }
        if (kDebugMode) debugPrint('Feed throttle remote skipped: $error');
        if (_failClosed) {
          _hits.removeLast();
          return false;
        }
      } catch (error) {
        if (kDebugMode) debugPrint('Feed throttle remote skipped: $error');
        if (_failClosed) {
          _hits.removeLast();
          return false;
        }
      }
    } else if (callRemote && !FirebaseBootstrap.ready && _failClosed) {
      _hits.removeLast();
      return false;
    }
    return true;
  }
}
