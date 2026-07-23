import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/like_display.dart';
import 'package:flut_marriage/services/likes_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('inbound entry keeps targetCard for two-block Liked me', () {
    final likes = LikesStore(repository: _OfflineLikesRepository());
    likes.receiveLike(
      AppDomainId.jobs,
      'liker',
      card: const DiscoveryCardModel(
        id: 'liker_post',
        domain: AppDomainId.jobs,
        ownerId: 'liker',
        title: 'Driver',
        subtitle: '',
        cityId: 'dubai',
        cityLabel: 'Dubai',
        categoryTags: <String>['Driver'],
        imageUrls: <String>[],
      ),
      targetCard: const DiscoveryCardModel(
        id: 'owner_post',
        domain: AppDomainId.jobs,
        ownerId: 'owner',
        title: 'Security',
        subtitle: '',
        cityId: 'dubai',
        cityLabel: 'Dubai',
        categoryTags: <String>['Security'],
        imageUrls: <String>['https://cdn.example/owner.webp'],
      ),
    );

    final entry = likes.inboundEntries(AppDomainId.jobs).single;
    expect(entry.targetCard?.title, 'Security');
    expect(entry.targetCard?.imageUrls, isNotEmpty);
    expect(entry.card?.title, 'Driver');
    expect(LikeDisplay.yourPostLabel, 'Your post');
    expect(LikeDisplay.likedByLabel, 'Liked by');
    expect(LikeDisplay.noPhotoYet, 'No photo');
  });

  test('accept unlocks WhatsApp both sides immediately when mutual', () async {
    final likes = LikesStore(repository: _OfflineLikesRepository());
    likes.receiveLike(
      AppDomainId.rooms,
      'peer',
      card: const DiscoveryCardModel(
        id: 'peer',
        domain: AppDomainId.rooms,
        ownerId: 'peer',
        title: 'Room',
        subtitle: '',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        categoryTags: <String>[],
        imageUrls: <String>[],
      ),
      targetCard: const DiscoveryCardModel(
        id: 'mine',
        domain: AppDomainId.rooms,
        ownerId: 'me',
        title: 'My room',
        subtitle: '',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        categoryTags: <String>[],
        imageUrls: <String>['https://cdn.example/room.webp'],
      ),
    );
    expect(likes.chatIconsActive(AppDomainId.rooms, 'peer'), isFalse);

    final mutual = await likes.like(
      AppDomainId.rooms,
      'peer',
      snapshot: const DiscoveryCardModel(
        id: 'peer',
        domain: AppDomainId.rooms,
        ownerId: 'peer',
        title: 'Room',
        subtitle: '',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        categoryTags: <String>[],
        imageUrls: <String>[],
      ),
    );
    expect(mutual, isTrue);
    expect(likes.chatIconsActive(AppDomainId.rooms, 'peer'), isTrue);
    expect(likes.matchCount, 1);
    expect(likes.inboundCount, 0);
    expect(likes.outboundCount, 0);
  });

  test('kuwait_jobs inbound carries dual snapshots', () {
    final likes = LikesStore(repository: _OfflineLikesRepository());
    likes.receiveLike(
      AppDomainId.kuwaitJobs,
      'liker',
      card: const DiscoveryCardModel(
        id: 'liker',
        domain: AppDomainId.kuwaitJobs,
        ownerId: 'liker',
        title: 'Cook',
        subtitle: '',
        cityId: 'kuwait',
        cityLabel: 'Kuwait',
        categoryTags: <String>['Cook'],
        imageUrls: <String>[],
      ),
      targetCard: const DiscoveryCardModel(
        id: 'post',
        domain: AppDomainId.kuwaitJobs,
        ownerId: 'me',
        title: 'Driller',
        subtitle: '',
        cityId: 'kuwait',
        cityLabel: 'Kuwait',
        categoryTags: <String>['Driller'],
        imageUrls: <String>['https://cdn.example/drill.webp'],
      ),
    );
    final entry = likes.inboundEntries(AppDomainId.kuwaitJobs).single;
    expect(entry.targetCard?.title, 'Driller');
    expect(entry.card?.title, 'Cook');
  });
}
