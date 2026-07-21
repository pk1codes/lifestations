import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/discovery_card.dart';
import '../models/public_share_card.dart';
import 'media_upload_service.dart';
import 'share_card_repository.dart';

class ShareService {
  ShareService(this._repository);

  final ShareCardRepository _repository;
  static const _configuredOrigin = String.fromEnvironment(
    'SHARE_ORIGIN',
    defaultValue: '',
  );

  String get origin {
    if (_configuredOrigin.isNotEmpty) {
      return _configuredOrigin.endsWith('/')
          ? _configuredOrigin.substring(0, _configuredOrigin.length - 1)
          : _configuredOrigin;
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    // Same hosting origin as media CDN so native shares resolve.
    return mediaCdnOrigin;
  }

  String canonicalUrl(String slug) => '$origin/c/$slug';

  Future<PublicShareCard> publish(DiscoveryCardModel card) =>
      _repository.createOrUpdate(card);

  Future<void> shareCard(DiscoveryCardModel card) async {
    final published = await publish(card);
    final url = canonicalUrl(published.slug);
    await SharePlus.instance.share(
      ShareParams(
        text: 'Private-by-design listing: $url',
        subject: 'Shared on Life Stations',
      ),
    );
  }
}
