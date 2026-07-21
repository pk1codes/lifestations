import '../models/app_domain.dart';
import '../models/domain_profiles.dart';
import '../models/owned_post.dart';
import '../state/domain_profile_stores.dart';
import 'listing_publisher.dart';
import 'owned_listing_cache.dart';

/// Builds the owner's My posts list from local profile/offer stores.
List<OwnedPost> collectOwnedPosts({
  required String ownerId,
  required ProfileStore marriage,
  required JobsProfileStore jobs,
  required RoomsOfferStore rooms,
  required BikesOfferStore bikes,
  required HomeHelpOfferStore homeHelp,
  required OwnedListingCache media,
  ListingPublisher? publisher,
}) {
  final cards = publisher ?? ListingPublisher();
  final out = <OwnedPost>[];

  final marriageProfile = marriage.value;
  if (marriageProfile != null) {
    out.add(
      OwnedPost(
        domain: AppDomainId.marriage,
        card: cards
            .buildMarriageCard(
              ownerId: ownerId,
              profile: marriageProfile,
              photoUrls: media.photos(AppDomainId.marriage),
            )
            .copyWith(active: media.isActive(AppDomainId.marriage)),
      ),
    );
  }

  final jobsProfile = jobs.value;
  if (jobsProfile != null) {
    out.add(
      OwnedPost(
        domain: AppDomainId.jobs,
        card: cards
            .buildJobsCard(
              ownerId: ownerId,
              profile: jobsProfile,
              photoUrls: media.photos(AppDomainId.jobs),
            )
            .copyWith(active: media.isActive(AppDomainId.jobs)),
      ),
    );
  }

  for (var i = 0; i < rooms.offers.length; i++) {
    out.add(
      OwnedPost(
        domain: AppDomainId.rooms,
        offerIndex: i,
        card: cards
            .buildRoomsCard(
              ownerId: ownerId,
              offer: rooms.offers[i],
              offerId: media.offerId(AppDomainId.rooms, i),
              photoUrls: media.photos(AppDomainId.rooms, i),
            )
            .copyWith(active: media.isActive(AppDomainId.rooms, i)),
      ),
    );
  }

  for (var i = 0; i < bikes.offers.length; i++) {
    out.add(
      OwnedPost(
        domain: AppDomainId.bikes,
        offerIndex: i,
        card: cards
            .buildBikesCard(
              ownerId: ownerId,
              offer: bikes.offers[i],
              offerId: media.offerId(AppDomainId.bikes, i),
              photoUrls: media.photos(AppDomainId.bikes, i),
            )
            .copyWith(active: media.isActive(AppDomainId.bikes, i)),
      ),
    );
  }

  for (var i = 0; i < homeHelp.offers.length; i++) {
    out.add(
      OwnedPost(
        domain: AppDomainId.homeHelp,
        offerIndex: i,
        card: cards
            .buildHomeHelpCard(
              ownerId: ownerId,
              offer: homeHelp.offers[i],
              offerId: media.offerId(AppDomainId.homeHelp, i),
              photoUrls: media.photos(AppDomainId.homeHelp, i),
            )
            .copyWith(active: media.isActive(AppDomainId.homeHelp, i)),
      ),
    );
  }

  return out;
}

RoomsOffer? roomsFromOwned(OwnedPost post, RoomsOfferStore store) {
  final index = post.offerIndex;
  if (post.domain != AppDomainId.rooms || index == null) return null;
  if (index < 0 || index >= store.offers.length) return null;
  return store.offers[index];
}

BikesOffer? bikesFromOwned(OwnedPost post, BikesOfferStore store) {
  final index = post.offerIndex;
  if (post.domain != AppDomainId.bikes || index == null) return null;
  if (index < 0 || index >= store.offers.length) return null;
  return store.offers[index];
}

HomeHelpOffer? homeHelpFromOwned(OwnedPost post, HomeHelpOfferStore store) {
  final index = post.offerIndex;
  if (post.domain != AppDomainId.homeHelp || index == null) return null;
  if (index < 0 || index >= store.offers.length) return null;
  return store.offers[index];
}
