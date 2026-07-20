import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_domain.dart';
import 'face_detection_service.dart';
import 'firebase_bootstrap.dart';
import 'image_pipeline/image_pipeline.dart';
import 'media_upload_service.dart';

/// Picks, moderates, and uploads photos for domain forms.
class FormMediaController extends ChangeNotifier {
  FormMediaController({
    required this.domain,
    String? uid,
    ImagePipeline? pipeline,
    MediaUploadService? uploader,
    FaceDetectionService? faces,
  }) : _uidOverride = uid,
       _pipeline = pipeline ?? ImagePipeline(),
       _uploader = uploader ?? MediaUploadService(),
       _faces = faces ?? FaceDetectionService();

  final AppDomainId domain;
  final String? _uidOverride;
  final ImagePipeline _pipeline;
  final MediaUploadService _uploader;
  final FaceDetectionService _faces;

  /// Remote / CDN URLs used when publishing.
  final List<String> urls = <String>[];

  /// Local thumbnails so the slot shows the photo even if CDN is slow/offline.
  final List<Uint8List?> previews = <Uint8List?>[];

  String? lastError;
  String? lastStatus;
  int? busySlot;
  /// 0.0–1.0 while a slot upload is in flight.
  double? uploadProgress;

  /// Prefill remote URLs when editing an existing post (no local previews).
  void seedUrls(List<String> existing) {
    urls
      ..clear()
      ..addAll(
        existing.map((url) => url.trim()).where((url) => url.isNotEmpty),
      );
    previews
      ..clear()
      ..addAll(List<Uint8List?>.filled(urls.length, null));
    lastError = null;
    lastStatus = urls.isEmpty ? null : 'Photos loaded.';
    busySlot = null;
    uploadProgress = null;
    notifyListeners();
  }

  /// Always prefer live Auth uid when Firebase is up (rules check path uid).
  String get uid {
    if (FirebaseBootstrap.ready) {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    }
    final fallback = _uidOverride;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return 'local';
  }

  Future<bool> pickAndUpload({
    required int slot,
    required bool requireFace,
    required ImageSource source,
    String? offerId,
  }) async {
    lastError = null;
    lastStatus = null;
    busySlot = slot;
    uploadProgress = 0;
    notifyListeners();
    try {
      final file = await _pipeline.pick(source);
      if (file == null) {
        lastStatus = 'No photo selected.';
        return false;
      }

      if (requireFace && _faces.supported) {
        final ok = await _faces.hasSingleFace(file.path);
        if (!ok) {
          lastError = 'Use a clear photo of one face.';
          return false;
        }
      }

      lastStatus = 'Preparing…';
      notifyListeners();
      final policy = AppDomains.byId(domain);
      final processed = await _pipeline.process(file, policy);

      _setPreview(slot, processed.medium);
      lastStatus = 'Uploading…';
      notifyListeners();

      if (FirebaseBootstrap.ready) {
        try {
          await FirebaseAppCheck.instance.getToken();
        } catch (error) {
          if (kDebugMode) {
            debugPrint('App Check token warning: $error');
          }
        }
      }

      final ownerId = uid;
      if (ownerId == 'local' && FirebaseBootstrap.ready) {
        lastError = 'Sign-in needed before uploading. Close and try again.';
        return false;
      }

      void onProgress(double value) {
        uploadProgress = value;
        lastStatus = 'Uploading… ${(value * 100).round()}%';
        notifyListeners();
      }

      final variants = offerId == null
          ? await _uploader.uploadProfileSlot(
              uid: ownerId,
              domain: domain,
              slot: slot,
              image: processed,
              requireFace: requireFace,
              onProgress: onProgress,
            )
          : await _uploader.uploadOfferSlot(
              uid: ownerId,
              domain: domain,
              offerId: offerId,
              slot: slot,
              image: processed,
              onProgress: onProgress,
            );

      while (urls.length <= slot) {
        urls.add('');
      }
      urls[slot] = variants.mediumUrl;
      while (urls.isNotEmpty && urls.last.isEmpty) {
        urls.removeLast();
      }
      lastStatus = 'Photo added.';
      return true;
    } catch (error) {
      lastError =
          '${ImagePipeline.friendlyError(error)} Tap the box to try again.';
      if (kDebugMode) debugPrint('Photo upload failed: $error');
      return false;
    } finally {
      busySlot = null;
      uploadProgress = null;
      notifyListeners();
    }
  }

  void _setPreview(int slot, Uint8List bytes) {
    while (previews.length <= slot) {
      previews.add(null);
    }
    previews[slot] = bytes;
  }

  void removeAt(int slot) {
    if (slot < 0) return;
    if (slot < urls.length) urls.removeAt(slot);
    if (slot < previews.length) previews.removeAt(slot);
    lastError = null;
    lastStatus = 'Photo removed.';
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_faces.dispose());
    super.dispose();
  }
}
