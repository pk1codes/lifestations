import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import 'feed_throttle.dart';
import 'firebase_bootstrap.dart';

class DiscoverPage {
  const DiscoverPage({required this.cards, this.cursor});
  final List<DiscoveryCardModel> cards;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  bool get hasMore => cursor != null && cards.length >= 20;
}

abstract interface class DomainRepository {
  Future<List<DiscoveryCardModel>> discover(
    AppDomainId domain, {
    int limit = 20,
  });
  Future<DiscoverPage> discoverPage(
    AppDomainId domain, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  });
  Future<void> saveProfile(DiscoveryCardModel profile);
  Future<void> saveOffer(DiscoveryCardModel offer);
  Future<void> setListingActive({
    required AppDomainId domain,
    required String listingId,
    required bool active,
  });
  Future<void> deleteListing({
    required AppDomainId domain,
    required String listingId,
  });
  Future<DiscoveryCardModel?> fetchOwnedProfile({
    required AppDomainId domain,
    required String ownerId,
  });
  Future<DiscoveryCardModel?> fetchOwnedOffer({
    required AppDomainId domain,
    required String offerId,
  });
  Future<List<DiscoveryCardModel>> listOwnedOffers({
    required AppDomainId domain,
    required String ownerId,
  });
}

class FirestoreDomainRepository implements DomainRepository {
  FirestoreDomainRepository({this.firestore});
  static final FeedFetchThrottle _feedThrottle = FeedFetchThrottle();

  final FirebaseFirestore? firestore;

  FirebaseFirestore get db {
    final injected = firestore;
    if (injected != null) return injected;
    if (!FirebaseBootstrap.ready) {
      throw StateError('Firestore unavailable until bootstrap succeeds');
    }
    return FirebaseFirestore.instance;
  }

  @override
  Future<List<DiscoveryCardModel>> discover(
    AppDomainId domain, {
    int limit = 20,
  }) async {
    final page = await discoverPage(domain, limit: limit);
    return page.cards;
  }

