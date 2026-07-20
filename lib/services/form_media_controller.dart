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

  /// Called whenever remote URLs change (upload success or remove).
  Future<void> Function(List<String> urls)? onUrlsChanged;

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

  /// Live Auth uid only. Never fall back to a stale identity id for Storage paths.
  String get uid {
    if (FirebaseBootstrap.ready) {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
      return '';
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
    var previewSet = false;
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
      previewSet = true;
      lastStatus = 'Uploading…';
      notifyListeners();

      final ownerId = await _ensureUploadUid();
      if (ownerId == null) return false;

      await _warmAppCheck();

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
      await onUrlsChanged?.call(List<String>.from(urls));
      return true;
    } catch (error) {
      if (previewSet) _clearPreview(slot);
      lastError =
          '${ImagePipeline.friendlyError(error)} Tap the box to try again.';
      // Always log — release Play builds need this in logcat / Crashlytics.
      debugPrint('Photo upload failed: $error');
      return false;
    } finally {
      busySlot = null;
      uploadProgress = null;
      notifyListeners();
    }
  }

  /// Ensures a live Firebase Auth session before Storage paths are written.
  Future<String?> _ensureUploadUid() async {
    if (!FirebaseBootstrap.ready) {
      final local = uid;
      if (local.isEmpty || local == 'local') {
        lastError = 'Sign-in needed before uploading. Close and try again.';
        return null;
      }
      return local;
    }

    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      } on FirebaseAuthException catch (error) {
        debugPrint('Upload sign-in failed: ${error.code}');
        lastError = error.code == 'admin-restricted-operation'
            ? 'Sign-in is turned off for this app. Enable Anonymous Auth in Firebase.'
            : 'Sign-in needed before uploading. Close and try again.';
        return null;
      }
    }
    final id = user?.uid;
    if (id == null || id.isEmpty) {
      lastError = 'Sign-in needed before uploading. Close and try again.';
      return null;
    }
    return id;
  }

  /// Best-effort App Check warm-up. Token failures are logged; Storage rules
  /// currently require Auth (App Check is optional during closed testing).
  Future<void> _warmAppCheck() async {
    if (!FirebaseBootstrap.ready) return;
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      if (token == null || token.isEmpty) {
        debugPrint('App Check token empty before upload');
      }
    } catch (error) {
      debugPrint('App Check token warning: $error');
    }
  }

  void _setPreview(int slot, Uint8List bytes) {
    while (previews.length <= slot) {
      previews.add(null);
    }
    previews[slot] = bytes;
  }

  void _clearPreview(int slot) {
    if (slot >= 0 && slot < previews.length) {
      previews[slot] = null;
    }
  }

  void removeAt(int slot) {
    if (slot < 0) return;
    if (slot < urls.length) urls.removeAt(slot);
    if (slot < previews.length) previews.removeAt(slot);
    lastError = null;
    lastStatus = 'Photo removed.';
    notifyListeners();
    unawaited(
      Future(() async {
        await onUrlsChanged?.call(List<String>.from(urls));
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_faces.dispose());
    super.dispose();
  }
}
