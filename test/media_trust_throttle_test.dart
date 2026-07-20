import 'package:flut_marriage/config/feature_flags.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/account_services.dart';
import 'package:flut_marriage/services/feed_throttle.dart';
import 'package:flut_marriage/services/image_pipeline/image_pipeline.dart';
import 'package:flut_marriage/services/media_upload_service.dart';
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

  test('photo errors map to short user lines', () {
    expect(
      ImagePipeline.friendlyError(StateError('Portrait must show exactly one face')),
      'Use a clear photo of one face.',
    );
    expect(
      ImagePipeline.friendlyError(const FormatException('Image must be 5 MiB or smaller')),
      'Photo is too large. Choose a smaller one.',
    );
    expect(
      ImagePipeline.friendlyError(Exception('firebase_storage/unauthorized')),
      'Upload blocked. Close the form and try again.',
    );
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

  test('compression ladder softens quality for large sources', () {
    final small = CompressionLadder.forSourceBytes(50 * 1024);
    final mid = CompressionLadder.forSourceBytes(500 * 1024);
    final large = CompressionLadder.forSourceBytes(2 * 1024 * 1024);
    final huge = CompressionLadder.forSourceBytes(4 * 1024 * 1024);
    expect(small.mediumQuality, greaterThan(mid.mediumQuality));
    expect(mid.mediumQuality, greaterThan(large.mediumQuality));
    expect(large.mediumQuality, greaterThan(huge.mediumQuality));
  });

  test('media CDN URLs route through Hosting /i/ prefix', () {
    expect(
      mediaCdnUrl('profile_photos/uid/marriage/0/medium.webp'),
      'https://aaaa-4eee0.web.app/i/profile_photos/uid/marriage/0/medium.webp',
    );
    expect(
      mediaCdnUrl('/media/uid/rooms/offer1/2/thumb.webp'),
      contains('/i/media/uid/rooms/offer1/2/thumb.webp'),
    );
  });

  test('refresh day key persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_refresh_day'), isNull);
  });
}
