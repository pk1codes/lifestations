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

  @override
  Future<void> unlike({
    required AppDomainId domain,
    required String targetUid,
  }) async {}
}

DiscoveryCardModel _card({
  required String id,
  required String ownerId,
  required String title,
  AppDomainId domain = AppDomainId.jobs,
}) => DiscoveryCardModel(
  id: id,
  domain: domain,
  ownerId: ownerId,
  title: title,
  subtitle: '',
  cityId: 'mumbai',
  cityLabel: 'Mumbai',
  categoryTags: <String>[title],
  imageUrls: <String>[],
);

void main() {
  test('mutual moves out of I liked and Liked me into Match', () async {
    final likes = LikesStore(repository: _OfflineLikesRepository());

    likes.receiveLike(
      AppDomainId.jobs,
      'peer',
      card: _card(id: 'peer_post', ownerId: 'peer', title: 'Cook'),
      targetCard: _card(id: 'my_post', ownerId: 'me', title: 'Driver'),
    );
    expect(likes.inboundCount, 1);
    expect(likes.matchCount, 0);
    expect(likes.inboundEntries(AppDomainId.jobs).single.card?.title, 'Cook');

    final mutual = await likes.like(
      AppDomainId.jobs,
      'peer',
      snapshot: _card(id: 'peer_post', ownerId: 'peer', title: 'Cook'),
    );
    expect(mutual, isTrue);
    expect(likes.isMutual(AppDomainId.jobs, 'peer'), isTrue);

    expect(likes.inboundCount, 0);
    expect(likes.outboundCount, 0);
    expect(likes.matchCount, 1);

    final match = likes.matchEntries(AppDomainId.jobs).single;
    expect(match.otherUid, 'peer');
    expect(match.targetCard?.title, 'Driver');
    expect(match.card?.title, 'Cook');
    expect(LikeDisplay.matchSectionTitle, 'Match');
  });

  test('outbound-only stays in I liked until they like back', () async {
    final likes = LikesStore(repository: _OfflineLikesRepository());
    await likes.like(
      AppDomainId.rooms,
      'peer',
      snapshot: _card(
        id: 'peer',
        ownerId: 'peer',
        title: 'Room',
        domain: AppDomainId.rooms,
      ),
    );
    expect(likes.outboundCount, 1);
    expect(likes.matchCount, 0);

    likes.receiveLike(
      AppDomainId.rooms,
      'peer',
      card: _card(
        id: 'peer',
        ownerId: 'peer',
        title: 'Room',
        domain: AppDomainId.rooms,
      ),
      targetCard: _card(
        id: 'mine',
        ownerId: 'me',
        title: 'My room',
        domain: AppDomainId.rooms,
      ),
    );
    expect(likes.outboundCount, 0);
    expect(likes.inboundCount, 0);
    expect(likes.matchCount, 1);
  });

  test('deleteMatch clears Match and does not bounce to Liked me', () async {
    final likes = LikesStore(repository: _OfflineLikesRepository());
    likes.receiveLike(
      AppDomainId.kuwaitJobs,
      'peer',
      card: _card(
        id: 'peer',
        ownerId: 'peer',
        title: 'Cook',
        domain: AppDomainId.kuwaitJobs,
      ),
      targetCard: _card(
        id: 'mine',
        ownerId: 'me',
        title: 'Driller',
        domain: AppDomainId.kuwaitJobs,
      ),
    );
    await likes.like(
      AppDomainId.kuwaitJobs,
      'peer',
      snapshot: _card(
        id: 'peer',
        ownerId: 'peer',
        title: 'Cook',
        domain: AppDomainId.kuwaitJobs,
      ),
    );
    expect(likes.matchCount, 1);

    await likes.deleteMatch(AppDomainId.kuwaitJobs, 'peer');
    expect(likes.matchCount, 0);
    expect(likes.outboundCount, 0);
    expect(likes.inboundCount, 0);
    expect(likes.isMutual(AppDomainId.kuwaitJobs, 'peer'), isFalse);
  });
}
