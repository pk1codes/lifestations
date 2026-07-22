import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../models/discovery_card.dart';
import 'listing_image_cache.dart';
import 'media_urls.dart';

/// Intent-based image warm-up so the next cards feel instant.
class ImagePrefetch {
  ImagePrefetch._();

  static final Set<String> _inflight = <String>{};

  /// Warm images around the card the user is looking at.
  /// Prefetches current + [ahead] following cards (thumb + primary).
  static void aroundCards(
    BuildContext context,
    List<DiscoveryCardModel> cards, {
    required int focusIndex,
    int ahead = 2,
  }) {
    if (cards.isEmpty || !context.mounted) return;
    final last = (focusIndex + ahead).clamp(0, cards.length - 1);
    final start = focusIndex.clamp(0, cards.length - 1);
    for (var i = start; i <= last; i++) {
      final urls = cards[i].imageUrls;
      if (urls.isEmpty) continue;
      // First photo: thumb + medium (browse hero).
      warm(context, urls.first, role: FastImageRole.card);
      // Extra photos on the focused card only (user may swipe the pager).
      if (i == focusIndex) {
        for (final url in urls.skip(1).take(3)) {
          warm(context, url, role: FastImageRole.card, primaryOnly: false);
        }
      }
    }
  }

  /// Warm a single URL (and its thumb when useful).
  static void warm(
    BuildContext context,
    String url, {
    FastImageRole role = FastImageRole.card,
    bool primaryOnly = false,
  }) {
    if (!context.mounted) return;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http')) return;

    if (!primaryOnly) {
      final preview = MediaUrls.preview(trimmed, role);
      if (preview != null) _precache(context, preview);
    }
    _precache(context, MediaUrls.primary(trimmed, role));
  }

  static void warmAll(
    BuildContext context,
    Iterable<String> urls, {
    FastImageRole role = FastImageRole.thumb,
  }) {
    for (final url in urls.take(8)) {
      warm(context, url, role: role);
    }
  }

  static void _precache(BuildContext context, String url) {
    if (!_inflight.add(url)) return;
    final provider = CachedNetworkImageProvider(
      url,
      cacheManager: ListingImageCache.instance,
    );
    unawaited(
      precacheImage(provider, context).then(
        (_) {},
        onError: (_) {
          _inflight.remove(url);
        },
      ),
    );
  }
}
