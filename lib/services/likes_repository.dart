import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import 'firebase_bootstrap.dart';

class LikesRepository {
  LikesRepository({this.firestore, this.auth});

  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  Future<void> like({
    required AppDomainId domain,
    String? targetUid,
    DiscoveryCardModel? target,
    DiscoveryCardModel? snapshot,
  }) async {
    if (!FirebaseBootstrap.ready) return;
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    final card = target ?? snapshot;
    final otherUid = targetUid ?? card?.ownerId;
    if (uid == null || otherUid == null || uid == otherUid) return;
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final safeSnapshot = {
      if (card != null)
        'headline': card.title.length > 60
            ? card.title.substring(0, 60)
            : card.title,
      if (card != null) 'cityLabel': card.cityLabel,
      if (card != null)
        'photoUrl': card.imageUrls.isEmpty ? null : card.imageUrls.first,
      // Never include contact fields in like snapshots.
    };
    final database = firestore ?? FirebaseFirestore.instance;
    final batch = database.batch();
    final outbound = database.doc(
      'domains/$slug/likes/$uid/outbound/$otherUid',
    );
    final inbound = database.doc('domains/$slug/likes/$otherUid/inbound/$uid');
    batch.set(outbound, {
      'fromUserId': uid,
      'toUserId': otherUid,
      'snapshot': safeSnapshot,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(inbound, {
      'fromUserId': uid,
      'toUserId': otherUid,
      'snapshot': safeSnapshot,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<Set<String>> loadOutbound(AppDomainId domain) async {
    if (!FirebaseBootstrap.ready) return const <String>{};
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) return const <String>{};
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final snap = await (firestore ?? FirebaseFirestore.instance)
        .collection('domains/$slug/likes/$uid/outbound')
        .limit(100)
        .get();
    return snap.docs.map((doc) => doc.id).toSet();
  }

  Future<Set<String>> loadInbound(AppDomainId domain) async {
    if (!FirebaseBootstrap.ready) return const <String>{};
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) return const <String>{};
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final snap = await (firestore ?? FirebaseFirestore.instance)
        .collection('domains/$slug/likes/$uid/inbound')
        .limit(100)
        .get();
    return snap.docs.map((doc) => doc.id).toSet();
  }
}
