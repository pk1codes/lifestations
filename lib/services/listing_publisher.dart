import '../models/app_domain.dart';
import '../models/cities.dart';
import '../models/discovery_card.dart';
import '../models/domain_profiles.dart';
import 'action_throttle.dart';
import 'domain_repository.dart';
import 'firebase_bootstrap.dart';
import 'moderation/moderation_service.dart';
import 'share_card_repository.dart';

export '../models/cities.dart' show cityLabels;

/// Maps typed domain forms into privacy-safe discovery documents and syncs.
class ListingPublisher {
  ListingPublisher({
    DomainRepository? repository,
    ShareCardRepository? shareRepository,
  }) : _repository = repository ?? FirestoreDomainRepository(),
       _share = shareRepository ?? ShareCardRepository();
  static const ActionThrottleService _throttle = ActionThrottleService();

  final DomainRepository _repository;
  final ShareCardRepository _share;

  DiscoveryCardModel buildMarriageCard({
    required String ownerId,
    required MarriageProfile profile,
    List<String> photoUrls = const <String>[],
  }) => DiscoveryCardModel(
    id: ownerId,
    domain: AppDomainId.marriage,
    ownerId: ownerId,
    title: profile.ageBand,
    subtitle: '',
    cityId: profile.cityId,
    cityLabel: cityLabels[profile.cityId] ?? profile.cityId,
    categoryTags: [
      profile.gender,
      if (profile.religion != null) profile.religion!,
    ],
    imageUrls: photoUrls,
    role: profile.seeking,
    ageBand: profile.ageBand,
    attributes: {
      'gender': profile.gender,
      'seeking': profile.seeking,
      if (profile.salaryBand != null) 'salaryBand': profile.salaryBand,
      if (profile.education != null) 'education': profile.education,
      if (profile.occupation != null) 'occupation': profile.occupation,
      if (profile.diet != null) 'diet': profile.diet,
      if (profile.heightCm != null) 'heightCm': profile.heightCm,
      // Bio stays off public discovery documents.
    },
  );

