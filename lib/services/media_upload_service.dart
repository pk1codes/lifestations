import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/app_domain.dart';
import 'face_detection_service.dart';
import 'firebase_bootstrap.dart';
import 'image_pipeline/image_pipeline.dart';
import 'moderation/moderation_service.dart';

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
      await ref.putData(bytes, SettableMetadata(contentType: 'image/webp'));
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
    final thumb = _db.ref('$prefix/thumb.webp');
    final medium = _db.ref('$prefix/medium.webp');
    final large = _db.ref('$prefix/large.webp');
    final meta = SettableMetadata(contentType: 'image/webp');
    await Future.wait([
      thumb.putData(image.thumb, meta),
      medium.putData(image.medium, meta),
      large.putData(image.large, meta),
    ]);
    final urls = await Future.wait([
      thumb.getDownloadURL(),
      medium.getDownloadURL(),
      large.getDownloadURL(),
    ]);
    return UploadedVariants(
      thumbUrl: urls[0],
      mediumUrl: urls[1],
      largeUrl: urls[2],
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
