import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/contact_service.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('likes store mutual gate for connect', () {
    final likes = LikesStore()
      ..like(AppDomainId.rooms, 'owner')
      ..receiveLike(AppDomainId.rooms, 'owner');
    expect(
      likes.canUnlock(
        domain: AppDomainId.rooms,
        otherId: 'owner',
        anonymous: false,
        phoneVerified: true,
      ),
      isTrue,
    );
  });

  test('likes store keeps snapshot entries across domains', () {
    const card = DiscoveryCardModel(
      id: 'listing-1',
      domain: AppDomainId.jobs,
      ownerId: 'owner-a',
      title: 'Driver available',
      subtitle: 'Looking for work',
      cityId: 'mumbai',
      cityLabel: 'Mumbai & MMR',
      categoryTags: ['driver'],
      imageUrls: ['assets/seed.jpg'],
    );
    final likes = LikesStore()
      ..like(AppDomainId.jobs, 'owner-a', snapshot: card)
      ..like(AppDomainId.rooms, 'owner-b')
      ..receiveLike(AppDomainId.jobs, 'owner-c');

    expect(likes.outboundCount, 2);
    expect(likes.inboundCount, 1);
    expect(likes.outboundEntries(AppDomainId.jobs).single.card?.title, 'Driver available');
    expect(likes.outboundEntries(AppDomainId.rooms).single.card, isNull);
    expect(likes.inboundEntries(AppDomainId.jobs).single.otherUid, 'owner-c');
    expect(likes.isMutual(AppDomainId.jobs, 'owner-a'), isFalse);
  });

  test('OTP throttle blocks rapid resend', () {
    final throttle = OtpThrottle();
    final now = DateTime(2026, 7, 19, 5);
    expect(throttle.record(now), isTrue);
    expect(throttle.record(now.add(const Duration(seconds: 10))), isFalse);
  });
}
