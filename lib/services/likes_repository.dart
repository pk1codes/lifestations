import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_domain.dart';
import '../models/card_side.dart';
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
    this.targetCard,
    this.createdAt,
    this.peerOpenedChat = false,
  });

  final AppDomainId domain;
  final String otherUid;
  final LikeDirection direction;

  /// Peer-facing card: outbound = their post; inbound = who liked you.
  final DiscoveryCardModel? card;

  /// Inbound only: the owner's post that was liked (two-block Liked me UI).
  final DiscoveryCardModel? targetCard;

  final DateTime? createdAt;

  /// Other party opened WhatsApp/Telegram after mutual interest.
  final bool peerOpenedChat;

  bool get hasCard => card != null;
}

enum LikeDirection { outbound, inbound }

class LikesRepository {
  LikesRepository({this.firestore, this.auth});
  static const ActionThrottleService _throttle = ActionThrottleService();

  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  Future<void> like({
    required AppDomainId domain,
    String? targetUid,
    DiscoveryCardModel? target,
    DiscoveryCardModel? snapshot,
    DiscoveryCardModel? fromCard,
  }) async {
    await FirebaseBootstrap.waitUntilReady();
    if (!FirebaseBootstrap.ready) {
      throw StateError('Not connected. Try again.');
    }
    final card = target ?? snapshot;
    final otherUid = targetUid ?? card?.ownerId;
    final uid = await _ensureUid();
    if (otherUid == null || otherUid.isEmpty) {
      throw StateError('Could not like this post.');
    }
    if (uid == otherUid) {
      throw StateError('You cannot like your own post.');
    }
    // Demo seed cards are local-only — never write orphan like docs for them.
    if (otherUid.startsWith('demo_owner_') || otherUid.startsWith('demo_')) {
      throw StateError('That demo card cannot be liked online.');
    }
    await _throttle.claim(ThrottledAction.like);
    final slug = AppDomains.byId(domain).slug;
    final targetSnap = _publicSnapshot(card);
    // Inbound must show the liker's public card so the owner can like back.
    var fromSnap = _publicSnapshot(fromCard);
    if (!_snapshotHasPhotos(fromSnap)) {
      final own = await _bestPublicListing(domain, uid);
      final ownSnap = _publicSnapshot(own);
      if (ownSnap.isNotEmpty) fromSnap = ownSnap;
    }
    if (fromSnap.isEmpty) {
      fromSnap = await _identityFallbackSnapshot(uid);
    }
    final batch = _db.batch();
    final outbound = _db.doc('domains/$slug/likes/$uid/outbound/$otherUid');
    final inbound = _db.doc('domains/$slug/likes/$otherUid/inbound/$uid');
    batch.set(outbound, {
      'fromUserId': uid,
      'toUserId': otherUid,
      'snapshot': targetSnap,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(inbound, {
      'fromUserId': uid,
      'toUserId': otherUid,
      // Who liked you (for Liked me + like-back).
      'snapshot': fromSnap,
      // Which of your posts they liked (for FCM / context).
      'targetSnapshot': targetSnap,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Remove our like both ways (outbound + their inbound mirror).
  Future<void> unlike({
    required AppDomainId domain,
    required String targetUid,
  }) async {
    await FirebaseBootstrap.waitUntilReady();
    if (!FirebaseBootstrap.ready) {
      throw StateError('Not connected. Try again.');
    }
    final uid = await _ensureUid();
    if (targetUid.isEmpty || uid == targetUid) return;
    final slug = AppDomains.byId(domain).slug;
    final batch = _db.batch();
    batch.delete(_db.doc('domains/$slug/likes/$uid/outbound/$targetUid'));
    batch.delete(_db.doc('domains/$slug/likes/$targetUid/inbound/$uid'));
    await batch.commit();
  }

  Future<List<LikeEntry>> loadOutbound(AppDomainId domain) =>
      _load(domain, LikeDirection.outbound);

  Future<List<LikeEntry>> loadInbound(AppDomainId domain) =>
      _load(domain, LikeDirection.inbound);

  /// Live inbound stream so like-back / chat-open updates unlock icons promptly.
  Stream<List<LikeEntry>> watchInbound(AppDomainId domain) async* {
    if (!FirebaseBootstrap.ready) {
      yield const <LikeEntry>[];
      return;
    }
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) {
      yield const <LikeEntry>[];
      return;
    }
    final slug = AppDomains.byId(domain).slug;
    yield* _db
        .collection('domains/$slug/likes/$uid/inbound')
        .limit(100)
        .snapshots()
        .asyncMap((snap) async {
          try {
            final entries = snap.docs
                .map(
                  (doc) => _entryFromDoc(domain, LikeDirection.inbound, doc),
                )
                .toList(growable: false);
            return _enrichAll(entries);
          } catch (_) {
            // Never kill the realtime subscription on a bad photo enrich.
            return snap.docs
                .map(
                  (doc) => _entryFromDoc(domain, LikeDirection.inbound, doc),
                )
                .toList(growable: false);
          }
        });
  }

  /// Tell the other party that WhatsApp/Telegram was opened (activates their icons).
  Future<void> signalChatOpened({
    required AppDomainId domain,
    required String otherUid,
  }) async {
    if (!FirebaseBootstrap.ready || otherUid.isEmpty) return;
    final uid = await _ensureUid();
    if (uid == otherUid) return;
    final slug = AppDomains.byId(domain).slug;
    // Our like sits on their inbound path — they listen there.
    final ref = _db.doc('domains/$slug/likes/$otherUid/inbound/$uid');
    try {
      await ref.set({
        'fromUserId': uid,
        'toUserId': otherUid,
        'peerOpenedChat': true,
        'peerOpenedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort; mutual icons still unlock via inbound like-back.
    }
  }

  Future<List<LikeEntry>> _load(
    AppDomainId domain,
    LikeDirection direction,
  ) async {
    if (!FirebaseBootstrap.ready) return const <LikeEntry>[];
    final uid = (auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) return const <LikeEntry>[];
    final slug = AppDomains.byId(domain).slug;
    final collection = direction == LikeDirection.outbound
        ? 'domains/$slug/likes/$uid/outbound'
        : 'domains/$slug/likes/$uid/inbound';
    try {
      final snap = await _db
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      final entries = snap.docs
          .map((doc) => _entryFromDoc(domain, direction, doc))
          .toList(growable: false);
      return _enrichAll(entries);
    } catch (_) {
      try {
        final snap = await _db.collection(collection).limit(100).get();
        final entries = snap.docs
            .map((doc) => _entryFromDoc(domain, direction, doc))
            .toList(growable: false);
        return _enrichAll(entries);
      } catch (_) {
        return const <LikeEntry>[];
      }
    }
  }

  Future<List<LikeEntry>> _enrichAll(List<LikeEntry> entries) async {
    if (entries.isEmpty) return entries;
    return Future.wait(entries.map(_enrichMissingPhotos));
  }

  /// Fill missing photos from the peer listing, then identity.
  Future<LikeEntry> _enrichMissingPhotos(LikeEntry entry) async {
    var next = entry;
    next = await _enrichPeerCard(next);
    if (next.direction == LikeDirection.inbound) {
      next = await _enrichTargetCard(next);
    }
    return next;
  }

  Future<LikeEntry> _enrichPeerCard(LikeEntry entry) async {
    final card = entry.card;
    if (card != null && card.imageUrls.isNotEmpty) return entry;

    // Prefer the exact listing id when present on the liker snapshot.
    final listingId = card?.id;
    if (listingId != null &&
        listingId.isNotEmpty &&
        listingId != entry.otherUid &&
        card?.attributes['identityOnly'] != true) {
      final exact = await _fetchListingById(entry.domain, listingId);
      if (exact != null && exact.imageUrls.isNotEmpty) {
        return _withPeerPhotos(entry, exact.imageUrls, titleHint: exact.title);
      }
    }

    final listing = await _bestPublicListing(entry.domain, entry.otherUid);
    if (listing != null && listing.imageUrls.isNotEmpty) {
      return _withPeerPhotos(
        entry,
        listing.imageUrls,
        titleHint: listing.title,
        subtitleHint: listing.subtitle,
        cityId: listing.cityId,
        cityLabel: listing.cityLabel,
      );
    }

    final public = await _fetchIdentityPublic(entry.otherUid);
    if (public == null) return entry;
    final photos = _stringList(public['photoUrls']);
    if (photos.isEmpty) return entry;
    final name = (public['displayName'] as String?)?.trim() ?? '';
    return _withPeerPhotos(
      entry,
      photos,
      titleHint: name.length >= 2 ? name : null,
      cityId: public['cityId'] as String?,
      cityLabel: public['cityLabel'] as String?,
      identityOnly: true,
    );
  }

  Future<LikeEntry> _enrichTargetCard(LikeEntry entry) async {
    final target = entry.targetCard;
    if (target != null && target.imageUrls.isNotEmpty) return entry;
    final listingId = target?.id;
    if (listingId == null || listingId.isEmpty) return entry;
    final exact = await _fetchListingById(entry.domain, listingId);
    if (exact == null) return entry;
    return LikeEntry(
      domain: entry.domain,
      otherUid: entry.otherUid,
      direction: entry.direction,
      card: entry.card,
      targetCard: exact,
      createdAt: entry.createdAt,
      peerOpenedChat: entry.peerOpenedChat,
    );
  }

  LikeEntry _withPeerPhotos(
    LikeEntry entry,
    List<String> photos, {
    String? titleHint,
    String? subtitleHint,
    String? cityId,
    String? cityLabel,
    bool identityOnly = false,
  }) {
    final card = entry.card;
    final existingTitle = card?.title.trim() ?? '';
    final title =
        (existingTitle.isEmpty ||
            existingTitle == 'Someone' ||
            existingTitle == 'Liked' ||
            existingTitle == 'Liked post')
        ? (titleHint?.trim().isNotEmpty == true ? titleHint!.trim() : 'Liked')
        : existingTitle;
    final attrs = Map<String, Object?>.from(
      card?.attributes ?? const <String, Object?>{},
    );
    if (identityOnly) attrs['identityOnly'] = true;
    return LikeEntry(
      domain: entry.domain,
      otherUid: entry.otherUid,
      direction: entry.direction,
      createdAt: entry.createdAt,
      peerOpenedChat: entry.peerOpenedChat,
      targetCard: entry.targetCard,
      card: DiscoveryCardModel(
        id: card?.id ?? entry.otherUid,
        domain: entry.domain,
        ownerId: entry.otherUid,
        title: title,
        subtitle: (card?.subtitle.isNotEmpty ?? false)
            ? card!.subtitle
            : (subtitleHint ?? ''),
        cityId: (card?.cityId.isNotEmpty ?? false)
            ? card!.cityId
            : (cityId ?? ''),
        cityLabel: (card?.cityLabel.isNotEmpty ?? false)
            ? card!.cityLabel
            : (cityLabel ?? ''),
        categoryTags: card?.categoryTags ?? const <String>[],
        imageUrls: photos,
        role: card?.role,
        ageBand: card?.ageBand,
        attributes: attrs,
        verified: card?.verified ?? false,
      ),
    );
  }

  LikeEntry _entryFromDoc(
    AppDomainId domain,
    LikeDirection direction,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final snapshot = Map<String, Object?>.from(
      data['snapshot'] as Map? ?? const {},
    );
    final targetSnap = Map<String, Object?>.from(
      data['targetSnapshot'] as Map? ?? const {},
    );
    final created = data['createdAt'];
    // Inbound otherUid is the liker; targetSnapshot is the owner's own post.
    final ownerUidHint = (data['toUserId'] as String?) ?? '';
    return LikeEntry(
      domain: domain,
      otherUid: doc.id,
      direction: direction,
      card: _cardFromSnapshot(
        domain: domain,
        otherUid: doc.id,
        snapshot: snapshot,
      ),
      targetCard: direction == LikeDirection.inbound && targetSnap.isNotEmpty
          ? _cardFromSnapshot(
              domain: domain,
              otherUid: ownerUidHint.isNotEmpty ? ownerUidHint : doc.id,
              snapshot: targetSnap,
            )
          : null,
      createdAt: created is Timestamp ? created.toDate() : null,
      peerOpenedChat: data['peerOpenedChat'] == true,
    );
  }

  Future<Map<String, Object?>> _identityFallbackSnapshot(String uid) async {
    final public = await _fetchIdentityPublic(uid);
    final name = (public?['displayName'] as String?)?.trim() ?? '';
    final title = name.length >= 2 ? name : 'Liked';
    final photos = _stringList(public?['photoUrls']);
    return <String, Object?>{
      'listingId': uid,
      'headline': title,
      'title': title,
      'subtitle': '',
      'cityId': (public?['cityId'] as String?) ?? '',
      'cityLabel': (public?['cityLabel'] as String?) ?? '',
      'photoUrl': photos.isEmpty ? null : photos.first,
      'photoUrls': photos,
      'identityOnly': true,
    };
  }

  Future<Map<String, dynamic>?> _fetchIdentityPublic(String uid) async {
    try {
      final doc = await _db.doc('users/$uid').get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<DiscoveryCardModel?> _fetchListingById(
    AppDomainId domain,
    String listingId,
  ) async {
    final policy = AppDomains.byId(domain);
    try {
      final doc = await _db.doc('${policy.collection}/$listingId').get();
      if (!doc.exists) return null;
      return _listingFromJson(domain, doc.id, doc.data() ?? const {});
    } catch (_) {
      return null;
    }
  }

  /// Prefer an active listing that still has photos (fromSnap / enrich).
  Future<DiscoveryCardModel?> _bestPublicListing(
    AppDomainId domain,
    String ownerUid,
  ) async {
    final policy = AppDomains.byId(domain);
    try {
      if (policy.storageKind == DomainStorageKind.profiles) {
        final doc = await _db.doc('${policy.collection}/$ownerUid').get();
        if (!doc.exists) return null;
        return _listingFromJson(domain, doc.id, doc.data() ?? const {});
      }
      final snap = await _db
          .collection(policy.collection)
          .where('ownerId', isEqualTo: ownerUid)
          .where('active', isEqualTo: true)
          .limit(5)
          .get();
      if (snap.docs.isEmpty) return null;
      DiscoveryCardModel? fallback;
      for (final doc in snap.docs) {
        final card = _listingFromJson(domain, doc.id, doc.data());
        if (card.imageUrls.isNotEmpty) return card;
        fallback ??= card;
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  DiscoveryCardModel _listingFromJson(
    AppDomainId domain,
    String id,
    Map<String, dynamic> json,
  ) => DiscoveryCardModel(
    id: id,
    domain: domain,
    ownerId: json['ownerId'] as String? ?? json['userId'] as String? ?? id,
    title: json['title'] as String? ?? 'Untitled',
    subtitle: json['subtitle'] as String? ?? '',
    cityId: json['cityId'] as String? ?? '',
    cityLabel: json['cityLabel'] as String? ?? '',
    categoryTags: _stringList(json['categoryTags']),
    imageUrls: _stringList(json['photoUrls']),
    role: json['role'] as String?,
    ageBand: json['ageBand'] as String?,
    attributes: Map<String, Object?>.from(
      json['attributes'] as Map? ?? const {},
    ),
    verified: json['verified'] as bool? ?? false,
    active: json['active'] as bool? ?? true,
  );

  Future<String> _ensureUid() async {
    try {
      return (await FirebaseBootstrap.ensureSignedIn()).uid;
    } catch (_) {
      throw StateError('Sign-in needed before liking.');
    }
  }

  bool _snapshotHasPhotos(Map<String, Object?> snap) {
    if (snap.isEmpty) return false;
    if (_stringList(snap['photoUrls']).isNotEmpty) return true;
    final single = (snap['photoUrl'] as String?)?.trim() ?? '';
    return single.isNotEmpty;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => '$e'.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, Object?> _publicSnapshot(DiscoveryCardModel? card) {
    if (card == null) return const <String, Object?>{};
    final title = cardTitleLine(card);
    final clippedTitle = title.length > 60 ? title.substring(0, 60) : title;
    final fact = cardFactLine(card);
    final clippedFact = fact.length > 120 ? fact.substring(0, 120) : fact;
    return <String, Object?>{
      'listingId': card.id,
      'headline': clippedTitle,
      'title': clippedTitle,
      'subtitle': clippedFact,
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
    final photos = <String>{
      ..._stringList(snapshot['photoUrls']),
      if ((snapshot['photoUrl'] as String?)?.trim().isNotEmpty ?? false)
        (snapshot['photoUrl'] as String).trim(),
    }.toList(growable: false);
    final title =
        (snapshot['title'] as String?) ??
        (snapshot['headline'] as String?) ??
        'Liked';
    final attrs = Map<String, Object?>.from(
      snapshot['attributes'] as Map? ?? const {},
    );
    if (snapshot['identityOnly'] == true) {
      attrs['identityOnly'] = true;
    }
    return DiscoveryCardModel(
      id: (snapshot['listingId'] as String?) ?? otherUid,
      domain: domain,
      ownerId: otherUid,
      title: title,
      subtitle: (snapshot['subtitle'] as String?) ?? '',
      cityId: (snapshot['cityId'] as String?) ?? '',
      cityLabel: (snapshot['cityLabel'] as String?) ?? '',
      categoryTags: _stringList(snapshot['categoryTags']),
      imageUrls: photos,
      role: snapshot['role'] as String?,
      ageBand: snapshot['ageBand'] as String?,
      attributes: attrs,
      verified: snapshot['verified'] as bool? ?? false,
    );
  }
}
