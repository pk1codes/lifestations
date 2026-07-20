import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_domain.dart';
import 'action_throttle.dart';
import 'firebase_bootstrap.dart';

class SafetyRepository {
  SafetyRepository({this.firestore, this.auth});
  static const ActionThrottleService _throttle = ActionThrottleService();

  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  Future<void> report({
    required AppDomainId domain,
    required String targetId,
    required String reason,
  }) async {
    if (!FirebaseBootstrap.ready) {
      if (kDebugMode) debugPrint('Report queued locally ($reason)');
      return;
    }
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) return;
    await _throttle.claim(ThrottledAction.report);
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final urgent = reason == 'underage' || reason == 'child_safety';
    await (firestore ?? FirebaseFirestore.instance).collection('reports').add({
      'kind': 'user',
      'reporterUid': uid,
      'targetId': targetId,
      'domain': slug,
      'reason': reason,
      'urgent': urgent,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> flagImage({
    required AppDomainId domain,
    required String targetId,
    required String reason,
    int photoSlot = 0,
  }) async {
    if (!FirebaseBootstrap.ready) return;
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) return;
    await _throttle.claim(ThrottledAction.imageFlag);
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    await (firestore ?? FirebaseFirestore.instance)
        .collection('image_flags')
        .add({
          'reporterUid': uid,
          'targetId': targetId,
          'domain': slug,
          'reason': reason,
          'photoSlot': photoSlot,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> blockUser(String targetUid) async {
    if (!FirebaseBootstrap.ready) return;
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null || uid == targetUid) return;
    await (firestore ?? FirebaseFirestore.instance)
        .doc('users/$uid/blocks/$targetUid')
        .set({
          'blockedUid': targetUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<Set<String>> loadBlocks() async {
    if (!FirebaseBootstrap.ready) return const <String>{};
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) return const <String>{};
    final snap = await (firestore ?? FirebaseFirestore.instance)
        .collection('users/$uid/blocks')
        .limit(200)
        .get();
    return snap.docs.map((doc) => doc.id).toSet();
  }
}