  @override
  Future<DiscoverPage> discoverPage(
    AppDomainId domain, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    if (!FirebaseBootstrap.ready) {
      return const DiscoverPage(cards: <DiscoveryCardModel>[]);
    }
    if (!await _feedThrottle.allow()) {
      throw StateError('Feed is moving too fast. Try again soon.');
    }
    final policy = AppDomains.byId(domain);
    Query<Map<String, dynamic>> query = db
        .collection(policy.collection)
        .where('active', isEqualTo: true)
        .orderBy('refreshedAt', descending: true)
        .limit(limit.clamp(1, 20));
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    final cards = snapshot.docs
        .map((doc) => _fromJson(domain, doc.id, doc.data()))
        .toList(growable: false);
    return DiscoverPage(
      cards: cards,
      cursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  @override
  Future<void> saveProfile(DiscoveryCardModel profile) async {
    final policy = AppDomains.byId(profile.domain);
    if (policy.storageKind != DomainStorageKind.profiles) {
      throw ArgumentError('${policy.label} uses offers');
    }
    _assertSafe(profile);
    // Canonical path only — legacy top-level /profiles expects a different
    // schema and would fail the whole batch if dual-written.
    // Full replace (no merge) so leftover legacy keys cannot fail rules.
    await db.doc('${policy.collection}/${profile.ownerId}').set({
      ...profile.toPublicJson(),
      'active': true,
      'refreshedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> saveOffer(DiscoveryCardModel offer) async {
    final policy = AppDomains.byId(offer.domain);
    if (policy.storageKind != DomainStorageKind.offers) {
      throw ArgumentError('${policy.label} uses profiles');
    }
    _assertSafe(offer);
    // Full replace so legacy/forbidden keys cannot linger and fail rules.
    await db.doc('${policy.collection}/${offer.id}').set({
      ...offer.toPublicJson(),
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'refreshedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setListingActive({
    required AppDomainId domain,
    required String listingId,
    required bool active,
  }) async {
    if (!FirebaseBootstrap.ready || listingId.isEmpty) {
      throw StateError('Not connected. Try again.');
    }
    final policy = AppDomains.byId(domain);
    final data = <String, Object?>{
      'active': active,
      'refreshedAt': FieldValue.serverTimestamp(),
    };
    if (policy.storageKind == DomainStorageKind.offers) {
      data['updatedAt'] = FieldValue.serverTimestamp();
    }
    await db.doc('${policy.collection}/$listingId').update(data);
  }

  @override
  Future<void> deleteListing({
    required AppDomainId domain,
    required String listingId,
  }) async {
    if (!FirebaseBootstrap.ready || listingId.isEmpty) {
      throw StateError('Not connected. Try again.');
    }
    final policy = AppDomains.byId(domain);
    await db.doc('${policy.collection}/$listingId').delete();
  }

  @override
  Future<DiscoveryCardModel?> fetchOwnedProfile({
    required AppDomainId domain,
    required String ownerId,
  }) async {
    if (!FirebaseBootstrap.ready || ownerId.isEmpty) return null;
    final policy = AppDomains.byId(domain);
    if (policy.storageKind != DomainStorageKind.profiles) return null;
    try {
      final doc = await db.doc('${policy.collection}/$ownerId').get();
      if (!doc.exists || doc.data() == null) return null;
      return _fromJson(domain, doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DiscoveryCardModel?> fetchOwnedOffer({
    required AppDomainId domain,
    required String offerId,
  }) async {
    if (!FirebaseBootstrap.ready || offerId.isEmpty) return null;
    final policy = AppDomains.byId(domain);
    if (policy.storageKind != DomainStorageKind.offers) return null;
    try {
      final doc = await db.doc('${policy.collection}/$offerId').get();
      if (!doc.exists || doc.data() == null) return null;
      return _fromJson(domain, doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DiscoveryCardModel>> listOwnedOffers({
    required AppDomainId domain,
    required String ownerId,
  }) async {
    if (!FirebaseBootstrap.ready || ownerId.isEmpty) {
      return const <DiscoveryCardModel>[];
    }
    final policy = AppDomains.byId(domain);
    if (policy.storageKind != DomainStorageKind.offers) {
      return const <DiscoveryCardModel>[];
    }
    try {
      final snap = await db
          .collection(policy.collection)
          .where('ownerId', isEqualTo: ownerId)
          .limit(policy.maxProfiles)
          .get();
      return snap.docs
          .map((doc) => _fromJson(domain, doc.id, doc.data()))
          .toList(growable: false);
    } catch (_) {
      return const <DiscoveryCardModel>[];
    }
  }

  void _assertSafe(DiscoveryCardModel card) {
    if (!DiscoveryCardModel.isPublicSafe(card.toPublicJson())) {
      throw StateError('Public domain documents cannot contain private fields');
    }
  }

  DiscoveryCardModel _fromJson(
    AppDomainId domain,
    String id,
    Map<String, dynamic> json,
  ) => DiscoveryCardModel(
    id: id,
    domain: domain,
    ownerId: json['ownerId'] as String? ?? json['userId'] as String? ?? '',
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
}

class ScopedSyncEngine {
  const ScopedSyncEngine(this.repository);
  final DomainRepository repository;

  static bool _isDemo(DiscoveryCardModel card) =>
      card.id.startsWith('demo_') || card.ownerId.startsWith('demo_owner_');

  /// Pulls the live feed. When remote has cards, demos are dropped entirely.
  Future<List<DiscoveryCardModel>> merge({
    required AppDomainId domain,
    required List<DiscoveryCardModel> local,
  }) async {
    try {
      // Browse rules require auth — wait/restore/anonymous before querying.
      if (FirebaseBootstrap.ready) {
        try {
          await FirebaseBootstrap.ensureSignedIn();
        } catch (_) {
          // Fall through; discover will fail closed to local.
        }
      }
      final remote = await repository.discover(domain);
      if (remote.isNotEmpty) {
        return remote;
      }
      // Empty remote: keep local only if it isn't just demos we already showed.
      return local;
    } catch (_) {
      return local;
    }
  }

  /// Drops bundled demo cards (used when a live feed is available).
  static List<DiscoveryCardModel> withoutDemos(
    Iterable<DiscoveryCardModel> cards,
  ) =>
      cards.where((card) => !_isDemo(card)).toList(growable: false);
}
