import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/app_domain.dart';
import '../models/card_side.dart';
import '../models/discovery_card.dart';
import '../models/domain_profiles.dart';
import '../models/owned_post.dart';
import '../services/account_services.dart';
import 'legal_screens.dart';
import '../services/contact_service.dart';
import '../services/firebase_bootstrap.dart';
import '../services/form_media_controller.dart';
import '../services/likes_repository.dart';
import '../services/listing_publisher.dart';
import '../services/owned_hydrate.dart';
import '../services/owned_listing_cache.dart';
import '../services/owned_posts.dart';
import '../services/push_service.dart';
import '../services/refresh_boost_service.dart';
import '../services/share_service.dart';
import '../state/app_stores.dart';
import '../state/domain_profile_stores.dart';
import '../theme/app_theme.dart';
import '../widgets/forms/bikes_form.dart';
import '../widgets/forms/home_help_form.dart';
import '../widgets/forms/jobs_form.dart';
import '../widgets/forms/marriage_form.dart';
import '../widgets/domain_sphere_selector.dart';
import '../widgets/forms/rooms_form.dart';
import '../widgets/forms/photo_source_sheet.dart';
import '../widgets/onboarding/otp_sheet.dart';
import '../widgets/photo_pager.dart';
import '../widgets/safety/safety_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_hydrateSession());
      final controller = context.read<DomainController>();
      if (!controller.shouldShowCoachMark) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hold the radio button to change Marriage, Jobs, Rooms…'),
          duration: Duration(seconds: 8),
          showCloseIcon: true,
        ),
      );
      unawaited(controller.markCoachSeen());
    });
  }

  Future<void> _hydrateSession() async {
    if (!FirebaseBootstrap.ready || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final identity = context.read<IdentityStore>();
    final blocks = context.read<BlockStore>();
    final likes = context.read<LikesStore>();
    await identity.bindUserId(uid);
    if (!mounted) return;
    await identity.hydrateRemote();
    if (!mounted) return;
    await blocks.hydrateRemote();
    if (!mounted) return;
    await likes.hydrateAll();
    await PushService().initialize(uid: uid);
    if (!mounted) return;
    await hydrateOwnedListings(
      ownerId: uid,
      media: context.read<OwnedListingCache>(),
      marriage: context.read<ProfileStore>(),
      jobs: context.read<JobsProfileStore>(),
      rooms: context.read<RoomsOfferStore>(),
      bikes: context.read<BikesOfferStore>(),
      homeHelp: context.read<HomeHelpOfferStore>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DomainController>();
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pages = <Widget>[
      const DiscoverScreen(),
      const LikesScreen(),
      const MeScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: IndexedStack(
              index: controller.selectedTab,
              children: [
                for (var i = 0; i < pages.length; i++)
                  _TabEntrance(
                    active: controller.selectedTab == i,
                    reduceMotion: reduceMotion,
                    child: pages[i],
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.selectedTab,
        onDestinationSelected: controller.selectTab,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: GestureDetector(
              key: const Key('domain_tuner'),
              onLongPress: () => showDomainDial(context),
              child: const Tooltip(
                message: 'Hold to change Marriage, Jobs, Rooms…',
                child: Icon(Icons.radio),
              ),
            ),
            selectedIcon: GestureDetector(
              onLongPress: () => showDomainDial(context),
              child: Icon(Icons.radio, color: controller.policy.color),
            ),
            label: l10n.text('browse'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.text('likes'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.text('me'),
          ),
        ],
      ),
    );
  }
}

/// Subtle fade + rise when a bottom tab becomes active.
class _TabEntrance extends StatefulWidget {
  const _TabEntrance({
    required this.active,
    required this.reduceMotion,
    required this.child,
  });

  final bool active;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<_TabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.018),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      if (widget.reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _TabEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (widget.reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

Future<void> showDomainDial(BuildContext context) async {
  final controller = context.read<DomainController>();
  unawaited(AudioPlayer().play(AssetSource('audio/rotary.wav'), volume: .35));
  var front = AppDomains.byId(controller.selected);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: front.softSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              front.color.withValues(alpha: .18),
              front.softSurface,
              AppColors.cream,
            ],
            stops: const [0, 0.35, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a world',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text('Same account. Five worlds.'),
                const SizedBox(height: 8),
                Center(
                  child: DomainSphereSelector(
                    selected: controller.selected,
                    onFrontDomainChanged: (id) {
                      final next = AppDomains.byId(id);
                      if (next.id == front.id) return;
                      setSheetState(() => front = next);
                    },
                    onDomainSelected: (id) {
                      controller.selectDomain(id);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final domain = context.watch<DomainController>().policy;
    final store = context.watch<DiscoveryStore>();
    if (!domain.enabled) return ComingSoonView(domain: domain);
    final cards = domain.id == AppDomainId.jobs
        ? () {
            final prefs = context.watch<JobsDiscoverPrefsStore>();
            return store.filtered(
              cityId: prefs.cityId,
              role: prefs.role,
              tradeId: prefs.tradeId,
            );
          }()
        : () {
            final prefs = context.watch<MatchPreferencesStore>();
            return store.filtered(
              cityId: prefs.cityId,
              gender: domain.id == AppDomainId.marriage ? prefs.gender : null,
              ageBand: domain.id == AppDomainId.marriage ? prefs.ageBand : null,
            );
          }();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: domain.softSurface.withValues(alpha: .96),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _domainIcons[domain.id],
                    color: domain.color,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    domain.label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: domain.color,
                    ),
                  ),
                ],
              ),
              Text(
                '${cards.length} nearby',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Filters',
              onPressed: () => _showFilters(context, domain),
              icon: Icon(Icons.tune, color: domain.color),
            ),
          ],
        ),
        if (cards.isEmpty)
          SliverFillRemaining(child: _EmptyFeed(onReset: store.reset))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList.separated(
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 18),
              itemBuilder: (context, index) => DiscoveryCard(
                card: cards[index],
                onPass: () => store.action(cards[index].id),
                onLike: () async {
                  final card = cards[index];
                  final mutual = context.read<LikesStore>().like(
                    domain.id,
                    card.ownerId,
                    snapshot: card,
                  );
                  store.action(card.id);
                  if (mutual) _showMatch(context, card);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class DiscoveryCard extends StatelessWidget {
  const DiscoveryCard({
    required this.card,
    required this.onPass,
    required this.onLike,
    super.key,
  });

  final DiscoveryCardModel card;
  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final side = cardSideMark(card);
    final fact = cardFactLine(card);
    final l10n = AppLocalizations.of(context);
    final domainColor = AppDomains.byId(card.domain).color;
    return Dismissible(
      key: ValueKey(card.id),
      background: _swipeBackground(
        Alignment.centerLeft,
        Icons.favorite,
        domainColor,
      ),
      secondaryBackground: _swipeBackground(
        Alignment.centerRight,
        Icons.close,
        AppColors.muted,
      ),
      confirmDismiss: (direction) async {
        direction == DismissDirection.startToEnd ? onLike() : onPass();
        return true;
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: domainColor, width: 5),
            ),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: PhotoGalleryPager(
                overlay: card.promoted
                    ? Positioned(
                        right: 12,
                        top: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text(
                              'Top',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
                children: card.imageUrls.isEmpty
                    ? <Widget>[
                        _SyntheticArtwork(
                          label: card.title,
                          seed: card.id.hashCode,
                        ),
                      ]
                    : card.imageUrls
                          .map(
                            (url) => _BrowsePhoto(
                              url: url,
                              label: card.title,
                              seed: card.id.hashCode,
                            ),
                          )
                          .toList(growable: false),
              ),
            ),
            if (side != null)
              ColoredBox(
                color: side.color.withValues(alpha: .12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(side.icon, size: 18, color: side.color),
                      const SizedBox(width: 8),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          card.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l10n.text('more'),
                        onSelected: (value) async {
                          if (value == 'share') {
                            await _share(context);
                          } else if (value == 'safety') {
                            await showSafetySheet(
                              context,
                              domain: card.domain,
                              targetId: card.id,
                              ownerId: card.ownerId,
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'share',
                            child: Text(l10n.text('share')),
                          ),
                          PopupMenuItem(
                            value: 'safety',
                            child: Text(l10n.text('safety')),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                  if (fact.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      fact,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          card.cityLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundAction(
                        key: const Key('skip_button'),
                        tooltip: l10n.text('pass'),
                        icon: Icons.close,
                        color: AppColors.muted,
                        filled: false,
                        compact: true,
                        onPressed: onPass,
                      ),
                      const SizedBox(width: 10),
                      _RoundAction(
                        key: const Key('interested_button'),
                        tooltip: l10n.text('like'),
                        icon: Icons.favorite,
                        color: domainColor,
                        filled: true,
                        compact: true,
                        onPressed: onLike,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    try {
      await context.read<ShareService>().shareCard(card);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create a safe share link.')),
      );
    }
  }

  Widget _swipeBackground(Alignment alignment, IconData icon, Color color) =>
      Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 36),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 42),
      );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 26.0 : 34.0;
    final padding = compact ? 12.0 : 16.0;
    final button = filled
        ? IconButton.filled(
            onPressed: onPressed,
            icon: Icon(icon),
            iconSize: iconSize,
            padding: EdgeInsets.all(padding),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          )
        : IconButton.outlined(
            onPressed: onPressed,
            icon: Icon(icon),
            iconSize: iconSize,
            padding: EdgeInsets.all(padding),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 2),
            ),
          );
    return Tooltip(message: tooltip, child: button);
  }
}

class _BrowsePhoto extends StatelessWidget {
  const _BrowsePhoto({
    required this.url,
    required this.label,
    required this.seed,
  });

  final String url;
  final String label;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final fallback = _SyntheticArtwork(label: label, seed: seed);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
  }
}

class _SyntheticArtwork extends StatelessWidget {
  const _SyntheticArtwork({required this.label, required this.seed});
  final String label;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[seed.abs() % Colors.primaries.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.shade100, color.shade400],
        ),
      ),
      child: Center(
        child: Icon(Icons.auto_awesome, size: 72, color: color.shade800),
      ),
    );
  }
}

