import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import '../models/public_share_card.dart';
import 'firebase_bootstrap.dart';

class ShareCardRepository {
  ShareCardRepository({this.firestore, Random? random})
    : _random = random ?? Random.secure();

  final FirebaseFirestore? firestore;
  final Random _random;
  final Map<String, PublicShareCard> _memory = <String, PublicShareCard>{};
  final Map<String, String> _sourceToSlug = <String, String>{};

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  String pathFor(PublicShareCard card) =>
      'domains/${card.domainSlug}/public_cards/${card.slug}';

  String _newSlug(AppDomainId domain) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final token = List.generate(
      12,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    final prefix = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    return '${prefix}_$token';
  }

  Future<PublicShareCard> createOrUpdate(DiscoveryCardModel card) async {
    final sourceKey = '${card.ownerId}/${card.id}';
    var existingSlug = _sourceToSlug[sourceKey];
    final uid = FirebaseBootstrap.ready
        ? FirebaseAuth.instance.currentUser?.uid
        : null;
    final isOwner = uid != null && uid == card.ownerId;

    if (FirebaseBootstrap.ready && isOwner && existingSlug == null) {
      final domain = AppDomains.byId(card.domain).slug;
      final result = await _db
          .collection('domains/$domain/public_cards')
          .where('ownerId', isEqualTo: uid)
          .where('sourceId', isEqualTo: card.id)
          .limit(1)
          .get();
      if (result.docs.isNotEmpty) existingSlug = result.docs.first.id;
    }

    // Non-owners may only reuse an already-published/memory card.
    if (FirebaseBootstrap.ready && !isOwner) {
      if (existingSlug != null) {
        final cached = _memory[existingSlug];
        if (cached != null) return cached;
      }
      final domain = AppDomains.byId(card.domain).slug;
      final result = await _db
          .collection('domains/$domain/public_cards')
          .where('ownerId', isEqualTo: card.ownerId)
          .where('sourceId', isEqualTo: card.id)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (result.docs.isNotEmpty) {
        final doc = result.docs.first;
        final parsed = PublicShareCard.fromFirestore(doc.id, doc.data());
        if (parsed != null) {
          _memory[doc.id] = parsed;
          _sourceToSlug[sourceKey] = doc.id;
          return parsed;
        }
      }
      // Fallback: ephemeral redacted projection for share sheet text only.
      final ephemeral = PublicShareCard.fromDiscovery(
        card,
        slug: existingSlug ?? _newSlug(card.domain),
      );
      _memory[ephemeral.slug] = ephemeral;
      _sourceToSlug[sourceKey] = ephemeral.slug;
      return ephemeral;
    }

    final slug = existingSlug ?? _newSlug(card.domain);
    final share = PublicShareCard.fromDiscovery(card, slug: slug);
    _memory[slug] = share;
    _sourceToSlug[sourceKey] = slug;
    if (FirebaseBootstrap.ready && isOwner) {
      await _db.doc(pathFor(share)).set(share.toFirestore());
    }
    return share;
  }

  Future<PublicShareCard?> fetchBySlug(String slug) async {
    if (!PublicShareCard.isValidSlug(slug)) return null;
    final cached = _memory[slug];
    if (cached != null) return cached;
    final domain = PublicShareCard.domainFromSlug(slug);
    if (domain == null || !FirebaseBootstrap.ready) return null;
    final domainSlug = domain == AppDomainId.homeHelp
        ? 'home_help'
        : domain.name;
    final snap = await _db.doc('domains/$domainSlug/public_cards/$slug').get();
    if (!snap.exists) return null;
    final card = PublicShareCard.fromFirestore(slug, snap.data()!);
    if (card != null) _memory[slug] = card;
    return card;
  }

  Future<void> deactivate(String slug) async {
    final existing = _memory[slug];
    if (existing != null) {
      _memory[slug] = PublicShareCard(
        slug: existing.slug,
        active: false,
        ownerId: existing.ownerId,
        domain: existing.domain,
        sourceId: existing.sourceId,
        headline: existing.headline,
        locationLabel: existing.locationLabel,
        ageBand: existing.ageBand,
        role: existing.role,
        tradeLabel: existing.tradeLabel,
        categoryTags: existing.categoryTags,
        photoUrl: existing.photoUrl,
        verified: existing.verified,
        promoted: existing.promoted,
      );
    }
    final domain = PublicShareCard.domainFromSlug(slug);
    if (domain == null || !FirebaseBootstrap.ready) return;
    final domainSlug = domain == AppDomainId.homeHelp
        ? 'home_help'
        : domain.name;
    await _db.doc('domains/$domainSlug/public_cards/$slug').update({
      'active': false,
    });
  }

  /// Test/demo helper — seed a card into memory without Firebase.
  void putMemory(PublicShareCard card) {
    _memory[card.slug] = card;
    _sourceToSlug['${card.ownerId}/${card.sourceId}'] = card.slug;
  }
}
