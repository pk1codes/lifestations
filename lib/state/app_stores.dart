import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import '../services/identity_repository.dart';
import '../services/likes_repository.dart';

class DomainController extends ChangeNotifier {
  DomainController(this._prefs)
    : _selected = AppDomainId.values[_prefs.getInt(_domainKey) ?? 0],
      _tabs = {
        for (final domain in AppDomainId.values)
          domain: _prefs.getInt('tab_${domain.name}') ?? 0,
      };

  static const _domainKey = 'selected_domain';
  final SharedPreferences _prefs;
  AppDomainId _selected;
  final Map<AppDomainId, int> _tabs;

  AppDomainId get selected => _selected;
  DomainPolicy get policy => AppDomains.byId(_selected);
  int get selectedTab => _tabs[_selected] ?? 0;
  bool get shouldShowCoachMark =>
      !(_prefs.getBool('domain_coach_seen') ?? false);

  Future<void> markCoachSeen() => _prefs.setBool('domain_coach_seen', true);

  void selectDomain(AppDomainId value) {
    if (_selected == value) return;
    _selected = value;
    _prefs.setInt(_domainKey, value.index);
    notifyListeners();
  }

  void selectTab(int value) {
    if (_tabs[_selected] == value) return;
    _tabs[_selected] = value;
    _prefs.setInt('tab_${_selected.name}', value);
    notifyListeners();
  }
}

class IdentityStore extends ChangeNotifier {
  IdentityStore(this._prefs, {IdentityRepository? repository})
    : _repository = repository ?? IdentityRepository(preferences: _prefs) {
    identity = Identity(
      userId: _prefs.getString('identity_user_id') ?? '',
      displayName: _prefs.getString('identity_name') ?? '',
      whatsappNumber: _prefs.getString('identity_phone') ?? '',
      cityId: _prefs.getString('identity_city_id') ?? '',
      cityLabel: _prefs.getString('identity_city_label') ?? '',
      nativeLanguage: _prefs.getString('identity_language') ?? '',
      phoneVerified: _prefs.getBool('identity_phone_verified') ?? false,
    );
  }

  final SharedPreferences _prefs;
  final IdentityRepository _repository;
  late Identity identity;

  bool get completed => identity.isValid;

  Future<void> bindUserId(String uid) async {
    if (uid.isEmpty || identity.userId == uid) return;
    identity = identity.copyWith(userId: uid);
    await _prefs.setString('identity_user_id', uid);
    notifyListeners();
  }

  Future<void> save(Identity value) async {
    identity = value.copyWith(
      userId: value.userId.isEmpty ? identity.userId : value.userId,
      displayName: value.displayName.trim(),
      whatsappNumber: value.whatsappNumber.replaceAll(RegExp(r'\D'), ''),
    );
    await Future.wait(<Future<bool>>[
      _prefs.setString('identity_name', identity.displayName),
      _prefs.setString('identity_phone', identity.whatsappNumber),
      _prefs.setString('identity_city_id', identity.cityId),
      _prefs.setString('identity_city_label', identity.cityLabel),
      _prefs.setString('identity_language', identity.nativeLanguage),
      _prefs.setBool('identity_phone_verified', identity.phoneVerified),
    ]);
    try {
      await _repository.save(identity);
    } catch (_) {
      // Local persistence is authoritative while remote sync is unavailable.
    }
    notifyListeners();
  }

  Future<void> clear() async {
    for (final key in _prefs.getKeys().where(
      (key) => key.startsWith('identity_'),
    )) {
      await _prefs.remove(key);
    }
    identity = const Identity();
    notifyListeners();
  }
}

enum SyncStatus { idle, loading, ready, error }

class DiscoveryStore extends ChangeNotifier {
  DiscoveryStore(this.domain);

  final AppDomainId domain;
  final List<DiscoveryCardModel> _cards = <DiscoveryCardModel>[];
  final Set<String> _actioned = <String>{};
  final Set<String> _blocked = <String>{};
  SyncStatus status = SyncStatus.idle;
  String? error;

