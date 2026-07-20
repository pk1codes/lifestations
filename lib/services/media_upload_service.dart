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
    void Function(double progress)? onProgress,
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
    return _putVariants(prefix, image, onProgress: onProgress);
  }

  Future<UploadedVariants> uploadOfferSlot({
    required String uid,
    required AppDomainId domain,
    required String offerId,
    required int slot,
    required ProcessedImage image,
    void Function(double progress)? onProgress,
  }) async {
    final search = await _safeSearch.inspect(image.medium);
    if (!search.safe) {
      throw StateError('Image failed SafeSearch');
    }
    final slug = domain == AppDomainId.homeHelp ? 'home_help' : domain.name;
    final prefix = 'media/$uid/$slug/$offerId/$slot';
    return _putVariants(prefix, image, onProgress: onProgress);
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
      for (final name in const ['thumb', 'medium', 'large'])
        for (final ext in const ['webp', 'jpg', 'jpeg', 'png'])
          _deleteQuietly('$prefix/$name.$ext'),
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
    ProcessedImage image, {
    void Function(double progress)? onProgress,
  }) async {
    final ext = image.extension;
    if (!FirebaseBootstrap.ready) {
      onProgress?.call(1);
      return UploadedVariants(
        thumbUrl: 'local://$prefix/thumb.$ext',
        mediumUrl: 'local://$prefix/medium.$ext',
        largeUrl: 'local://$prefix/large.$ext',
        pathPrefix: prefix,
      );
    }
    await clearSlot(prefix);
    final thumb = _db.ref('$prefix/thumb.$ext');
    final medium = _db.ref('$prefix/medium.$ext');
    final large = _db.ref('$prefix/large.$ext');
    final meta = SettableMetadata(
      contentType: image.mimeType,
      cacheControl: mediaCacheControl,
    );
    final totals = <int>[
      image.thumb.length,
      image.medium.length,
      image.large.length,
    ];
    final sent = <int>[0, 0, 0];
    void report() {
      final total = totals.fold<int>(0, (a, b) => a + b);
      final done = sent.fold<int>(0, (a, b) => a + b);
      if (total <= 0) return;
      onProgress?.call((done / total).clamp(0.0, 1.0));
    }

    Future<void> put(int index, Reference ref, Uint8List bytes) async {
      final task = ref.putData(bytes, meta);
      await for (final snap in task.snapshotEvents) {
        sent[index] = snap.bytesTransferred;
        report();
      }
      await task;
      sent[index] = bytes.length;
      report();
    }

    await Future.wait([
      put(0, thumb, image.thumb),
      put(1, medium, image.medium),
      put(2, large, image.large),
    ]);
    onProgress?.call(1);
    return UploadedVariants(
      thumbUrl: mediaCdnUrl('$prefix/thumb.$ext'),
      mediumUrl: mediaCdnUrl('$prefix/medium.$ext'),
      largeUrl: mediaCdnUrl('$prefix/large.$ext'),
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
