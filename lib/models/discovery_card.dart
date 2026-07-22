import 'app_domain.dart';

class DiscoveryCardModel {
  const DiscoveryCardModel({
    required this.id,
    required this.domain,
    required this.ownerId,
    required this.title,
    required this.subtitle,
    required this.cityId,
    required this.cityLabel,
    required this.categoryTags,
    required this.imageUrls,
    this.role,
    this.ageBand,
    this.attributes = const <String, Object?>{},
    this.verified = false,
    this.refreshed = false,
    this.promoted = false,
    this.active = true,
    this.refreshedAtMs,
  });

  final String id;
  final AppDomainId domain;
  final String ownerId;
  final String title;
  final String subtitle;
  final String cityId;
  final String cityLabel;
  final List<String> categoryTags;
  final List<String> imageUrls;
  final String? role;
  final String? ageBand;
  final Map<String, Object?> attributes;
  final bool verified;
  final bool refreshed;
  final bool promoted;

  /// False when the owner paused the listing (hidden from Browse).
  final bool active;

  /// Backend `refreshedAt` / `updatedAt` millis — used for local cache freshness.
  final int? refreshedAtMs;

  /// Stamp for “same as last time?” — prefer server time, else content fingerprint.
  String get cacheStamp {
    final ms = refreshedAtMs;
    if (ms != null && ms > 0) return '$id@$ms';
    return '$id|'
        '$title|'
        '$subtitle|'
        '$cityId|'
        '${imageUrls.join(',')}|'
        '$active|'
        '${categoryTags.join(',')}|'
        '${role ?? ''}|'
        '${ageBand ?? ''}';
  }

  DiscoveryCardModel copyWith({
    String? id,
    AppDomainId? domain,
    String? ownerId,
    String? title,
    String? subtitle,
    String? cityId,
    String? cityLabel,
    List<String>? categoryTags,
    List<String>? imageUrls,
    String? role,
    String? ageBand,
    Map<String, Object?>? attributes,
    bool? verified,
    bool? refreshed,
    bool? promoted,
    bool? active,
    int? refreshedAtMs,
  }) => DiscoveryCardModel(
    id: id ?? this.id,
    domain: domain ?? this.domain,
    ownerId: ownerId ?? this.ownerId,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    cityId: cityId ?? this.cityId,
    cityLabel: cityLabel ?? this.cityLabel,
    categoryTags: categoryTags ?? this.categoryTags,
    imageUrls: imageUrls ?? this.imageUrls,
    role: role ?? this.role,
    ageBand: ageBand ?? this.ageBand,
    attributes: attributes ?? this.attributes,
    verified: verified ?? this.verified,
    refreshed: refreshed ?? this.refreshed,
    promoted: promoted ?? this.promoted,
    active: active ?? this.active,
    refreshedAtMs: refreshedAtMs ?? this.refreshedAtMs,
  );

  Map<String, Object?> toPublicJson() {
    final json = <String, Object?>{
      'id': id,
      'domainId': AppDomains.byId(domain).slug,
      'ownerId': ownerId,
      'title': title,
      'subtitle': subtitle,
      'cityId': cityId,
      'cityLabel': cityLabel,
      'categoryTags': categoryTags,
      'photoUrls': imageUrls,
      'attributes': attributes,
      'verified': verified,
    };
    // Omit nulls — Firestore keeps null keys, and rules reject non-string role/ageBand.
    if (role != null) json['role'] = role;
    if (ageBand != null) json['ageBand'] = ageBand;
    return json;
  }

  static const forbiddenPublicKeys = <String>{
    'name',
    'displayName',
    'bio',
    'phone',
    'whatsappNumber',
    'telegramHandle',
    'rcUrl',
    'insuranceUrl',
  };

  static bool isPublicSafe(Map<String, Object?> value) {
    bool safeMap(Map<Object?, Object?> map) {
      for (final entry in map.entries) {
        if (forbiddenPublicKeys.contains(entry.key)) return false;
        final item = entry.value;
        if (item is Map && !safeMap(item)) return false;
      }
      return true;
    }

    return safeMap(value);
  }
}

class Identity {
  const Identity({
    this.userId = '',
    this.displayName = '',
    this.whatsappNumber = '',
    this.cityId = '',
    this.cityLabel = '',
    this.nativeLanguage = '',
    this.photoUrls = const <String>[],
    this.phoneVerified = false,
    this.dialCodePreference = '91',
  });

  final String userId;
  final String displayName;
  final String whatsappNumber;
  final String cityId;
  final String cityLabel;
  final String nativeLanguage;
  final List<String> photoUrls;
  final bool phoneVerified;

  /// Last chosen dial digits (`91` or `965`) for Account / OTP chips.
  final String dialCodePreference;

  bool get isValid =>
      displayName.trim().length >= 2 &&
      whatsappNumber.replaceAll(RegExp(r'\D'), '').length >= 8 &&
      cityId.isNotEmpty &&
      nativeLanguage.isNotEmpty &&
      nativeLanguage != 'Prefer not to say';

  Identity copyWith({
    String? userId,
    String? displayName,
    String? whatsappNumber,
    String? cityId,
    String? cityLabel,
    String? nativeLanguage,
    List<String>? photoUrls,
    bool? phoneVerified,
    String? dialCodePreference,
  }) => Identity(
    userId: userId ?? this.userId,
    displayName: displayName ?? this.displayName,
    whatsappNumber: whatsappNumber ?? this.whatsappNumber,
    cityId: cityId ?? this.cityId,
    cityLabel: cityLabel ?? this.cityLabel,
    nativeLanguage: nativeLanguage ?? this.nativeLanguage,
    photoUrls: photoUrls ?? this.photoUrls,
    phoneVerified: phoneVerified ?? this.phoneVerified,
    dialCodePreference: dialCodePreference ?? this.dialCodePreference,
  );
}
