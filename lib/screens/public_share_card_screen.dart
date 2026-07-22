import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_domain.dart';
import '../models/public_share_card.dart';
import '../services/firebase_bootstrap.dart';
import '../services/media_urls.dart';
import '../services/share_card_repository.dart';
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
              _ShareLoadState.ready => _ReadyCard(card: _card!),
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
  const _ReadyCard({required this.card});
  final PublicShareCard card;

  @override
  Widget build(BuildContext context) {
    final policy = AppDomains.byId(card.domain);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (card.photoUrl != null)
            AspectRatio(
              aspectRatio: 4 / 3,
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
            ColoredBox(
              color: AppColors.darkCream,
              child: const AspectRatio(
                aspectRatio: 4 / 3,
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 64,
                    color: AppColors.muted,
                  ),
                ),
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
                if (card.verified || card.promoted) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (card.verified)
                        'Self-attested ID is a claim by the owner, not a check by us.',
                      if (card.promoted) 'Top means boosted visibility.',
                    ].join(' '),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
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
                  'Names, bios, phones, WhatsApp, Telegram, and documents are never included on public cards.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (_) => false,
                  ),
                  child: const Text('Explore safely'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
