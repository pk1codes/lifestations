import 'app_domain.dart';
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
  final String? ageBand;
  final String? role;
  final String? tradeLabel;
  final List<String> categoryTags;
  final String? photoUrl;
  final bool verified;
  final bool promoted;

  String get domainSlug =>
      domain == AppDomainId.homeHelp ? 'home_help' : domain.name;

  bool get isActive => active;

  static AppDomainId? domainFromSlug(String slug) {
    final parts = slug.split('_');
    if (parts.length < 2) return null;
    if (slug.startsWith('home_help_')) return AppDomainId.homeHelp;
    for (final domain in AppDomainId.values) {
      if (domain == AppDomainId.homeHelp) continue;
      if (slug.startsWith('${domain.name}_')) return domain;
    }
    return null;
  }

  static bool isValidSlug(String slug) {
    final domain = domainFromSlug(slug);
    if (domain == null) return false;
    final prefix = domain == AppDomainId.homeHelp
        ? 'home_help_'
        : '${domain.name}_';
    final token = slug.substring(prefix.length);
    return RegExp(r'^[a-zA-Z0-9]{6,64}$').hasMatch(token);
  }

  /// Builds a redacted headline — never copies free-text title/subtitle/bio.
  factory PublicShareCard.fromDiscovery(
    DiscoveryCardModel card, {
    required String slug,
  }) {
    final policy = AppDomains.byId(card.domain);
    final safeTags = card.categoryTags
        .where(_isSafeLabel)
        .take(5)
        .toList(growable: false);
    final tag = safeTags.isEmpty ? policy.label : safeTags.first;
    final role = _isSafeLabel(card.role) ? card.role : null;
    final headline = [
      if (card.domain == AppDomainId.jobs) _titleCase(tag) else policy.label,
      if (role != null && role.isNotEmpty) role,
      if (card.cityLabel.trim().isNotEmpty) card.cityLabel.trim(),
    ].join(' · ');
    return PublicShareCard(
      slug: slug,
      active: true,
      ownerId: card.ownerId,
      domain: card.domain,
      sourceId: card.id,
      headline: headline.length > 80 ? headline.substring(0, 80) : headline,
      locationLabel: card.cityLabel,
      ageBand: _isSafeLabel(card.ageBand) ? card.ageBand : null,
      role: role,
      tradeLabel:
          card.domain == AppDomainId.jobs && card.categoryTags.isNotEmpty
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
    if (domain == null ||
        data['domain'] !=
            (domain == AppDomainId.homeHelp ? 'home_help' : domain.name)) {
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

  static String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
