import 'package:flutter/foundation.dart';

/// Compile-time and runtime feature switches for seeds / vision / sharing.
abstract final class FeatureFlags {
  static const allowDemoSeedsOverride = bool.fromEnvironment(
    'ALLOW_DEMO_SEEDS',
  );
  static const enableVisionDev = bool.fromEnvironment('ENABLE_VISION_DEV');

  /// Bundled demo people: debug/profile only (or explicit ALLOW_DEMO_SEEDS).
  /// Release never starts with synthetic inventory.
  static bool get allowSeedsAtStartup =>
      allowDemoSeedsOverride || !kReleaseMode;

  /// When remote Browse is empty, show empty state — not fake cards.
  /// Low-literacy users treat demos as real people.
  static bool allowBundledSeeds({required bool remoteFeedEmpty}) {
    if (allowDemoSeedsOverride) return true;
    if (!kReleaseMode) return true;
    return false;
  }
}
