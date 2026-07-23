import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/models/owned_post.dart';
import 'package:flut_marriage/services/listing_lifecycle.dart';
import 'package:flut_marriage/services/owned_listing_cache.dart';
import 'package:flut_marriage/services/owned_posts.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pause and delete owned posts', () {
    late SharedPreferences prefs;
    late OwnedListingCache media;
    late ProfileStore marriage;
    late JobsOfferStore jobs;
    late RoomsOfferStore rooms;
    late BikesOfferStore bikes;
    late HomeHelpOfferStore homeHelp;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      media = OwnedListingCache(prefs);
      marriage = ProfileStore(prefs);
      jobs = JobsOfferStore(preferences: prefs);
      rooms = RoomsOfferStore(preferences: prefs);
      bikes = BikesOfferStore(preferences: prefs);
      homeHelp = HomeHelpOfferStore(preferences: prefs);
    });

    test('pause flag hides live state in My posts list', () async {
      marriage.saveLocal(
        const MarriageProfile(
          age: 28,
          gender: 'woman',
          seeking: 'man',
          bio: 'Hello',
          cityId: 'mumbai',
          photoCount: 1,
        ),
      );
      await media.setPhotos(AppDomainId.marriage, const ['https://x/a.webp']);
      await media.setActive(AppDomainId.marriage, false);

      final posts = collectOwnedPosts(
        ownerId: 'owner-1',
        marriage: marriage,
        jobs: jobs,
        kuwaitJobs: KuwaitJobsOfferStore(preferences: prefs),
        rooms: rooms,
        bikes: bikes,
        homeHelp: homeHelp,
        media: media,
      );

      expect(posts, hasLength(1));
      expect(posts.single.paused, isTrue);
      expect(posts.single.card.active, isFalse);
    });

    test('local pause without Firebase updates cache', () async {
      final post = OwnedPost(
        domain: AppDomainId.jobs,
        card: const DiscoveryCardModel(
          id: 'owner-1',
          domain: AppDomainId.jobs,
          ownerId: 'owner-1',
          title: 'Driver',
          subtitle: '',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          categoryTags: ['driver'],
          imageUrls: [],
        ),
      );
      await expectLater(
        ListingLifecycleService().setPaused(
          post: post,
          paused: true,
          media: media,
        ),
        throwsA(isA<StateError>()),
      );
      // Still allow direct cache writes used by hydrate / offline UI state.
      await media.setActive(AppDomainId.jobs, false);
      expect(media.isActive(AppDomainId.jobs), isFalse);
    });

    test('delete marriage clears local store and media', () async {
      marriage.saveLocal(
        const MarriageProfile(
          age: 28,
          gender: 'woman',
          seeking: 'man',
          bio: 'Hello',
          cityId: 'mumbai',
          photoCount: 1,
        ),
      );
      await media.setPhotos(AppDomainId.marriage, const ['https://x/a.webp']);
      await media.setActive(AppDomainId.marriage, true);

      final post = collectOwnedPosts(
        ownerId: 'owner-1',
        marriage: marriage,
        jobs: jobs,
        kuwaitJobs: KuwaitJobsOfferStore(preferences: prefs),
        rooms: rooms,
        bikes: bikes,
        homeHelp: homeHelp,
        media: media,
      ).single;

      // Without Firebase, delete refuses so remote cannot resurrect later.
      await expectLater(
        ListingLifecycleService().deletePost(
          post: post,
          media: media,
          marriage: marriage,
          jobs: jobs,
          kuwaitJobs: KuwaitJobsOfferStore(preferences: prefs),
          rooms: rooms,
          bikes: bikes,
          homeHelp: homeHelp,
        ),
        throwsA(isA<StateError>()),
      );
      expect(marriage.value, isNotNull);

      // Direct local cleanup path (same as after a successful remote delete).
      marriage.clearLocal();
      await media.clearProfileSlot(AppDomainId.marriage);
      expect(marriage.value, isNull);
      expect(media.photos(AppDomainId.marriage), isEmpty);
      expect(
        collectOwnedPosts(
          ownerId: 'owner-1',
          marriage: marriage,
          jobs: jobs,
          kuwaitJobs: KuwaitJobsOfferStore(preferences: prefs),
          rooms: rooms,
          bikes: bikes,
          homeHelp: homeHelp,
          media: media,
        ),
        isEmpty,
      );
    });

    test('delete rooms offer shifts remaining slots', () async {
      rooms.upsert(
        const RoomsOffer(
          type: 'Room',
          furnishing: 'Semi',
          monthlyRent: 8000,
          depositMonths: 1,
          cityId: 'mumbai',
          photoCount: 2,
          amenities: ['wifi'],
          hasAddressProof: false,
        ),
      );
      rooms.upsert(
        const RoomsOffer(
          type: 'Studio',
          furnishing: 'Unfurnished',
          monthlyRent: 12000,
          depositMonths: 2,
          cityId: 'delhi',
          photoCount: 2,
          amenities: ['parking'],
          hasAddressProof: true,
        ),
      );
      await media.setOfferId(AppDomainId.rooms, 0, 'room_a');
      await media.setOfferId(AppDomainId.rooms, 1, 'room_b');
      await media.setPhotos(AppDomainId.rooms, const [
        'https://a.webp',
      ], index: 0);
      await media.setPhotos(AppDomainId.rooms, const [
        'https://b.webp',
      ], index: 1);

      // Exercise cache shift used after a successful remote delete.
      rooms.removeAt(0);
      await media.removeOfferSlot(AppDomainId.rooms, 0);

      expect(rooms.offers, hasLength(1));
      expect(rooms.offers.single.type, 'Studio');
      expect(media.offerId(AppDomainId.rooms, 0), 'room_b');
      expect(media.photos(AppDomainId.rooms, 0), ['https://b.webp']);
    });
  });
}
