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

  Map<String, Object?> toPublicJson() => <String, Object?>{
    'id': id,
    'domainId': AppDomains.byId(domain).slug,
    'ownerId': ownerId,
    'title': title,
    'subtitle': subtitle,
    'cityId': cityId,
    'cityLabel': cityLabel,
    'categoryTags': categoryTags,
    'photoUrls': imageUrls,
    'role': role,
    'ageBand': ageBand,
    'attributes': attributes,
    'verified': verified,
  };

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
  });

  final String userId;
  final String displayName;
  final String whatsappNumber;
  final String cityId;
  final String cityLabel;
  final String nativeLanguage;
  final List<String> photoUrls;
  final bool phoneVerified;

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
  }) => Identity(
    userId: userId ?? this.userId,
    displayName: displayName ?? this.displayName,
    whatsappNumber: whatsappNumber ?? this.whatsappNumber,
    cityId: cityId ?? this.cityId,
    cityLabel: cityLabel ?? this.cityLabel,
    nativeLanguage: nativeLanguage ?? this.nativeLanguage,
    photoUrls: photoUrls ?? this.photoUrls,
    phoneVerified: phoneVerified ?? this.phoneVerified,
  );
}
