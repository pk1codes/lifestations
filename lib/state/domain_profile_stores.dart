import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_domain.dart';
import '../models/domain_profiles.dart';
import '../services/safety_repository.dart';

abstract class LocalFirstStore<T> extends ChangeNotifier {
  T? _value;
  bool syncing = false;
  String? syncError;

  T? get value => _value;

  @protected
  void setValue(T? value) {
    _value = value;
  }

  void saveLocal(T value) {
    _value = value;
    syncError = null;
    notifyListeners();
    persistLocal(value);
  }

  /// Clears the local profile (used when the owner deletes the post).
  void clearLocal() {
    _value = null;
    syncError = null;
    notifyListeners();
    clearPersisted();
  }

  /// Override to persist across restarts.
  @protected
  void persistLocal(T value) {}

  /// Override to remove persisted profile data.
  @protected
  void clearPersisted() {}

  /// Returns `true` when remote write succeeds.
  Future<bool> synchronize(Future<void> Function(T value) write) async {
    final current = _value;
    if (current == null || syncing) return false;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await write(current);
      return true;
    } catch (error) {
      syncError = _friendlySyncError(error);
      debugPrint('Remote sync failed: $error');
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}

String _friendlySyncError(Object error) {
  final text = '$error'.toLowerCase();
  if (text.contains('permission-denied') || text.contains('permission_denied')) {
    return 'Could not save. Check sign-in and try again.';
  }
  if (text.contains('resource-exhausted') || text.contains('too many')) {
    return 'Too many saves. Wait a minute and try again.';
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'Network problem. Try again.';
  }
  if (text.contains('disallowed') || text.contains('safesearch')) {
    return 'That content cannot be saved. Change the text and try again.';
  }
  return 'Could not save online. Try again.';
}

class ProfileStore extends LocalFirstStore<MarriageProfile> {
  ProfileStore([SharedPreferences? preferences]) : _prefs = preferences {
    _load();
  }

  static const _key = 'owned_marriage_profile_json';
  final SharedPreferences? _prefs;

  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setValue(_marriageFromJson(map));
    } catch (_) {}
  }

  @override
  void persistLocal(MarriageProfile value) {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(prefs.setString(_key, jsonEncode(_marriageToJson(value))));
  }

  @override
  void clearPersisted() {
    unawaited(_prefs?.remove(_key) ?? Future<void>.value());
  }
}

class JobsProfileStore extends LocalFirstStore<JobsProfile> {
  JobsProfileStore([SharedPreferences? preferences]) : _prefs = preferences {
    _load();
  }

  static const _key = 'owned_jobs_profile_json';
  final SharedPreferences? _prefs;

  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setValue(
        JobsProfile(
          role: map['role'] as String? ?? 'seek',
          tradeId: map['tradeId'] as String? ?? JobsProfile.trades.first,
          cityId: map['cityId'] as String? ?? 'mumbai',
          salaryBand:
              map['salaryBand'] as String? ?? JobsProfile.salaryBands.first,
        ),
      );
    } catch (_) {}
  }

  @override
  void persistLocal(JobsProfile value) {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(
      prefs.setString(
        _key,
        jsonEncode({
          'role': value.role,
          'tradeId': value.tradeId,
          'cityId': value.cityId,
          'salaryBand': value.salaryBand,
        }),
      ),
    );
  }

  @override
  void clearPersisted() {
    unawaited(_prefs?.remove(_key) ?? Future<void>.value());
  }
}

abstract class MultiOfferStore<T> extends ChangeNotifier {
  MultiOfferStore(this.domain, {SharedPreferences? preferences})
    : _prefs = preferences {
    loadPersisted();
  }
  final AppDomainId domain;
  final SharedPreferences? _prefs;
  final List<T> _offers = <T>[];

  List<T> get offers => List.unmodifiable(_offers);
  int get limit => AppDomains.byId(domain).maxProfiles;

  @protected
  SharedPreferences? get prefs => _prefs;

  @protected
  void loadPersisted() {}

  @protected
  void persistOffers() {}

  void replaceAll(List<T> offers) {
    _offers
      ..clear()
      ..addAll(offers);
    notifyListeners();
    persistOffers();
  }

  void upsert(T offer, {int? index}) {
    if (index != null) {
      _offers[index] = offer;
    } else {
      if (_offers.length >= limit) throw StateError('Offer limit reached');
      _offers.add(offer);
    }
    notifyListeners();
    persistOffers();
  }

