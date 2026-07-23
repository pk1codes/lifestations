import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/likes_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skips Firestore so like-back cascade can be proven in-memory.
class _OfflineLikesRepository extends LikesRepository {
  @override
  Future<void> like({
    required AppDomainId domain,
    String? targetUid,
    DiscoveryCardModel? target,
    DiscoveryCardModel? snapshot,
    DiscoveryCardModel? fromCard,
  }) async {}
}

void main() {
  test('U2 like-back: mutual, chat icons, unlock needs phone verify', () async {
    final likes = LikesStore(repository: _OfflineLikesRepository());

    // Prior: U1 liked U2 → U2 has inbound from user1 on Liked me.
    likes.receiveLike(
      AppDomainId.jobs,
      'user1',
      card: const DiscoveryCardModel(
        id: 'user1_listing',
        domain: AppDomainId.jobs,
        ownerId: 'user1',
        title: 'Driver',
        subtitle: '',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        categoryTags: <String>['Driver'],
        imageUrls: <String>[],
      ),
    );
    expect(likes.isMutual(AppDomainId.jobs, 'user1'), isFalse);
    expect(likes.chatIconsActive(AppDomainId.jobs, 'user1'), isFalse);

    // U2 Like back (after phone OTP — same as Me verify).
    final mutual = await likes.like(
      AppDomainId.jobs,
      'user1',
      snapshot: const DiscoveryCardModel(
        id: 'user1_listing',
        domain: AppDomainId.jobs,
        ownerId: 'user1',
        title: 'Driver',
        subtitle: '',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        categoryTags: <String>['Driver'],
        imageUrls: <String>[],
      ),
    );

    expect(mutual, isTrue);
    expect(likes.isMutual(AppDomainId.jobs, 'user1'), isTrue);
    expect(likes.chatIconsActive(AppDomainId.jobs, 'user1'), isTrue);
    expect(likes.outbound(AppDomainId.jobs), contains('user1'));
    expect(likes.matchCount, 1);
    expect(
      likes.matchEntries(AppDomainId.jobs).single.card?.title,
      'Driver',
    );
    expect(
      likes.canUnlock(
        domain: AppDomainId.jobs,
        otherId: 'user1',
        anonymous: false,
        phoneVerified: true,
      ),
      isTrue,
    );
    expect(
      likes.canUnlock(
        domain: AppDomainId.jobs,
        otherId: 'user1',
        anonymous: false,
        phoneVerified: false,
      ),
      isFalse,
      reason: 'OTP still required at chat unlock, not at like-back',
    );
  });
}
