import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_domain.dart';
import 'account_services.dart';
import 'firebase_bootstrap.dart';

/// One free listing refresh per calendar day + boost fan-out helpers.
class RefreshBoostService {
  RefreshBoostService(this._prefs, {this.firestore});

  final SharedPreferences _prefs;
  final FirebaseFirestore? firestore;
  static const _dayKey = 'last_refresh_day';

  FirebaseFirestore get _db {
    final injected = firestore;
    if (injected != null) return injected;
    if (!FirebaseBootstrap.ready) {
      throw StateError('Firestore unavailable until bootstrap succeeds');
    }
    return FirebaseFirestore.instance;
  }

  bool get refreshedToday {
    final today = _dayStamp(DateTime.now());
    return _prefs.getString(_dayKey) == today;
  }

  Future<bool> refreshOwnedCards({
    required String uid,
    required Iterable<AppDomainId> domains,
  }) async {
    if (refreshedToday) return false;
    final now = DateTime.now();
    await _prefs.setString(_dayKey, _dayStamp(now));
    if (!FirebaseBootstrap.ready) return true;
    final stamp = Timestamp.fromDate(now);
    for (final domain in domains) {
      final policy = AppDomains.byId(domain);
      if (policy.storageKind == DomainStorageKind.profiles) {
        await _db.doc('${policy.collection}/$uid').set({
          'refreshedAt': stamp,
        }, SetOptions(merge: true));
        if (domain == AppDomainId.marriage) {
          await _db.doc('profiles/$uid').set({
            'refreshedAt': stamp,
          }, SetOptions(merge: true));
        }
      } else {
        final owned = await _db
            .collection(policy.collection)
            .where('ownerId', isEqualTo: uid)
            .where('active', isEqualTo: true)
            .get();
        for (final doc in owned.docs) {
          await doc.reference.set({
            'refreshedAt': stamp,
          }, SetOptions(merge: true));
        }
      }
    }
    return true;
  }

  Future<void> fanOutBoost({
    required String uid,
    required BillingService billing,
    required Iterable<AppDomainId> domains,
  }) async {
    final until = billing.boostUntil;
    if (until == null) return;
    if (!FirebaseBootstrap.ready) return;
    final stamp = Timestamp.fromDate(until);
    await _db.doc('users/$uid').set({
      'boostUntil': stamp,
    }, SetOptions(merge: true));
    for (final domain in domains) {
      final policy = AppDomains.byId(domain);
      if (policy.storageKind == DomainStorageKind.profiles) {
        await _db.doc('${policy.collection}/$uid').set({
          'boostUntil': stamp,
          'promoted': true,
        }, SetOptions(merge: true));
      }
    }
    if (kDebugMode) debugPrint('Boost fan-out applied until $until');
  }

  String _dayStamp(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
