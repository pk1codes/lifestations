import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/app_domain.dart';
import 'face_detection_service.dart';
import 'firebase_bootstrap.dart';
import 'image_pipeline/image_pipeline.dart';
import 'moderation/moderation_service.dart';

/// Public CDN origin for user media. Hosting rewrites `/i/**` to the
/// [serveMedia] Cloud Function, which streams Storage objects with a
/// long-lived Cache-Control so the Hosting edge CDN can cache them.
const mediaCdnOrigin = String.fromEnvironment(
  'SHARE_ORIGIN',
  defaultValue: 'https://aaaa-4eee0.web.app',
);

const mediaCacheControl = 'public,max-age=31536000,immutable';

/// Builds the Hosting-CDN URL for a Storage object path
/// (e.g. `profile_photos/uid/marriage/0/medium.webp`).
String mediaCdnUrl(String objectPath) {
  final cleaned = objectPath.replaceFirst(RegExp(r'^/+'), '');
  final encoded = cleaned
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
  return '$mediaCdnOrigin/i/$encoded';
}

class UploadedVariants {
  const UploadedVariants({
    required this.thumbUrl,
    required this.mediumUrl,
    required this.largeUrl,
    required this.pathPrefix,
  });
  final String thumbUrl;
  final String mediumUrl;
  final String largeUrl;
  final String pathPrefix;
}

/// Uploads processed WebP variants to canonical Storage paths.
class MediaUploadService {
  MediaUploadService({
    this.storage,
    SafeSearchClient? safeSearch,
    FaceGate? faceGate,
  }) : _safeSearch = safeSearch ?? GoogleVisionSafeSearchClient(),
       _faceGate = faceGate ?? FaceGate();

  final FirebaseStorage? storage;
  final SafeSearchClient _safeSearch;
  final FaceGate _faceGate;

  FirebaseStorage get _db {
    final injected = storage;
    if (injected != null) return injected;
    if (!FirebaseBootstrap.ready) {
      throw StateError('Firebase Storage unavailable until bootstrap succeeds');
    }
    return FirebaseStorage.instance;
  }

  Future<UploadedVariants> uploadProfileSlot({
    required String uid,
    required AppDomainId domain,
    required int slot,
    required ProcessedImage image,
    required bool requireFace,
  }) async {
    if (requireFace) {
      await _faceGate.requireSingleFace(image.large);
    }
    final search = await _safeSearch.inspect(image.medium);
    if (!search.safe) {
      throw StateError('Image failed SafeSearch');
    }
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final prefix = 'profile_photos/$uid/$slug/$slot';
    return _putVariants(prefix, image);
  }

  Future<UploadedVariants> uploadOfferSlot({
    required String uid,
    required AppDomainId domain,
    required String offerId,
    required int slot,
    required ProcessedImage image,
  }) async {
    final search = await _safeSearch.inspect(image.medium);
    if (!search.safe) {
      throw StateError('Image failed SafeSearch');
    }
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final prefix = 'media/$uid/$slug/$offerId/$slot';
    return _putVariants(prefix, image);
  }

  Future<void> uploadVerifyStaging({
    required String uid,
    required String docType,
    required Uint8List bytes,
  }) async {
    if (!FirebaseBootstrap.ready) return;
    final ref = _db.ref('verify_staging/$uid/$docType/attest.webp');
    try {
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/webp',
          cacheControl: 'private,max-age=0,no-store',
        ),
      );
    } finally {
      try {
        await ref.delete();
      } catch (_) {
        if (kDebugMode) {
          debugPrint('verify_staging cleanup skipped');
        }
      }
    }
  }

  /// Best-effort wipe of an existing slot before overwrite so stale
  /// variant names / orphaned bytes cannot accumulate under the prefix.
  Future<void> clearSlot(String prefix) async {
    if (!FirebaseBootstrap.ready) return;
    await Future.wait([
      _deleteQuietly('$prefix/thumb.webp'),
      _deleteQuietly('$prefix/medium.webp'),
      _deleteQuietly('$prefix/large.webp'),
    ]);
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await _db.ref(path).delete();
    } catch (_) {
      // Object missing or rules denied — overwrite will still succeed.
    }
  }

  Future<UploadedVariants> _putVariants(
    String prefix,
    ProcessedImage image,
  ) async {
    if (!FirebaseBootstrap.ready) {
      return UploadedVariants(
        thumbUrl: 'local://$prefix/thumb.webp',
        mediumUrl: 'local://$prefix/medium.webp',
        largeUrl: 'local://$prefix/large.webp',
        pathPrefix: prefix,
      );
    }
    await clearSlot(prefix);
    final thumb = _db.ref('$prefix/thumb.webp');
    final medium = _db.ref('$prefix/medium.webp');
    final large = _db.ref('$prefix/large.webp');
    final meta = SettableMetadata(
      contentType: 'image/webp',
      cacheControl: mediaCacheControl,
    );
    await Future.wait([
      thumb.putData(image.thumb, meta),
      medium.putData(image.medium, meta),
      large.putData(image.large, meta),
    ]);
    // Prefer Hosting-CDN URLs over signed Storage download URLs so repeat
    // views are served from the edge with immutable caching.
    return UploadedVariants(
      thumbUrl: mediaCdnUrl('$prefix/thumb.webp'),
      mediumUrl: mediaCdnUrl('$prefix/medium.webp'),
      largeUrl: mediaCdnUrl('$prefix/large.webp'),
      pathPrefix: prefix,
    );
  }
}

/// On-device face gate. Prefer path-based ML Kit via [FaceDetectionService].
class FaceGate {
  FaceGate({this.faces});

  final FaceDetectionService? faces;

  Future<void> requireSingleFace(
    Uint8List bytes, {
    String? absolutePath,
  }) async {
    if (!ImagePipeline.faceDetectionSupported) return;
    final path = absolutePath;
    if (path == null || path.isEmpty) {
      if (kDebugMode) {
        debugPrint('FaceGate: skipped path-less check (${bytes.length} bytes)');
      }
      return;
    }
    final detector = faces ?? FaceDetectionService();
    final ok = await detector.hasSingleFace(path);
    if (!ok) {
      throw StateError('Portrait must show exactly one face');
    }
  }
}
