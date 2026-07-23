import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/app_domain.dart';
import '../models/card_side.dart';
import '../models/discovery_card.dart';
import '../models/domain_profiles.dart';
import '../models/like_display.dart';
import '../models/owned_post.dart';
import '../services/account_services.dart';
import 'legal_screens.dart';
import '../services/contact_service.dart';
import '../services/domain_repository.dart';
import '../services/firebase_bootstrap.dart';
import '../services/form_media_controller.dart';
import '../services/likes_repository.dart';
import '../services/listing_lifecycle.dart';
import '../services/listing_publisher.dart';
import '../services/owned_hydrate.dart';
import '../services/owned_listing_cache.dart';
import '../services/owned_posts.dart';
import '../services/phone_number.dart';
import '../services/push_service.dart';
import '../services/refresh_boost_service.dart';
import '../services/session_service.dart';
import '../services/share_service.dart';
import '../state/app_stores.dart';
import '../widgets/listing_meta.dart';
import '../state/domain_profile_stores.dart';
import '../theme/app_theme.dart';
import '../widgets/forms/form_fields.dart';
import '../widgets/forms/bikes_form.dart';
import '../widgets/forms/home_help_form.dart';
import '../widgets/forms/jobs_form.dart';
import '../widgets/forms/kuwait_jobs_form.dart';
import '../widgets/forms/marriage_form.dart';
import '../widgets/domain_tile_picker.dart';
import '../widgets/domain_switcher_button.dart';
import '../widgets/expandable_domain_section.dart';
import '../widgets/forms/rooms_form.dart';
import '../widgets/forms/photo_source_sheet.dart';
import '../widgets/tap_feedback.dart';
import '../services/image_prefetch.dart';
import '../services/media_urls.dart';
import '../widgets/fast_network_image.dart';
import '../widgets/onboarding/identity_form_sheet.dart';
import '../widgets/onboarding/otp_sheet.dart';
import '../widgets/onboarding/whatsapp_gate_sheet.dart';
import '../widgets/photo_pager.dart';
import '../widgets/safety/safety_sheet.dart';

