import 'app_domain.dart';
import 'card_side.dart';
import 'discovery_card.dart';

/// Redacted public projection for `/c/{slug}` deep links.
class PublicShareCard {
  const PublicShareCard({
    required this.slug,
    required this.active,
    required this.ownerId,
    required this.domain,
    required this.sourceId,
    required this.headline,
    required this.locationLabel,
    this.detailLine = '',
    this.sideLabel,
    this.ageBand,
    this.role,
    this.tradeLabel,
    this.categoryTags = const <String>[],
    this.photoUrl,
    this.verified = false,
    this.promoted = false,
  });

  static const allowlist = <String>{
    'slug',
    'active',
    'ownerId',
    'domain',
    'sourceId',
    'headline',
    'locationLabel',
    'detailLine',
    'sideLabel',
    'ageBand',
    'role',
    'tradeLabel',
    'categoryTags',
    'photoUrl',
    'verified',
    'promoted',
  };

  static const forbidden = <String>{
    'name',
    'displayName',
    'bio',
    'phone',
    'whatsappNumber',
    'telegramHandle',
    'rcUrl',
    'insuranceUrl',
    'title',
    'subtitle',
  };

  final String slug;
  final bool active;
  final String ownerId;
  final AppDomainId domain;
  final String sourceId;
  final String headline;
  final String locationLabel;
  final String detailLine;
  final String? sideLabel;
  final String? ageBand;
  final String? role;
  final String? tradeLabel;
  final List<String> categoryTags;
  final String? photoUrl;
  final bool verified;
  final bool promoted;

  String get domainSlug => AppDomains.byId(domain).slug;

  bool get isActive => active;

  static AppDomainId? domainFromSlug(String slug) {
    // Longer slugs first so kuwait_jobs_ wins over jobs_.
    final policies = [...AppDomains.all]
      ..sort((a, b) => b.slug.length.compareTo(a.slug.length));
    for (final policy in policies) {
      if (slug.startsWith('${policy.slug}_')) return policy.id;
    }
    return null;
  }

  static bool isValidSlug(String slug) {
    final domain = domainFromSlug(slug);
    if (domain == null) return false;
    final prefix = '${AppDomains.byId(domain).slug}_';
    final token = slug.substring(prefix.length);
    return RegExp(r'^[a-zA-Z0-9]{6,64}$').hasMatch(token);
  }

  /// Builds a redacted headline from structured fields only — never free-text.
  factory PublicShareCard.fromDiscovery(
    DiscoveryCardModel card, {
    required String slug,
  }) {
    final policy = AppDomains.byId(card.domain);
    final safeTags = card.categoryTags
        .where(_isSafeLabel)
        .take(5)
        .toList(growable: false);
    final role = _isSafeLabel(card.role) ? card.role : null;
    var headline = cardTitleLine(card, allowFallback: false).trim();
    if (headline.isEmpty) headline = policy.label;
    if (headline.length > 80) headline = headline.substring(0, 80);
    final fact = cardFactLine(card).trim();
    final detail = fact.length > 80 ? fact.substring(0, 80) : fact;
    final side = cardSideMark(card)?.label;
    return PublicShareCard(
      slug: slug,
      active: true,
      ownerId: card.ownerId,
      domain: card.domain,
      sourceId: card.id,
      headline: headline,
      locationLabel: card.cityLabel,
      detailLine: detail,
      sideLabel: side,
      ageBand: _isSafeLabel(card.ageBand) ? card.ageBand : null,
      role: role,
      tradeLabel:
          (card.domain == AppDomainId.jobs ||
                  card.domain == AppDomainId.kuwaitJobs) &&
              card.categoryTags.isNotEmpty
          ? card.categoryTags.first
          : null,
      categoryTags: safeTags,
      photoUrl: card.imageUrls.isEmpty
          ? null
          : _safePhoto(card.imageUrls.first),
      verified: card.verified,
      promoted: card.promoted,
    );
  }

  Map<String, Object?> toFirestore() {
    final map = <String, Object?>{
      'slug': slug,
      'active': active,
      'ownerId': ownerId,
      'domain': domainSlug,
      'sourceId': sourceId,
      'headline': headline,
      'locationLabel': locationLabel,
      if (detailLine.isNotEmpty)
        'detailLine': detailLine.length > 80
            ? detailLine.substring(0, 80)
            : detailLine,
      if (sideLabel != null)
        'sideLabel': sideLabel!.length > 40
            ? sideLabel!.substring(0, 40)
            : sideLabel,
      if (ageBand != null) 'ageBand': ageBand,
      if (role != null) 'role': role,
      if (tradeLabel != null) 'tradeLabel': tradeLabel,
      if (categoryTags.isNotEmpty) 'categoryTags': categoryTags,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'verified': verified,
      'promoted': promoted,
    };
    assert(map.keys.every(allowlist.contains));
    assert(map.keys.every((key) => !forbidden.contains(key)));
    return map;
  }

  static PublicShareCard? fromFirestore(
    String slug,
    Map<String, dynamic> data,
  ) {
    for (final key in data.keys) {
      if (forbidden.contains(key)) return null;
      if (!allowlist.contains(key)) return null;
    }
    if (!isValidSlug(slug) || data['slug'] != slug) return null;
    final domain = domainFromSlug(slug);
    if (domain == null || data['domain'] != AppDomains.byId(domain).slug) {
      return null;
    }
    if (data['active'] is! bool ||
        data['ownerId'] is! String ||
        data['sourceId'] is! String ||
        data['headline'] is! String ||
        data['locationLabel'] is! String) {
      return null;
    }
    return PublicShareCard(
      slug: slug,
      active: data['active'] as bool,
      ownerId: data['ownerId'] as String,
      domain: domain,
      sourceId: data['sourceId'] as String,
      headline: data['headline'] as String,
      locationLabel: data['locationLabel'] as String,
      detailLine: data['detailLine'] as String? ?? '',
      sideLabel: data['sideLabel'] as String?,
      ageBand: data['ageBand'] as String?,
      role: data['role'] as String?,
      tradeLabel: data['tradeLabel'] as String?,
      categoryTags: List<String>.from(
        data['categoryTags'] as List? ?? const [],
      ),
      photoUrl: data['photoUrl'] as String?,
      verified: data['verified'] as bool? ?? false,
      promoted: data['promoted'] as bool? ?? false,
    );
  }

  static bool _isSafeLabel(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 60 &&
        !RegExp(r'\d{7,}').hasMatch(trimmed) &&
        !trimmed.contains('@');
  }

  static String? _safePhoto(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return value;
    }
    return value.startsWith('assets/') || value.startsWith('initial_seeds/')
        ? value
        : null;
  }
}
