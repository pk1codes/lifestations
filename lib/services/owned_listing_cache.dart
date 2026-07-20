import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_domain.dart';

/// Persists photo URLs and offer document ids for the owner's own posts.
///
/// Profile stores keep typed fields only; discovery photos live here so
/// My posts can show the same cards the owner published.
class OwnedListingCache extends ChangeNotifier {
  OwnedListingCache(this._prefs);

  final SharedPreferences _prefs;

  String _photosKey(AppDomainId domain, [int? index]) {
    if (index == null) return 'owned_photos_${domain.name}';
    return 'owned_photos_${domain.name}_$index';
  }

  String _offerIdKey(AppDomainId domain, int index) =>
      'owned_offer_id_${domain.name}_$index';

  List<String> photos(AppDomainId domain, [int? index]) {
    final raw = _prefs.getStringList(_photosKey(domain, index)) ?? const <String>[];
    return raw.where((url) => url.trim().isNotEmpty).toList(growable: false);
  }

  Future<void> setPhotos(
    AppDomainId domain,
    List<String> urls, {
    int? index,
  }) async {
    final cleaned = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    await _prefs.setStringList(_photosKey(domain, index), cleaned);
    notifyListeners();
  }

  String offerId(AppDomainId domain, int index) {
    return _prefs.getString(_offerIdKey(domain, index)) ??
        '${domain.name}_$index';
  }

  Future<void> setOfferId(AppDomainId domain, int index, String id) async {
    await _prefs.setString(_offerIdKey(domain, index), id);
    notifyListeners();
  }
}
