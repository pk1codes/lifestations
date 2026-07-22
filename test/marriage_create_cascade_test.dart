import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/models/public_share_card.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:flut_marriage/services/owned_listing_cache.dart';
import 'package:flut_marriage/services/owned_posts.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Proves local cascade after U1 creates a Marriage post (Save path).
void main() {
  test(
    'Marriage create cascade: validate → public card → Me post → hide self',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final media = OwnedListingCache(prefs);
      final publisher = ListingPublisher();

      // Cap + policy (New post gated by maxProfiles).
      expect(AppDomains.marriage.maxProfiles, 1);
      expect(AppDomains.marriage.storageKind, DomainStorageKind.profiles);
      expect(AppDomains.marriage.minPhotos, 1);
      expect(AppDomains.marriage.mediaPolicy, MediaPolicy.face);
      expect(AppDomains.marriage.collection, 'domains/marriage/profiles');

      const profile = MarriageProfile(
        age: 28,
        gender: 'woman',
        seeking: 'man',
        bio: 'Private bio never published',
        cityId: 'mumbai',
        photoCount: 1,
        religion: 'Hindu',
        salaryBand: '₹5–10L/year',
      );
      expect(profile.isValid, isTrue);
      expect(profile.ageBand, '25-29');

      // Local store (MarriageForm saveLocal).
      final marriage = ProfileStore(prefs)..saveLocal(profile);
      expect(marriage.value?.age, 28);

      await media.setPhotos(AppDomainId.marriage, const [
        'https://cdn.example/m.webp',
      ]);

      // Publish payload (ListingPublisher.buildMarriageCard — bio omitted).
      final card = publisher.buildMarriageCard(
        ownerId: 'user1',
        profile: profile,
        photoUrls: media.photos(AppDomainId.marriage),
      );
      expect(card.id, 'user1'); // profiles storage = owner uid
      expect(card.title, '25-29');
      expect(card.role, 'man');
      expect(card.ageBand, '25-29');
      expect(card.categoryTags, containsAll(['woman', 'Hindu']));
      expect(card.attributes['bio'], isNull);
      expect(card.toPublicJson().containsKey('bio'), isFalse);
      expect(card.toPublicJson()['photoUrls'], isNotEmpty);
      expect(card.toPublicJson().keys, isNot(contains('whatsappNumber')));

      // Me → owned posts list.
      final posts = collectOwnedPosts(
        ownerId: 'user1',
        marriage: marriage,
        jobs: JobsOfferStore(),
        rooms: RoomsOfferStore(),
        bikes: BikesOfferStore(),
        homeHelp: HomeHelpOfferStore(),
        media: media,
        publisher: publisher,
      );
      expect(posts, hasLength(1));
      expect(posts.single.domain, AppDomainId.marriage);
      expect(posts.single.card.imageUrls.single, 'https://cdn.example/m.webp');

      // Browse hides own listing.
      final discovery = DiscoveryStore(AppDomainId.marriage)
        ..load([
          card,
          card.copyWith(id: 'other', ownerId: 'user2', title: '30-34'),
        ]);
      expect(discovery.cardsForViewer('user1').single.ownerId, 'user2');

      // Share slug shape for peer links.
      expect(PublicShareCard.isValidSlug('marriage_abcdef123456'), isTrue);
    },
  );

  test('Marriage invalid without photo or under-18', () {
    expect(
      const MarriageProfile(
        age: 17,
        gender: 'man',
        seeking: 'woman',
        bio: '',
        cityId: 'mumbai',
        photoCount: 1,
      ).isValid,
      isFalse,
    );
    expect(
      const MarriageProfile(
        age: 25,
        gender: 'man',
        seeking: 'woman',
        bio: '',
        cityId: 'mumbai',
        photoCount: 0,
      ).isValid,
      isFalse,
    );
  });
}
