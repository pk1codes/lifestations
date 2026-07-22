import 'app_domain.dart';
import 'discovery_card.dart';

/// One of the signed-in user's published posts (profile or multi-offer slot).
class OwnedPost {
  const OwnedPost({required this.domain, required this.card, this.offerIndex});

  final AppDomainId domain;
  final DiscoveryCardModel card;

  /// Index in the domain's multi-offer store; null for Marriage / Jobs.
  final int? offerIndex;

  bool get isOffer => offerIndex != null;

  /// Hidden from Browse; still shown in My posts.
  bool get paused => !card.active;

  OwnedPost copyWith({
    AppDomainId? domain,
    DiscoveryCardModel? card,
    int? offerIndex,
  }) => OwnedPost(
    domain: domain ?? this.domain,
    card: card ?? this.card,
    offerIndex: offerIndex ?? this.offerIndex,
  );
}
