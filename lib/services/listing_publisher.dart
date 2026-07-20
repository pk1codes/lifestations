import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import '../models/domain_profiles.dart';
import 'action_throttle.dart';
import 'domain_repository.dart';
import 'firebase_bootstrap.dart';
import 'moderation/moderation_service.dart';
import 'share_card_repository.dart';

const cityLabels = <String, String>{
  'mumbai': 'Mumbai & MMR',
  'delhi': 'Delhi NCR',
  'bengaluru': 'Bengaluru',
};

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

  Future<DiscoveryCardModel> publishMarriage({
    required String ownerId,
    required MarriageProfile profile,
    List<String> photoUrls = const <String>[],
  }) async {
    final card = DiscoveryCardModel(
      id: ownerId,
      domain: AppDomainId.marriage,
      ownerId: ownerId,
      title: 'Marriage · ${profile.ageBand}',
      subtitle: 'Seeking ${profile.seeking}',
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
    return _persist(card);
  }

  Future<DiscoveryCardModel> publishJobs({
    required String ownerId,
    required JobsProfile profile,
    List<String> photoUrls = const <String>[],
  }) async {
    final card = DiscoveryCardModel(
      id: ownerId,
      domain: AppDomainId.jobs,
      ownerId: ownerId,
      title: profile.needLine,
      subtitle: profile.salaryBand,
      cityId: profile.cityId,
      cityLabel: cityLabels[profile.cityId] ?? profile.cityId,
      categoryTags: [profile.tradeId],
      imageUrls: photoUrls,
      role: profile.role,
      attributes: {
        'tradeId': profile.tradeId,
        'salaryBand': profile.salaryBand,
      },
    );
    return _persist(card);
  }

  Future<DiscoveryCardModel> publishRooms({
    required String ownerId,
    required RoomsOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) async {
    final card = DiscoveryCardModel(
      id: offerId,
      domain: AppDomainId.rooms,
      ownerId: ownerId,
      title: offer.title,
      subtitle: offer.subtitle,
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
    return _persist(card);
  }

  Future<DiscoveryCardModel> publishBikes({
    required String ownerId,
    required BikesOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) async {
    final card = DiscoveryCardModel(
      id: offerId,
      domain: AppDomainId.bikes,
      ownerId: ownerId,
      title: offer.title,
      subtitle: offer.subtitle,
      cityId: offer.cityId,
      cityLabel: cityLabels[offer.cityId] ?? offer.cityId,
      categoryTags: [offer.type, offer.make],
      imageUrls: photoUrls,
      role: 'lend',
      attributes: offer.publicAttributes,
    );
    return _persist(card);
  }

  Future<DiscoveryCardModel> publishHomeHelp({
    required String ownerId,
    required HomeHelpOffer offer,
    required String offerId,
    List<String> photoUrls = const <String>[],
  }) async {
    final card = DiscoveryCardModel(
      id: offerId,
      domain: AppDomainId.homeHelp,
      ownerId: ownerId,
      title: offer.title,
      subtitle: offer.subtitle,
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
      },
    );
    return _persist(card);
  }

  Future<DiscoveryCardModel> _persist(DiscoveryCardModel card) async {
    _assertTextSafe(card);
    await _throttle.claim(ThrottledAction.post);
    if (FirebaseBootstrap.ready) {
      final policy = AppDomains.byId(card.domain);
      if (policy.storageKind == DomainStorageKind.profiles) {
        await _repository.saveProfile(card);
      } else {
        await _repository.saveOffer(card);
      }
      try {
        await _share.createOrUpdate(card);
      } catch (_) {
        // Share publish is best-effort after listing save.
      }
    } else {
      await _share.createOrUpdate(card);
    }
    return card;
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
