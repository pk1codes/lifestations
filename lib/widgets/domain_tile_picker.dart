import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/app_domain.dart';
import '../theme/app_theme.dart';

String domainShortLine(AppDomainId id) => switch (id) {
  AppDomainId.marriage => 'Find a life partner',
  AppDomainId.jobs => 'Find work',
  AppDomainId.rooms => 'Find a room',
  AppDomainId.bikes => 'Rent a bike',
  AppDomainId.homeHelp => 'Get help at home',
};

/// Post / offer side — what the user can put up (not browse).
String domainPostLine(AppDomainId id, [AppLocalizations? l10n]) {
  final key = switch (id) {
    AppDomainId.marriage => 'postMarriage',
    AppDomainId.jobs => 'postJobs',
    AppDomainId.rooms => 'postRooms',
    AppDomainId.bikes => 'postBikes',
    AppDomainId.homeHelp => 'postHomeHelp',
  };
  if (l10n != null) return l10n.text(key);
  return const AppLocalizations(Locale('en')).text(key);
}

/// Google apps-launcher: 3-column grid, icon on top, short name under it.
/// Uses [Wrap] + fixed cell height so both rows stay fully visible in sheets.
class DomainTilePicker extends StatelessWidget {
  const DomainTilePicker({
    required this.selected,
    required this.onDomainSelected,
    this.onHighlight,
    super.key,
  });

  final AppDomainId selected;
  final ValueChanged<AppDomainId> onDomainSelected;
  final ValueChanged<AppDomainId>? onHighlight;

  static const icons = <AppDomainId, IconData>{
    AppDomainId.marriage: Icons.favorite,
    AppDomainId.jobs: Icons.work,
    AppDomainId.rooms: Icons.hotel,
    AppDomainId.bikes: Icons.pedal_bike,
    AppDomainId.homeHelp: Icons.cleaning_services,
  };

  /// Icon tile + label — fixed so sheet height is predictable.
  static const cellHeight = 104.0;
  static const crossAxisCount = 3;

  static String shortLabel(AppDomainId id) {
    switch (id) {
      case AppDomainId.homeHelp:
        return 'Help';
      case AppDomainId.marriage:
      case AppDomainId.jobs:
      case AppDomainId.rooms:
      case AppDomainId.bikes:
        return AppDomains.byId(id).label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final domains = AppDomains.all;
    return LayoutBuilder(
      key: const Key('domain_apps_grid'),
      builder: (context, constraints) {
        final gap = 8.0;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final cellW = (maxW - gap * (crossAxisCount - 1)) / crossAxisCount;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final domain in domains)
              SizedBox(
                width: cellW,
                height: cellHeight,
                child: _DomainAppCell(
                  key: Key('domain_tile_${domain.id.name}'),
                  domain: domain,
                  selected: domain.id == selected,
                  icon: icons[domain.id] ?? Icons.circle,
                  label: shortLabel(domain.id),
                  onHighlight: onHighlight == null
                      ? null
                      : () => onHighlight!(domain.id),
                  onTap: () => onDomainSelected(domain.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DomainAppCell extends StatelessWidget {
  const _DomainAppCell({
    required this.domain,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onHighlight,
    super.key,
  });

  final DomainPolicy domain;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onHighlight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onHighlightChanged: (pressed) {
          if (pressed) onHighlight?.call();
        },
        borderRadius: radius,
        enableFeedback: true,
        splashColor: AppTapFeedback.splash,
        highlightColor: AppTapFeedback.highlight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ink paints tile color under the ripple so splash stays visible.
            Ink(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected ? domain.softColor : AppColors.surface,
                borderRadius: radius,
                border: Border.all(
                  color: selected
                      ? domain.color.withValues(alpha: .45)
                      : AppColors.darkCream,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(icon, color: domain.color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
