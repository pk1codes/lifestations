import 'card_side.dart';
import 'discovery_card.dart';

  /// Honest copy for like rows when the peer listing is missing or identity-only.
abstract final class LikeDisplay {
  static const placeholderTitle = 'Liked';
  static const missingListing = 'Listing not ready';
  static const yourPostLabel = 'Your post';
  static const likedByLabel = 'Liked by';
  static const noPhotoYet = 'No photo';
  static const matchSectionTitle = 'Match';

  static bool isPlaceholderTitle(String title) {
    final t = title.trim();
    return t.isEmpty ||
        t == 'Someone' ||
        t == 'Liked post' ||
        t == placeholderTitle;
  }

  static bool isPlaceholderCard(DiscoveryCardModel? card) {
    if (card == null) return true;
    return isPlaceholderTitle(card.title) ||
        card.attributes['identityOnly'] == true;
  }

  static String rowTitle(DiscoveryCardModel? card) {
    if (card == null) return placeholderTitle;
    if (!isPlaceholderCard(card)) return cardTitleLine(card);
    final raw = card.title.trim();
    if (raw.isNotEmpty && !isPlaceholderTitle(raw)) {
      return cardTitleLine(card);
    }
    return placeholderTitle;
  }
}

/// Consent-to-chat copy (all domains). Same words everywhere — not a second ♥.
abstract final class LikeConsent {
  /// Liked-me primary action: unlock mutual chat path.
  static const acceptCta = 'Accept — chat';
  static const acceptingCta = 'Accepting…';

  static const mutualDetail = 'Both interested — WhatsApp';
  static const inboundHint = 'They liked you — Accept to chat';
  static const outboundWaiting = 'Waiting for them';

  static const listMutual = 'Both interested';
  static const listWaiting = 'Waiting';

  static const removeTooltip = 'Remove';
  static const deleteMatchTooltip = 'Delete';
  static const removedSnack = 'Removed';
  static const matchRemovedSnack = 'Match removed';
  static const undo = 'Undo';

  static const acceptFirst = 'Accept first to unlock chat';
  static const acceptFailed = 'Could not accept. Try again.';
  static const mutualSnack = 'Both interested — WhatsApp';
  static const bothNeeded = 'Both must be interested';
}