  void removeAt(int index) {
    _offers.removeAt(index);
    notifyListeners();
    persistOffers();
  }

  @protected
  void setOffersForLoad(List<T> values) {
    _offers
      ..clear()
      ..addAll(values);
  }
}

class RoomsOfferStore extends MultiOfferStore<RoomsOffer> {
  RoomsOfferStore({SharedPreferences? preferences})
    : super(AppDomainId.rooms, preferences: preferences);

  static const _key = 'owned_rooms_offers_json';

  @override
  void loadPersisted() {
    final raw = prefs?.getStringList(_key);
    if (raw == null || raw.isEmpty) return;
    final loaded = <RoomsOffer>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        loaded.add(
          RoomsOffer(
            type: map['type'] as String? ?? RoomsOffer.types.first,
            furnishing:
                map['furnishing'] as String? ??
                RoomsOffer.furnishingOptions.first,
            monthlyRent: map['monthlyRent'] as int? ?? RoomsOffer.rentPresets.first,
            depositMonths: map['depositMonths'] as int? ?? 0,
            cityId: map['cityId'] as String? ?? 'mumbai',
            photoCount: map['photoCount'] as int? ?? 2,
            amenities: List<String>.from(
              map['amenities'] as List? ?? const <String>[],
            ),
            hasAddressProof: map['hasAddressProof'] == true,
          ),
        );
      } catch (_) {}
    }
    setOffersForLoad(loaded);
  }

  @override
  void persistOffers() {
    final p = prefs;
    if (p == null) return;
    unawaited(
      p.setStringList(
        _key,
        offers
            .map(
              (o) => jsonEncode({
                'type': o.type,
                'furnishing': o.furnishing,
                'monthlyRent': o.monthlyRent,
                'depositMonths': o.depositMonths,
                'cityId': o.cityId,
                'photoCount': o.photoCount,
                'amenities': o.amenities,
                'hasAddressProof': o.hasAddressProof,
              }),
            )
            .toList(growable: false),
      ),
    );
  }
}

class BikesOfferStore extends MultiOfferStore<BikesOffer> {
  BikesOfferStore({SharedPreferences? preferences})
    : super(AppDomainId.bikes, preferences: preferences);

  static const _key = 'owned_bikes_offers_json';

  @override
  void loadPersisted() {
    final raw = prefs?.getStringList(_key);
    if (raw == null || raw.isEmpty) return;
    final loaded = <BikesOffer>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        loaded.add(
          BikesOffer(
            type: map['type'] as String? ?? BikesOffer.types.first,
            transmission:
                map['transmission'] as String? ??
                BikesOffer.transmissions.first,
            make: map['make'] as String? ?? BikesOffer.makes.first,
            hourlyRent:
                map['hourlyRent'] as int? ?? BikesOffer.hourlyRentPresets.first,
            photoCount: map['photoCount'] as int? ?? 4,
            cityId: map['cityId'] as String? ?? 'mumbai',
            model: map['model'] as String?,
            availableWeekdays: List<String>.from(
              map['availableWeekdays'] as List? ?? BikesOffer.weekdays,
            ),
            fromTime: map['fromTime'] as String? ?? '09:00',
            toTime: map['toTime'] as String? ?? '20:00',
            hasRc: map['hasRc'] == true,
            hasInsurance: map['hasInsurance'] == true,
          ),
        );
      } catch (_) {}
    }
    setOffersForLoad(loaded);
  }

  @override
  void persistOffers() {
    final p = prefs;
    if (p == null) return;
    unawaited(
      p.setStringList(
        _key,
        offers
            .map(
              (o) => jsonEncode({
                'type': o.type,
                'transmission': o.transmission,
                'make': o.make,
                'hourlyRent': o.hourlyRent,
                'photoCount': o.photoCount,
                'cityId': o.cityId,
                'model': o.model,
                'availableWeekdays': o.availableWeekdays,
                'fromTime': o.fromTime,
                'toTime': o.toTime,
                'hasRc': o.hasRc,
                'hasInsurance': o.hasInsurance,
              }),
            )
            .toList(growable: false),
      ),
    );
  }
}

class HomeHelpOfferStore extends MultiOfferStore<HomeHelpOffer> {
  HomeHelpOfferStore({SharedPreferences? preferences})
    : super(AppDomainId.homeHelp, preferences: preferences);

  static const _key = 'owned_home_help_offers_json';

