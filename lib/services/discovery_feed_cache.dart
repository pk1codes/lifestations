import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_domain.dart';
import '../models/discovery_card.dart';

/// Local-first Browse feed cache — persist cards; replace only when stamp changes.
class DiscoveryFeedCache {
  DiscoveryFeedCache(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'discovery_feed_v1_';

  String _key(AppDomainId domain) => '$_prefix${domain.name}';

  static bool isDemo(DiscoveryCardModel card) =>
      card.id.startsWith('demo_') || card.ownerId.startsWith('demo_owner_');

  List<DiscoveryCardModel> read(AppDomainId domain) {
    final raw = _prefs.getString(_key(domain));
    if (raw == null || raw.isEmpty) return const <DiscoveryCardModel>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((row) => fromCacheJson(domain, Map<String, Object?>.from(row)))
          .where((card) => !isDemo(card) && card.active)
          .toList(growable: false);
    } catch (_) {
      return const <DiscoveryCardModel>[];
    }
  }

  Future<void> write(
    AppDomainId domain,
    Iterable<DiscoveryCardModel> cards,
  ) async {
    final live = cards
        .where((card) => card.domain == domain && !isDemo(card) && card.active)
        .take(40)
        .map(toCacheJson)
        .toList(growable: false);
    if (live.isEmpty) {
      await _prefs.remove(_key(domain));
      return;
    }
    await _prefs.setString(_key(domain), jsonEncode(live));
  }

  /// Keep local objects when stamps match; take remote when new/changed.
  static List<DiscoveryCardModel> mergeKeepingUnchanged(
    List<DiscoveryCardModel> local,
    List<DiscoveryCardModel> remote,
  ) {
    if (remote.isEmpty) return local;
    final localById = <String, DiscoveryCardModel>{
      for (final card in local) card.id: card,
    };
    return [
      for (final next in remote)
        if (localById[next.id]?.cacheStamp == next.cacheStamp)
          localById[next.id]!
        else
          next,
    ];
  }

  static Map<String, Object?> toCacheJson(DiscoveryCardModel card) {
    final json = card.toPublicJson();
    json['active'] = card.active;
    json['refreshed'] = card.refreshed;
    json['promoted'] = card.promoted;
    if (card.refreshedAtMs != null) {
      json['refreshedAtMs'] = card.refreshedAtMs;
    }
    return json;
  }

  static DiscoveryCardModel fromCacheJson(
    AppDomainId domain,
    Map<String, Object?> json,
  ) {
    final slug = json['domainId'] as String?;
    var resolved = domain;
    if (slug != null) {
      for (final policy in AppDomains.all) {
        if (policy.slug == slug) {
          resolved = policy.id;
          break;
        }
      }
    }
    return DiscoveryCardModel(
      id: json['id'] as String? ?? '',
      domain: resolved,
      ownerId: json['ownerId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      subtitle: json['subtitle'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      cityLabel: json['cityLabel'] as String? ?? '',
      categoryTags: List<String>.from(
        json['categoryTags'] as List? ?? const <String>[],
      ),
      imageUrls: List<String>.from(
        json['photoUrls'] as List? ?? const <String>[],
      ),
      role: json['role'] as String?,
      ageBand: json['ageBand'] as String?,
      attributes: Map<String, Object?>.from(
        json['attributes'] as Map? ?? const <String, Object?>{},
      ),
      verified: json['verified'] as bool? ?? false,
      refreshed: json['refreshed'] as bool? ?? false,
      promoted: json['promoted'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      refreshedAtMs: (json['refreshedAtMs'] as num?)?.toInt(),
    );
  }
}
