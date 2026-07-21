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

  String _activeKey(AppDomainId domain, [int? index]) {
    if (index == null) return 'owned_active_${domain.name}';
    return 'owned_active_${domain.name}_$index';
  }

  /// Defaults to live (true) when unset.
  bool isActive(AppDomainId domain, [int? index]) {
    return _prefs.getBool(_activeKey(domain, index)) ?? true;
  }

  Future<void> setActive(
    AppDomainId domain,
    bool active, {
    int? index,
  }) async {
    await _prefs.setBool(_activeKey(domain, index), active);
    notifyListeners();
  }

  Future<void> clearPhotos(AppDomainId domain, [int? index]) async {
    await _prefs.remove(_photosKey(domain, index));
    notifyListeners();
  }

  /// After deleting offer slot [index], shift later photo/id/active keys down.
  Future<void> removeOfferSlot(AppDomainId domain, int index) async {
    final maxSlots = AppDomains.byId(domain).maxProfiles;
    for (var i = index; i < maxSlots - 1; i++) {
      final nextPhotos =
          _prefs.getStringList(_photosKey(domain, i + 1)) ?? const <String>[];
      final nextId = _prefs.getString(_offerIdKey(domain, i + 1));
      final nextActive = _prefs.getBool(_activeKey(domain, i + 1));
      if (nextPhotos.isEmpty) {
        await _prefs.remove(_photosKey(domain, i));
      } else {
        await _prefs.setStringList(_photosKey(domain, i), nextPhotos);
      }
      if (nextId == null) {
        await _prefs.remove(_offerIdKey(domain, i));
      } else {
        await _prefs.setString(_offerIdKey(domain, i), nextId);
      }
      if (nextActive == null) {
        await _prefs.remove(_activeKey(domain, i));
      } else {
        await _prefs.setBool(_activeKey(domain, i), nextActive);
      }
    }
    final last = maxSlots - 1;
    await _prefs.remove(_photosKey(domain, last));
    await _prefs.remove(_offerIdKey(domain, last));
    await _prefs.remove(_activeKey(domain, last));
    notifyListeners();
  }

  Future<void> clearProfileSlot(AppDomainId domain) async {
    await _prefs.remove(_photosKey(domain));
    await _prefs.remove(_activeKey(domain));
    notifyListeners();
  }
}
