import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_domain.dart';
import '../models/public_share_card.dart';
import '../services/share_card_repository.dart';
import '../theme/app_theme.dart';

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
    try {
      if (!widget.slug.contains('_') ||
          !PublicShareCard.isValidSlug(widget.slug)) {
        setState(() => _state = _ShareLoadState.notFound);
        return;
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Shared card')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_state) {
              _ShareLoadState.loading => const CircularProgressIndicator(),
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
                body: 'Try again later. Contact details are never shown here.',
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
            onPressed: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
            child: const Text('Explore safely'),
          ),
        ],
      ),
    ),
  );
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.card});
  final PublicShareCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (card.photoUrl != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: card.photoUrl!.startsWith('http')
                  ? Image.network(card.photoUrl!, fit: BoxFit.cover)
                  : Image.asset(
                      card.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.darkCream,
                        child: const Icon(Icons.image_outlined, size: 64),
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
                  children: [
                    Chip(label: Text(AppDomains.byId(card.domain).label)),
                    if (card.verified)
                      const Chip(label: Text('Self-attested ID')),
                    if (card.promoted) const Chip(label: Text('Top')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  card.headline,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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
                if (card.ageBand != null) Text('Age band ${card.ageBand}'),
                if (card.tradeLabel != null) Text(card.tradeLabel!),
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
