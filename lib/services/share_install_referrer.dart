import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/public_share_card.dart';

/// Best-effort Play Install Referrer → shared card slug.
///
/// True deferred deep links need Play Console + additional wiring; this recovers
/// `utm_content` from [StoreLinks.playStoreForShareSlug] on first Android open.
abstract final class ShareInstallReferrer {
  static const _consumedKey = 'share_install_referrer_consumed_v1';

  /// Returns a share slug once per install when Play reports our UTM referrer.
  static Future<String?> tryConsumeShareSlug(SharedPreferences prefs) async {
    if (kIsWeb) return null;
    if (prefs.getBool(_consumedKey) == true) return null;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      await prefs.setBool(_consumedKey, true);
      return parseSlugFromReferrer(details.installReferrer ?? '');
    } catch (_) {
      // Play Services missing / not from Play — retry on a later cold start.
      return null;
    }
  }

  /// Parses `utm_content=<slug>` from a Play install referrer string.
  static String? parseSlugFromReferrer(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    String decoded = trimmed;
    try {
      decoded = Uri.decodeComponent(trimmed);
    } catch (_) {}
    final params = Uri.splitQueryString(decoded);
    final content = (params['utm_content'] ?? '').trim();
    if (content.isEmpty || !PublicShareCard.isValidSlug(content)) return null;
    return content;
  }
}