  @override
  void loadPersisted() {
    final raw = prefs?.getStringList(_key);
    if (raw == null || raw.isEmpty) return;
    final loaded = <HomeHelpOffer>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        loaded.add(
          HomeHelpOffer(
            role: map['role'] as String? ?? HomeHelpOffer.roles.first,
            service: map['service'] as String? ?? HomeHelpOffer.services.first,
            shift: map['shift'] as String? ?? HomeHelpOffer.shifts.first,
            salaryBand:
                map['salaryBand'] as String? ?? HomeHelpOffer.salaryBands.first,
            languages: List<String>.from(
              map['languages'] as List? ?? const <String>['Hindi'],
            ),
            photoCount: map['photoCount'] as int? ?? 0,
            cityId: map['cityId'] as String? ?? 'mumbai',
          ),
        );
      } catch (_) {}
    }
    setOffersForLoad(loaded);
  }

  @override
  void persistOffers() {
    final p = prefs;
    if (p == null) return;
    unawaited(
      p.setStringList(
        _key,
        offers
            .map(
              (o) => jsonEncode({
                'role': o.role,
                'service': o.service,
                'shift': o.shift,
                'salaryBand': o.salaryBand,
                'languages': o.languages,
                'photoCount': o.photoCount,
                'cityId': o.cityId,
              }),
            )
            .toList(growable: false),
      ),
    );
  }
}

class MatchPreferencesStore extends ChangeNotifier {
  String? cityId;
  String? gender;
  String? ageBand;

  void update({String? city, String? genderValue, String? age}) {
    cityId = city;
    gender = genderValue;
    ageBand = age;
    notifyListeners();
  }
}

class JobsDiscoverPrefsStore extends ChangeNotifier {
  String? cityId;
  String? role;
  String? tradeId;

  void update({String? city, String? roleValue, String? trade}) {
    cityId = city;
    role = roleValue;
    tradeId = trade;
    notifyListeners();
  }
}

class BlockStore extends ChangeNotifier {
  BlockStore({
    this.onBlock,
    SharedPreferences? preferences,
    SafetyRepository? safety,
  }) : _prefs = preferences,
       _safety = safety ?? SafetyRepository() {
    final saved = _prefs?.getStringList(_prefsKey) ?? const <String>[];
    _ids.addAll(saved);
  }

  static const _prefsKey = 'blocked_user_ids';
  final void Function(String id)? onBlock;
  final SharedPreferences? _prefs;
  final SafetyRepository _safety;
  final Set<String> _ids = <String>{};
  Set<String> get ids => Set.unmodifiable(_ids);

  void block(String id) {
    if (id.isEmpty || !_ids.add(id)) return;
    onBlock?.call(id);
    notifyListeners();
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(prefs.setStringList(_prefsKey, _ids.toList(growable: false)));
    }
    unawaited(_safety.blockUser(id).catchError((_) {}));
  }

  Future<void> hydrateRemote() async {
    final remote = await _safety.loadBlocks();
    if (remote.isEmpty) return;
    final before = _ids.length;
    _ids.addAll(remote);
    if (_ids.length == before) return;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
    }
    for (final id in remote) {
      onBlock?.call(id);
    }
    notifyListeners();
  }
}

Map<String, Object?> _marriageToJson(MarriageProfile value) => {
  'age': value.age,
  'gender': value.gender,
  'seeking': value.seeking,
  'bio': value.bio,
  'cityId': value.cityId,
  'photoCount': value.photoCount,
  'salaryBand': value.salaryBand,
  'religion': value.religion,
  'nativeLanguage': value.nativeLanguage,
  'maritalStatus': value.maritalStatus,
  'heightCm': value.heightCm,
  'education': value.education,
  'occupation': value.occupation,
  'diet': value.diet,
  'community': value.community,
};

MarriageProfile _marriageFromJson(Map<String, dynamic> map) => MarriageProfile(
  age: map['age'] as int? ?? 25,
  gender: map['gender'] as String? ?? 'woman',
  seeking: map['seeking'] as String? ?? 'man',
  bio: map['bio'] as String? ?? '',
  cityId: map['cityId'] as String? ?? 'mumbai',
  photoCount: map['photoCount'] as int? ?? 1,
  salaryBand: map['salaryBand'] as String?,
  religion: map['religion'] as String?,
  nativeLanguage: map['nativeLanguage'] as String?,
  maritalStatus: map['maritalStatus'] as String?,
  heightCm: map['heightCm'] as int?,
  education: map['education'] as String?,
  occupation: map['occupation'] as String?,
  diet: map['diet'] as String?,
  community: map['community'] as String?,
);
