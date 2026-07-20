import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import '../models/domain_profiles.dart';
import '../models/owned_post.dart';
import '../state/domain_profile_stores.dart';
import 'domain_repository.dart';
import 'firebase_bootstrap.dart';
import 'owned_listing_cache.dart';

/// Fills [OwnedListingCache] and local stores from Firestore when the device
/// cache is empty (e.g. after reinstall or a Save that never cached photos).
Future<void> hydrateOwnedListings({
  required String ownerId,
  required OwnedListingCache media,
  required ProfileStore marriage,
  required JobsProfileStore jobs,
  required RoomsOfferStore rooms,
  required BikesOfferStore bikes,
  required HomeHelpOfferStore homeHelp,
  DomainRepository? repository,
}) async {
  if (!FirebaseBootstrap.ready || ownerId.isEmpty || ownerId == 'local') {
    return;
  }
  final repo = repository ?? FirestoreDomainRepository();

  final marriageCard = await repo.fetchOwnedProfile(
    domain: AppDomainId.marriage,
    ownerId: ownerId,
  );
  if (marriageCard != null) {
    if (media.photos(AppDomainId.marriage).isEmpty &&
        marriageCard.imageUrls.isNotEmpty) {
      await media.setPhotos(AppDomainId.marriage, marriageCard.imageUrls);
    }
    if (marriage.value == null) {
      final profile = marriageFromCard(marriageCard);
      if (profile != null) marriage.saveLocal(profile);
    }
  }

  final jobsCard = await repo.fetchOwnedProfile(
    domain: AppDomainId.jobs,
    ownerId: ownerId,
  );
  if (jobsCard != null) {
    if (media.photos(AppDomainId.jobs).isEmpty &&
        jobsCard.imageUrls.isNotEmpty) {
      await media.setPhotos(AppDomainId.jobs, jobsCard.imageUrls);
    }
    if (jobs.value == null) {
      final profile = jobsFromCard(jobsCard);
      if (profile != null) jobs.saveLocal(profile);
    }
  }

  await _hydrateOffers(
    domain: AppDomainId.rooms,
    ownerId: ownerId,
    media: media,
    store: rooms,
    repo: repo,
    fromCard: roomsFromCard,
  );
  await _hydrateOffers(
    domain: AppDomainId.bikes,
    ownerId: ownerId,
    media: media,
    store: bikes,
    repo: repo,
    fromCard: bikesFromCard,
  );
  await _hydrateOffers(
    domain: AppDomainId.homeHelp,
    ownerId: ownerId,
    media: media,
    store: homeHelp,
    repo: repo,
    fromCard: homeHelpFromCard,
  );
}

Future<void> _hydrateOffers<T>({
  required AppDomainId domain,
  required String ownerId,
  required OwnedListingCache media,
  required MultiOfferStore<T> store,
  required DomainRepository repo,
  required T? Function(DiscoveryCardModel card) fromCard,
}) async {
  if (store.offers.isNotEmpty) {
    // Still backfill missing photo caches for existing local offers.
    for (var i = 0; i < store.offers.length; i++) {
      if (media.photos(domain, i).isNotEmpty) continue;
      final id = media.offerId(domain, i);
      final card = await repo.fetchOwnedOffer(domain: domain, offerId: id);
      if (card != null && card.imageUrls.isNotEmpty) {
        await media.setPhotos(domain, card.imageUrls, index: i);
      }
    }
    return;
  }
  final cards = await repo.listOwnedOffers(domain: domain, ownerId: ownerId);
  for (var i = 0; i < cards.length; i++) {
    final card = cards[i];
    final offer = fromCard(card);
    if (offer == null) continue;
    store.upsert(offer);
    await media.setOfferId(domain, i, card.id);
    if (card.imageUrls.isNotEmpty) {
      await media.setPhotos(domain, card.imageUrls, index: i);
    }
  }
}

