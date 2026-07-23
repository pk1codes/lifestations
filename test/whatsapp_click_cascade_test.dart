import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/contact_service.dart';
import 'package:flut_marriage/services/likes_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineLikesRepository extends LikesRepository {
  String? signaledOther;
  AppDomainId? signaledDomain;

  @override
  Future<void> like({
    required AppDomainId domain,
    String? targetUid,
    DiscoveryCardModel? target,
    DiscoveryCardModel? snapshot,
    DiscoveryCardModel? fromCard,
  }) async {}

  @override
  Future<void> signalChatOpened({
    required AppDomainId domain,
    required String otherUid,
  }) async {
    signaledDomain = domain;
    signaledOther = otherUid;
  }
}

void main() {
  test(
    'I liked → WhatsApp: locked until mutual, then OTP gate + signal',
    () async {
      final repo = _OfflineLikesRepository();
      final likes = LikesStore(repository: repo);

      // U1 liked U2 only (They liked / I liked card).
      await likes.like(
        AppDomainId.jobs,
        'user2',
        snapshot: const DiscoveryCardModel(
          id: 'u2',
          domain: AppDomainId.jobs,
          ownerId: 'user2',
          title: 'Cook',
          subtitle: '',
          cityId: 'mumbai',
          cityLabel: 'Mumbai',
          categoryTags: <String>['Cook'],
          imageUrls: <String>[],
        ),
      );
      expect(likes.isMutual(AppDomainId.jobs, 'user2'), isFalse);
      expect(likes.chatIconsActive(AppDomainId.jobs, 'user2'), isFalse);
      expect(
        likes.canUnlock(
          domain: AppDomainId.jobs,
          otherId: 'user2',
          anonymous: false,
          phoneVerified: true,
        ),
        isFalse,
        reason: 'No mutual → unlockContact must refuse',
      );

      // U2 liked back → mutual; WhatsApp button enables (chatIconsActive).
      likes.receiveLike(AppDomainId.jobs, 'user2');
      expect(likes.isMutual(AppDomainId.jobs, 'user2'), isTrue);
      expect(likes.chatIconsActive(AppDomainId.jobs, 'user2'), isTrue);
      expect(
        likes.canUnlock(
          domain: AppDomainId.jobs,
          otherId: 'user2',
          anonymous: false,
          phoneVerified: false,
        ),
        isFalse,
        reason: 'OTP required at WhatsApp tap, not earlier',
      );
      expect(
        likes.canUnlock(
          domain: AppDomainId.jobs,
          otherId: 'user2',
          anonymous: false,
          phoneVerified: true,
        ),
        isTrue,
      );

      // UI path after unlock: signalChatOpened → peer inbound peerOpenedChat.
      await likes.signalChatOpened(AppDomainId.jobs, 'user2');
      expect(repo.signaledDomain, AppDomainId.jobs);
      expect(repo.signaledOther, 'user2');
    },
  );

  test('openWhatsApp digit gate (≥8) matches wa.me launch path', () {
    expect(cleanWhatsAppDigits('1234567').length >= 8, isFalse);
    expect(cleanWhatsAppDigits('').length >= 8, isFalse);
    expect(cleanWhatsAppDigits('+91 98765 43210').length >= 8, isTrue);
    final uri = buildWhatsAppHttpsUri(
      '+91 98765 43210',
      message: contactOpenMessage(domainLabel: 'Jobs'),
    );
    expect(uri.queryParameters['text'], contains('Life Stations'));
    expect(uri.path, '/919876543210');
  });

  test('OTP throttle applies when resending at chat unlock', () {
    final throttle = OtpThrottle();
    final now = DateTime(2026, 7, 22, 11);
    expect(throttle.record(now), isTrue);
    expect(throttle.record(now.add(const Duration(seconds: 30))), isFalse);
  });
}
