import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/services/domain_repository.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements DomainRepository {
  final savedProfiles = <DiscoveryCardModel>[];
  final savedOffers = <DiscoveryCardModel>[];

  @override
  Future<List<DiscoveryCardModel>> discover(
    AppDomainId domain, {
    int limit = 20,
  }) async => const [];

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
  }) => Stream<List<DiscoveryCardModel>>.value(const []);

  @override
  Future<void> saveProfile(DiscoveryCardModel profile) async {
    savedProfiles.add(profile);
  }

  @override
  Future<void> saveOffer(DiscoveryCardModel offer) async {
    savedOffers.add(offer);
  }

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

void main() {
  test('Jobs publish path is offers storage with distinct offer id', () async {
    final repo = _FakeRepo();
    final card = ListingPublisher(repository: repo).buildJobsCard(
      ownerId: 'u1',
      offerId: 'jobs_route_1',
      profile: const JobsProfile(
        role: 'seek',
        tradeId: 'Driver',
        cityId: 'mumbai',
        salaryBand: 'Prefer not to say',
        photoCount: 1,
      ),
      photoUrls: const ['https://cdn.example/j.webp'],
    );
    expect(AppDomains.byId(card.domain).storageKind, DomainStorageKind.offers);
    await repo.saveOffer(card);
    expect(repo.savedOffers, hasLength(1));
    expect(repo.savedProfiles, isEmpty);
    expect(repo.savedOffers.single.id, 'jobs_route_1');
  });

  test('marriage storageKind stays profiles; Jobs/Rooms are offers', () {
    expect(AppDomains.marriage.storageKind, DomainStorageKind.profiles);
    expect(AppDomains.jobs.storageKind, DomainStorageKind.offers);
    expect(AppDomains.rooms.storageKind, DomainStorageKind.offers);
  });
}
