import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/public_share_card.dart';
import 'share_install_referrer.dart';

/// Handles public share routes from Android App Links and Play install referrer.
class ShareLinkRouter {
  ShareLinkRouter({
    Future<Uri?> Function()? getInitialUri,
    Stream<Uri>? incomingUriStream,
    Future<String?> Function(SharedPreferences prefs)? consumeInstallReferrer,
  }) : _getInitialUri = getInitialUri ?? AppLinks().getInitialLink,
       _incomingUriStream = incomingUriStream ?? AppLinks().uriLinkStream,
       _consumeInstallReferrer =
           consumeInstallReferrer ?? ShareInstallReferrer.tryConsumeShareSlug;

  final Future<Uri?> Function() _getInitialUri;
  final Stream<Uri> _incomingUriStream;
  final Future<String?> Function(SharedPreferences prefs)
  _consumeInstallReferrer;
  StreamSubscription<Uri>? _sub;

  Future<String> resolveInitialRoute({
    required SharedPreferences prefs,
    String defaultRouteName = '/',
  }) async {
    final routeFromPlatform = shareRouteFromLocation(defaultRouteName);
    if (routeFromPlatform != null) return routeFromPlatform;

    if (!kIsWeb) {
      try {
        final initialUri = await _getInitialUri();
        final routeFromUri = shareRouteFromUri(initialUri);
        if (routeFromUri != null) return routeFromUri;
      } catch (_) {}
    }

    if (!kIsWeb) {
      final slug = await _consumeInstallReferrer(prefs);
      if (slug != null) return '/c/$slug';
    }
    return '/';
  }

  void attach(GlobalKey<NavigatorState> navigatorKey) {
    if (kIsWeb) return;
    _sub?.cancel();
    _sub = _incomingUriStream.listen((uri) {
      final route = shareRouteFromUri(uri);
      final nav = navigatorKey.currentState;
      if (route == null || nav == null) return;
      nav.pushNamedAndRemoveUntil(route, (route) => false);
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  static String? shareRouteFromLocation(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    return shareRouteFromUri(uri);
  }

  static String? shareRouteFromUri(Uri? uri) {
    if (uri == null) return null;
    final parts = uri.pathSegments;
    if (parts.length != 2 || parts.first != 'c') return null;
    final slug = parts.last.trim();
    if (!PublicShareCard.isValidSlug(slug)) return null;
    return '/c/$slug';
  }
}
