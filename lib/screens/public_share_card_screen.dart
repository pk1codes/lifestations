import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/store_links.dart';
import '../models/app_domain.dart';
import '../models/public_share_card.dart';
import '../services/firebase_bootstrap.dart';
import '../services/media_urls.dart';
import '../services/share_card_repository.dart';
import '../services/share_service.dart';
import '../state/app_stores.dart';
import '../theme/app_theme.dart';
import '../widgets/fast_network_image.dart';
import '../widgets/image_skeleton.dart';

enum _ShareLoadState { loading, ready, inactive, notFound, error }

class PublicShareCardScreen extends StatefulWidget {
  const PublicShareCardScreen({required this.slug, super.key});
  final String slug;

  @override
  State<PublicShareCardScreen> createState() => _PublicShareCardScreenState();
}

class _PublicShareCardScreenState extends State<PublicShareCardScreen> {
  _ShareLoadState _state = _ShareLoadState.loading;
  PublicShareCard? _card;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _ShareLoadState.loading);
    try {
      if (!widget.slug.contains('_') ||
          !PublicShareCard.isValidSlug(widget.slug)) {
        setState(() => _state = _ShareLoadState.notFound);
        return;
      }
      await FirebaseBootstrap.waitUntilReady();
      if (!mounted) return;
      final repo = context.read<ShareCardRepository>();
      final card = await repo.fetchBySlug(widget.slug);
      if (!mounted) return;
      if (card == null) {
        setState(() => _state = _ShareLoadState.notFound);
      } else if (!card.active) {
        setState(() {
          _card = card;
          _state = _ShareLoadState.inactive;
        });
      } else {
        setState(() {
          _card = card;
          _state = _ShareLoadState.ready;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _state = _ShareLoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainLabel = _card != null
        ? AppDomains.byId(_card!.domain).label
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(domainLabel ?? 'Shared listing')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (_state) {
              _ShareLoadState.loading => const _ShareCardSkeleton(),
              _ShareLoadState.notFound => _message(
                context,
                icon: Icons.link_off,
                title: 'Link not found',
                body: 'This share card is missing or the link is incomplete.',
              ),
              _ShareLoadState.inactive => _message(
                context,
                icon: Icons.visibility_off_outlined,
                title: 'No longer active',
                body: 'The owner deactivated this public card.',
              ),
              _ShareLoadState.error => _message(
                context,
                icon: Icons.error_outline,
                title: 'Could not load',
                body: 'Try again. Contact details are never shown here.',
                actionLabel: 'Try again',
                onAction: _load,
              ),
              _ShareLoadState.ready => _ReadyCard(
                card: _card!,
                slug: widget.slug,
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    String actionLabel = 'Explore safely',
    VoidCallback? onAction,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(
            onPressed:
                onAction ??
                () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (_) => false,
                ),
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

class _ShareCardSkeleton extends StatelessWidget {
  const _ShareCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(aspectRatio: 4 / 3, child: ImageSkeleton()),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 18, width: 120, color: AppColors.darkCream),
                const SizedBox(height: 12),
                Container(
                  height: 28,
                  width: double.infinity,
                  color: AppColors.darkCream,
                ),
                const SizedBox(height: 8),
                Container(height: 16, width: 180, color: AppColors.darkCream),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.card, required this.slug});
  final PublicShareCard card;
  final String slug;

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(StoreLinks.playStoreForShareSlug(slug));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInAppOrWeb(BuildContext context) async {
    if (!kIsWeb && context.mounted) {
      // Already in the app on this card → Browse that domain.
      context.read<DomainController>().selectDomain(card.domain);
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      return;
    }
    // Web: try to hand off to the installed Android app on the same /c/slug.
    final origin = context.read<ShareService>().origin;
    final shareHttps = '$origin/c/$slug';
    final play = StoreLinks.playStoreForShareSlug(slug);
    final intent = Uri.parse(
      'intent://${Uri.parse(shareHttps).host}/c/$slug'
      '#Intent;scheme=https;package=com.lifestations.app;'
      'S.browser_fallback_url=${Uri.encodeComponent(play)};end',
    );
    try {
      final launched = await launchUrl(
        intent,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}
    await launchUrl(
      Uri.parse(shareHttps),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = AppDomains.byId(card.domain);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (card.photoUrl != null)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: FastNetworkImage(
                      url: card.photoUrl!,
                      role: FastImageRole.card,
                      fit: BoxFit.cover,
                      placeholderColor: AppColors.darkCream,
                      fallback: Container(
                        color: AppColors.darkCream,
                        child: const Icon(Icons.image_outlined, size: 64),
                      ),
                    ),
                  )
                else
                  const ColoredBox(
                    color: AppColors.darkCream,
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        'Preview — get the app to open',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(policy.label),
                      avatar: Icon(
                        Icons.category_outlined,
                        size: 16,
                        color: policy.color,
                      ),
                    ),
                    if (card.verified)
                      const Tooltip(
                        message:
                            'Owner marked an ID claim — not independently verified',
                        child: Chip(label: Text('Self-attested ID')),
                      ),
                    if (card.promoted)
                      const Tooltip(
                        message: 'This listing paid for extra visibility',
                        child: Chip(label: Text('Top')),
                      ),
                  ],
                ),
                if (card.sideLabel != null && card.sideLabel!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    card.sideLabel!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: policy.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  card.headline,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (card.detailLine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    card.detailLine,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
                if (card.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 4),
                      Text(card.locationLabel),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Photo is blurred. Names, phones, WhatsApp, and Telegram stay private.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('share_get_app'),
                  onPressed: _openPlayStore,
                  icon: const Icon(Icons.shop_outlined),
                  label: const Text('Get the app'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('share_open_app'),
                  onPressed: () => _openInAppOrWeb(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Open in Life Stations'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
