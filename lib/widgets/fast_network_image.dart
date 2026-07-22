import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/listing_image_cache.dart';
import '../services/media_urls.dart';
import '../theme/app_theme.dart';
import 'image_skeleton.dart';

/// Fast photo tile: soft placeholder → optional thumb → sharp primary, with
/// disk/memory cache and decode sized to the screen (not full bitmap).
class FastNetworkImage extends StatelessWidget {
  const FastNetworkImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.role = FastImageRole.card,
    this.fallback,
    this.placeholderColor,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final FastImageRole role;
  final Widget? fallback;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return fallback ?? ImageSkeleton(color: placeholderColor);
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return Image.asset(
        trimmed,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) =>
            fallback ?? ImageSkeleton(color: placeholderColor),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final memW = _memCacheWidth(role, screenW, dpr);
    final previewUrl = MediaUrls.preview(trimmed, role);
    final primaryUrl = MediaUrls.primary(trimmed, role);
    final fill = placeholderColor ?? AppColors.darkCream;
    final error = fallback ?? ImageSkeleton(color: fill);
    final skeleton = ImageSkeleton(color: fill);

    return ColoredBox(
      color: fill,
      child: Stack(
        fit: StackFit.expand,
        children: [
          skeleton,
          if (previewUrl != null)
            CachedNetworkImage(
              imageUrl: previewUrl,
              cacheManager: ListingImageCache.instance,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth: memW ~/ 3,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          CachedNetworkImage(
            imageUrl: primaryUrl,
            cacheManager: ListingImageCache.instance,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: Duration.zero,
            memCacheWidth: memW,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => error,
          ),
        ],
      ),
    );
  }

  static int _memCacheWidth(FastImageRole role, double screenW, double dpr) {
    switch (role) {
      case FastImageRole.thumb:
        return (96 * dpr).round().clamp(64, 256);
      case FastImageRole.card:
        return (screenW * dpr).round().clamp(320, 1200);
      case FastImageRole.detail:
        return (screenW * dpr).round().clamp(480, 1600);
    }
  }
}