class ComingSoonView extends StatelessWidget {
  const ComingSoonView({required this.domain, super.key});
  final DomainPolicy domain;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: domain.softColor,
          child: Icon(
            Icons.construction_rounded,
            size: 44,
            color: domain.color,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${domain.label} is tuning up',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'The listing foundation is ready. Public discovery will open after safety and local supply checks.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.tonal(
          onPressed: () {},
          child: const Text('Join the waitlist'),
        ),
      ],
    ),
  );
}

class LikesScreen extends StatelessWidget {
  const LikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final likes = context.watch<LikesStore>();
    final empty = likes.outboundCount == 0 && likes.inboundCount == 0;
    return _Page(
      title: 'Likes',
      child: empty
          ? const _InfoCard(
              icon: Icons.favorite_outline,
              title: 'No likes yet',
              body: 'Tap ♥ on Browse. Your likes show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LikesSection(
                  title: 'I liked',
                  count: likes.outboundCount,
                  icon: Icons.favorite,
                  entriesFor: likes.outboundEntries,
                  likes: likes,
                ),
                const SizedBox(height: 16),
                _LikesSection(
                  title: 'Liked me',
                  count: likes.inboundCount,
                  icon: Icons.favorite_border,
                  entriesFor: likes.inboundEntries,
                  likes: likes,
                ),
              ],
            ),
    );
  }
}

class _LikesSection extends StatelessWidget {
  const _LikesSection({
    required this.title,
    required this.count,
    required this.icon,
    required this.entriesFor,
    required this.likes,
  });