/// Prefer cache, then the card already in memory, then remote profile/offer.
Future<List<String>> resolveOwnedPhotoUrls({
  required OwnedPost post,
  required OwnedListingCache media,
  required String ownerId,
  DomainRepository? repository,
}) async {
  final cached = media.photos(post.domain, post.offerIndex);
  if (cached.isNotEmpty) return cached;
  if (post.card.imageUrls.isNotEmpty) {
    await media.setPhotos(
      post.domain,
      post.card.imageUrls,
      index: post.offerIndex,
    );
    return post.card.imageUrls;
  }
  if (!FirebaseBootstrap.ready || ownerId.isEmpty) return const <String>[];
  final repo = repository ?? FirestoreDomainRepository();
  final remote = post.offerIndex != null
      ? await repo.fetchOwnedOffer(domain: post.domain, offerId: post.card.id)
      : await repo.fetchOwnedProfile(domain: post.domain, ownerId: ownerId);
  final urls = remote?.imageUrls ?? const <String>[];
  if (urls.isNotEmpty) {
    await media.setPhotos(post.domain, urls, index: post.offerIndex);
  }
  return urls;
}

MarriageProfile? marriageFromCard(DiscoveryCardModel card) {
  if (card.domain != AppDomainId.marriage) return null;
  final attrs = card.attributes;
  final gender = attrs['gender'] as String? ?? 'woman';
  final seeking =
      attrs['seeking'] as String? ?? card.role ?? 'man';
  final age = _ageFromBand(card.ageBand);
  return MarriageProfile(
    age: age,
    gender: MarriageProfile.genders.contains(gender) ? gender : 'woman',
    seeking: MarriageProfile.seekingOptions.contains(seeking)
        ? seeking
        : 'everyone',
    bio: '',
    cityId: card.cityId.isNotEmpty ? card.cityId : 'mumbai',
    photoCount: card.imageUrls.length.clamp(1, 3),
    salaryBand: attrs['salaryBand'] as String?,
    religion: attrs['religion'] as String?,
    education: attrs['education'] as String?,
    occupation: attrs['occupation'] as String?,
    diet: attrs['diet'] as String?,
    heightCm: attrs['heightCm'] is int
        ? attrs['heightCm'] as int
        : int.tryParse('${attrs['heightCm'] ?? ''}'),
  );
}

JobsProfile? jobsFromCard(DiscoveryCardModel card) {
  if (card.domain != AppDomainId.jobs) return null;
  final attrs = card.attributes;
  final role = card.role ?? attrs['role'] as String? ?? 'seek';
  final trade = attrs['tradeId'] as String? ?? JobsProfile.trades.first;
  final salary =
      attrs['salaryBand'] as String? ?? JobsProfile.salaryBands.first;
  return JobsProfile(
    role: const {'seek', 'offer'}.contains(role) ? role : 'seek',
    tradeId: JobsProfile.trades.contains(trade) ? trade : JobsProfile.trades.first,
    cityId: card.cityId.isNotEmpty ? card.cityId : 'mumbai',
    salaryBand: JobsProfile.salaryBands.contains(salary)
        ? salary
        : JobsProfile.salaryBands.first,
  );
}

RoomsOffer? roomsFromCard(DiscoveryCardModel card) {
  if (card.domain != AppDomainId.rooms) return null;
  final attrs = card.attributes;
  final type = attrs['type'] as String? ?? RoomsOffer.types.first;
  final furnishing =
      attrs['furnishing'] as String? ?? RoomsOffer.furnishingOptions.first;
  final rent = attrs['monthlyRent'] is int
      ? attrs['monthlyRent'] as int
      : int.tryParse('${attrs['monthlyRent'] ?? ''}') ??
            RoomsOffer.rentPresets.first;
  final deposit = attrs['depositMonths'] is int
      ? attrs['depositMonths'] as int
      : int.tryParse('${attrs['depositMonths'] ?? ''}') ?? 0;
  final amenities = List<String>.from(
    attrs['amenities'] as List? ?? const <String>[],
  );
  return RoomsOffer(
    type: RoomsOffer.types.contains(type) ? type : RoomsOffer.types.first,
    furnishing: RoomsOffer.furnishingOptions.contains(furnishing)
        ? furnishing
        : RoomsOffer.furnishingOptions.first,
    monthlyRent: rent,
    depositMonths: deposit.clamp(0, 3),
    cityId: card.cityId.isNotEmpty ? card.cityId : 'mumbai',
    photoCount: card.imageUrls.length.clamp(2, 8),
    amenities: amenities
        .where(RoomsOffer.amenityOptions.contains)
        .toList(growable: false),
    hasAddressProof: attrs['hasAddressProof'] == true,
  );
}

