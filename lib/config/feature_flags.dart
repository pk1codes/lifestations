import 'package:flutter/foundation.dart';

/// Compile-time and runtime feature switches for seeds / vision / sharing.
abstract final class FeatureFlags {
  static const allowDemoSeedsOverride = bool.fromEnvironment(
    'ALLOW_DEMO_SEEDS',
  );
  static const enableVisionDev = bool.fromEnvironment('ENABLE_VISION_DEV');

  /// Safe before a remote fetch: release mobile must first try the real feed.
  static bool get allowSeedsAtStartup =>
      allowDemoSeedsOverride || !kReleaseMode || kIsWeb;

  /// Debug/profile: allow seeds. Release web: allow. Release mobile: empty-feed fallback only.
  static bool allowBundledSeeds({required bool remoteFeedEmpty}) {
    if (allowDemoSeedsOverride) return true;
    if (kDebugMode) return true;
    if (kIsWeb) return true;
    // Release mobile
    return remoteFeedEmpty;
  }
}
