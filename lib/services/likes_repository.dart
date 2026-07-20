import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import 'action_throttle.dart';
import 'firebase_bootstrap.dart';

/// Privacy-safe like record with enough public card metadata for the Likes UI.
class LikeEntry {
  const LikeEntry({
    required this.domain,
    required this.otherUid,
    required this.direction,
    this.card,
    this.createdAt,
  });

  final AppDomainId domain;
  final String otherUid;
  final LikeDirection direction;
  final DiscoveryCardModel? card;
  final DateTime? createdAt;

  bool get hasCard => card != null;
}

enum LikeDirection { outbound, inbound }

class LikesRepository {
  LikesRepository({this.firestore, this.auth});
  static const ActionThrottleService _throttle = ActionThrottleService();

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
    await _throttle.claim(ThrottledAction.like);
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final safeSnapshot = _publicSnapshot(card);
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

  Future<List<LikeEntry>> loadOutbound(AppDomainId domain) =>
      _load(domain, LikeDirection.outbound);

  Future<List<LikeEntry>> loadInbound(AppDomainId domain) =>
      _load(domain, LikeDirection.inbound);

  Future<List<LikeEntry>> _load(AppDomainId domain, LikeDirection direction) async {
    if (!FirebaseBootstrap.ready) return const <LikeEntry>[];
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) return const <LikeEntry>[];
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final collection = direction == LikeDirection.outbound
        ? 'domains/$slug/likes/$uid/outbound'
        : 'domains/$slug/likes/$uid/inbound';
    final snap = await (firestore ?? FirebaseFirestore.instance)
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snap.docs
        .map((doc) {
          final data = doc.data();
          final snapshot = Map<String, Object?>.from(
            data['snapshot'] as Map? ?? const {},
          );
          final created = data['createdAt'];
          return LikeEntry(
            domain: domain,
            otherUid: doc.id,
            direction: direction,
            card: _cardFromSnapshot(
              domain: domain,
              otherUid: doc.id,
              snapshot: snapshot,
            ),
            createdAt: created is Timestamp ? created.toDate() : null,
          );
        })
        .toList(growable: false);
  }

  Map<String, Object?> _publicSnapshot(DiscoveryCardModel? card) {
    if (card == null) return const <String, Object?>{};
    final title = card.title.length > 60
        ? card.title.substring(0, 60)
        : card.title;
    final subtitle = card.subtitle.length > 120
        ? card.subtitle.substring(0, 120)
        : card.subtitle;
    return <String, Object?>{
      'listingId': card.id,
      'headline': title,
      'title': title,
      'subtitle': subtitle,
      'cityId': card.cityId,
      'cityLabel': card.cityLabel,
      'photoUrl': card.imageUrls.isEmpty ? null : card.imageUrls.first,
      'photoUrls': card.imageUrls.take(8).toList(growable: false),
      'categoryTags': card.categoryTags,
      'role': card.role,
      'ageBand': card.ageBand,
      'attributes': card.attributes,
      'verified': card.verified,
      // Never include contact fields in like snapshots.
    };
  }

  DiscoveryCardModel? _cardFromSnapshot({
    required AppDomainId domain,
    required String otherUid,
    required Map<String, Object?> snapshot,
  }) {
    if (snapshot.isEmpty) return null;
    final photos = <String>[
      ...List<String>.from(snapshot['photoUrls'] as List? ?? const []),
      if ((snapshot['photoUrl'] as String?)?.isNotEmpty ?? false)
        snapshot['photoUrl'] as String,
    ];
    final uniquePhotos = <String>{
      for (final url in photos)
        if (url.isNotEmpty) url,
    }.toList(growable: false);
    final title =
        (snapshot['title'] as String?) ??
        (snapshot['headline'] as String?) ??
        'Liked post';
    return DiscoveryCardModel(
      id: (snapshot['listingId'] as String?) ?? otherUid,
      domain: domain,
      ownerId: otherUid,
      title: title,
      subtitle: (snapshot['subtitle'] as String?) ?? '',
      cityId: (snapshot['cityId'] as String?) ?? '',
      cityLabel: (snapshot['cityLabel'] as String?) ?? '',
      categoryTags: List<String>.from(
        snapshot['categoryTags'] as List? ?? const [],
      ),
      imageUrls: uniquePhotos,
      role: snapshot['role'] as String?,
      ageBand: snapshot['ageBand'] as String?,
      attributes: Map<String, Object?>.from(
        snapshot['attributes'] as Map? ?? const {},
      ),
      verified: snapshot['verified'] as bool? ?? false,
    );
  }
}
