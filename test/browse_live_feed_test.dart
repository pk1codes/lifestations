import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/domain_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LiveFakeRepo implements DomainRepository {
  final controller = StreamController<List<DiscoveryCardModel>>.broadcast();
  var discoverCalls = 0;

  @override
  Future<List<DiscoveryCardModel>> discover(
    AppDomainId domain, {
    int limit = 20,
  }) async {
    discoverCalls++;
    return const [];
  }

  @override
  Future<DiscoverPage> discoverPage(
    AppDomainId domain, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async => const DiscoverPage(cards: []);

  @override
  Stream<List<DiscoveryCardModel>> watchDiscover(
    AppDomainId domain, {
    int limit = 20,
  }) => controller.stream;

  @override
  Future<void> saveProfile(DiscoveryCardModel profile) async {}

  @override
  Future<void> saveOffer(DiscoveryCardModel offer) async {}

  @override
  Future<void> setListingActive({
    required AppDomainId domain,
    required String listingId,
    required bool active,
  }) async {}

  @override
  Future<void> deleteListing({
    required AppDomainId domain,
    required String listingId,
  }) async {}

  @override
  Future<DiscoveryCardModel?> fetchOwnedProfile({
    required AppDomainId domain,
    required String ownerId,
  }) async => null;

  @override
  Future<DiscoveryCardModel?> fetchLegacyJobsProfile({
    required String ownerId,
  }) async => null;

  @override
  Future<DiscoveryCardModel?> fetchOwnedOffer({
    required AppDomainId domain,
    required String offerId,
  }) async => null;

  @override
  Future<List<DiscoveryCardModel>> listOwnedOffers({
    required AppDomainId domain,
    required String ownerId,
  }) async => const [];
}

DiscoveryCardModel _card(String id) => DiscoveryCardModel(
  id: id,
  domain: AppDomainId.jobs,
  ownerId: 'owner_$id',
  title: 'Driver needed',
  subtitle: 'I need',
  cityId: 'mumbai',
  cityLabel: 'Mumbai',
  categoryTags: const ['driver'],
  imageUrls: const [],
);

void main() {
  test('startLiveFeed applies snapshot cards without force-quit', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DiscoveryStore(AppDomainId.jobs);
    final repo = _LiveFakeRepo();
    addTearDown(() {
      store.stopLiveFeed();
      unawaited(repo.controller.close());
    });

    store.startLiveFeed(repo);
    repo.controller.add([_card('live_1')]);
    await Future<void>.delayed(Duration.zero);

    expect(store.cards.map((c) => c.id), contains('live_1'));
  });

  test('retryRemoteSync invokes onRetry (Refresh / resume path)', () async {
    var retries = 0;
    final store = DiscoveryStore(AppDomainId.marriage);
    store.onRetry = () async {
      retries++;
    };

    await store.retryRemoteSync();
    expect(retries, 1);
  });
}
