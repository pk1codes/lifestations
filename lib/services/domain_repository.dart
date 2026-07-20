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
    final batch = db.batch();
    final canonical = db.doc('${policy.collection}/${profile.ownerId}');
    batch.set(canonical, {
      ...profile.toPublicJson(),
      'active': true,
      'refreshedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (profile.domain == AppDomainId.marriage) {
      batch.set(db.doc('profiles/${profile.ownerId}'), {
        ...profile.toPublicJson(),
        'active': true,
        'refreshedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> saveOffer(DiscoveryCardModel offer) async {
    final policy = AppDomains.byId(offer.domain);
    if (policy.storageKind != DomainStorageKind.offers) {
      throw ArgumentError('${policy.label} uses profiles');
    }
    _assertSafe(offer);
    await db.doc('${policy.collection}/${offer.id}').set({
      ...offer.toPublicJson(),
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'refreshedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
  );
}

class ScopedSyncEngine {
  const ScopedSyncEngine(this.repository);
  final DomainRepository repository;

  Future<List<DiscoveryCardModel>> merge({
    required AppDomainId domain,
    required List<DiscoveryCardModel> local,
  }) async {
    try {
      final remote = await repository.discover(domain);
      if (remote.isEmpty) return local;
      final merged = <String, DiscoveryCardModel>{
        for (final card in local) card.id: card,
      };
      for (final card in remote) {
        merged[card.id] = card;
      }
      return merged.values.toList(growable: false);
    } catch (_) {
      return local;
    }
  }
}
