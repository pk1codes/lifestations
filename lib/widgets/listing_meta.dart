import 'package:flutter/material.dart';

import '../models/card_side.dart';
import '../models/discovery_card.dart';
import '../theme/app_theme.dart';

/// Shared listing copy: side → title → fact → city.
/// Used on Browse, Likes, and Me so every domain reads the same way.
class ListingMeta extends StatelessWidget {
  const ListingMeta({
    required this.card,
    this.compact = false,
    this.showSide = true,
    this.showCity = true,
    this.titleStyle,
    this.trailing,
    this.contentPadding,
    super.key,
  });

  final DiscoveryCardModel card;
  final bool compact;
  final bool showSide;
  final bool showCity;
  final TextStyle? titleStyle;
  final Widget? trailing;

  /// Pads title / fact / city only — side strip stays edge-to-edge.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final side = showSide ? cardSideMark(card) : null;
    final title = cardTitleLine(card);
    final fact = cardFactLine(card);
    final theme = Theme.of(context);
    final titleTextStyle =
        titleStyle ??
        (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (side != null)
          compact
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    side.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: side.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : ColoredBox(
                  color: side.color.withValues(alpha: .12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (side.side != MarketplaceSide.match) ...[
                          Icon(side.icon, size: 18, color: side.color),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          side.label,
                          style: TextStyle(
                            color: side.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        Padding(
          padding: contentPadding == null
              ? EdgeInsets.only(top: side != null && !compact ? 12 : 0)
              : (contentPadding!).add(
                  EdgeInsets.only(top: side != null && !compact ? 12 : 0),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: titleTextStyle,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ?trailing,
                ],
              ),
              if (fact.trim().isNotEmpty) ...[
                SizedBox(height: compact ? 4 : 6),
                Text(
                  fact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    fontSize: compact ? 13 : null,
                  ),
                ),
              ],
              if (showCity && card.cityLabel.isNotEmpty) ...[
                SizedBox(height: compact ? 4 : 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: compact ? 16 : 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        card.cityLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          fontSize: compact ? 13 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
