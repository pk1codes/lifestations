import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/likes_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

class _CaptureLikesRepository extends LikesRepository {
  DiscoveryCardModel? lastFromCard;
  DiscoveryCardModel? lastSnapshot;
  AppDomainId? lastDomain;
  String? lastTarget;

  @override
  Future<void> like({
    required AppDomainId domain,
    String? targetUid,
    DiscoveryCardModel? target,
    DiscoveryCardModel? snapshot,
    DiscoveryCardModel? fromCard,
  }) async {
    lastDomain = domain;
    lastTarget = targetUid;
    lastSnapshot = snapshot ?? target;
    lastFromCard = fromCard;
  }
}

void main() {
  test('like-back passes fromCard and unlocks chat when inbound exists', () async {
    final repo = _CaptureLikesRepository();
    final likes = LikesStore(repository: repo);

    likes.receiveLike(
      AppDomainId.kuwaitJobs,
      'user1',
      card: const DiscoveryCardModel(
        id: 'user1_listing',
        domain: AppDomainId.kuwaitJobs,
        ownerId: 'user1',
        title: 'Driller',
        subtitle: '',
        cityId: 'kuwait',
        cityLabel: 'Kuwait',
        categoryTags: <String>['Driller'],
        imageUrls: <String>['https://cdn.example/a.webp'],
      ),
    );

    final fromCard = const DiscoveryCardModel(
      id: 'me_listing',
      domain: AppDomainId.kuwaitJobs,
      ownerId: 'me',
      title: 'Cook',
      subtitle: '',
      cityId: 'kuwait',
      cityLabel: 'Kuwait',
      categoryTags: <String>['Cook'],
      imageUrls: <String>['https://cdn.example/me.webp'],
    );

    final mutual = await likes.like(
      AppDomainId.kuwaitJobs,
      'user1',
      snapshot: const DiscoveryCardModel(
        id: 'user1_listing',
        domain: AppDomainId.kuwaitJobs,
        ownerId: 'user1',
        title: 'Driller',
        subtitle: '',
        cityId: 'kuwait',
        cityLabel: 'Kuwait',
        categoryTags: <String>['Driller'],
        imageUrls: <String>['https://cdn.example/a.webp'],
      ),
      fromCard: fromCard,
    );

    expect(mutual, isTrue);
    expect(repo.lastFromCard?.imageUrls.single, 'https://cdn.example/me.webp');
    expect(repo.lastDomain, AppDomainId.kuwaitJobs);
    expect(likes.chatIconsActive(AppDomainId.kuwaitJobs, 'user1'), isTrue);
  });

  test('applyInboundPush chatReady activates icons for existing outbound', () async {
    final repo = _CaptureLikesRepository();
    final likes = LikesStore(repository: repo);
    await likes.like(
      AppDomainId.jobs,
      'peer',
      snapshot: const DiscoveryCardModel(
        id: 'peer_job',
        domain: AppDomainId.jobs,
        ownerId: 'peer',
        title: 'Driver',
        subtitle: '',
        cityId: 'dubai',
        cityLabel: 'Dubai',
        categoryTags: <String>[],
        imageUrls: <String>['https://cdn.example/peer.webp'],
      ),
    );
    expect(likes.chatIconsActive(AppDomainId.jobs, 'peer'), isFalse);

    likes.applyInboundPush(
      domainSlug: 'jobs',
      fromUid: 'peer',
      title: 'Peer',
      photoUrl: 'https://cdn.example/peer2.webp',
      chatReady: true,
    );

    expect(likes.isMutual(AppDomainId.jobs, 'peer'), isTrue);
    expect(likes.chatIconsActive(AppDomainId.jobs, 'peer'), isTrue);
    expect(likes.matchCount, 1);
    expect(likes.inboundCount, 0);
    expect(
      likes.matchEntries(AppDomainId.jobs).single.card?.imageUrls.single,
      'https://cdn.example/peer2.webp',
    );
  });

  test('kuwait_jobs slug maps for push payloads', () {
    final likes = LikesStore(repository: _CaptureLikesRepository());
    likes.applyInboundPush(
      domainSlug: 'kuwait_jobs',
      fromUid: 'peer',
      title: 'Cook',
      photoUrl: 'https://cdn.example/k.webp',
      chatReady: false,
    );
    expect(likes.inbound(AppDomainId.kuwaitJobs), contains('peer'));
    expect(
      likes.inboundEntries(AppDomainId.kuwaitJobs).single.card?.imageUrls,
      isNotEmpty,
    );
  });
}
