import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/app_domain.dart';
import '../models/discovery_card.dart';
import '../models/domain_profiles.dart';
import '../services/account_services.dart';
import '../services/contact_service.dart';
import '../services/firebase_bootstrap.dart';
import '../services/form_media_controller.dart';
import '../services/listing_publisher.dart';
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
import '../widgets/forms/rooms_form.dart';
import '../widgets/onboarding/otp_sheet.dart';
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
          content: Text('Long-press the radio to tune into another domain.'),
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
    final domain = context.read<DomainController>().selected;
    await identity.bindUserId(uid);
    if (!mounted) return;
    await blocks.hydrateRemote();
    if (!mounted) return;
    await likes.hydrate(domain);
    await PushService().initialize(uid: uid);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DomainController>();
    final l10n = AppLocalizations.of(context);
    final pages = <Widget>[
      const DiscoverScreen(),
      const LikesScreen(),
      const MeScreen(),
      const GuideScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: IndexedStack(index: controller.selectedTab, children: pages),
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
                message: 'Long-press to tune domains',
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
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: l10n.text('guide'),
          ),
        ],
      ),
    );
  }
}

Future<void> showDomainDial(BuildContext context) async {
  final controller = context.read<DomainController>();
  unawaited(AudioPlayer().play(AssetSource('audio/rotary.wav'), volume: .35));
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tune your world',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'One account. Independent profiles for every part of life.',
            ),
            const SizedBox(height: 18),
            ...AppDomains.all.map(
              (domain) => Semantics(
                label:
                    '${domain.label}, ${domain.frequency} FM'
                    '${domain.enabled ? '' : ', coming soon'}',
                child: ListTile(
                  enabled: domain.enabled,
                  leading: CircleAvatar(
                    backgroundColor: domain.color.withValues(alpha: .14),
                    child: Icon(Icons.graphic_eq, color: domain.color),
                  ),
                  title: Text(domain.label),
                  subtitle: Text(
                    '${domain.frequency.toStringAsFixed(1)} FM'
                    '${domain.enabled ? '' : '  •  Coming soon'}',
                  ),
                  trailing: controller.selected == domain.id
                      ? Icon(Icons.radio_button_checked, color: domain.color)
                      : const Icon(Icons.radio_button_off),
                  onTap: () {
                    controller.selectDomain(domain.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
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
          backgroundColor: AppColors.cream.withValues(alpha: .95),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(domain.label, style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${domain.frequency.toStringAsFixed(1)} FM • ${cards.length} nearby',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Filters',
              onPressed: () => _showFilters(context, domain),
              icon: const Icon(Icons.tune),
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
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(card.id),
    background: _swipeBackground(
      Alignment.centerLeft,
      Icons.favorite,
      AppColors.rose,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView(
              children: card.imageUrls
                  .map(
                    (url) => Image.asset(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _SyntheticArtwork(
                        label: card.title,
                        seed: card.id.hashCode,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    if (card.promoted) const Chip(label: Text('Ad')),
                    if (card.verified)
                      const Chip(label: Text('Self-attested ID')),
                    if (card.refreshed) const Chip(label: Text('Fresh today')),
                  ],
                ),
                Text(card.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(card.subtitle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text(card.cityLabel),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Share safely',
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.share_outlined),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPass,
                        icon: const Icon(Icons.close),
                        label: Text(AppLocalizations.of(context).text('pass')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onLike,
                        icon: const Icon(Icons.favorite),
                        label: Text(AppLocalizations.of(context).text('like')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

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
          backgroundColor: domain.color.withValues(alpha: .14),
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
    final domain = context.watch<DomainController>().policy;
    final likes = context.watch<LikesStore>();
    final identity = context.watch<IdentityStore>();
    return _Page(
      title: '${domain.label} likes',
      child: likes.outbound(domain.id).isEmpty
          ? const _InfoCard(
              icon: Icons.favorite_outline,
              title: 'No likes yet',
              body: 'Swipe right when someone or something feels right.',
            )
          : Column(
              children: likes
                  .outbound(domain.id)
                  .map(
                    (id) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.lock)),
                        title: const Text('Contact stays private'),
                        subtitle: Text(
                          likes.isMutual(domain.id, id)
                              ? 'Mutual interest • verify phone to connect'
                              : 'Waiting for mutual interest',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Safety',
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => showSafetySheet(
                                context,
                                domain: domain.id,
                                targetId: id,
                                ownerId: id,
                              ),
                            ),
                            if (likes.isMutual(domain.id, id))
                              FilledButton(
                                onPressed: () async {
                                  if (!identity.identity.phoneVerified) {
                                    final ok = await showOtpSheet(context);
                                    if (!ok || !context.mounted) return;
                                  }
                                  try {
                                    final contact = await ContactService()
                                        .unlock(
                                          domain: domain.id,
                                          targetUid: id,
                                        );
                                    if (!context.mounted) return;
                                    if (contact == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Contact is not available yet',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    await ContactService().openWhatsApp(
                                      contact.whatsappNumber,
                                    );
                                    final telegram = contact.telegramHandle;
                                    if (telegram != null &&
                                        telegram.trim().isNotEmpty) {
                                      await ContactService().openTelegram(
                                        telegram,
                                      );
                                    }
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Verify phone and mutual interest first',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Connect'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityStore>();
    return _Page(
      title: 'Your account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.darkCream,
                child: Text(
                  identity.identity.displayName.isEmpty
                      ? '?'
                      : identity.identity.displayName.characters.first
                            .toUpperCase(),
                ),
              ),
              title: Text(
                identity.completed
                    ? identity.identity.displayName
                    : 'Add shared identity',
              ),
              subtitle: Text(
                identity.completed
                    ? '${identity.identity.cityLabel} • used privately across domains'
                    : 'Minimum details first. Domain profiles stay independent.',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => showIdentityForm(context),
            ),
          ),
          const SizedBox(height: 16),
          Text('Your domains', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...AppDomains.all.map(
            (domain) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.circle, size: 14, color: domain.color),
                  title: Text(domain.label),
                  subtitle: Text(
                    domain.enabled
                        ? 'Ready to create or edit'
                        : 'Foundation ready • coming soon',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDomainProfileForm(context, domain),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Consumer2<BillingService, TrustService>(
            builder: (context, billing, trust, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Growth & trust',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        trust.flags.idPlus
                            ? 'ID+ self-attested'
                            : 'Earn trust badges',
                      ),
                    ),
                    if (billing.active)
                      const Chip(label: Text('Boost active'))
                    else if (!billing.available)
                      Chip(label: Text(billing.webMessage)),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
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
                          ok
                              ? 'Listings refreshed for today'
                              : 'Already refreshed today',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.autorenew),
                  label: const Text('Refresh today (1/day)'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    trust.applySelfAttested(
                      trust.flags.copyWith(aadhaar: true, drivingLicence: true),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Self-attested ID+ saved locally. Documents stay private.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Self-attest ID+'),
                ),
                if (billing.available)
                  FilledButton.tonalIcon(
                    onPressed: () async {
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
                    icon: const Icon(Icons.rocket_launch_outlined),
                    label: const Text('Boost for 7 days'),
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
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showSettings(context),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Settings & safety'),
          ),
        ],
      ),
    );
  }
}

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Page(
    title: 'A safer way to connect',
    child: Column(
      children: [
        _InfoCard(
          icon: Icons.swipe,
          title: 'Swipe with intent',
          body:
              'Right means interested. Left passes. Buttons provide the same actions.',
        ),
        SizedBox(height: 12),
        _InfoCard(
          icon: Icons.radio,
          title: 'Long-press the radio',
          body:
              'Tune between independent domains while keeping one shared identity.',
        ),
        SizedBox(height: 12),
        _InfoCard(
          icon: Icons.lock_outline,
          title: 'Contact is private',
          body:
              'Only mutual interest plus a verified phone session can unlock contact.',
        ),
        SizedBox(height: 12),
        _InfoCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Use your judgment',
          body:
              'Trust labels are self-attested, not government verification. Block and report concerns.',
        ),
        SizedBox(height: 12),
        _InfoCard(
          icon: Icons.science_outlined,
          title: 'Synthetic starter cards',
          body:
              'Demo inventory is fictional and contains no real people or release contact details.',
        ),
      ],
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.cream.withValues(alpha: .95),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
          const Text('You reached the end for now.'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onReset,
            child: const Text('Browse again'),
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
                    DropdownMenuItem(value: null, child: Text('Any role')),
                    DropdownMenuItem(value: 'seek', child: Text('Workers')),
                    DropdownMenuItem(value: 'offer', child: Text('Jobs')),
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
    title: const Text('It is mutual'),
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
  builder: (context) {
    final locale = context.watch<LocaleController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Settings & safety',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            RadioGroup<String?>(
              groupValue: locale.localeCode,
              onChanged: locale.setLocale,
              child: const Column(
                children: [
                  RadioListTile(
                    value: null,
                    title: Text('Use system language'),
                  ),
                  RadioListTile(value: 'en', title: Text('English')),
                  RadioListTile(value: 'hi', title: Text('हिन्दी')),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Community standards'),
              subtitle: const Text(
                'Respect, consent, truth, and no harassment.',
              ),
            ),
          ],
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
                  'Shared identity',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Private contact is stored once and never copied into discovery cards.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display name'),
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
                  child: const Text('Save identity'),
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

Future<void> showDomainProfileForm(BuildContext context, DomainPolicy domain) {
  final identity = context.read<IdentityStore>();
  final publisher = context.read<ListingPublisher>();
  final uid = identity.identity.userId.isEmpty
      ? (FirebaseBootstrap.ready
            ? (FirebaseAuth.instance.currentUser?.uid ?? 'local')
            : 'local')
      : identity.identity.userId;
  final media = FormMediaController(domain: domain.id, uid: uid);
  final offerId = '${domain.id.name}_${DateTime.now().millisecondsSinceEpoch}';
  final requireFace =
      domain.id == AppDomainId.marriage || domain.id == AppDomainId.jobs;

  Future<bool> pickPhoto() async {
    final ok = await media.pickAndUpload(
      slot: media.urls.length,
      requireFace: requireFace,
      offerId: domain.storageKind == DomainStorageKind.offers ? offerId : null,
    );
    if (!ok && context.mounted && media.lastError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(media.lastError!)));
    }
    return ok;
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      builder: (context, scrollController) {
        final form = switch (domain.id) {
          AppDomainId.marriage => MarriageForm(
            onPickPhoto: pickPhoto,
            onAfterSave: (profile) => publisher.publishMarriage(
              ownerId: uid,
              profile: profile,
              photoUrls: List<String>.from(media.urls),
            ),
          ),
          AppDomainId.jobs => JobsForm(
            onPickPhoto: pickPhoto,
            onAfterSave: (profile) => publisher.publishJobs(
              ownerId: uid,
              profile: profile,
              photoUrls: List<String>.from(media.urls),
            ),
          ),
          AppDomainId.rooms => RoomsForm(
            onPickPhoto: pickPhoto,
            onAfterSave: (offer) => publisher.publishRooms(
              ownerId: uid,
              offer: offer,
              offerId: offerId,
              photoUrls: List<String>.from(media.urls),
            ),
          ),
          AppDomainId.bikes => BikesForm(
            onPickPhoto: pickPhoto,
            onAfterSave: (offer) => publisher.publishBikes(
              ownerId: uid,
              offer: offer,
              offerId: offerId,
              photoUrls: List<String>.from(media.urls),
            ),
          ),
          AppDomainId.homeHelp => HomeHelpForm(
            onPickPhoto: pickPhoto,
            onAfterSave: (offer) => publisher.publishHomeHelp(
              ownerId: uid,
              offer: offer,
              offerId: offerId,
              photoUrls: List<String>.from(media.urls),
            ),
          ),
        };
        return PrimaryScrollController(
          controller: scrollController,
          child: form,
        );
      },
    ),
  ).whenComplete(media.dispose);
}
