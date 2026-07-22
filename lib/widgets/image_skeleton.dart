import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft pulsing block used while network images load.
class ImageSkeleton extends StatefulWidget {
  const ImageSkeleton({this.color, super.key});

  final Color? color;

  @override
  State<ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<ImageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? AppColors.darkCream;
    if (MediaQuery.disableAnimationsOf(context)) {
      return ColoredBox(color: base);
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return ColoredBox(
          color: Color.lerp(base, Colors.white, 0.18 + t * 0.22)!,
        );
      },
    );
  }
}
