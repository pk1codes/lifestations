import 'dart:async';

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

  void saveLocal(T value) {
    _value = value;
    syncError = null;
    notifyListeners();
  }

  Future<void> synchronize(Future<void> Function(T value) write) async {
    final current = _value;
    if (current == null || syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await write(current);
    } catch (_) {
      syncError = 'Saved locally. Remote sync will retry.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}

class ProfileStore extends LocalFirstStore<MarriageProfile> {}

class JobsProfileStore extends LocalFirstStore<JobsProfile> {}

abstract class MultiOfferStore<T> extends ChangeNotifier {
  MultiOfferStore(this.domain);
  final AppDomainId domain;
  final List<T> _offers = <T>[];

  List<T> get offers => List.unmodifiable(_offers);
  int get limit => AppDomains.byId(domain).maxProfiles;

  void upsert(T offer, {int? index}) {
    if (index != null) {
      _offers[index] = offer;
    } else {
      if (_offers.length >= limit) throw StateError('Offer limit reached');
      _offers.add(offer);
    }
    notifyListeners();
  }

  void removeAt(int index) {
    _offers.removeAt(index);
    notifyListeners();
  }
}

class RoomsOfferStore extends MultiOfferStore<RoomsOffer> {
  RoomsOfferStore() : super(AppDomainId.rooms);
}

class BikesOfferStore extends MultiOfferStore<BikesOffer> {
  BikesOfferStore() : super(AppDomainId.bikes);
}

class HomeHelpOfferStore extends MultiOfferStore<HomeHelpOffer> {
  HomeHelpOfferStore() : super(AppDomainId.homeHelp);
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
