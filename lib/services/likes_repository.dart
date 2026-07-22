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
    this.createdAt,
    this.peerOpenedChat = false,
  });

  final AppDomainId domain;
  final String otherUid;
  final LikeDirection direction;
  final DiscoveryCardModel? card;
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
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final targetSnap = _publicSnapshot(card);
    // Inbound must show the liker's public card so the owner can like back.
    var fromSnap = _publicSnapshot(fromCard);
    if (fromSnap.isEmpty) {
      fromSnap = _publicSnapshot(await _fetchPublicListing(domain, uid));
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
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
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
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    yield* _db
        .collection('domains/$slug/likes/$uid/inbound')
        .limit(100)
        .snapshots()
        .asyncMap((snap) async {
          final entries = snap.docs
              .map((doc) => _entryFromDoc(domain, LikeDirection.inbound, doc))
              .toList(growable: false);
          return _enrichAll(entries);
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
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
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
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
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
      final snap = await _db.collection(collection).limit(100).get();
      final entries = snap.docs
          .map((doc) => _entryFromDoc(domain, direction, doc))
          .toList(growable: false);
      return _enrichAll(entries);
    }
  }

  Future<List<LikeEntry>> _enrichAll(List<LikeEntry> entries) async {
    if (entries.isEmpty) return entries;
    return Future.wait(entries.map(_enrichIdentityPhoto));
  }

  /// Fill missing photos from the peer's universal identity image.
  Future<LikeEntry> _enrichIdentityPhoto(LikeEntry entry) async {
    final card = entry.card;
    if (card != null && card.imageUrls.isNotEmpty) return entry;
    final public = await _fetchIdentityPublic(entry.otherUid);
    if (public == null) return entry;
    final photos = List<String>.from(
      public['photoUrls'] as List? ?? const <dynamic>[],
    ).where((url) => url.trim().isNotEmpty).toList(growable: false);
    if (photos.isEmpty) return entry;
    final name = (public['displayName'] as String?)?.trim() ?? '';
    final fallbackTitle = name.length >= 2 ? name : 'Liked';
    final existingTitle = card?.title.trim() ?? '';
    final title =
        (existingTitle.isEmpty ||
            existingTitle == 'Someone' ||
            existingTitle == 'Liked' ||
            existingTitle == 'Liked post')
        ? fallbackTitle
        : existingTitle;
    return LikeEntry(
      domain: entry.domain,
      otherUid: entry.otherUid,
      direction: entry.direction,
      createdAt: entry.createdAt,
      peerOpenedChat: entry.peerOpenedChat,
      card: DiscoveryCardModel(
        id: card?.id ?? entry.otherUid,
        domain: entry.domain,
        ownerId: entry.otherUid,
        title: title,
        subtitle: card?.subtitle ?? '',
        cityId: (card?.cityId.isNotEmpty ?? false)
            ? card!.cityId
            : (public['cityId'] as String? ?? ''),
        cityLabel: (card?.cityLabel.isNotEmpty ?? false)
            ? card!.cityLabel
            : (public['cityLabel'] as String? ?? ''),
        categoryTags: card?.categoryTags ?? const <String>[],
        imageUrls: photos,
        role: card?.role,
        ageBand: card?.ageBand,
        attributes: card?.attributes ?? const <String, Object?>{},
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
      peerOpenedChat: data['peerOpenedChat'] == true,
    );
  }

  Future<Map<String, Object?>> _identityFallbackSnapshot(String uid) async {
    final public = await _fetchIdentityPublic(uid);
    final name = (public?['displayName'] as String?)?.trim() ?? '';
    final title = name.length >= 2 ? name : 'Liked';
    final photos = List<String>.from(
      public?['photoUrls'] as List? ?? const <dynamic>[],
    ).where((url) => url.trim().isNotEmpty).toList(growable: false);
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

  Future<DiscoveryCardModel?> _fetchPublicListing(
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
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return _listingFromJson(domain, doc.id, doc.data());
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
    categoryTags: List<String>.from(json['categoryTags'] as List? ?? const []),
    imageUrls: List<String>.from(json['photoUrls'] as List? ?? const []),
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
        'Liked';
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
