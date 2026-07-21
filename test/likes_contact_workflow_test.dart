import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/contact_service.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('likes store mutual gate for connect', () async {
    final likes = LikesStore();
    // Without Firebase, remote like throws — use receiveLike + local mutual check
    // via the synchronous receive path after a failed-open isn't available.
    // Mutual unlock still needs both directions in memory:
    likes.receiveLike(AppDomainId.rooms, 'owner');
    (likes.outbound(AppDomainId.rooms)); // empty until remote like
    expect(
      likes.canUnlock(
        domain: AppDomainId.rooms,
        otherId: 'owner',
        anonymous: false,
        phoneVerified: true,
      ),
      isFalse,
    );
  });

  test('likes store keeps inbound snapshot entries across domains', () {
    final likes = LikesStore()
      ..receiveLike(
        AppDomainId.jobs,
        'owner-c',
        card: const DiscoveryCardModel(
          id: 'jobs-c',
          domain: AppDomainId.jobs,
          ownerId: 'owner-c',
          title: 'Cook',
          subtitle: 'Nights',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          categoryTags: [],
          imageUrls: [],
        ),
      );

    expect(likes.inboundCount, 1);
    expect(likes.inboundEntries(AppDomainId.jobs).single.otherUid, 'owner-c');
    expect(likes.inboundEntries(AppDomainId.jobs).single.card?.title, 'Cook');
    expect(likes.isMutual(AppDomainId.jobs, 'owner-c'), isFalse);
  });

  test('inbound push applies liker card for Liked me', () {
    final likes = LikesStore()
      ..applyInboundPush(
        domainSlug: 'marriage',
        fromUid: 'liker-1',
        title: 'Priya',
        cityLabel: 'Pune',
        photoUrl: 'https://example.com/a.webp',
        listingId: 'marriage-liker-1',
      );

    expect(likes.inboundCount, 1);
    final entry = likes.inboundEntries(AppDomainId.marriage).single;
    expect(entry.otherUid, 'liker-1');
    expect(entry.card?.title, 'Priya');
    expect(entry.card?.cityLabel, 'Pune');
    expect(entry.card?.imageUrls.single, 'https://example.com/a.webp');
  });

  test('OTP throttle blocks rapid resend', () {
    final throttle = OtpThrottle();
    final now = DateTime(2026, 7, 19, 5);
    expect(throttle.record(now), isTrue);
    expect(throttle.record(now.add(const Duration(seconds: 10))), isFalse);
  });

  test('discovery cardsForViewer hides own listings', () {
    final store = DiscoveryStore(AppDomainId.marriage)
      ..load(const [
        DiscoveryCardModel(
          id: 'a',
          domain: AppDomainId.marriage,
          ownerId: 'me',
          title: 'Mine',
          subtitle: '',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          categoryTags: [],
          imageUrls: [],
        ),
        DiscoveryCardModel(
          id: 'b',
          domain: AppDomainId.marriage,
          ownerId: 'other',
          title: 'Theirs',
          subtitle: '',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          categoryTags: [],
          imageUrls: [],
        ),
      ]);
    expect(store.cardsForViewer('me').single.ownerId, 'other');
  });
}
