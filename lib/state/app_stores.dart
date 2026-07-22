import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import '../services/discovery_feed_cache.dart';
import '../services/domain_repository.dart';
import '../services/firebase_bootstrap.dart';
import '../services/identity_repository.dart';
import '../services/likes_repository.dart';
import '../services/listing_image_cache.dart';

class DomainController extends ChangeNotifier {
  DomainController(this._prefs)
    : _selected = AppDomainId.values[_prefs.getInt(_domainKey) ?? 0],
      _tabs = {
        for (final domain in AppDomainId.values)
          domain: (_prefs.getInt('tab_${domain.name}') ?? 0).clamp(
            0,
            maxTabIndex,
          ),
      };

  static const _domainKey = 'selected_domain';

  /// Browse = 0, Likes = 1, Me = 2.
  static const maxTabIndex = 2;
  final SharedPreferences _prefs;
  AppDomainId _selected;
  final Map<AppDomainId, int> _tabs;

  AppDomainId get selected => _selected;
  DomainPolicy get policy => AppDomains.byId(_selected);
  int get selectedTab => (_tabs[_selected] ?? 0).clamp(0, maxTabIndex);
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
    final next = value.clamp(0, maxTabIndex);
    if (_tabs[_selected] == next) return;
    _tabs[_selected] = next;
    _prefs.setInt('tab_${_selected.name}', next);
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
      photoUrls:
          _prefs.getStringList('identity_photo_urls') ?? const <String>[],
      phoneVerified: _prefs.getBool('identity_phone_verified') ?? false,
      dialCodePreference: _prefs.getString('identity_dial_code') ?? '91',
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

