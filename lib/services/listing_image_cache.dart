import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/discovery_card.dart';
import 'media_urls.dart';

/// Shared on-disk image cache for Browse / Likes / Me (all domains).
class ListingImageCache {
  ListingImageCache._();

  static const key = 'listingImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 400,
    ),
  );

  /// Download listing photos to disk without needing a BuildContext.
  static void warmCards(Iterable<DiscoveryCardModel> cards, {int limit = 12}) {
    var n = 0;
    for (final card in cards) {
      if (n >= limit) break;
      for (final url in card.imageUrls.take(2)) {
        if (n >= limit) break;
        final trimmed = url.trim();
        if (!trimmed.startsWith('http')) continue;
        final primary = MediaUrls.primary(trimmed, FastImageRole.card);
        unawaited(instance.downloadFile(primary).then((_) {}, onError: (_) {}));
        final preview = MediaUrls.preview(trimmed, FastImageRole.card);
        if (preview != null) {
          unawaited(
            instance.downloadFile(preview).then((_) {}, onError: (_) {}),
          );
        }
        n++;
      }
    }
  }
}
