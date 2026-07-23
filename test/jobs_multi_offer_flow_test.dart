import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:flut_marriage/services/owned_listing_cache.dart';
import 'package:flut_marriage/services/owned_posts.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flut_marriage/widgets/domain_tile_picker.dart';
import 'package:flut_marriage/widgets/forms/home_help_form.dart';
import 'package:flut_marriage/widgets/forms/jobs_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Jobs multi-offer + howMany + domain grid', () {
    test('JobsOfferStore holds multiple posts in Me list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final media = OwnedListingCache(prefs);
      final jobs = JobsOfferStore(preferences: prefs)
        ..upsert(
          const JobsProfile(
            role: 'seek',
            tradeId: 'Driver',
            cityId: 'mumbai',
            salaryBand: '₹15–25k/mo',
            photoCount: 1,
          ),
        )
        ..upsert(
          const JobsProfile(
            role: 'offer',
            tradeId: 'Security',
            cityId: 'delhi',
            salaryBand: '₹25–40k/mo',
            howMany: 'Team',
          ),
        );
      await media.setOfferId(AppDomainId.jobs, 0, 'jobs_a');
      await media.setOfferId(AppDomainId.jobs, 1, 'jobs_b');
      await media.setPhotos(AppDomainId.jobs, const [
        'https://a.example/j0.webp',
      ], index: 0);

      final posts = collectOwnedPosts(
        ownerId: 'u1',
        marriage: ProfileStore(prefs),
        jobs: jobs,
        kuwaitJobs: KuwaitJobsOfferStore(preferences: prefs),
        rooms: RoomsOfferStore(preferences: prefs),
        bikes: BikesOfferStore(preferences: prefs),
        homeHelp: HomeHelpOfferStore(preferences: prefs),
        media: media,
        publisher: ListingPublisher(),
      );

      expect(posts.where((p) => p.domain == AppDomainId.jobs), hasLength(2));
      expect(posts[0].offerIndex, 0);
      expect(posts[0].card.id, 'jobs_a');
      expect(posts[1].offerIndex, 1);
      expect(posts[1].card.id, 'jobs_b');
      expect(posts[1].card.attributes['howMany'], 'Team');
    });

    test('ListingPublisher Jobs card uses offerId not ownerId', () {
      final card = ListingPublisher().buildJobsCard(
        ownerId: 'owner-1',
        offerId: 'jobs_unique_99',
        profile: const JobsProfile(
          role: 'seek',
          tradeId: 'Cook',
          cityId: 'mumbai',
          salaryBand: 'Prefer not to say',
          photoCount: 1,
        ),
        photoUrls: const ['https://cdn.example/c.webp'],
      );
      expect(card.id, 'jobs_unique_99');
      expect(card.id, isNot('owner-1'));
      expect(card.domain, AppDomainId.jobs);
      expect(AppDomains.jobs.storageKind, DomainStorageKind.offers);
    });

    test(
      'JobsOfferStore rolls back new post if remote publish fails',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final jobs = JobsOfferStore(preferences: prefs);
        const profile = JobsProfile(
          role: 'offer',
          tradeId: 'Driver',
          cityId: 'mumbai',
          salaryBand: '₹15–25k/mo',
          howMany: '2',
        );

        await expectLater(
          () => jobs.synchronizeUpsert(
            profile,
            write: (_) async => throw StateError('publish failed'),
          ),
          throwsStateError,
        );

        expect(jobs.offers, isEmpty);
      },
    );

    test('JobsOfferStore rolls back edit if remote publish fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final jobs = JobsOfferStore(preferences: prefs)
        ..upsert(
          const JobsProfile(
            role: 'seek',
            tradeId: 'Cook',
            cityId: 'mumbai',
            salaryBand: 'Prefer not to say',
            photoCount: 1,
          ),
        );

      await expectLater(
        () => jobs.synchronizeUpsert(
          const JobsProfile(
            role: 'offer',
            tradeId: 'Driver',
            cityId: 'delhi',
            salaryBand: '₹15–25k/mo',
            howMany: '3',
          ),
          index: 0,
          write: (_) async => throw StateError('publish failed'),
        ),
        throwsStateError,
      );

      expect(jobs.offers.single.tradeId, 'Cook');
      expect(jobs.offers.single.role, 'seek');
    });

    testWidgets('Jobs form shows How many only for I need', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => JobsOfferStore(preferences: prefs),
          child: const MaterialApp(home: Scaffold(body: JobsForm())),
        ),
      );
      await tester.pump();

      expect(find.text('How many'), findsNothing);

      await tester.tap(find.text('I need'));
      await tester.pump();
      expect(find.text('How many'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);

      await tester.tap(find.text('I have'));
      await tester.pump();
      expect(find.text('How many'), findsNothing);
    });

    testWidgets('Home Help form shows How many only for I need', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => HomeHelpOfferStore(preferences: prefs),
          child: const MaterialApp(home: Scaffold(body: HomeHelpForm())),
        ),
      );
      await tester.pump();

      expect(find.text('How many'), findsNothing);
      await tester.tap(find.text('I need'));
      await tester.pump();
      expect(find.text('How many'), findsOneWidget);
    });

    testWidgets('domain apps grid lays out both rows fully visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: DomainTilePicker(
                  selected: AppDomainId.marriage,
                  onDomainSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final help = tester.getRect(
        find.byKey(const Key('domain_tile_homeHelp')),
      );
      final marriage = tester.getRect(
        find.byKey(const Key('domain_tile_marriage')),
      );
      expect(help.height, DomainTilePicker.cellHeight);
      expect(help.top, greaterThan(marriage.bottom - 1));
      expect(help.bottom, lessThanOrEqualTo(800));
    });
  });
}
