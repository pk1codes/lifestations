import '../models/app_domain.dart';
import '../models/owned_post.dart';
import '../state/domain_profile_stores.dart';
import 'domain_repository.dart';
import 'firebase_bootstrap.dart';
import 'owned_listing_cache.dart';
import 'share_card_repository.dart';

/// Pause / resume / delete for the owner's My posts.
class ListingLifecycleService {
  ListingLifecycleService({
    DomainRepository? repository,
    ShareCardRepository? share,
  }) : _repository = repository ?? FirestoreDomainRepository(),
       _share = share ?? ShareCardRepository();

  final DomainRepository _repository;
  final ShareCardRepository _share;

  Future<void> setPaused({
    required OwnedPost post,
    required bool paused,
    required OwnedListingCache media,
  }) async {
    if (!FirebaseBootstrap.ready) {
      throw StateError('Not connected. Try again.');
    }
    final active = !paused;
    await _repository.setListingActive(
      domain: post.domain,
      listingId: post.card.id,
      active: active,
    );
    await media.setActive(post.domain, active, index: post.offerIndex);
    if (paused) {
      await _share.deactivateForSource(
        domain: post.domain,
        ownerId: post.card.ownerId,
        sourceId: post.card.id,
      );
    } else {
      try {
        await _share.createOrUpdate(post.card.copyWith(active: true));
      } catch (_) {}
    }
  }

  Future<void> deletePost({
    required OwnedPost post,
    required OwnedListingCache media,
    required ProfileStore marriage,
    required JobsOfferStore jobs,
    required KuwaitJobsOfferStore kuwaitJobs,
    required RoomsOfferStore rooms,
    required BikesOfferStore bikes,
    required HomeHelpOfferStore homeHelp,
  }) async {
    if (!FirebaseBootstrap.ready) {
      throw StateError('Not connected. Try again.');
    }
    await _repository.deleteListing(
      domain: post.domain,
      listingId: post.card.id,
    );
    await _share.deactivateForSource(
      domain: post.domain,
      ownerId: post.card.ownerId,
      sourceId: post.card.id,
    );

    switch (post.domain) {
      case AppDomainId.marriage:
        marriage.clearLocal();
        await media.clearProfileSlot(AppDomainId.marriage);
      case AppDomainId.jobs:
        await _deleteOfferSlot(
          domain: AppDomainId.jobs,
          index: post.offerIndex,
          store: jobs,
          media: media,
        );
      case AppDomainId.kuwaitJobs:
        await _deleteOfferSlot(
          domain: AppDomainId.kuwaitJobs,
          index: post.offerIndex,
          store: kuwaitJobs,
          media: media,
        );
      case AppDomainId.rooms:
        await _deleteOfferSlot(
          domain: AppDomainId.rooms,
          index: post.offerIndex,
          store: rooms,
          media: media,
        );
      case AppDomainId.bikes:
        await _deleteOfferSlot(
          domain: AppDomainId.bikes,
          index: post.offerIndex,
          store: bikes,
          media: media,
        );
      case AppDomainId.homeHelp:
        await _deleteOfferSlot(
          domain: AppDomainId.homeHelp,
          index: post.offerIndex,
          store: homeHelp,
          media: media,
        );
    }
  }

  Future<void> _deleteOfferSlot<T>({
    required AppDomainId domain,
    required int? index,
    required MultiOfferStore<T> store,
    required OwnedListingCache media,
  }) async {
    if (index == null || index < 0 || index >= store.offers.length) {
      throw StateError('Could not find that post.');
    }
    store.removeAt(index);
    await media.removeOfferSlot(domain, index);
  }
}