  List<DiscoveryCardModel> get cards => List.unmodifiable(
    _cards.where(
      (card) =>
          !_actioned.contains(card.id) && !_blocked.contains(card.ownerId),
    ),
  );

  List<DiscoveryCardModel> filtered({
    String? cityId,
    String? gender,
    String? ageBand,
    String? role,
    String? tradeId,
  }) => cards
      .where((card) {
        if (cityId != null && cityId.isNotEmpty && card.cityId != cityId) {
          return false;
        }
        if (ageBand != null && ageBand.isNotEmpty && card.ageBand != ageBand) {
          return false;
        }
        if (role != null && role.isNotEmpty && card.role != role) return false;
        if (gender != null &&
            gender.isNotEmpty &&
            card.attributes['gender'] != gender) {
          return false;
        }
        if (tradeId != null &&
            tradeId.isNotEmpty &&
            !card.categoryTags.any(
              (tag) => tag.toLowerCase() == tradeId.toLowerCase(),
            )) {
          return false;
        }
        return true;
      })
      .toList(growable: false);

  void load(Iterable<DiscoveryCardModel> values) {
    _cards
      ..clear()
      ..addAll(values.where((card) => card.domain == domain));
    status = SyncStatus.ready;
    error = null;
    notifyListeners();
  }

  void action(String id) {
    if (_actioned.add(id)) notifyListeners();
  }

  void block(String ownerId) {
    if (_blocked.add(ownerId)) notifyListeners();
  }

  void reset() {
    _actioned.clear();
    notifyListeners();
  }
}

class LikesStore extends ChangeNotifier {
  LikesStore({LikesRepository? repository})
    : _repository = repository ?? LikesRepository();

  final LikesRepository _repository;
  final Map<AppDomainId, Set<String>> _outbound = <AppDomainId, Set<String>>{};
  final Map<AppDomainId, Set<String>> _inbound = <AppDomainId, Set<String>>{};

  Set<String> outbound(AppDomainId domain) =>
      Set.unmodifiable(_outbound[domain] ?? <String>{});
  Set<String> inbound(AppDomainId domain) =>
      Set.unmodifiable(_inbound[domain] ?? <String>{});

  bool like(
    AppDomainId domain,
    String targetId, {
    DiscoveryCardModel? snapshot,
  }) {
    final added = (_outbound[domain] ??= <String>{}).add(targetId);
    if (added) {
      notifyListeners();
      unawaited(
        _repository
            .like(domain: domain, targetUid: targetId, snapshot: snapshot)
            .catchError((_) {}),
      );
    }
    return isMutual(domain, targetId);
  }

  void receiveLike(AppDomainId domain, String ownerId) {
    if ((_inbound[domain] ??= <String>{}).add(ownerId)) notifyListeners();
  }

  bool isMutual(AppDomainId domain, String otherId) =>
      (_outbound[domain]?.contains(otherId) ?? false) &&
      (_inbound[domain]?.contains(otherId) ?? false);

  bool canUnlock({
    required AppDomainId domain,
    required String otherId,
    required bool anonymous,
    required bool phoneVerified,
  }) => !anonymous && phoneVerified && isMutual(domain, otherId);

  Future<void> hydrate(AppDomainId domain) async {
    final outbound = await _repository.loadOutbound(domain);
    final inbound = await _repository.loadInbound(domain);
    _outbound[domain] = {...outbound};
    _inbound[domain] = {...inbound};
    notifyListeners();
  }
}

class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs) : localeCode = _prefs.getString('locale_code');

  final SharedPreferences _prefs;
  String? localeCode;

  void setLocale(String? code) {
    if (localeCode == code) return;
    localeCode = code;
    code == null
        ? _prefs.remove('locale_code')
        : _prefs.setString('locale_code', code);
    notifyListeners();
  }
}