BikesOffer? bikesFromCard(DiscoveryCardModel card) {
  if (card.domain != AppDomainId.bikes) return null;
  final attrs = card.attributes;
  final type = attrs['type'] as String? ?? BikesOffer.types.first;
  final transmission =
      attrs['transmission'] as String? ?? BikesOffer.transmissions.first;
  final make = attrs['make'] as String? ?? BikesOffer.makes.first;
  final rent = attrs['hourlyRent'] is int
      ? attrs['hourlyRent'] as int
      : int.tryParse('${attrs['hourlyRent'] ?? ''}') ??
            BikesOffer.hourlyRentPresets.first;
  return BikesOffer(
    type: BikesOffer.types.contains(type) ? type : BikesOffer.types.first,
    transmission: BikesOffer.transmissions.contains(transmission)
        ? transmission
        : BikesOffer.transmissions.first,
    make: BikesOffer.makes.contains(make) ? make : BikesOffer.makes.first,
    hourlyRent: rent,
    photoCount: card.imageUrls.length.clamp(4, 4),
    cityId: card.cityId.isNotEmpty ? card.cityId : 'mumbai',
    model: attrs['model'] as String?,
    availableWeekdays: List<String>.from(
      attrs['availableWeekdays'] as List? ?? BikesOffer.weekdays,
    ),
    fromTime: attrs['fromTime'] as String? ?? '09:00',
    toTime: attrs['toTime'] as String? ?? '20:00',
    hasRc: attrs['hasRc'] == true,
    hasInsurance: attrs['hasInsurance'] == true,
  );
}

HomeHelpOffer? homeHelpFromCard(DiscoveryCardModel card) {
  if (card.domain != AppDomainId.homeHelp) return null;
  final attrs = card.attributes;
  final role = card.role ?? attrs['role'] as String? ?? 'have';
  final service = attrs['service'] as String? ?? HomeHelpOffer.services.first;
  final shift = attrs['shift'] as String? ?? HomeHelpOffer.shifts.first;
  final salary =
      attrs['salaryBand'] as String? ?? HomeHelpOffer.salaryBands.first;
  final languages = List<String>.from(
    attrs['languages'] as List? ?? const <String>['Hindi'],
  );
  return HomeHelpOffer(
    role: HomeHelpOffer.roles.contains(role) ? role : 'have',
    service: HomeHelpOffer.services.contains(service)
        ? service
        : HomeHelpOffer.services.first,
    shift: HomeHelpOffer.shifts.contains(shift)
        ? shift
        : HomeHelpOffer.shifts.first,
    salaryBand: HomeHelpOffer.salaryBands.contains(salary)
        ? salary
        : HomeHelpOffer.salaryBands.first,
    languages: languages
        .where(HomeHelpOffer.languageOptions.contains)
        .toList(growable: false),
    photoCount: card.imageUrls.length,
    cityId: card.cityId.isNotEmpty ? card.cityId : 'mumbai',
  );
}

int _ageFromBand(String? band) {
  return switch (band) {
    '18-24' => 22,
    '25-29' => 27,
    '30-34' => 32,
    '35-39' => 37,
    '40-49' => 45,
    '50+' => 55,
    _ => 28,
  };
}
