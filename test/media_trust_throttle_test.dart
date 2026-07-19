import 'package:flut_marriage/config/feature_flags.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/account_services.dart';
import 'package:flut_marriage/services/feed_throttle.dart';
import 'package:flut_marriage/services/image_pipeline/image_pipeline.dart';
import 'package:flut_marriage/services/moderation/moderation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('image slot enforcement respects domain policy', () {
    expect(
      () => ImagePipeline.enforceSlots(AppDomains.bikes, 4, creating: true),
      returnsNormally,
    );
    expect(
      () => ImagePipeline.enforceSlots(AppDomains.bikes, 3, creating: true),
      throwsRangeError,
    );
    expect(
      () => ImagePipeline.enforceSlots(AppDomains.rooms, 2, creating: true),
      returnsNormally,
    );
  });

  test('Vision is disabled without compile-time key', () {
    expect(GoogleVisionSafeSearchClient().enabled, isFalse);
  });

  test('trust flags expose honest self-attested badges', () {
    const flags = TrustFlags(aadhaar: true, drivingLicence: true);
    expect(flags.idPlus, isTrue);
    expect(flags.toSafeJson()['idPlus'], isTrue);
    expect(flags.toSafeJson().containsKey('aadhaarNumber'), isFalse);
  });

  test('billing entitlement duration is seven days from purchase', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final purchase = DateTime.now();
    final billing = BillingService(listenToPurchases: false)
      ..applyVerifiedEntitlement(purchase);
    expect(billing.boostUntil, purchase.add(const Duration(days: 7)));
    expect(billing.webMessage, contains('Android'));
  });

  test('feed throttle locks after 10 hits in 30 seconds', () async {
    final throttle = FeedFetchThrottle();
    for (var i = 0; i < 10; i++) {
      expect(await throttle.allow(callRemote: false), isTrue);
    }
    expect(await throttle.allow(callRemote: false), isFalse);
    expect(throttle.isLocked, isTrue);
  });

  test('seed feature flag allows debug and empty-feed mobile fallback', () {
    expect(FeatureFlags.allowBundledSeeds(remoteFeedEmpty: false), isTrue);
    expect(FeatureFlags.allowBundledSeeds(remoteFeedEmpty: true), isTrue);
  });

  test('refresh day key persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_refresh_day'), isNull);
  });
}