  final String title;
  final int count;
  final IconData icon;
  final List<LikeEntry> Function(AppDomainId domain) entriesFor;
  final LikesStore likes;

  @override
  Widget build(BuildContext context) {
    final domainsWithLikes = AppDomains.all
        .where((policy) => entriesFor(policy.id).isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.rose),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.darkCream,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (domainsWithLikes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('None yet'),
          )
        else
          ...domainsWithLikes.map((policy) {
            final entries = entriesFor(policy.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  leading: CircleAvatar(
                    backgroundColor: policy.softColor,
                    child: Icon(
                      _domainIcons[policy.id],
                      color: policy.color,
                      size: 22,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          policy.label,
                          style: TextStyle(
                            color: policy.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: policy.softColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${entries.length}',
                          style: TextStyle(
                            color: policy.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LikeRow(
                            entry: entry,
                            mutual: likes.isMutual(
                              entry.domain,
                              entry.otherUid,
                            ),
                            onOpen: () => _showLikeDetail(context, entry),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _LikeRow extends StatelessWidget {
  const _LikeRow({
    required this.entry,
    required this.mutual,
    required this.onOpen,
  });

  final LikeEntry entry;
  final bool mutual;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final card = entry.card;
    final title = card?.title ?? 'Liked post';
    final city = card?.cityLabel ?? '';
    final photo = card?.imageUrls.isNotEmpty == true
        ? card!.imageUrls.first
        : null;
    final policy = AppDomains.byId(entry.domain);
    return Material(
      color: policy.softColor.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: photo == null
                      ? _SyntheticArtwork(
                          label: title,
                          seed: entry.otherUid.hashCode,
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            _LikePhoto(
                              url: photo,
                              label: title,
                              seed: entry.otherUid.hashCode,
                            ),
                            if ((card?.imageUrls.length ?? 0) > 1)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: PhotoExtraBadge(
                                  extraCount: card!.imageUrls.length - 1,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          mutual ? Icons.lock_open : Icons.lock_outline,
                          size: 16,
                          color: mutual
                              ? CardSideMark.supplyColor
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mutual ? 'Both interested' : 'Waiting',
                          style: TextStyle(
                            color: mutual
                                ? CardSideMark.supplyColor
                                : AppColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikePhoto extends StatelessWidget {
  const _LikePhoto({
    required this.url,
    required this.label,
    required this.seed,
  });

  final String url;
  final String label;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final fallback = _SyntheticArtwork(label: label, seed: seed);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

Future<void> _showLikeDetail(BuildContext context, LikeEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _LikeDetailSheet(entry: entry),
  );
}

class _LikeDetailSheet extends StatefulWidget {
  const _LikeDetailSheet({required this.entry});

  final LikeEntry entry;

  @override
  State<_LikeDetailSheet> createState() => _LikeDetailSheetState();
}

class _LikeDetailSheetState extends State<_LikeDetailSheet> {
  PrivateContact? _contact;
  bool _unlocking = false;

  LikeEntry get entry => widget.entry;

  Future<PrivateContact?> _ensureContact() async {
    if (_contact != null) return _contact;
    final identity = context.read<IdentityStore>();
    final likes = context.read<LikesStore>();
    if (!likes.isMutual(entry.domain, entry.otherUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both must be interested')),
      );
      return null;
    }
    if (!identity.identity.phoneVerified) {
      final ok = await showOtpSheet(context);
      if (!ok || !mounted) return null;
    }
    setState(() => _unlocking = true);
    try {
      final contact = await ContactService().unlock(
        domain: entry.domain,
        targetUid: entry.otherUid,
      );
      if (!mounted) return null;
      if (contact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone not ready yet')),
        );
        return null;
      }
      setState(() => _contact = contact);
      return contact;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check phone first')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _openWhatsApp() async {
    final contact = await _ensureContact();
    if (contact == null) return;
    await ContactService().openWhatsApp(contact.whatsappNumber);
  }

  Future<void> _openTelegram() async {
    final contact = await _ensureContact();
    if (contact == null) return;
    final handle = contact.telegramHandle?.trim() ?? '';
    if (handle.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Telegram yet')),
      );
      return;
    }
    await ContactService().openTelegram(handle);
  }

  @override
  Widget build(BuildContext context) {
    final likes = context.watch<LikesStore>();
    final policy = AppDomains.byId(entry.domain);
    final mutual = likes.isMutual(entry.domain, entry.otherUid);
    final card = entry.card;
    final title = card?.title ?? 'Liked post';
    final fact = card == null ? '' : cardFactLine(card);
    final photos = card?.imageUrls ?? const <String>[];
    final side = card == null ? null : cardSideMark(card);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: policy.color, width: 4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: policy.softColor,
                    child: Icon(
                      _domainIcons[policy.id],
                      color: policy.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    policy.label,
                    style: TextStyle(
                      color: policy.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Safety',
                    onPressed: () => showSafetySheet(
                      context,
                      domain: entry.domain,
                      targetId: entry.otherUid,
                      ownerId: entry.otherUid,
                    ),
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: photos.isEmpty
                      ? _SyntheticArtwork(
                          label: title,
                          seed: entry.otherUid.hashCode,
                        )
                      : PhotoGalleryPager(
                          children: photos
                              .map(
                                (url) => _LikePhoto(
                                  url: url,
                                  label: title,
                                  seed: entry.otherUid.hashCode,
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
              ),
              if (side != null) ...[
                const SizedBox(height: 12),
                ColoredBox(
                  color: side.color.withValues(alpha: .12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(side.icon, size: 18, color: side.color),
                        const SizedBox(width: 8),
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
              ],
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (fact.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(fact),
              ],
              if (card?.cityLabel.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      card!.cityLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                mutual ? 'Both interested — chat' : 'Waiting for them',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: mutual ? CardSideMark.supplyColor : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ContactActionButton(
                      label: 'WhatsApp',
                      icon: Icons.chat,
                      color: const Color(0xFF25D366),
                      enabled: mutual && !_unlocking,
                      locked: !mutual,
                      busy: _unlocking,
                      onPressed: _openWhatsApp,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ContactActionButton(
                      label: 'Telegram',
                      icon: Icons.send,
                      color: const Color(0xFF229ED9),
                      enabled: mutual && !_unlocking,
                      locked: !mutual,
                      busy: _unlocking,
                      onPressed: _openTelegram,
                    ),
                  ),
                ],
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.locked,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool locked;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final faded = locked || !enabled;
    return OutlinedButton.icon(
      onPressed: faded
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    locked ? 'Both must be interested' : 'Please wait…',
                  ),
                ),
              );
            }
          : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: faded ? AppColors.muted : color,
        side: BorderSide(color: faded ? AppColors.muted : color),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: faded ? AppColors.muted : color,
              ),
            )
          : Icon(locked ? Icons.lock_outline : icon),
      label: Text(label),
    );
  }
}

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityStore>();
    final posted = _postedDomains(context);
    final photoUrl = identity.identity.photoUrls.isNotEmpty
        ? identity.identity.photoUrls.first
        : null;
    return _Page(
      title: 'Me',
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: () => _showSettings(context),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MeActionCard(
            accent: identity.completed ? AppColors.rose : AppColors.muted,
            onTap: () => showIdentityForm(context),
            leading: _IdentityAvatar(photoUrl: photoUrl),
            title: identity.completed
                ? identity.identity.displayName
                : 'Add my details',
            subtitle: identity.completed
                ? identity.identity.cityLabel
                : 'Name, phone & city',
            trailing: identity.completed && identity.identity.phoneVerified
                ? const Icon(Icons.verified, color: AppColors.rose, size: 22)
                : null,
          ),
          const SizedBox(height: 16),
          _MeActionCard(
            accent: posted.isEmpty ? AppColors.muted : posted.first.color,
            footerColors: posted.map((domain) => domain.color).toList(growable: false),
            onTap: () {
              if (posted.isEmpty) {
                _showNewPostPicker(context);
              } else {
                _showMyPostsSheet(context);
              }
            },
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.darkCream,
              child: Icon(
                posted.isEmpty ? Icons.campaign_outlined : Icons.check_circle,
                color: posted.isEmpty ? AppColors.muted : posted.first.color,
              ),
            ),
            title: 'My posts',
            subtitle: posted.isEmpty
                ? 'Add your first post'
                : '${_totalPostCount(context)} posted',
          ),
        ],
      ),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({this.photoUrl});

  final String? photoUrl;
  static const double _radius = 32;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    final hasPhoto = url.startsWith('http');
    if (!hasPhoto) {
      return CircleAvatar(
        radius: _radius,
        backgroundColor: AppColors.darkCream,
        child: Icon(
          Icons.person_outline,
          size: _radius * 0.9,
          color: AppColors.muted,
        ),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: _radius * 2,
        height: _radius * 2,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CircleAvatar(
            radius: _radius,
            backgroundColor: AppColors.darkCream,
            child: Icon(
              Icons.person_outline,
              size: _radius * 0.9,
              color: AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeActionCard extends StatelessWidget {
  const _MeActionCard({
    required this.accent,
    required this.onTap,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.footerColors = const <Color>[],
  });

  final Color accent;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Color> footerColors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 16, 18),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              if (footerColors.isNotEmpty)
                SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      for (final color in footerColors)
                        Expanded(child: ColoredBox(color: color)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _watchPostStores(BuildContext context) {
  context.watch<ProfileStore>();
  context.watch<JobsProfileStore>();
  context.watch<RoomsOfferStore>();
  context.watch<BikesOfferStore>();
  context.watch<HomeHelpOfferStore>();
  context.watch<OwnedListingCache>();
}

String _ownerUid(BuildContext context) {
  final identity = context.read<IdentityStore>();
  if (identity.identity.userId.isNotEmpty) return identity.identity.userId;
  if (FirebaseBootstrap.ready) {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) return authUid;
  }
  return 'local';
}

List<OwnedPost> _ownedPosts(BuildContext context) {
  _watchPostStores(context);
  return collectOwnedPosts(
    ownerId: _ownerUid(context),
    marriage: context.read<ProfileStore>(),
    jobs: context.read<JobsProfileStore>(),
    rooms: context.read<RoomsOfferStore>(),
    bikes: context.read<BikesOfferStore>(),
    homeHelp: context.read<HomeHelpOfferStore>(),
    media: context.read<OwnedListingCache>(),
    publisher: context.read<ListingPublisher>(),
  );
}

List<DomainPolicy> _postedDomains(BuildContext context) {
  _watchPostStores(context);
  return AppDomains.all
      .where((domain) => domain.enabled && _domainPostCount(context, domain.id) > 0)
      .toList(growable: false);
}

int _totalPostCount(BuildContext context) {
  _watchPostStores(context);
  return AppDomainId.values.fold<int>(
    0,
    (sum, id) => sum + _domainPostCount(context, id),
  );
}

int _domainPostCount(BuildContext context, AppDomainId id) {
  switch (id) {
    case AppDomainId.marriage:
      return context.read<ProfileStore>().value != null ? 1 : 0;
    case AppDomainId.jobs:
      return context.read<JobsProfileStore>().value != null ? 1 : 0;
    case AppDomainId.rooms:
      return context.read<RoomsOfferStore>().offers.length;
    case AppDomainId.bikes:
      return context.read<BikesOfferStore>().offers.length;
    case AppDomainId.homeHelp:
      return context.read<HomeHelpOfferStore>().offers.length;
  }
}

/// True until the domain's [DomainPolicy.maxProfiles] cap is reached.
bool _domainCanAddPost(BuildContext context, AppDomainId id) {
  final policy = AppDomains.byId(id);
  return _domainPostCount(context, id) < policy.maxProfiles;
}

String _domainPostSubtitle(BuildContext context, DomainPolicy domain) {
  final l10n = AppLocalizations.of(context);
  final action = domainPostLine(domain.id, l10n);
  final count = _domainPostCount(context, domain.id);
  final max = domain.maxProfiles;
  if (max <= 1) return action;
  if (count <= 0) return action;
  return '$count of $max · $action';
}

Future<void> _showMyPostsSheet(BuildContext context) async {
  // Open immediately from local cache; refresh remote in the background.
  final uid = _ownerUid(context);
  unawaited(
    hydrateOwnedListings(
      ownerId: uid,
      media: context.read<OwnedListingCache>(),
      marriage: context.read<ProfileStore>(),
      jobs: context.read<JobsProfileStore>(),
      rooms: context.read<RoomsOfferStore>(),
      bikes: context.read<BikesOfferStore>(),
      homeHelp: context.read<HomeHelpOfferStore>(),
    ),
  );
  if (!context.mounted) return;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final posts = _ownedPosts(sheetContext);
      final canPostMore = AppDomains.all.any(
        (domain) =>
            domain.enabled && _domainCanAddPost(sheetContext, domain.id),
      );
      final hasAds = posts.isNotEmpty;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'My posts',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (posts.isEmpty)
                Text(
                  'No posts yet',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: posts
                        .map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _OwnedPostRow(
                              post: post,
                              onOpen: () =>
                                  _showOwnedPostDetail(sheetContext, post),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              if (canPostMore)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.darkCream,
                    child: Icon(
                      Icons.add_circle_outline,
                      color: AppColors.rose,
                    ),
                  ),
                  title: Text(posts.isEmpty ? 'New post' : 'Add another'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showNewPostPicker(context);
                  },
                ),
              if (hasAds) ...[
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.darkCream,
                    child: Icon(Icons.trending_up, color: AppColors.rose),
                  ),
                  title: const Text('Get more views'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showGrowthSheet(context);
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showOwnedPostDetail(BuildContext context, OwnedPost post) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _OwnedPostDetailSheet(
      post: post,
      hostContext: context,
    ),
  );
}

class _OwnedPostRow extends StatelessWidget {
  const _OwnedPostRow({required this.post, required this.onOpen});

  final OwnedPost post;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final card = post.card;
    final title = card.title;
    final city = card.cityLabel;
    final photo = card.imageUrls.isNotEmpty ? card.imageUrls.first : null;
    final policy = AppDomains.byId(post.domain);
    return Material(
      color: policy.softColor.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: photo == null
                      ? _SyntheticArtwork(
                          label: title,
                          seed: card.id.hashCode,
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            _LikePhoto(
                              url: photo,
                              label: title,
                              seed: card.id.hashCode,
                            ),
                            if (card.imageUrls.length > 1)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: PhotoExtraBadge(
                                  extraCount: card.imageUrls.length - 1,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      policy.label,
                      style: TextStyle(
                        color: policy.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: policy.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnedPostDetailSheet extends StatelessWidget {
  const _OwnedPostDetailSheet({
    required this.post,
    required this.hostContext,
  });

  final OwnedPost post;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final policy = AppDomains.byId(post.domain);
    final card = post.card;
    final title = card.title;
    final fact = cardFactLine(card);
    final photos = card.imageUrls;
    final side = cardSideMark(card);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: policy.color, width: 4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: policy.softColor,
                        child: Icon(
                          _domainIcons[policy.id],
                          color: policy.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        policy.label,
                        style: TextStyle(
                          color: policy.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: photos.isEmpty
                          ? _SyntheticArtwork(
                              label: title,
                              seed: card.id.hashCode,
                            )
                          : PhotoGalleryPager(
                              children: photos
                                  .map(
                                    (url) => _LikePhoto(
                                      url: url,
                                      label: title,
                                      seed: card.id.hashCode,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                  ),
                  if (side != null) ...[
                    const SizedBox(height: 12),
                    ColoredBox(
                      color: side.color.withValues(alpha: .12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(side.icon, size: 18, color: side.color),
                            const SizedBox(width: 8),
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
                  ],
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  if (fact.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(fact),
                  ],
                  if (card.cityLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          card.cityLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: policy.color,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      showDomainProfileForm(
                        hostContext,
                        policy,
                        edit: post,
                      );
                    },
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showNewPostPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      _watchPostStores(context);
      final open = AppDomains.all
          .where(
            (domain) =>
                domain.enabled && _domainCanAddPost(context, domain.id),
          )
          .toList(growable: false);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New post', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (open.isEmpty)
                Text(
                  'All post slots are full.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                )
              else
                ...open.map(
                  (domain) => _DomainAdRow(
                    domain: domain,
                    subtitle: _domainPostSubtitle(context, domain),
                    trailing: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.muted,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDomainProfileForm(context, domain);
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _DomainAdRow extends StatelessWidget {
  const _DomainAdRow({
    required this.domain,
    required this.trailing,
    required this.onTap,
    this.subtitle,
  });

  final DomainPolicy domain;
  final Widget trailing;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: domain.softColor,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: .7),
            child: Icon(_domainIcons[domain.id], color: domain.color),
          ),
          title: Text(
            domain.label,
            style: TextStyle(
              color: domain.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle ?? domainPostLine(domain.id, l10n),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
            ),
          ),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}

const _domainIcons = <AppDomainId, IconData>{
  AppDomainId.marriage: Icons.favorite,
  AppDomainId.jobs: Icons.work,
  AppDomainId.rooms: Icons.hotel,
  AppDomainId.bikes: Icons.pedal_bike,
  AppDomainId.homeHelp: Icons.cleaning_services,
};

Future<void> _showGrowthSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Consumer2<BillingService, TrustService>(
      builder: (context, billing, trust, _) {
        final identity = context.read<IdentityStore>();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Get more views',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.darkCream,
                  child: Icon(Icons.autorenew, color: AppColors.rose),
                ),
                title: const Text('Refresh'),
                subtitle: const Text('Free • 1 a day'),
                onTap: () async {
                  final uid = identity.identity.userId.isEmpty
                      ? (FirebaseBootstrap.ready
                            ? (FirebaseAuth.instance.currentUser?.uid ??
                                  'local')
                            : 'local')
                      : identity.identity.userId;
                  final ok = await RefreshBoostService(
                    await SharedPreferences.getInstance(),
                  ).refreshOwnedCards(uid: uid, domains: AppDomainId.values);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Done for today.' : 'Already done today.',
                      ),
                    ),
                  );
                },
              ),
              if (billing.active)
                const ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.darkCream,
                    child: Icon(
                      Icons.rocket_launch_outlined,
                      color: AppColors.rose,
                    ),
                  ),
                  title: Text('Boost is on'),
                )
              else if (billing.available)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.darkCream,
                    child: Icon(
                      Icons.rocket_launch_outlined,
                      color: AppColors.rose,
                    ),
                  ),
                  title: const Text('Boost 7 days'),
                  subtitle: const Text('Paid'),
                  onTap: () async {
                    await billing.buyBoost();
                    final uid = identity.identity.userId;
                    if (uid.isEmpty || !billing.active) return;
                    await RefreshBoostService(
                      await SharedPreferences.getInstance(),
                    ).fanOutBoost(
                      uid: uid,
                      billing: billing,
                      domains: AppDomainId.values,
                    );
                  },
                )
              else
                ListTile(
                  enabled: false,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.darkCream,
                    child: Icon(
                      Icons.rocket_launch_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                  title: const Text('Boost'),
                  subtitle: Text(billing.webMessage),
                ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.darkCream,
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: trust.flags.idPlus ? Colors.green : AppColors.muted,
                  ),
                ),
                title: const Text('ID badge'),
                subtitle: const Text('Aadhaar + licence. No upload.'),
                trailing: trust.flags.idPlus
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: trust.flags.idPlus
                    ? null
                    : () {
                        trust.applySelfAttested(
                          trust.flags.copyWith(
                            aadhaar: true,
                            drivingLicence: true,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID badge added.')),
                        );
                      },
              ),
              if (kDebugMode && !billing.available)
                TextButton(
                  onPressed: () async {
                    billing.debugGrant(DateTime.now());
                    final uid = identity.identity.userId.isEmpty
                        ? 'local'
                        : identity.identity.userId;
                    await RefreshBoostService(
                      await SharedPreferences.getInstance(),
                    ).fanOutBoost(
                      uid: uid,
                      billing: billing,
                      domains: AppDomainId.values,
                    );
                  },
                  child: const Text('Debug grant boost'),
                ),
            ],
          ),
        );
      },
    ),
  ),
);

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.cream.withValues(alpha: .95),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        actions: actions,
      ),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.rose),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.travel_explore, size: 54),
          const SizedBox(height: 16),
          const Text('Nothing more here for now.'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onReset,
            child: const Text('Show again'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showFilters(BuildContext context, DomainPolicy domain) async {
  final match = context.read<MatchPreferencesStore>();
  final jobs = context.read<JobsDiscoverPrefsStore>();
  String? city = domain.id == AppDomainId.jobs ? jobs.cityId : match.cityId;
  String? gender = match.gender;
  String? age = match.ageBand;
  String? role = jobs.role;
  String? trade = jobs.tradeId;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${domain.label} filters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: city,
                decoration: const InputDecoration(labelText: 'City'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any city')),
                  DropdownMenuItem(
                    value: 'mumbai',
                    child: Text('Mumbai & MMR'),
                  ),
                  DropdownMenuItem(value: 'delhi', child: Text('Delhi NCR')),
                  DropdownMenuItem(
                    value: 'bengaluru',
                    child: Text('Bengaluru'),
                  ),
                ],
                onChanged: (v) => setState(() => city = v),
              ),
              if (domain.id == AppDomainId.marriage) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any')),
                    DropdownMenuItem(value: 'woman', child: Text('Woman')),
                    DropdownMenuItem(value: 'man', child: Text('Man')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => gender = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: age,
                  decoration: const InputDecoration(labelText: 'Age band'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    ...[
                      '18-24',
                      '25-29',
                      '30-34',
                      '35-39',
                      '40-49',
                      '50+',
                    ].map((v) => DropdownMenuItem(value: v, child: Text(v))),
                  ],
                  onChanged: (v) => setState(() => age = v),
                ),
              ],
              if (domain.id == AppDomainId.jobs) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Looking for'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any')),
                    DropdownMenuItem(value: 'seek', child: Text('I have')),
                    DropdownMenuItem(value: 'offer', child: Text('I need')),
                  ],
                  onChanged: (v) => setState(() => role = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: trade,
                  decoration: const InputDecoration(labelText: 'Trade'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any trade'),
                    ),
                    ...JobsProfile.trades.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => setState(() => trade = v),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (domain.id == AppDomainId.jobs) {
                    jobs.update(city: city, roleValue: role, trade: trade);
                  } else {
                    match.update(city: city, genderValue: gender, age: age);
                  }
                  Navigator.pop(sheetContext);
                },
                child: const Text('Apply filters'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showMatch(
  BuildContext context,
  DiscoveryCardModel card,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.favorite, color: AppColors.rose, size: 42),
    title: const Text('Both interested'),
    content: const Text(
      'Verify your phone when you are ready to unlock the private contact card.',
      textAlign: TextAlign.center,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Continue'),
      ),
    ],
  ),
);

Future<void> _showSettings(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final locale = context.watch<LocaleController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Language', style: Theme.of(context).textTheme.titleMedium),
              RadioGroup<String?>(
                groupValue: locale.localeCode,
                onChanged: locale.setLocale,
                child: const Column(
                  children: [
                    RadioListTile(
                      value: null,
                      title: Text('Phone language'),
                    ),
                    RadioListTile(value: 'en', title: Text('English')),
                    RadioListTile(value: 'hi', title: Text('हिन्दी')),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Terms'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPageScreen.terms(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPageScreen.privacy(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPageScreen.dataDeletion(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

Future<void> showIdentityForm(BuildContext context) async {
  final store = context.read<IdentityStore>();
  final current = store.identity;
  final name = TextEditingController(text: current.displayName);
  final phone = TextEditingController(text: current.whatsappNumber);
  String city = current.cityId.isEmpty ? 'mumbai' : current.cityId;
  String language = current.nativeLanguage.isEmpty
      ? 'Hindi'
      : current.nativeLanguage;
  final key = GlobalKey<FormState>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'My details',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter at least 2 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                  ),
                  validator: (value) =>
                      (value ?? '').replaceAll(RegExp(r'\D'), '').length < 8
                      ? 'Enter at least 8 digits'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: city,
                  decoration: const InputDecoration(labelText: 'City'),
                  items: const [
                    DropdownMenuItem(
                      value: 'mumbai',
                      child: Text('Mumbai & MMR'),
                    ),
                    DropdownMenuItem(value: 'delhi', child: Text('Delhi NCR')),
                    DropdownMenuItem(
                      value: 'bengaluru',
                      child: Text('Bengaluru'),
                    ),
                  ],
                  onChanged: (value) => setState(() => city = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: language,
                  decoration: const InputDecoration(
                    labelText: 'Native language',
                  ),
                  items:
                      const [
                            'Hindi',
                            'English',
                            'Marathi',
                            'Tamil',
                            'Telugu',
                            'Kannada',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => language = value!),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if (!key.currentState!.validate()) return;
                    const labels = {
                      'mumbai': 'Mumbai & MMR',
                      'delhi': 'Delhi NCR',
                      'bengaluru': 'Bengaluru',
                    };
                    await store.save(
                      current.copyWith(
                        displayName: name.text,
                        whatsappNumber: phone.text,
                        cityId: city,
                        cityLabel: labels[city],
                        nativeLanguage: language,
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  name.dispose();
  phone.dispose();
}

Future<void> showDomainProfileForm(
  BuildContext context,
  DomainPolicy domain, {
  OwnedPost? edit,
}) async {
  final hostMessenger = ScaffoldMessenger.of(context);
  final identity = context.read<IdentityStore>();
  final publisher = context.read<ListingPublisher>();
  final mediaCache = context.read<OwnedListingCache>();
  final uid = identity.identity.userId.isEmpty
      ? (FirebaseBootstrap.ready
            ? (FirebaseAuth.instance.currentUser?.uid ?? 'local')
            : 'local')
      : identity.identity.userId;

  OwnedPost? activeEdit = edit;
  if (activeEdit != null) {
    final photos = await resolveOwnedPhotoUrls(
      post: activeEdit,
      media: mediaCache,
      ownerId: uid,
    );
    if (!context.mounted) return;
    // Refresh local typed fields from remote public attrs when store is empty.
    switch (activeEdit.domain) {
      case AppDomainId.marriage:
        final store = context.read<ProfileStore>();
        if (store.value == null) {
          final profile = marriageFromCard(activeEdit.card);
          if (profile != null) store.saveLocal(profile);
        }
      case AppDomainId.jobs:
        final store = context.read<JobsProfileStore>();
        if (store.value == null) {
          final profile = jobsFromCard(activeEdit.card);
          if (profile != null) store.saveLocal(profile);
        }
      case AppDomainId.rooms:
      case AppDomainId.bikes:
      case AppDomainId.homeHelp:
        break;
    }
    activeEdit = OwnedPost(
      domain: activeEdit.domain,
      offerIndex: activeEdit.offerIndex,
      card: DiscoveryCardModel(
        id: activeEdit.card.id,
        domain: activeEdit.card.domain,
        ownerId: activeEdit.card.ownerId,
        title: activeEdit.card.title,
        subtitle: activeEdit.card.subtitle,
        cityId: activeEdit.card.cityId,
        cityLabel: activeEdit.card.cityLabel,
        categoryTags: activeEdit.card.categoryTags,
        imageUrls: photos.isNotEmpty ? photos : activeEdit.card.imageUrls,
        role: activeEdit.card.role,
        ageBand: activeEdit.card.ageBand,
        attributes: activeEdit.card.attributes,
        verified: activeEdit.card.verified,
      ),
    );
  }

  final media = FormMediaController(domain: domain.id, uid: uid);
  final editingOffer = activeEdit?.offerIndex != null;
  final offerId = editingOffer
      ? activeEdit!.card.id
      : '${domain.id.name}_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> rememberMedia({int? offerIndex}) async {
    final urls = List<String>.from(media.urls);
    if (domain.storageKind == DomainStorageKind.offers) {
      final index = offerIndex ??
          activeEdit?.offerIndex ??
          (switch (domain.id) {
            AppDomainId.rooms =>
              context.read<RoomsOfferStore>().offers.length - 1,
            AppDomainId.bikes =>
              context.read<BikesOfferStore>().offers.length - 1,
            AppDomainId.homeHelp =>
              context.read<HomeHelpOfferStore>().offers.length - 1,
            _ => 0,
          });
      if (index < 0) return;
      await mediaCache.setPhotos(domain.id, urls, index: index);
      await mediaCache.setOfferId(domain.id, index, offerId);
    } else {
      await mediaCache.setPhotos(domain.id, urls);
    }
  }

  media.onUrlsChanged = (urls) => rememberMedia(offerIndex: activeEdit?.offerIndex);

  if (activeEdit != null) {
    media.seedUrls(activeEdit.card.imageUrls);
  }

  final requireFace =
      domain.id == AppDomainId.marriage || domain.id == AppDomainId.jobs;

  Future<bool> pickPhoto(BuildContext hostContext, int slot) async {
    if (!hostContext.mounted) return false;
    final source = await showPhotoSourceSheet(
      hostContext,
      accent: domain.color,
    );
    if (source == null) return false;
    final ok = await media.pickAndUpload(
      slot: slot,
      requireFace: requireFace,
      source: source,
      offerId: domain.storageKind == DomainStorageKind.offers ? offerId : null,
    );
    if (!ok && hostContext.mounted && media.lastError != null) {
      ScaffoldMessenger.of(
        hostContext,
      ).showSnackBar(SnackBar(content: Text(media.lastError!)));
    }
    return ok;
  }

  void removePhoto(int slot) => media.removeAt(slot);

  String publishOwnerId() {
    if (FirebaseBootstrap.ready) {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    }
    final fallback = media.uid;
    if (fallback.isNotEmpty && fallback != 'local') return fallback;
    return uid;
  }

  void finishSaved(BuildContext formContext) {
    Navigator.of(formContext).pop();
    hostMessenger.showSnackBar(
      SnackBar(
        content: const Text('Saved'),
        backgroundColor: domain.color,
      ),
    );
  }

  final marriageInitial = activeEdit?.domain == AppDomainId.marriage
      ? context.read<ProfileStore>().value
      : null;
  final jobsInitial = activeEdit?.domain == AppDomainId.jobs
      ? context.read<JobsProfileStore>().value
      : null;
  final roomsInitial = activeEdit != null
      ? roomsFromOwned(activeEdit, context.read<RoomsOfferStore>())
      : null;
  final bikesInitial = activeEdit != null
      ? bikesFromOwned(activeEdit, context.read<BikesOfferStore>())
      : null;
  final homeHelpInitial = activeEdit != null
      ? homeHelpFromOwned(activeEdit, context.read<HomeHelpOfferStore>())
      : null;

  if (!context.mounted) return;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      builder: (formContext, scrollController) {
        return ListenableBuilder(
          listenable: media,
          builder: (context, _) {
            final urls = List<String>.from(media.urls);
            final previews = List<Uint8List?>.from(media.previews);
            final busy = media.busySlot;
            final progress = media.uploadProgress;
            Future<bool> onPick(int slot) => pickPhoto(formContext, slot);
            void onSaved() => finishSaved(formContext);
            final form = switch (domain.id) {
              AppDomainId.marriage => MarriageForm(
                initial: marriageInitial,
                photoUrls: urls,
                photoPreviews: previews,
                busySlot: busy,
                uploadProgress: progress,
                photoStatus: media.lastStatus,
                photoError: media.lastError,
                onPickPhoto: onPick,
                onRemovePhoto: removePhoto,
                onSaveSuccess: onSaved,
                onAfterSave: (profile) async {
                  await publisher.publishMarriage(
                    ownerId: publishOwnerId(),
                    profile: profile,
                    photoUrls: List<String>.from(media.urls),
                  );
                  await rememberMedia();
                },
              ),
              AppDomainId.jobs => JobsForm(
                initial: jobsInitial,
                photoUrls: urls,
                photoPreviews: previews,
                busySlot: busy,
                uploadProgress: progress,
                photoStatus: media.lastStatus,
                photoError: media.lastError,
                onPickPhoto: onPick,
                onRemovePhoto: removePhoto,
                onSaveSuccess: onSaved,
                onAfterSave: (profile) async {
                  await publisher.publishJobs(
                    ownerId: publishOwnerId(),
                    profile: profile,
                    photoUrls: List<String>.from(media.urls),
                  );
                  await rememberMedia();
                },
              ),
              AppDomainId.rooms => RoomsForm(
                initial: roomsInitial,
                editIndex: activeEdit?.offerIndex,
                photoUrls: urls,
                photoPreviews: previews,
                busySlot: busy,
                uploadProgress: progress,
                photoStatus: media.lastStatus,
                photoError: media.lastError,
                onPickPhoto: onPick,
                onRemovePhoto: removePhoto,
                onSaveSuccess: onSaved,
                onAfterSave: (offer) async {
                  await publisher.publishRooms(
                    ownerId: publishOwnerId(),
                    offer: offer,
                    offerId: offerId,
                    photoUrls: List<String>.from(media.urls),
                  );
                  await rememberMedia(offerIndex: activeEdit?.offerIndex);
                },
              ),
              AppDomainId.bikes => BikesForm(
                initial: bikesInitial,
                editIndex: activeEdit?.offerIndex,
                photoUrls: urls,
                photoPreviews: previews,
                busySlot: busy,
                uploadProgress: progress,
                photoStatus: media.lastStatus,
                photoError: media.lastError,
                onPickPhoto: onPick,
                onRemovePhoto: removePhoto,
                onSaveSuccess: onSaved,
                onAfterSave: (offer) async {
                  await publisher.publishBikes(
                    ownerId: publishOwnerId(),
                    offer: offer,
                    offerId: offerId,
                    photoUrls: List<String>.from(media.urls),
                  );
                  await rememberMedia(offerIndex: activeEdit?.offerIndex);
                },
              ),
              AppDomainId.homeHelp => HomeHelpForm(
                initial: homeHelpInitial,
                editIndex: activeEdit?.offerIndex,
                photoUrls: urls,
                photoPreviews: previews,
                busySlot: busy,
                uploadProgress: progress,
                photoStatus: media.lastStatus,
                photoError: media.lastError,
                onPickPhoto: onPick,
                onRemovePhoto: removePhoto,
                onSaveSuccess: onSaved,
                onAfterSave: (offer) async {
                  await publisher.publishHomeHelp(
                    ownerId: publishOwnerId(),
                    offer: offer,
                    offerId: offerId,
                    photoUrls: List<String>.from(media.urls),
                  );
                  await rememberMedia(offerIndex: activeEdit?.offerIndex);
                },
              ),
            };
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(formContext),
                          child: const Text('Close'),
                        ),
                        const Spacer(),
                        Text(
                          domain.label,
                          style: TextStyle(
                            color: domain.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 64),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PrimaryScrollController(
                      controller: scrollController,
                      child: form,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  ).whenComplete(media.dispose);
}

