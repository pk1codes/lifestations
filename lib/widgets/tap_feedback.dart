import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared Material press surface — use for custom tappable rows/tiles.
/// Prefer standard buttons/chips/ListTiles elsewhere; they inherit [buildTheme].
class AppInkWell extends StatelessWidget {
  const AppInkWell({
    required this.child,
    this.onTap,
    this.onHighlightChanged,
    this.borderRadius,
    this.color,
    this.padding,
    super.key,
  });

  static final BorderRadius defaultRadius = BorderRadius.circular(16);

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHighlightChanged;
  final BorderRadius? borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? defaultRadius;
    return Material(
      color: color ?? Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        onHighlightChanged: onHighlightChanged,
        borderRadius: radius,
        enableFeedback: true,
        splashColor: AppTapFeedback.splash,
        highlightColor: AppTapFeedback.highlight,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