  DiscoveryCardModel buildJobsCard({
    required String ownerId,
    required JobsProfile profile,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => DiscoveryCardModel(
    id: offerId,
    domain: AppDomainId.jobs,
    ownerId: ownerId,
    title: profile.tradeId,
    subtitle: profile.salaryBand,
    cityId: profile.cityId,
    cityLabel: cityLabels[profile.cityId] ?? profile.cityId,
    categoryTags: [profile.tradeId],
    imageUrls: photoUrls,
    role: profile.role,
    attributes: {
      'tradeId': profile.tradeId,
      'salaryBand': profile.salaryBand,
      if (profile.isDemand && profile.howMany != null)
        'howMany': profile.howMany,
    },
  );

  DiscoveryCardModel buildKuwaitJobsCard({
    required String ownerId,
    required KuwaitJobsProfile profile,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => DiscoveryCardModel(
    id: offerId,
    domain: AppDomainId.kuwaitJobs,
    ownerId: ownerId,
    title: KuwaitJobsProfile.titleLine(profile.tradeIds),
    subtitle: profile.salaryBand,
    cityId: profile.countryId,
    cityLabel:
        KuwaitJobsProfile.countryLabels[profile.countryId] ??
        profile.countryId,
    categoryTags: List<String>.of(profile.tradeIds),
    imageUrls: photoUrls,
    role: profile.role,
    attributes: {
      'tradeId': profile.tradeId,
      'tradeIds': List<String>.of(profile.tradeIds),
      'salaryBand': profile.salaryBand,
      'countryId': profile.countryId,
      'nationality': profile.nationality,
      'experienceBand': profile.experienceBand,
      if (profile.isDemand && profile.howMany != null)
        'howMany': profile.howMany,
    },
  );

  DiscoveryCardModel buildRoomsCard({
    required String ownerId,
    required RoomsOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => DiscoveryCardModel(
    id: offerId,
    domain: AppDomainId.rooms,
    ownerId: ownerId,
    title: offer.type,
    subtitle: '₹${offer.monthlyRent}/month',
    cityId: offer.cityId,
    cityLabel: cityLabels[offer.cityId] ?? offer.cityId,
    categoryTags: [offer.type, ...offer.amenities.take(3)],
    imageUrls: photoUrls,
    role: 'have',
    attributes: {
      'type': offer.type,
      'furnishing': offer.furnishing,
      'monthlyRent': offer.monthlyRent,
      'depositMonths': offer.depositMonths,
      'amenities': offer.amenities,
      'hasAddressProof': offer.hasAddressProof,
    },
  );

  DiscoveryCardModel buildBikesCard({
    required String ownerId,
    required BikesOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => DiscoveryCardModel(
    id: offerId,
    domain: AppDomainId.bikes,
    ownerId: ownerId,
    title: offer.title,
    subtitle: '₹${offer.hourlyRent}/hour',
    cityId: offer.cityId,
    cityLabel: cityLabels[offer.cityId] ?? offer.cityId,
    categoryTags: [offer.type, offer.make],
    imageUrls: photoUrls,
    role: 'lend',
    attributes: offer.publicAttributes,
  );

  DiscoveryCardModel buildHomeHelpCard({
    required String ownerId,
    required HomeHelpOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => DiscoveryCardModel(
    id: offerId,
    domain: AppDomainId.homeHelp,
    ownerId: ownerId,
    title: offer.service,
    subtitle: '${offer.shift} · ${offer.salaryBand}',
    cityId: offer.cityId,
    cityLabel: cityLabels[offer.cityId] ?? offer.cityId,
    categoryTags: [offer.service, ...offer.languages.take(2)],
    imageUrls: photoUrls,
    role: offer.role,
    attributes: {
      'service': offer.service,
      'shift': offer.shift,
      'salaryBand': offer.salaryBand,
      'languages': offer.languages,
      if (offer.isDemand && offer.howMany != null) 'howMany': offer.howMany,
    },
  );

  Future<DiscoveryCardModel> publishMarriage({
    required String ownerId,
    required MarriageProfile profile,
    List<String> photoUrls = const <String>[],
  }) => _persist(
    buildMarriageCard(ownerId: ownerId, profile: profile, photoUrls: photoUrls),
  );

  Future<DiscoveryCardModel> publishJobs({
    required String ownerId,
    required JobsProfile profile,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => _persist(
    buildJobsCard(
      ownerId: ownerId,
      profile: profile,
      offerId: offerId,
      photoUrls: photoUrls,
    ),
  );

  Future<DiscoveryCardModel> publishKuwaitJobs({
    required String ownerId,
    required KuwaitJobsProfile profile,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => _persist(
    buildKuwaitJobsCard(
      ownerId: ownerId,
      profile: profile,
      offerId: offerId,
      photoUrls: photoUrls,
    ),
  );

  Future<DiscoveryCardModel> publishRooms({
    required String ownerId,
    required RoomsOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => _persist(
    buildRoomsCard(
      ownerId: ownerId,
      offer: offer,
      offerId: offerId,
      photoUrls: photoUrls,
    ),
  );

  Future<DiscoveryCardModel> publishBikes({
    required String ownerId,
    required BikesOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => _persist(
    buildBikesCard(
      ownerId: ownerId,
      offer: offer,
      offerId: offerId,
      photoUrls: photoUrls,
    ),
  );

  Future<DiscoveryCardModel> publishHomeHelp({
    required String ownerId,
    required HomeHelpOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) => _persist(
    buildHomeHelpCard(
      ownerId: ownerId,
      offer: offer,
      offerId: offerId,
      photoUrls: photoUrls,
    ),
  );

  Future<DiscoveryCardModel> _persist(DiscoveryCardModel card) async {
    _assertTextSafe(card);
    await _throttle.claim(ThrottledAction.post);
    var toWrite = card;
    if (FirebaseBootstrap.ready) {
      // Align owner with the live auth session (same uid photo upload used).
      final user = await FirebaseBootstrap.ensureSignedIn();
      final policy = AppDomains.byId(card.domain);
      if (card.ownerId != user.uid) {
        toWrite = card.copyWith(
          ownerId: user.uid,
          id: policy.storageKind == DomainStorageKind.profiles
              ? user.uid
              : card.id,
        );
      }
      if (policy.storageKind == DomainStorageKind.profiles) {
        await _repository.saveProfile(toWrite);
      } else {
        await _repository.saveOffer(toWrite);
      }
    }
    // Owner share card must exist so peer Share links resolve (no ephemeral URLs).
    await _share.createOrUpdate(toWrite);
    return toWrite;
  }

  void _assertTextSafe(DiscoveryCardModel card) {
    const scanner = TextSafetyScanner();
    final fields = <String>[
      card.title,
      card.subtitle,
      if (card.role != null) card.role!,
      if (card.ageBand != null) card.ageBand!,
      ...card.categoryTags,
      ...card.attributes.values.whereType<String>(),
    ];
    for (final value in fields) {
      final result = scanner.scan(value);
      if (!result.safe) {
        throw StateError(result.reason ?? 'Disallowed content');
      }
    }
  }
}
