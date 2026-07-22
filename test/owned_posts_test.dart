import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:flut_marriage/services/owned_listing_cache.dart';
import 'package:flut_marriage/services/owned_posts.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('collectOwnedPosts lists each offer as its own card', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final media = OwnedListingCache(prefs);
    final marriage = ProfileStore()
      ..saveLocal(
        const MarriageProfile(
          age: 28,
          gender: 'woman',
          seeking: 'man',
          bio: '',
          cityId: 'mumbai',
          photoCount: 1,
        ),
      );
    final jobs = JobsOfferStore();
    final rooms = RoomsOfferStore()
      ..upsert(
        const RoomsOffer(
          type: '1 BHK',
          furnishing: 'Semi',
          monthlyRent: 15000,
          depositMonths: 1,
          cityId: 'mumbai',
          photoCount: 2,
        ),
      )
      ..upsert(
        const RoomsOffer(
          type: 'Studio',
          furnishing: 'Unfurnished',
          monthlyRent: 12000,
          depositMonths: 0,
          cityId: 'delhi',
          photoCount: 2,
        ),
      );
    final bikes = BikesOfferStore();
    final homeHelp = HomeHelpOfferStore();

    await media.setPhotos(AppDomainId.marriage, const [
      'https://a.example/m.jpg',
    ]);
    await media.setPhotos(AppDomainId.rooms, const [
      'https://a.example/r0.jpg',
    ], index: 0);

    final posts = collectOwnedPosts(
      ownerId: 'u1',
      marriage: marriage,
      jobs: jobs,
      rooms: rooms,
      bikes: bikes,
      homeHelp: homeHelp,
      media: media,
      publisher: ListingPublisher(),
    );

    expect(posts, hasLength(3));
    expect(posts[0].domain, AppDomainId.marriage);
    expect(posts[0].card.imageUrls, ['https://a.example/m.jpg']);
    expect(posts[1].offerIndex, 0);
    expect(posts[1].card.title, '1 BHK');
    expect(posts[1].card.imageUrls, ['https://a.example/r0.jpg']);
    expect(posts[2].offerIndex, 1);
    expect(posts[2].card.title, 'Studio');
  });
}
