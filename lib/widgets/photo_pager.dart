import 'package:flutter/material.dart';

/// Quiet multi-photo pager: swipe + dots when there are 2+ pages.
/// Shared by Browse cards and Likes detail.
class PhotoGalleryPager extends StatefulWidget {
  const PhotoGalleryPager({
    required this.children,
    this.overlay,
    super.key,
  });

  final List<Widget> children;
  final Widget? overlay;

  @override
  State<PhotoGalleryPager> createState() => _PhotoGalleryPagerState();
}

class _PhotoGalleryPagerState extends State<PhotoGalleryPager> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant PhotoGalleryPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.children.length) {
      _index = widget.children.isEmpty ? 0 : widget.children.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.children;
    if (pages.isEmpty) return const SizedBox.expand();
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView(
          onPageChanged: (value) => setState(() => _index = value),
          children: pages,
        ),
        if (widget.overlay != null) widget.overlay!,
        if (pages.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: PhotoPageDots(count: pages.length, index: _index),
            ),
          ),
      ],
    );
  }
}

/// Soft page marks — visible on photos, not loud.
class PhotoPageDots extends StatelessWidget {
  const PhotoPageDots({required this.count, required this.index, super.key});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(count, (i) {
            final active = i == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 7 : 5,
                height: active ? 7 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: active ? 0.95 : 0.45),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Small +N badge for Likes list thumbs when more photos exist.
class PhotoExtraBadge extends StatelessWidget {
  const PhotoExtraBadge({required this.extraCount, super.key});

  final int extraCount;

  @override
  Widget build(BuildContext context) {
    if (extraCount < 1) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          '+$extraCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
