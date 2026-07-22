import 'package:flutter/material.dart';

/// One control to change domain — Google-style apps square (top right).
/// Domain name in the title stays a label only (not a second switcher).
class DomainSwitcherButton extends StatelessWidget {
  const DomainSwitcherButton({
    required this.color,
    required this.onPressed,
    super.key,
  });

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('domain_switcher'),
    tooltip: 'Change',
    onPressed: onPressed,
    icon: Icon(Icons.apps_rounded, color: color),
  );
}

/// Shared app-bar title: where you are + one quiet fact line.
class DomainPageTitle extends StatelessWidget {
  const DomainPageTitle({
    required this.title,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.subtitleKey,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final Key? subtitleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(color: titleColor),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            key: subtitleKey,
            style: theme.textTheme.bodySmall?.copyWith(
              color: subtitleColor,
              fontWeight: subtitleColor != null ? FontWeight.w600 : null,
            ),
          ),
      ],
    );
  }
}