  Future<void> hydrateRemote() async {
    if (!FirebaseBootstrap.ready || identity.userId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .doc('users/${identity.userId}')
          .get();
      if (!doc.exists) return;
      final remotePhotos = List<String>.from(
        doc.data()?['photoUrls'] as List? ?? const <dynamic>[],
      );
      if (listEquals(remotePhotos, identity.photoUrls)) return;
      identity = identity.copyWith(photoUrls: remotePhotos);
      await _prefs.setStringList('identity_photo_urls', identity.photoUrls);
      notifyListeners();
    } catch (_) {
      // Local identity stays authoritative when remote is unavailable.
    }
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
      _prefs.setStringList('identity_photo_urls', identity.photoUrls),
      _prefs.setBool('identity_phone_verified', identity.phoneVerified),
      _prefs.setString('identity_dial_code', identity.dialCodePreference),
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
  DiscoveryStore(this.domain, {this._feedCache});

  final AppDomainId domain;
  final DiscoveryFeedCache? _feedCache;
  final List<DiscoveryCardModel> _cards = <DiscoveryCardModel>[];
  final Set<String> _actioned = <String>{};
  final Set<String> _blocked = <String>{};
  SyncStatus status = SyncStatus.idle;
  String? error;
  StreamSubscription<List<DiscoveryCardModel>>? _liveSub;
  static DiscoveryStore? _activeLive;

  /// Assigned by app bootstrap so Browse can retry a failed remote sync.
  Future<void> Function()? onRetry;

  List<DiscoveryCardModel> get cards => List.unmodifiable(
    _cards.where(
      (card) =>
          !_actioned.contains(card.id) && !_blocked.contains(card.ownerId),
    ),
  );

  /// Browse list excluding the signed-in user's own listings.
  List<DiscoveryCardModel> cardsForViewer(String? viewerUid) {
    final uid = viewerUid?.trim() ?? '';
    return cards
        .where((card) => uid.isEmpty || card.ownerId != uid)
        .toList(growable: false);
  }

  List<DiscoveryCardModel> filtered({
    Iterable<DiscoveryCardModel>? source,
    String? cityId,
    String? gender,
    String? ageBand,
    String? role,
    String? tradeId,
  }) => (source ?? cards)
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

  /// Apply remote cards: keep local objects when unchanged; persist + warm images.
  void applyRemote(Iterable<DiscoveryCardModel> values, {bool persist = true}) {
    final remote = values
        .where((card) => card.domain == domain)
        .where((card) => !DiscoveryFeedCache.isDemo(card))
        .toList(growable: false);
    if (remote.isEmpty) {
      markReady();
      return;
    }
    final merged = DiscoveryFeedCache.mergeKeepingUnchanged(_cards, remote);
    load(merged);
    if (persist) {
      unawaited(_feedCache?.write(domain, merged) ?? Future<void>.value());
    }
    ListingImageCache.warmCards(merged);
  }

  /// Show a loading state when the feed is still empty.
  void beginRemoteSync() {
    error = null;
    if (_cards.isEmpty && status != SyncStatus.loading) {
      status = SyncStatus.loading;
      notifyListeners();
    }
  }

  void failRemoteSync([String message = 'Could not load. Try again.']) {
    error = message;
    status = SyncStatus.error;
    notifyListeners();
  }

  void markReady() {
    if (status == SyncStatus.ready && error == null) return;
    status = SyncStatus.ready;
    error = null;
    notifyListeners();
  }

  Future<void> retryRemoteSync() async {
    final fn = onRetry;
    if (fn == null) return;
    beginRemoteSync();
    await fn();
  }

  /// Live updates for the open Browse domain (one domain at a time).
  void startLiveFeed(DomainRepository repository) {
    if (!identical(_activeLive, this)) {
      _activeLive?.stopLiveFeed();
    }
    _activeLive = this;
    stopLiveFeed();
    if (!FirebaseBootstrap.ready) return;
    _liveSub = repository
        .watchDiscover(domain)
        .listen(
          (remote) {
            final live = remote
                .where((card) => !DiscoveryFeedCache.isDemo(card))
                .toList(growable: false);
            if (live.isNotEmpty) {
              applyRemote(live);
            } else if (status == SyncStatus.loading) {
              markReady();
            }
          },
          onError: (_) {
            // Keep last good cards; user can pull to refresh.
            if (status == SyncStatus.loading && _cards.isEmpty) {
              failRemoteSync();
            } else if (status == SyncStatus.loading) {
              markReady();
            }
          },
        );
  }

  void stopLiveFeed() {
    unawaited(_liveSub?.cancel() ?? Future<void>.value());
    _liveSub = null;
  }

  @override
  void dispose() {
    stopLiveFeed();
    super.dispose();
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
  LikesStore({LikesRepository? repository, SharedPreferences? preferences})
    : _repository = repository ?? LikesRepository(),
      _prefs = preferences {
    _loadDismissedInbound();
  }

  static const _dismissedInboundKey = 'likes_dismissed_inbound';

  final LikesRepository _repository;
  final SharedPreferences? _prefs;
  final Map<AppDomainId, Set<String>> _outbound = <AppDomainId, Set<String>>{};
  final Map<AppDomainId, Set<String>> _inbound = <AppDomainId, Set<String>>{};
  final Map<AppDomainId, List<LikeEntry>> _outboundEntries =
      <AppDomainId, List<LikeEntry>>{};
  final Map<AppDomainId, List<LikeEntry>> _inboundEntries =
      <AppDomainId, List<LikeEntry>>{};
  final Map<AppDomainId, Set<String>> _chatReady = <AppDomainId, Set<String>>{};
  final Set<String> _dismissedInbound = <String>{};
  final List<StreamSubscription<List<LikeEntry>>> _inboundSubs =
      <StreamSubscription<List<LikeEntry>>>[];

  static String _dismissKey(AppDomainId domain, String otherUid) =>
      '${domain.name}|$otherUid';

  void _loadDismissedInbound() {
    final stored = _prefs?.getStringList(_dismissedInboundKey);
    if (stored == null) return;
    _dismissedInbound
      ..clear()
      ..addAll(stored);
  }

  Future<void> _persistDismissedInbound() async {
    try {
      await _prefs?.setStringList(
        _dismissedInboundKey,
        _dismissedInbound.toList(growable: false),
      );
    } catch (_) {}
  }

  bool isInboundDismissed(AppDomainId domain, String otherUid) =>
      _dismissedInbound.contains(_dismissKey(domain, otherUid));

  List<LikeEntry> _visibleInbound(AppDomainId domain) {
    final all = _inboundEntries[domain] ?? const <LikeEntry>[];
    return all
        .where((e) => !isInboundDismissed(domain, e.otherUid))
        .toList(growable: false);
  }

  Set<String> outbound(AppDomainId domain) =>
      Set.unmodifiable(_outbound[domain] ?? <String>{});
  Set<String> inbound(AppDomainId domain) => Set.unmodifiable({
    for (final id in _inbound[domain] ?? const <String>{})
      if (!isInboundDismissed(domain, id)) id,
  });

  List<LikeEntry> outboundEntries(AppDomainId domain) =>
      List.unmodifiable(_outboundEntries[domain] ?? const <LikeEntry>[]);
  List<LikeEntry> inboundEntries(AppDomainId domain) =>
      List.unmodifiable(_visibleInbound(domain));

  int get outboundCount =>
      _outbound.values.fold<int>(0, (total, ids) => total + ids.length);
  int get inboundCount => AppDomainId.values.fold<int>(
    0,
    (total, domain) => total + _visibleInbound(domain).length,
  );

  /// WhatsApp / Telegram icons unlock for mutual pairs (or peer already opened chat).
  bool chatIconsActive(AppDomainId domain, String otherId) =>
      isMutual(domain, otherId) ||
      (_chatReady[domain]?.contains(otherId) ?? false);

  void markChatReady(AppDomainId domain, String otherId) {
    if (otherId.isEmpty) return;
    if (!(_chatReady[domain] ??= <String>{}).add(otherId)) return;
    notifyListeners();
  }

  /// Persists the like online first, then updates local state.
  /// Returns whether the pair is mutual after a successful write.
  /// Throws if the remote write fails (caller should show an error).
  Future<bool> like(
    AppDomainId domain,
    String targetId, {
    DiscoveryCardModel? snapshot,
  }) async {
    if (_outbound[domain]?.contains(targetId) ?? false) {
      return isMutual(domain, targetId);
    }
    await _repository.like(
      domain: domain,
      targetUid: targetId,
      snapshot: snapshot,
    );
    (_outbound[domain] ??= <String>{}).add(targetId);
    final entries = _outboundEntries[domain] ??= <LikeEntry>[];
    entries.removeWhere((entry) => entry.otherUid == targetId);
    entries.insert(
      0,
      LikeEntry(
        domain: domain,
        otherUid: targetId,
        direction: LikeDirection.outbound,
        card: snapshot,
        createdAt: DateTime.now(),
      ),
    );
    if (isMutual(domain, targetId)) {
      markChatReady(domain, targetId);
    }
    notifyListeners();
    return isMutual(domain, targetId);
  }

  /// Remove an "I liked" row — deletes both like docs when online.
  Future<void> unlike(AppDomainId domain, String targetId) async {
    if (targetId.isEmpty) return;
    try {
      await _repository.unlike(domain: domain, targetUid: targetId);
    } catch (error) {
      debugPrint('Unlike remote failed: $error');
    }
    _removeOutboundLocal(domain, targetId);
  }

  void _removeOutboundLocal(AppDomainId domain, String targetId) {
    _outbound[domain]?.remove(targetId);
    _outboundEntries[domain]?.removeWhere((e) => e.otherUid == targetId);
    _chatReady[domain]?.remove(targetId);
    notifyListeners();
  }

  /// Hide a "Liked me" row for this user (does not delete their like).
  Future<void> dismissInbound(AppDomainId domain, String fromUid) async {
    if (fromUid.isEmpty) return;
    final key = _dismissKey(domain, fromUid);
    if (!_dismissedInbound.add(key)) return;
    await _persistDismissedInbound();
    _chatReady[domain]?.remove(fromUid);
    notifyListeners();
  }

  /// Restore a dismissed inbound row (Undo).
  Future<void> restoreInbound(AppDomainId domain, String fromUid) async {
    if (!_dismissedInbound.remove(_dismissKey(domain, fromUid))) return;
    await _persistDismissedInbound();
    notifyListeners();
  }

  /// Restore an outbound like locally after Undo (re-writes when possible).
  Future<void> restoreOutbound(
    AppDomainId domain,
    String targetId, {
    DiscoveryCardModel? snapshot,
  }) async {
    if (targetId.isEmpty) return;
    if (_outbound[domain]?.contains(targetId) ?? false) return;
    try {
      await like(domain, targetId, snapshot: snapshot);
    } catch (_) {
      (_outbound[domain] ??= <String>{}).add(targetId);
      final entries = _outboundEntries[domain] ??= <LikeEntry>[];
      entries.removeWhere((entry) => entry.otherUid == targetId);
      entries.insert(
        0,
        LikeEntry(
          domain: domain,
          otherUid: targetId,
          direction: LikeDirection.outbound,
          card: snapshot,
          createdAt: DateTime.now(),
        ),
      );
      notifyListeners();
    }
  }

  /// After WhatsApp/Telegram open — unlock chat icons on the other device too.
  Future<void> signalChatOpened(AppDomainId domain, String otherUid) async {
    markChatReady(domain, otherUid);
    await _repository.signalChatOpened(domain: domain, otherUid: otherUid);
  }

  void receiveLike(
    AppDomainId domain,
    String fromUid, {
    DiscoveryCardModel? card,
    bool peerOpenedChat = false,
  }) {
    (_inbound[domain] ??= <String>{}).add(fromUid);
    final entries = _inboundEntries[domain] ??= <LikeEntry>[];
    entries.removeWhere((entry) => entry.otherUid == fromUid);
    entries.insert(
      0,
      LikeEntry(
        domain: domain,
        otherUid: fromUid,
        direction: LikeDirection.inbound,
        card: card,
        createdAt: DateTime.now(),
        peerOpenedChat: peerOpenedChat,
      ),
    );
    if (peerOpenedChat || isMutual(domain, fromUid)) {
      markChatReady(domain, fromUid);
    }
    notifyListeners();
  }

  /// Apply an inbound-like FCM payload (public card fields only).
  void applyInboundPush({
    required String domainSlug,
    required String fromUid,
    String? title,
    String? subtitle,
    String? cityLabel,
    String? photoUrl,
    String? listingId,
    bool chatReady = false,
  }) {
    if (fromUid.isEmpty) return;
    final domain = _domainFromSlug(domainSlug);
    if (domain == null) return;
    final photos = <String>[
      if (photoUrl != null && photoUrl.isNotEmpty) photoUrl,
    ];
    final card = DiscoveryCardModel(
      id: (listingId != null && listingId.isNotEmpty) ? listingId : fromUid,
      domain: domain,
      ownerId: fromUid,
      title: (title != null && title.isNotEmpty) ? title : 'Liked',
      subtitle: subtitle ?? '',
      cityId: '',
      cityLabel: cityLabel ?? '',
      categoryTags: const <String>[],
      imageUrls: photos,
    );
    receiveLike(domain, fromUid, card: card, peerOpenedChat: chatReady);
  }

  static AppDomainId? _domainFromSlug(String slug) {
    for (final policy in AppDomains.all) {
      if (policy.slug == slug) return policy.id;
    }
    return null;
  }

  bool isMutual(AppDomainId domain, String otherId) =>
      (_outbound[domain]?.contains(otherId) ?? false) &&
      (_inbound[domain]?.contains(otherId) ?? false) &&
      !isInboundDismissed(domain, otherId);

  bool canUnlock({
    required AppDomainId domain,
    required String otherId,
    required bool anonymous,
    required bool phoneVerified,
  }) => !anonymous && phoneVerified && isMutual(domain, otherId);

  Future<void> hydrate(AppDomainId domain) async {
    await _loadDomain(domain);
    notifyListeners();
  }

  Future<void> hydrateAll() async {
    await Future.wait(AppDomainId.values.map(_loadDomain));
    notifyListeners();
  }

  /// Live inbound for all domains — like-back / peer chat-open unlock icons.
  void startRealtimeSync() {
    stopRealtimeSync();
    for (final domain in AppDomainId.values) {
      _inboundSubs.add(
        _repository.watchInbound(domain).listen((entries) {
          _inboundEntries[domain] = List<LikeEntry>.from(entries);
          _inbound[domain] = {for (final entry in entries) entry.otherUid};
          for (final entry in entries) {
            if (isInboundDismissed(domain, entry.otherUid)) continue;
            if (entry.peerOpenedChat || isMutual(domain, entry.otherUid)) {
              (_chatReady[domain] ??= <String>{}).add(entry.otherUid);
            }
          }
          notifyListeners();
        }),
      );
    }
  }

  void stopRealtimeSync() {
    for (final sub in _inboundSubs) {
      unawaited(sub.cancel());
    }
    _inboundSubs.clear();
  }

  @override
  void dispose() {
    stopRealtimeSync();
    super.dispose();
  }

  Future<void> _loadDomain(AppDomainId domain) async {
    try {
      final outbound = await _repository.loadOutbound(domain);
      final inbound = await _repository.loadInbound(domain);
      _outboundEntries[domain] = List<LikeEntry>.from(outbound);
      _inboundEntries[domain] = List<LikeEntry>.from(inbound);
      _outbound[domain] = {for (final entry in outbound) entry.otherUid};
      _inbound[domain] = {for (final entry in inbound) entry.otherUid};
      for (final entry in inbound) {
        if (isInboundDismissed(domain, entry.otherUid)) continue;
        if (entry.peerOpenedChat || isMutual(domain, entry.otherUid)) {
          (_chatReady[domain] ??= <String>{}).add(entry.otherUid);
        }
      }
      for (final other in _outbound[domain] ?? const <String>{}) {
        if (isMutual(domain, other)) {
          (_chatReady[domain] ??= <String>{}).add(other);
        }
      }
    } catch (error) {
      // Keep any in-memory likes if a domain load fails.
      debugPrint('Likes hydrate failed for $domain: $error');
    }
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