/// Visible over Match / Liked-me sheets (SnackBars often hide behind them).
Future<void> _showContactActionDialog(
  BuildContext context,
  String message,
) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  var _hydratedUid = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PushService.onInboundLikeData = (data) {
        if (!mounted) return;
        final likes = context.read<LikesStore>();
        final chatReady =
            data['chatReady'] == 'true' || data['type'] == 'chat_ready';
        final peer = data['fromUid'] ?? data['peerUid'] ?? '';
        likes.applyInboundPush(
          domainSlug: data['domain'] ?? '',
          fromUid: peer,
          title: data['title'],
          subtitle: data['subtitle'],
          cityLabel: data['cityLabel'],
          photoUrl: data['photoUrl'],
          listingId: data['listingId'],
          chatReady: chatReady,
        );
        unawaited(likes.hydrateAll());
      };
      unawaited(_hydrateSession());
      if (Firebase.apps.isNotEmpty) {
        _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
          if (!mounted) return;
          if (user == null || user.uid == _hydratedUid) return;
          unawaited(_hydrateSession());
        });
      }
      final controller = context.read<DomainController>();
      if (!controller.shouldShowCoachMark) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap the domain name to change Marriage, Jobs, Rooms…'),
          duration: Duration(seconds: 8),
          showCloseIcon: true,
        ),
      );
      unawaited(controller.markCoachSeen());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushService.onInboundLikeData = null;
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // Pull latest listings + likes without requiring force-quit.
    unawaited(context.read<DiscoveryStore>().retryRemoteSync());
    unawaited(context.read<LikesStore>().hydrateAll());
  }

  Future<void> _hydrateSession() async {
    await FirebaseBootstrap.waitUntilReady();
    if (!FirebaseBootstrap.ready || !mounted) return;
    final user = await FirebaseBootstrap.waitForRestoredUser();
    if (!mounted) return;
    final uid = user?.uid;
    if (uid == null) return;
    _hydratedUid = uid;
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
    likes.startRealtimeSync();
    await PushService().initialize(uid: uid);
    if (!mounted) return;
    await hydrateOwnedListings(
      ownerId: uid,
      media: context.read<OwnedListingCache>(),
      marriage: context.read<ProfileStore>(),
      jobs: context.read<JobsOfferStore>(),
      kuwaitJobs: context.read<KuwaitJobsOfferStore>(),
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
        onDestinationSelected: (index) {
          controller.selectTab(index);
          if (index == 1) {
            unawaited(context.read<LikesStore>().hydrateAll());
          }
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(
              Icons.travel_explore,
              color: controller.policy.color,
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
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DomainTilePicker(
              selected: controller.selected,
              onDomainSelected: (id) {
                controller.selectDomain(id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  /// Count only — never implies GPS/"nearby" accuracy.
  static String feedCountLabel(int count) => '$count';

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  AppDomainId? _watching;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final domain = context.watch<DomainController>().selected;
    if (_watching == domain) return;
    _watching = domain;
    final store = context.read<DiscoveryStore>();
    store.startLiveFeed(FirestoreDomainRepository());
  }

  @override
  void dispose() {
    // Store may already be swapped; best-effort stop via last known.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domain = context.watch<DomainController>().policy;
    final store = context.watch<DiscoveryStore>();
    if (!domain.enabled) return ComingSoonView(domain: domain);
    final viewerUid = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    final visible = store.cardsForViewer(viewerUid);
    final matchPrefs = context.watch<MatchPreferencesStore>();
    final jobsPrefs = context.watch<JobsDiscoverPrefsStore>();
    final kuwaitJobsPrefs = context.watch<KuwaitJobsDiscoverPrefsStore>();
    final cards = domain.id == AppDomainId.kuwaitJobs
        ? store.filtered(
            source: visible,
            cityId: kuwaitJobsPrefs.countryId,
            role: kuwaitJobsPrefs.role,
            tradeId: kuwaitJobsPrefs.tradeId,
            nationality: kuwaitJobsPrefs.nationality,
            experienceBand: kuwaitJobsPrefs.experienceBand,
          )
        : domain.id == AppDomainId.jobs
        ? store.filtered(
            source: visible,
            cityId: jobsPrefs.cityId,
            role: jobsPrefs.role,
            tradeId: jobsPrefs.tradeId,
          )
        : store.filtered(
            source: visible,
            cityId: matchPrefs.cityId,
            gender: domain.id == AppDomainId.marriage
                ? matchPrefs.gender
                : null,
            ageBand: domain.id == AppDomainId.marriage
                ? matchPrefs.ageBand
                : null,
          );
    final filterChips = browseActiveFilterLabels(
      domainId: domain.id,
      match: matchPrefs,
      jobs: jobsPrefs,
      kuwaitJobs: kuwaitJobsPrefs,
    );
    final filtersOn = filterChips.isNotEmpty;
    return RefreshIndicator(
      color: domain.color,
      onRefresh: () => store.retryRemoteSync(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: domain.softSurface.withValues(alpha: .96),
            title: DomainPageTitle(
              title: domain.label,
              subtitle: DiscoverScreen.feedCountLabel(cards.length),
              titleColor: domain.color,
            ),
            actions: [
              DomainSwitcherButton(
                color: domain.color,
                onPressed: () => showDomainDial(context),
              ),
              IconButton(
                tooltip: 'Filters',
                onPressed: () => _showFilters(context, domain),
                icon: Badge(
                  isLabelVisible: filtersOn,
                  smallSize: 8,
                  child: Icon(Icons.tune, color: domain.color),
                ),
              ),
            ],
          ),
          if (filtersOn)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final label in filterChips) Chip(label: Text(label)),
                    ActionChip(
                      key: const Key('clear_filters'),
                      label: const Text('Clear'),
                      onPressed: () => _clearBrowseFilters(context, domain.id),
                    ),
                  ],
                ),
              ),
            ),
          if (cards.isEmpty)
            SliverFillRemaining(
              child: store.status == SyncStatus.loading
                  ? const BrowseFeedLoading()
                  : store.status == SyncStatus.error
                  ? BrowseFeedError(
                      message: store.error ?? 'Could not load. Try again.',
                      onRetry: () => store.retryRemoteSync(),
                    )
                  : EmptyBrowseFeed(
                      domainLabel: domain.label,
                      hasFilters: filtersOn,
                      onClearFilters: filtersOn
                          ? () => _clearBrowseFilters(context, domain.id)
                          : null,
                      onReset: store.reset,
                      onChangeDomain: () => showDomainDial(context),
                    ),
            )
          else
            // Keep existing list body — replaced in next patch chunk if needed.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.separated(
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  ImagePrefetch.aroundCards(context, cards, focusIndex: index);
                  return DiscoveryCard(
                    card: cards[index],
                    onPass: () => store.action(cards[index].id),
                    onLike: () async {
                      final card = cards[index];
                      final messenger = ScaffoldMessenger.of(context);
                      final likes = context.read<LikesStore>();
                      try {
                        final ready = await ensurePhoneVerifiedForAction(
                          context,
                        );
                        if (!ready || !context.mounted) return false;
                        final newlyMutual = await likes.like(
                          domain.id,
                          card.ownerId,
                          snapshot: card,
                          fromCard: _ownCardForDomain(context, domain.id),
                        );
                        store.action(card.id);
                        if (newlyMutual && context.mounted) {
                          _showMatch(context, card);
                        } else if (context.mounted &&
                            likes.isMutual(domain.id, card.ownerId)) {
                          // Same person, another listing — Match is per UID.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Already matched — open WhatsApp from Match',
                              ),
                            ),
                          );
                        }
                        return true;
                      } catch (error) {
                        final message = error is StateError
                            ? error.message
                            : 'Could not save like. Try again.';
                        messenger.showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                        return false;
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
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

  /// Returns true when the like (or gate) succeeded and the card may dismiss.
  final Future<bool> Function() onLike;

  @override
  Widget build(BuildContext context) {
    final title = cardTitleLine(card);
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
        if (direction == DismissDirection.startToEnd) {
          return onLike();
        }
        onPass();
        return true;
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: domainColor, width: 5)),
          ),
          child: Stack(
            children: [
              Column(
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
                                label: title,
                                seed: card.id.hashCode,
                              ),
                            ]
                          : card.imageUrls
                                .map(
                                  (url) => _BrowsePhoto(
                                    url: url,
                                    label: title,
                                    seed: card.id.hashCode,
                                  ),
                                )
                                .toList(growable: false),
                    ),
                  ),
                  ListingMeta(
                    card: card,
                    showCity: false,
                    contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
                    trailing: PopupMenuButton<String>(
                      tooltip: l10n.text('more'),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'safety',
                          child: Text(l10n.text('safety')),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'safety') {
                          await showSafetySheet(
                            context,
                            domain: card.domain,
                            targetId: card.id,
                            ownerId: card.ownerId,
                          );
                        }
                      },
                      icon: const Icon(Icons.more_vert),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Row(
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
                          key: const Key('share_button'),
                          tooltip: l10n.text('share'),
                          icon: Icons.share_outlined,
                          color: domainColor,
                          filled: false,
                          compact: true,
                          onPressed: () => unawaited(_share(context)),
                        ),
                        const SizedBox(width: 10),
                        _RoundAction(
                          key: const Key('interested_button'),
                          tooltip: l10n.text('like'),
                          icon: Icons.favorite,
                          color: domainColor,
                          filled: true,
                          compact: true,
                          onPressed: () => unawaited(onLike()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Positioned(
                right: 0,
                bottom: 0,
                child: IgnorePointer(child: _BrowseCardCornerAccent()),
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
        const SnackBar(
          content: Text('Share link is not ready for this post yet.'),
        ),
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

/// Faint L-border framing the bottom-right corner of Browse cards.
class _BrowseCardCornerAccent extends StatelessWidget {
  const _BrowseCardCornerAccent();

  static final _color = AppColors.muted.withValues(alpha: .28);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(painter: _CornerLPainter(color: _color)),
    );
  }
}

class _CornerLPainter extends CustomPainter {
  const _CornerLPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerLPainter oldDelegate) =>
      oldDelegate.color != color;
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
    final overlay = AppTapFeedback.overlayColor();
    final button = filled
        ? IconButton.filled(
            onPressed: onPressed,
            enableFeedback: true,
            icon: Icon(icon),
            iconSize: iconSize,
            padding: EdgeInsets.all(padding),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ).copyWith(overlayColor: overlay),
          )
        : IconButton.outlined(
            onPressed: onPressed,
            enableFeedback: true,
            icon: Icon(icon),
            iconSize: iconSize,
            padding: EdgeInsets.all(padding),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 2),
            ).copyWith(overlayColor: overlay),
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
    return FastNetworkImage(
      url: url,
      role: FastImageRole.card,
      fit: BoxFit.cover,
      fallback: fallback,
      placeholderColor: AppColors.darkCream,
    );
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
      ],
    ),
  );
}

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<LikesStore>().hydrateAll());
    });
  }

  @override
  Widget build(BuildContext context) {
    final likes = context.watch<LikesStore>();
    return _Page(
      title: 'Likes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Match first so it is not buried under long I liked / Liked me lists.
          _MatchSection(likes: likes),
          const SizedBox(height: 16),
          _LikesSection(
            title: 'I liked',
            count: likes.outboundCount,
            icon: Icons.favorite,
            direction: LikeDirection.outbound,
            entriesFor: likes.outboundEntries,
            likes: likes,
          ),
          const SizedBox(height: 16),
          _LikesSection(
            title: 'Liked me',
            count: likes.inboundCount,
            icon: Icons.favorite_border,
            direction: LikeDirection.inbound,
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
    required this.direction,
    required this.entriesFor,
    required this.likes,
  });

  final String title;
  final int count;
  final IconData icon;
  final LikeDirection direction;
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
        _HubSectionHeader(title: title, icon: icon, count: count),
        if (domainsWithLikes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('None yet'),
          )
        else
          ...domainsWithLikes.map((policy) {
            final entries = entriesFor(policy.id);
            ImagePrefetch.warmAll(
              context,
              entries.expand((e) {
                return <String?>[
                  e.targetCard?.imageUrls.isNotEmpty == true
                      ? e.targetCard!.imageUrls.first
                      : null,
                  e.card?.imageUrls.isNotEmpty == true
                      ? e.card!.imageUrls.first
                      : null,
                ];
              }).whereType<String>(),
              role: FastImageRole.thumb,
            );
            return ExpandableDomainSection(
              sectionKey: Key('likes_domain_${policy.id.name}'),
              domain: policy,
              count: entries.length,
              icon: _domainIcons[policy.id] ?? Icons.circle,
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LikeRow(
                      entry: entry,
                      mutual: likes.chatIconsActive(
                        entry.domain,
                        entry.otherUid,
                      ),
                      onOpen: () => _showLikeDetail(context, entry),
                      onRemove: () => _removeLikeRow(
                        context,
                        likes: likes,
                        entry: entry,
                        direction: direction,
                      ),
                    ),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

Future<void> _removeLikeRow(
  BuildContext context, {
  required LikesStore likes,
  required LikeEntry entry,
  required LikeDirection direction,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (direction == LikeDirection.outbound) {
    final snapshot = entry.card;
    await likes.unlike(entry.domain, entry.otherUid);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(LikeConsent.removedSnack),
        action: SnackBarAction(
          label: LikeConsent.undo,
          onPressed: () {
            unawaited(
              likes.restoreOutbound(
                entry.domain,
                entry.otherUid,
                snapshot: snapshot,
              ),
            );
          },
        ),
      ),
    );
    return;
  }
  await likes.dismissInbound(entry.domain, entry.otherUid);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: const Text(LikeConsent.removedSnack),
      action: SnackBarAction(
        label: LikeConsent.undo,
        onPressed: () {
          unawaited(likes.restoreInbound(entry.domain, entry.otherUid));
        },
      ),
    ),
  );
}

Future<void> _deleteMatchRow(
  BuildContext context, {
  required LikesStore likes,
  required LikeEntry entry,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  await likes.deleteMatch(entry.domain, entry.otherUid);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    const SnackBar(content: Text(LikeConsent.matchRemovedSnack)),
  );
}

class _MatchSection extends StatelessWidget {
  const _MatchSection({required this.likes});

  final LikesStore likes;

  @override
  Widget build(BuildContext context) {
    final domainsWithMatches = AppDomains.all
        .where((policy) => likes.matchEntries(policy.id).isNotEmpty)
        .toList(growable: false);
    return Column(
      key: const Key('likes_match_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HubSectionHeader(
          title: LikeDisplay.matchSectionTitle,
          icon: Icons.handshake_outlined,
          count: likes.matchCount,
        ),
        if (domainsWithMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(LikeDisplay.matchEmptyHint),
          )
        else
          ...domainsWithMatches.map((policy) {
            final entries = likes.matchEntries(policy.id);
            ImagePrefetch.warmAll(
              context,
              entries.expand((e) {
                return <String?>[
                  e.targetCard?.imageUrls.isNotEmpty == true
                      ? e.targetCard!.imageUrls.first
                      : null,
                  e.card?.imageUrls.isNotEmpty == true
                      ? e.card!.imageUrls.first
                      : null,
                ];
              }).whereType<String>(),
              role: FastImageRole.thumb,
            );
            return ExpandableDomainSection(
              sectionKey: Key('match_domain_${policy.id.name}'),
              domain: policy,
              count: entries.length,
              icon: _domainIcons[policy.id] ?? Icons.circle,
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MatchRow(
                      entry: entry,
                      onOpen: () => _showMatchDetail(context, entry),
                      onDelete: () =>
                          _deleteMatchRow(context, likes: likes, entry: entry),
                    ),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _MatchRow extends StatefulWidget {
  const _MatchRow({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
  });

  final LikeEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<_MatchRow> {
  _ContactChannel? _opening;

  LikeEntry get entry => widget.entry;

  Future<PrivateContact?> _ensureContact() async {
    final shareReady = await ensureContactShareForChat(context);
    if (!shareReady || !mounted) return null;
    try {
      final contact = await ContactService().unlock(
        domain: entry.domain,
        targetUid: entry.otherUid,
      );
      if (!mounted) return null;
      if (contact == null) {
        await _showContactActionDialog(
          context,
          'Their WhatsApp is not saved yet. Ask them to open the app once.',
        );
        return null;
      }
      return contact;
    } catch (error) {
      if (!mounted) return null;
      final message = error is StateError
          ? error.message
          : 'Could not unlock chat. Check phone verification.';
      await _showContactActionDialog(context, message);
      return null;
    }
  }

  Future<void> _openWhatsApp() async {
    if (_opening != null) return;
    setState(() => _opening = _ContactChannel.whatsapp);
    try {
      final contact = await _ensureContact();
      if (contact == null || !mounted) return;
      await context.read<LikesStore>().signalChatOpened(
        entry.domain,
        entry.otherUid,
      );
      final label = AppDomains.byId(entry.domain).label;
      final opened = await ContactService().openWhatsApp(
        contact.whatsappNumber,
        domainLabel: label,
      );
      if (!mounted) return;
      if (!opened) {
        await _showContactActionDialog(
          context,
          'Could not open WhatsApp — number & message copied. '
          'Is WhatsApp installed?',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _openTelegram() async {
    if (_opening != null) return;
    setState(() => _opening = _ContactChannel.telegram);
    try {
      final contact = await _ensureContact();
      if (contact == null || !mounted) return;
      final handle = contact.telegramHandle?.trim() ?? '';
      final phone = contact.whatsappNumber;
      if (handle.isEmpty && cleanWhatsAppDigits(phone).length < 8) {
        await _showContactActionDialog(context, 'No Telegram number yet');
        return;
      }
      await context.read<LikesStore>().signalChatOpened(
        entry.domain,
        entry.otherUid,
      );
      final label = AppDomains.byId(entry.domain).label;
      final opened = await ContactService().openTelegram(
        handle: handle.isEmpty ? null : handle,
        phoneDigits: phone,
        domainLabel: label,
      );
      if (!mounted) return;
      if (!opened) {
        await _showContactActionDialog(
          context,
          'Could not open Telegram — message copied to paste',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final theirTitle = LikeDisplay.rowTitle(entry.card);
    final yourTitle = LikeDisplay.rowTitle(entry.targetCard);
    final city = entry.card?.cityLabel.trim() ?? '';
    return Material(
      key: Key('match_row_${entry.domain.name}_${entry.otherUid}'),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.muted.withValues(alpha: .18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _DualLikeThumbs(entry: entry, compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theirTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          city.isNotEmpty
                              ? city
                              : '${LikeDisplay.yourPostLabel}: $yourTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: Key(
                      'match_more_${entry.domain.name}_${entry.otherUid}',
                    ),
                    tooltip: 'More',
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') widget.onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        key: Key(
                          'match_delete_${entry.domain.name}_${entry.otherUid}',
                        ),
                        value: 'delete',
                        child: Text(LikeDisplay.deleteMatchLabel),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MatchWhatsAppButton(
                      busy: _opening == _ContactChannel.whatsapp,
                      enabled: _opening == null,
                      onPressed: _openWhatsApp,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MatchTelegramIconButton(
                    busy: _opening == _ContactChannel.telegram,
                    enabled: _opening == null,
                    onPressed: _openTelegram,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showMatchDetail(BuildContext context, LikeEntry entry) {
  final photos = <String>[
    ...?entry.targetCard?.imageUrls,
    ...?entry.card?.imageUrls,
  ];
  ImagePrefetch.warmAll(context, photos, role: FastImageRole.detail);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _MatchDetailSheet(entry: entry),
  );
}

class _MatchDetailSheet extends StatefulWidget {
  const _MatchDetailSheet({required this.entry});

  final LikeEntry entry;

  @override
  State<_MatchDetailSheet> createState() => _MatchDetailSheetState();
}

class _MatchDetailSheetState extends State<_MatchDetailSheet> {
  PrivateContact? _contact;
  _ContactChannel? _opening;

  LikeEntry get entry => widget.entry;

  Future<PrivateContact?> _ensureContact() async {
    if (_contact != null) return _contact;
    final shareReady = await ensureContactShareForChat(context);
    if (!shareReady || !mounted) return null;
    try {
      final contact = await ContactService().unlock(
        domain: entry.domain,
        targetUid: entry.otherUid,
      );
      if (!mounted) return null;
      if (contact == null) {
        await _showContactActionDialog(
          context,
          'Their WhatsApp is not saved yet. Ask them to open the app once.',
        );
        return null;
      }
      setState(() => _contact = contact);
      return contact;
    } catch (error) {
      if (!mounted) return null;
      final message = error is StateError
          ? error.message
          : 'Could not unlock chat. Check phone verification.';
      await _showContactActionDialog(context, message);
      return null;
    }
  }

  Future<void> _openWhatsApp() async {
    if (_opening != null) return;
    setState(() => _opening = _ContactChannel.whatsapp);
    try {
      final contact = await _ensureContact();
      if (contact == null || !mounted) return;
      await context.read<LikesStore>().signalChatOpened(
        entry.domain,
        entry.otherUid,
      );
      final label = AppDomains.byId(entry.domain).label;
      final opened = await ContactService().openWhatsApp(
        contact.whatsappNumber,
        domainLabel: label,
      );
      if (!mounted) return;
      if (!opened) {
        await _showContactActionDialog(
          context,
          'Could not open WhatsApp — number & message copied. '
          'Is WhatsApp installed?',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _openTelegram() async {
    if (_opening != null) return;
    setState(() => _opening = _ContactChannel.telegram);
    try {
      final contact = await _ensureContact();
      if (contact == null || !mounted) return;
      final handle = contact.telegramHandle?.trim() ?? '';
      final phone = contact.whatsappNumber;
      if (handle.isEmpty && cleanWhatsAppDigits(phone).length < 8) {
        await _showContactActionDialog(context, 'No Telegram number yet');
        return;
      }
      await context.read<LikesStore>().signalChatOpened(
        entry.domain,
        entry.otherUid,
      );
      final label = AppDomains.byId(entry.domain).label;
      final opened = await ContactService().openTelegram(
        handle: handle.isEmpty ? null : handle,
        phoneDigits: phone,
        domainLabel: label,
      );
      if (!mounted) return;
      if (!opened) {
        await _showContactActionDialog(
          context,
          'Could not open Telegram — message copied to paste',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = AppDomains.byId(entry.domain);
    final theme = Theme.of(context);
    final theirTitle = LikeDisplay.rowTitle(entry.card);
    final city = entry.card?.cityLabel.trim() ?? '';
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      LikeDisplay.matchSectionTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: policy.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        policy.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: policy.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MatchHero(
                  card: entry.card,
                  seed: entry.otherUid.hashCode,
                ),
                const SizedBox(height: 12),
                Text(
                  theirTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    city,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _YourPostChip(
                  card: entry.targetCard,
                  seed: (entry.targetCard?.id ?? entry.otherUid).hashCode,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MatchWhatsAppButton(
                        busy: _opening == _ContactChannel.whatsapp,
                        enabled: _opening == null,
                        onPressed: _openWhatsApp,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MatchTelegramIconButton(
                      busy: _opening == _ContactChannel.telegram,
                      enabled: _opening == null,
                      onPressed: _openTelegram,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: Key(
                    'match_detail_delete_${entry.domain.name}_${entry.otherUid}',
                  ),
                  onPressed: () async {
                    final likes = context.read<LikesStore>();
                    Navigator.of(context).pop();
                    await _deleteMatchRow(
                      context,
                      likes: likes,
                      entry: entry,
                    );
                  },
                  child: Text(
                    LikeDisplay.deleteMatchLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LikeRow extends StatelessWidget {
  const _LikeRow({
    required this.entry,
    required this.mutual,
    required this.onOpen,
    required this.onRemove,
  });

  final LikeEntry entry;
  final bool mutual;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final inbound = entry.direction == LikeDirection.inbound;
    final policy = AppDomains.byId(entry.domain);
    return AppInkWell(
      color: policy.softColor.withValues(alpha: .35),
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inbound)
            _DualLikeThumbs(entry: entry)
          else
            _LikeThumb(card: entry.card, seed: entry.otherUid.hashCode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inbound) ...[
                  Text(
                    '${LikeDisplay.yourPostLabel} · ${LikeDisplay.rowTitle(entry.targetCard ?? entry.card)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${LikeDisplay.likedByLabel} · ${LikeDisplay.rowTitle(entry.card)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ] else
                  _LikeTitleBlock(card: entry.card),
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
                      mutual ? LikeConsent.listMutual : LikeConsent.listWaiting,
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
          IconButton(
            key: Key(
              'like_remove_${entry.direction.name}_${entry.domain.name}_${entry.otherUid}',
            ),
            tooltip: LikeConsent.removeTooltip,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _LikeTitleBlock extends StatelessWidget {
  const _LikeTitleBlock({required this.card});

  final DiscoveryCardModel? card;

  @override
  Widget build(BuildContext context) {
    final resolved = card;
    final blank = LikeDisplay.isPlaceholderCard(resolved);
    final title = LikeDisplay.rowTitle(resolved);
    if (blank) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            LikeDisplay.missingListing,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      );
    }
    if (resolved == null) {
      return Text(title, style: Theme.of(context).textTheme.titleSmall);
    }
    return ListingMeta(card: resolved, compact: true);
  }
}

class _DualLikeThumbs extends StatelessWidget {
  const _DualLikeThumbs({required this.entry, this.compact = false});

  final LikeEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final box = compact ? 56.0 : 72.0;
    final thumb = compact ? 38.0 : 48.0;
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _LikeThumb(
              card: entry.targetCard,
              seed: (entry.targetCard?.id ?? entry.otherUid).hashCode,
              size: thumb,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _LikeThumb(
                card: entry.card,
                seed: entry.otherUid.hashCode,
                size: thumb,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHero extends StatelessWidget {
  const _MatchHero({required this.card, required this.seed});

  final DiscoveryCardModel? card;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final photos = card?.imageUrls ?? const <String>[];
    final title = LikeDisplay.rowTitle(card);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220, maxWidth: 220),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: photos.isEmpty
                ? const _BlankLikeHero()
                : PhotoGalleryPager(
                    children: photos
                        .map(
                          (url) => _LikePhoto(
                            url: url,
                            label: title,
                            seed: seed,
                            role: FastImageRole.detail,
                            blankWhenMissing: true,
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ),
      ),
    );
  }
}

class _YourPostChip extends StatelessWidget {
  const _YourPostChip({required this.card, required this.seed});

  final DiscoveryCardModel? card;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = LikeDisplay.rowTitle(card);
    return Material(
      key: const Key('match_your_post_chip'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            _LikeThumb(card: card, seed: seed, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LikeDisplay.yourPostLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchWhatsAppButton extends StatelessWidget {
  const _MatchWhatsAppButton({
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF25D366);
    return FilledButton.icon(
      key: const Key('match_whatsapp_btn'),
      onPressed: enabled && !busy ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: green.withValues(alpha: .45),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.chat, size: 18),
      label: const Text('WhatsApp'),
    );
  }
}

class _MatchTelegramIconButton extends StatelessWidget {
  const _MatchTelegramIconButton({
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF229ED9);
    return IconButton.outlined(
      key: const Key('match_telegram_btn'),
      onPressed: enabled && !busy ? onPressed : null,
      tooltip: 'Telegram',
      style: IconButton.styleFrom(
        foregroundColor: blue,
        side: BorderSide(color: blue.withValues(alpha: .55)),
        minimumSize: const Size(48, 48),
      ),
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: blue),
            )
          : const Icon(Icons.send, size: 20),
    );
  }
}

class _LikeThumb extends StatelessWidget {
  const _LikeThumb({required this.card, required this.seed, this.size = 72});

  final DiscoveryCardModel? card;
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = card?.imageUrls.isNotEmpty == true
        ? card!.imageUrls.first
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _LikePhoto(
              url: photo ?? '',
              label: LikeDisplay.rowTitle(card),
              seed: seed,
              blankWhenMissing: true,
            ),
            if ((card?.imageUrls.length ?? 0) > 1)
              Positioned(
                right: 4,
                bottom: 4,
                child: PhotoExtraBadge(extraCount: card!.imageUrls.length - 1),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlankLikeHero extends StatelessWidget {
  const _BlankLikeHero({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ColoredBox(
        color: AppColors.darkCream,
        child: CustomPaint(
          painter: _DashedRectPainter(
            color: AppColors.muted.withValues(alpha: .45),
            radius: 12,
          ),
          child: const Center(
            child: Icon(Icons.image_outlined, color: AppColors.muted, size: 22),
          ),
        ),
      );
    }
    return CustomPaint(
      painter: _DashedRectPainter(
        color: AppColors.muted.withValues(alpha: .45),
      ),
      child: const ColoredBox(
        color: AppColors.darkCream,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, color: AppColors.muted, size: 40),
              SizedBox(height: 8),
              Text(
                LikeDisplay.noPhotoYet,
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, this.radius = 16});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _LikePhoto extends StatelessWidget {
  const _LikePhoto({
    required this.url,
    required this.label,
    required this.seed,
    this.role = FastImageRole.thumb,
    this.blankWhenMissing = false,
  });

  final String url;
  final String label;
  final int seed;
  final FastImageRole role;
  final bool blankWhenMissing;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return blankWhenMissing
          ? const _BlankLikeHero(compact: true)
          : _SyntheticArtwork(label: label, seed: seed);
    }
    final fallback = blankWhenMissing
        ? const _BlankLikeHero(compact: true)
        : _SyntheticArtwork(label: label, seed: seed);
    return FastNetworkImage(
      url: trimmed,
      role: role,
      fit: BoxFit.cover,
      fallback: fallback,
      placeholderColor: AppColors.darkCream,
    );
  }
}

Future<void> _showLikeDetail(BuildContext context, LikeEntry entry) {
  final photos = <String>[
    ...?entry.targetCard?.imageUrls,
    ...?entry.card?.imageUrls,
  ];
  ImagePrefetch.warmAll(context, photos, role: FastImageRole.detail);
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

  /// Which contact button is busy (only that one shows a spinner).
  _ContactChannel? _opening;
  bool _likingBack = false;

  LikeEntry get entry => widget.entry;

  Future<void> _likeBack() async {
    if (_likingBack) return;
    final likes = context.read<LikesStore>();
    if (likes.isMutual(entry.domain, entry.otherUid)) return;
    setState(() => _likingBack = true);
    try {
      final ready = await ensurePhoneVerifiedForAction(context);
      if (!ready || !mounted) return;
      final card =
          entry.card ??
          DiscoveryCardModel(
            id: entry.otherUid,
            domain: entry.domain,
            ownerId: entry.otherUid,
            title: LikeDisplay.placeholderTitle,
            subtitle: '',
            cityId: '',
            cityLabel: '',
            categoryTags: const <String>[],
            imageUrls: const <String>[],
          );
      final mutual = await likes.like(
        entry.domain,
        entry.otherUid,
        snapshot: card,
        fromCard: _ownCardForDomain(context, entry.domain),
      );
      if (!mounted) return;
      if (mutual) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(LikeConsent.mutualSnack)));
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : LikeConsent.acceptFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _likingBack = false);
    }
  }

  Future<PrivateContact?> _ensureContact() async {
    if (_contact != null) return _contact;
    final likes = context.read<LikesStore>();
    if (!likes.isMutual(entry.domain, entry.otherUid)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(LikeConsent.acceptFirst)));
      return null;
    }
    final shareReady = await ensureContactShareForChat(context);
    if (!shareReady || !mounted) return null;
    try {
      final contact = await ContactService().unlock(
        domain: entry.domain,
        targetUid: entry.otherUid,
      );
      if (!mounted) return null;
      if (contact == null) {
        await _showContactActionDialog(
          context,
          'Their WhatsApp is not saved yet. Ask them to open the app once.',
        );
        return null;
      }
      setState(() => _contact = contact);
      return contact;
    } catch (error) {
      if (!mounted) return null;
      final message = error is StateError
          ? error.message
          : 'Could not unlock chat. Check phone verification.';
      await _showContactActionDialog(context, message);
      return null;
    }
  }

  Future<void> _openWhatsApp() async {
    if (_opening != null) return;
    setState(() => _opening = _ContactChannel.whatsapp);
    try {
      final contact = await _ensureContact();
      if (contact == null || !mounted) return;
      final likes = context.read<LikesStore>();
      await likes.signalChatOpened(entry.domain, entry.otherUid);
      final label = AppDomains.byId(entry.domain).label;
      final opened = await ContactService().openWhatsApp(
        contact.whatsappNumber,
        domainLabel: label,
      );
      if (!mounted) return;
      if (!opened) {
        await _showContactActionDialog(
          context,
          'Could not open WhatsApp — number & message copied. '
          'Is WhatsApp installed?',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _openTelegram() async {
    if (_opening != null) return;
    setState(() => _opening = _ContactChannel.telegram);
    try {
      final contact = await _ensureContact();
      if (contact == null || !mounted) return;
      final handle = contact.telegramHandle?.trim() ?? '';
      final phone = contact.whatsappNumber;
      if (handle.isEmpty && cleanWhatsAppDigits(phone).length < 8) {
        await _showContactActionDialog(context, 'No Telegram number yet');
        return;
      }
      final likes = context.read<LikesStore>();
      await likes.signalChatOpened(entry.domain, entry.otherUid);
      final label = AppDomains.byId(entry.domain).label;
      final opened = await ContactService().openTelegram(
        handle: handle.isEmpty ? null : handle,
        phoneDigits: phone,
        domainLabel: label,
      );
      if (!mounted) return;
      if (!opened) {
        await _showContactActionDialog(
          context,
          'Could not open Telegram — message copied to paste',
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final likes = context.watch<LikesStore>();
    final policy = AppDomains.byId(entry.domain);
    final mutual = likes.isMutual(entry.domain, entry.otherUid);
    final chatActive = likes.chatIconsActive(entry.domain, entry.otherUid);
    final alreadyLiked = likes.outbound(entry.domain).contains(entry.otherUid);
    final inbound = entry.direction == LikeDirection.inbound;
    final likerCard = entry.card;
    final yourPost = inbound ? (entry.targetCard ?? entry.card) : entry.card;
    final statusText = mutual || chatActive
        ? LikeConsent.mutualDetail
        : inbound
        ? LikeConsent.inboundHint
        : LikeConsent.outboundWaiting;

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
              border: Border(left: BorderSide(color: policy.color, width: 4)),
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
                  if (inbound) ...[
                    _LikeDetailBlock(
                      label: LikeDisplay.yourPostLabel,
                      card: yourPost,
                      seed: (yourPost?.id ?? entry.otherUid).hashCode,
                    ),
                    const SizedBox(height: 16),
                    _LikeDetailBlock(
                      label: LikeDisplay.likedByLabel,
                      card: likerCard,
                      seed: entry.otherUid.hashCode,
                    ),
                  ] else
                    _LikeDetailBlock(
                      label: null,
                      card: entry.card,
                      seed: entry.otherUid.hashCode,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: chatActive
                          ? CardSideMark.supplyColor
                          : AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (inbound && !alreadyLiked) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('like_accept_button'),
                      onPressed: _likingBack ? null : _likeBack,
                      icon: _likingBack
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.favorite),
                      label: Text(
                        _likingBack
                            ? LikeConsent.acceptingCta
                            : LikeConsent.acceptCta,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ContactActionButton(
                          label: 'WhatsApp',
                          icon: Icons.chat,
                          color: const Color(0xFF25D366),
                          enabled: chatActive && _opening == null,
                          locked: !chatActive,
                          busy: _opening == _ContactChannel.whatsapp,
                          onPressed: _openWhatsApp,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ContactActionButton(
                          label: 'Telegram',
                          icon: Icons.send,
                          color: const Color(0xFF229ED9),
                          enabled: chatActive && _opening == null,
                          locked: !chatActive,
                          busy: _opening == _ContactChannel.telegram,
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

class _LikeDetailBlock extends StatelessWidget {
  const _LikeDetailBlock({
    required this.label,
    required this.card,
    required this.seed,
  });

  final String? label;
  final DiscoveryCardModel? card;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final photos = card?.imageUrls ?? const <String>[];
    final placeholder = LikeDisplay.isPlaceholderCard(card);
    final title = LikeDisplay.rowTitle(card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: photos.isEmpty
                ? const _BlankLikeHero()
                : PhotoGalleryPager(
                    children: photos
                        .map(
                          (url) => _LikePhoto(
                            url: url,
                            label: title,
                            seed: seed,
                            role: FastImageRole.detail,
                            blankWhenMissing: true,
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (placeholder) ...[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            LikeDisplay.missingListing,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ],
        ] else if (card != null)
          ListingMeta(card: card!),
      ],
    );
  }
}

enum _ContactChannel { whatsapp, telegram }

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
                    locked ? LikeConsent.bothNeeded : 'Please wait…',
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
    final posts = _ownedPosts(context);
    final photoUrl = identity.identity.photoUrls.isNotEmpty
        ? identity.identity.photoUrls.first
        : null;
    final canPostMore = AppDomains.all.any(
      (domain) => domain.enabled && _domainCanAddPost(context, domain.id),
    );
    final name = identity.identity.displayName.trim();
    final city = identity.identity.cityLabel.trim();
    final verified = identity.identity.phoneVerified;
    return _Page(
      title: 'Me',
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: () => showSettingsSheet(context),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HubSectionHeader(title: 'Account', icon: Icons.person_outline),
          _MeHubRow(
            key: const Key('me_account_row'),
            onTap: () => showIdentityForm(context),
            leading: _IdentityAvatar(photoUrl: photoUrl),
            title: name.isNotEmpty ? name : 'Account',
            subtitle: verified
                ? (city.isNotEmpty ? city : 'Phone verified')
                : 'Verify phone',
            trailing: verified
                ? const Icon(Icons.verified, color: Color(0xFF059669), size: 22)
                : null,
          ),
          const SizedBox(height: 16),
          _HubSectionHeader(
            title: 'Posts',
            icon: Icons.campaign_outlined,
            count: posts.length,
          ),
          if (posts.isEmpty)
            _MeHubRow(
              key: const Key('me_posts_empty'),
              onTap: () => _showNewPostPicker(context),
              leading: CircleAvatar(
                radius: _IdentityAvatar.radius,
                backgroundColor: AppColors.surface,
                child: Icon(
                  Icons.campaign_outlined,
                  size: _IdentityAvatar.radius * 0.9,
                  color: AppColors.muted,
                ),
              ),
              title: 'Add one',
            )
          else ...[
            for (final policy in AppDomains.all)
              if (posts.any((p) => p.domain == policy.id))
                ExpandableDomainSection(
                  sectionKey: Key('me_domain_${policy.id.name}'),
                  domain: policy,
                  count: posts.where((p) => p.domain == policy.id).length,
                  icon: _domainIcons[policy.id] ?? Icons.circle,
                  children: [
                    for (final post in posts.where(
                      (p) => p.domain == policy.id,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OwnedPostRow(
                          post: post,
                          onOpen: () => _showOwnedPostDetail(context, post),
                        ),
                      ),
                  ],
                ),
            if (canPostMore)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MeHubRow(
                  onTap: () => _showNewPostPicker(context),
                  leading: CircleAvatar(
                    radius: _IdentityAvatar.radius,
                    backgroundColor: AppColors.surface,
                    child: Icon(
                      Icons.add_circle_outline,
                      size: _IdentityAvatar.radius * 0.9,
                      color: AppColors.rose,
                    ),
                  ),
                  title: 'Add one',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MeHubRow extends StatelessWidget {
  const _MeHubRow({
    required this.onTap,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppInkWell(
      color: AppColors.darkCream.withValues(alpha: .45),
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          leading,
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
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(right: 4), child: trailing),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _HubSectionHeader extends StatelessWidget {
  const _HubSectionHeader({required this.title, this.icon, this.count});

  final String title;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: AppColors.rose),
            const SizedBox(width: 8),
          ],
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (count != null) ...[
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
        ],
      ),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({this.photoUrl});

  final String? photoUrl;
  static const double radius = 32;
  static const double _radius = radius;

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
        child: FastNetworkImage(
          url: url,
          role: FastImageRole.thumb,
          fit: BoxFit.cover,
          placeholderColor: AppColors.darkCream,
          fallback: CircleAvatar(
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

void _watchPostStores(BuildContext context) {
  context.watch<ProfileStore>();
  context.watch<JobsOfferStore>();
  context.watch<KuwaitJobsOfferStore>();
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
    jobs: context.read<JobsOfferStore>(),
    kuwaitJobs: context.read<KuwaitJobsOfferStore>(),
    rooms: context.read<RoomsOfferStore>(),
    bikes: context.read<BikesOfferStore>(),
    homeHelp: context.read<HomeHelpOfferStore>(),
    media: context.read<OwnedListingCache>(),
    publisher: context.read<ListingPublisher>(),
  );
}

/// Best local listing for inbound "who liked you" snapshots (prefer photos).
DiscoveryCardModel? _ownCardForDomain(
  BuildContext context,
  AppDomainId domain,
) {
  final posts = _ownedPosts(
    context,
  ).where((p) => p.domain == domain && p.card.active).toList(growable: false);
  if (posts.isEmpty) return null;
  for (final post in posts) {
    if (post.card.imageUrls.isNotEmpty) return post.card;
  }
  return posts.first.card;
}

int _domainPostCount(BuildContext context, AppDomainId id) {
  switch (id) {
    case AppDomainId.marriage:
      return context.read<ProfileStore>().value != null ? 1 : 0;
    case AppDomainId.jobs:
      return context.read<JobsOfferStore>().offers.length;
    case AppDomainId.kuwaitJobs:
      return context.read<KuwaitJobsOfferStore>().offers.length;
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

Future<void> _showOwnedPostDetail(BuildContext hostContext, OwnedPost post) {
  return showModalBottomSheet<void>(
    context: hostContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _OwnedPostDetailSheet(post: post, hostContext: hostContext),
  );
}

class _OwnedPostRow extends StatelessWidget {
  const _OwnedPostRow({required this.post, required this.onOpen});

  final OwnedPost post;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final card = post.card;
    final title = cardTitleLine(card);
    final photo = card.imageUrls.isNotEmpty ? card.imageUrls.first : null;
    final policy = AppDomains.byId(post.domain);
    return AppInkWell(
      color: policy.softColor.withValues(alpha: .35),
      onTap: onOpen,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: photo == null
                  ? _SyntheticArtwork(label: title, seed: card.id.hashCode)
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
                ListingMeta(card: card, compact: true),
                if (post.paused) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Paused',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
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
    );
  }
}

class _OwnedPostDetailSheet extends StatefulWidget {
  const _OwnedPostDetailSheet({required this.post, required this.hostContext});

  final OwnedPost post;
  final BuildContext hostContext;

  @override
  State<_OwnedPostDetailSheet> createState() => _OwnedPostDetailSheetState();
}

class _OwnedPostDetailSheetState extends State<_OwnedPostDetailSheet> {
  late OwnedPost _post;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  Widget build(BuildContext context) {
    final policy = AppDomains.byId(_post.domain);
    final card = _post.card;
    final title = cardTitleLine(card);
    final photos = card.imageUrls;
    final paused = _post.paused;

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
              border: Border(left: BorderSide(color: policy.color, width: 4)),
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
                      if (paused) ...[
                        const Spacer(),
                        Text(
                          'Paused',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
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
                                      role: FastImageRole.detail,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListingMeta(card: card),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: policy.color,
                    ),
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.pop(context);
                            showDomainProfileForm(
                              widget.hostContext,
                              policy,
                              edit: _post,
                            );
                          },
                    child: const Text('Edit'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.pop(context);
                            _showGrowthSheet(widget.hostContext);
                          },
                    child: const Text('Get more views'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => unawaited(_togglePause()),
                    child: Text(paused ? 'Resume' : 'Pause'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_confirmDelete()),
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.muted),
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

  Future<void> _togglePause() async {
    final messenger = ScaffoldMessenger.of(widget.hostContext);
    final media = widget.hostContext.read<OwnedListingCache>();
    final nextPaused = !_post.paused;
    setState(() => _busy = true);
    try {
      await ListingLifecycleService().setPaused(
        post: _post,
        paused: nextPaused,
        media: media,
      );
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(card: _post.card.copyWith(active: !nextPaused));
        _busy = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(nextPaused ? 'Paused' : 'Live again')),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final host = widget.hostContext;
    final messenger = ScaffoldMessenger.of(host);
    final media = host.read<OwnedListingCache>();
    final marriage = host.read<ProfileStore>();
    final jobs = host.read<JobsOfferStore>();
    final kuwaitJobs = host.read<KuwaitJobsOfferStore>();
    final rooms = host.read<RoomsOfferStore>();
    final bikes = host.read<BikesOfferStore>();
    final homeHelp = host.read<HomeHelpOfferStore>();
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text("You can't undo."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ListingLifecycleService().deletePost(
        post: _post,
        media: media,
        marriage: marriage,
        jobs: jobs,
        kuwaitJobs: kuwaitJobs,
        rooms: rooms,
        bikes: bikes,
        homeHelp: homeHelp,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete. Try again.')),
      );
    }
  }
}

Future<void> _showNewPostPicker(BuildContext hostContext) {
  return showModalBottomSheet<void>(
    context: hostContext,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      _watchPostStores(sheetContext);
      final open = AppDomains.all
          .where(
            (domain) =>
                domain.enabled && _domainCanAddPost(sheetContext, domain.id),
          )
          .toList(growable: false);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New post',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (open.isEmpty)
                Text(
                  'All post slots are full.',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                )
              else
                ...open.map(
                  (domain) => _DomainAdRow(
                    domain: domain,
                    subtitle: _domainPostSubtitle(sheetContext, domain),
                    trailing: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.muted,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      // Must use host (Me) context — sheet context is disposed after pop.
                      showDomainProfileForm(hostContext, domain);
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
            style: TextStyle(color: domain.color, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            subtitle ?? domainPostLine(domain.id, l10n),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
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
  AppDomainId.kuwaitJobs: Icons.engineering,
  AppDomainId.rooms: Icons.hotel,
  AppDomainId.bikes: Icons.pedal_bike,
  AppDomainId.homeHelp: Icons.cleaning_services,
};

Future<void> _showGrowthSheet(
  BuildContext context,
) => showModalBottomSheet<void>(
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
  Widget build(BuildContext context) {
    final domain = context.watch<DomainController>().policy;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: domain.softSurface.withValues(alpha: .95),
          title: DomainPageTitle(
            title: title,
            subtitle: domain.label,
            subtitleColor: domain.color,
            subtitleKey: const Key('page_domain_label'),
          ),
          actions: [
            DomainSwitcherButton(
              color: domain.color,
              onPressed: () => showDomainDial(context),
            ),
            ...?actions,
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
  }
}

class EmptyBrowseFeed extends StatelessWidget {
  const EmptyBrowseFeed({
    required this.domainLabel,
    required this.hasFilters,
    required this.onReset,
    required this.onChangeDomain,
    this.onClearFilters,
    super.key,
  });

  final String domainLabel;
  final bool hasFilters;
  final VoidCallback onReset;
  final VoidCallback onChangeDomain;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.travel_explore, size: 54),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'Nothing in $domainLabel matches your filters.'
                : 'Nothing in $domainLabel right now.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (onClearFilters != null) ...[
            FilledButton(
              key: const Key('empty_clear_filters'),
              onPressed: onClearFilters,
              child: const Text('Clear filters'),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.tonal(
            onPressed: onReset,
            child: const Text('Show again'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('empty_change_domain'),
            onPressed: onChangeDomain,
            child: const Text('Change domain'),
          ),
        ],
      ),
    ),
  );
}

class BrowseFeedLoading extends StatelessWidget {
  const BrowseFeedLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading…'),
        ],
      ),
    ),
  );
}

class BrowseFeedError extends StatelessWidget {
  const BrowseFeedError({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 54),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('feed_retry'),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

/// Visible labels for active Browse filters (city / gender / age / role / trade).
List<String> browseActiveFilterLabels({
  required AppDomainId domainId,
  required MatchPreferencesStore match,
  required JobsDiscoverPrefsStore jobs,
  required KuwaitJobsDiscoverPrefsStore kuwaitJobs,
}) {
  final labels = <String>[];
  if (domainId == AppDomainId.kuwaitJobs) {
    final country = kuwaitJobs.countryId;
    if (country != null && country.isNotEmpty) {
      labels.add(KuwaitJobsProfile.countryLabels[country] ?? country);
    }
    final role = kuwaitJobs.role;
    if (role != null && role.isNotEmpty) {
      labels.add(KuwaitJobsProfile.roleLabel(role));
    }
    final trade = kuwaitJobs.tradeId;
    if (trade != null && trade.isNotEmpty) labels.add(trade);
    final nationality = kuwaitJobs.nationality;
    if (nationality != null && nationality.isNotEmpty) labels.add(nationality);
    final experience = kuwaitJobs.experienceBand;
    if (experience != null && experience.isNotEmpty) labels.add(experience);
    return labels;
  }
  if (domainId == AppDomainId.jobs) {
    final city = jobs.cityId;
    if (city != null && city.isNotEmpty) {
      labels.add(cityLabels[city] ?? city);
    }
    final role = jobs.role;
    if (role != null && role.isNotEmpty) {
      labels.add(JobsProfile.roleLabel(role));
    }
    final trade = jobs.tradeId;
    if (trade != null && trade.isNotEmpty) labels.add(trade);
    return labels;
  }
  final city = match.cityId;
  if (city != null && city.isNotEmpty) {
    labels.add(cityLabels[city] ?? city);
  }
  if (domainId == AppDomainId.marriage) {
    final gender = match.gender;
    if (gender != null && gender.isNotEmpty) labels.add(gender);
    final age = match.ageBand;
    if (age != null && age.isNotEmpty) labels.add(age);
  }
  return labels;
}

void _clearBrowseFilters(BuildContext context, AppDomainId domainId) {
  if (domainId == AppDomainId.kuwaitJobs) {
    context.read<KuwaitJobsDiscoverPrefsStore>().clear();
  } else if (domainId == AppDomainId.jobs) {
    context.read<JobsDiscoverPrefsStore>().clear();
  } else {
    context.read<MatchPreferencesStore>().clear();
  }
}

Future<void> _showFilters(BuildContext context, DomainPolicy domain) async {
  final match = context.read<MatchPreferencesStore>();
  final jobs = context.read<JobsDiscoverPrefsStore>();
  final kuwaitJobs = context.read<KuwaitJobsDiscoverPrefsStore>();
  String? city = domain.id == AppDomainId.jobs ? jobs.cityId : match.cityId;
  String? country = kuwaitJobs.countryId;
  String? gender = match.gender;
  String? age = match.ageBand;
  String? role = domain.id == AppDomainId.kuwaitJobs
      ? kuwaitJobs.role
      : jobs.role;
  String? trade = domain.id == AppDomainId.kuwaitJobs
      ? kuwaitJobs.tradeId
      : jobs.tradeId;
  String? nationality = kuwaitJobs.nationality;
  String? experience = kuwaitJobs.experienceBand;
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
              if (domain.id == AppDomainId.kuwaitJobs) ...[
                DropdownButtonFormField<String?>(
                  initialValue: country,
                  decoration: const InputDecoration(labelText: 'Country'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    ...KuwaitJobsProfile.countryIds.map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(KuwaitJobsProfile.countryLabels[v] ?? v),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => country = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Looking for'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    ...KuwaitJobsProfile.roles.map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(KuwaitJobsProfile.roleLabel(v)),
                      ),
                    ),
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
                    ...KuwaitJobsProfile.trades.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => setState(() => trade = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: nationality,
                  decoration: const InputDecoration(labelText: 'Nationality'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    ...KuwaitJobsProfile.nationalities.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => setState(() => nationality = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: experience,
                  decoration: const InputDecoration(labelText: 'Experience'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    ...KuwaitJobsProfile.experienceBands.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => setState(() => experience = v),
                ),
              ] else ...[
                CityFilterDropdown(
                  value: city,
                  onChanged: (v) => setState(() => city = v),
                ),
                if (domain.id == AppDomainId.marriage) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      ...MarriageProfile.genders.map(
                        (v) => DropdownMenuItem(value: v, child: Text(v)),
                      ),
                    ],
                    onChanged: (v) => setState(() => gender = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: age,
                    decoration: const InputDecoration(labelText: 'Age band'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      ...MarriageProfile.ageBands.map(
                        (v) => DropdownMenuItem(value: v, child: Text(v)),
                      ),
                    ],
                    onChanged: (v) => setState(() => age = v),
                  ),
                ],
                if (domain.id == AppDomainId.jobs) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Looking for'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      ...JobsProfile.roles.map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(JobsProfile.roleLabel(v)),
                        ),
                      ),
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
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (domain.id == AppDomainId.kuwaitJobs) {
                    kuwaitJobs.update(
                      country: country,
                      roleValue: role,
                      trade: trade,
                      nationalityValue: nationality,
                      experience: experience,
                    );
                  } else if (domain.id == AppDomainId.jobs) {
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

Future<void> showMatchDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: const Icon(Icons.favorite, color: AppColors.rose, size: 42),
    title: const Text('Both interested'),
    content: const Text(
      'Both interested — open WhatsApp from Likes. '
      'Verify your phone with one code first.',
      textAlign: TextAlign.center,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: () {
          final domains = dialogContext.read<DomainController>();
          Navigator.pop(dialogContext);
          domains.selectTab(1); // Likes
        },
        child: const Text('Continue'),
      ),
    ],
  ),
);

Future<void> _showMatch(BuildContext context, DiscoveryCardModel card) =>
    showMatchDialog(context);

Future<void> showSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final locale = sheetContext.watch<LocaleController>();
        final identity = sheetContext.watch<IdentityStore>().identity;
        final photoUrl = identity.photoUrls.isNotEmpty
            ? identity.photoUrls.first
            : null;
        final name = identity.displayName.trim();
        final phone = identity.whatsappNumber.trim();
        final phoneParts = phone.isEmpty ? null : splitStoredPhone(phone);
        final phoneLabel = phoneParts == null
            ? (identity.phoneVerified ? 'Phone verified' : 'Not signed in')
            : '${phoneParts.dial.label} ${phoneParts.national}';
        // Bound height so SingleChildScrollView can scroll; without this,
        // Sign out (below Delete account) is clipped on short phones.
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  const SizedBox(height: 16),
                  Material(
                    key: const Key('settings_account_card'),
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.muted.withValues(alpha: .18),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        children: [
                          _IdentityAvatar(photoUrl: photoUrl),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isNotEmpty ? name : 'Account',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phoneLabel,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Language',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
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
                    onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPageScreen.terms(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPageScreen.privacy(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Delete account'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(sheetContext).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPageScreen.dataDeletion(),
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  ListTile(
                    key: const Key('settings_sign_out'),
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              key: const Key('settings_sign_out_confirm'),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Sign out'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !sheetContext.mounted) return;
                      await signOutLocalSession(sheetContext);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signed out')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );

Future<void> showDomainProfileForm(
  BuildContext context,
  DomainPolicy domain, {
  OwnedPost? edit,
}) async {
  final ready = await ensurePhoneVerifiedForAction(context);
  if (!ready || !context.mounted) return;
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
      case AppDomainId.kuwaitJobs:
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
      final index =
          offerIndex ??
          activeEdit?.offerIndex ??
          (switch (domain.id) {
            AppDomainId.jobs =>
              context.read<JobsOfferStore>().offers.length - 1,
            AppDomainId.kuwaitJobs =>
              context.read<KuwaitJobsOfferStore>().offers.length - 1,
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

  media.onUrlsChanged = (urls) =>
      rememberMedia(offerIndex: activeEdit?.offerIndex);

  if (activeEdit != null) {
    media.seedUrls(activeEdit.card.imageUrls);
  }

  final requireFace =
      domain.id == AppDomainId.marriage ||
      domain.id == AppDomainId.jobs ||
      domain.id == AppDomainId.kuwaitJobs;

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
      SnackBar(content: const Text('Saved'), backgroundColor: domain.color),
    );
  }

  final marriageInitial = activeEdit?.domain == AppDomainId.marriage
      ? context.read<ProfileStore>().value
      : null;
  final jobsInitial = activeEdit != null
      ? jobsFromOwned(activeEdit, context.read<JobsOfferStore>())
      : null;
  final kuwaitJobsInitial = activeEdit != null
      ? kuwaitJobsFromOwned(activeEdit, context.read<KuwaitJobsOfferStore>())
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
                onAfterSave: (profile) async {
                  await publisher.publishJobs(
                    ownerId: publishOwnerId(),
                    profile: profile,
                    offerId: offerId,
                    photoUrls: List<String>.from(media.urls),
                  );
                  await rememberMedia(offerIndex: activeEdit?.offerIndex);
                },
              ),
              AppDomainId.kuwaitJobs => KuwaitJobsForm(
                initial: kuwaitJobsInitial,
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
                onAfterSave: (profile) async {
                  await publisher.publishKuwaitJobs(
                    ownerId: publishOwnerId(),
                    profile: profile,
                    offerId: offerId,
                    photoUrls: List<String>.from(media.urls),
                  );
                  await rememberMedia(offerIndex: activeEdit?.offerIndex);
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
