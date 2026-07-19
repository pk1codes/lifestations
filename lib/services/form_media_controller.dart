import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_domain.dart';
import 'face_detection_service.dart';
import 'image_pipeline/image_pipeline.dart';
import 'media_upload_service.dart';

/// Picks, moderates, and uploads photos for domain forms.
class FormMediaController extends ChangeNotifier {
  FormMediaController({
    required this.domain,
    required this.uid,
    ImagePipeline? pipeline,
    MediaUploadService? uploader,
    FaceDetectionService? faces,
  }) : _pipeline = pipeline ?? ImagePipeline(),
       _uploader = uploader ?? MediaUploadService(),
       _faces = faces ?? FaceDetectionService();

  final AppDomainId domain;
  final String uid;
  final ImagePipeline _pipeline;
  final MediaUploadService _uploader;
  final FaceDetectionService _faces;
  final List<String> urls = <String>[];
  String? lastError;

  Future<bool> pickAndUpload({
    required int slot,
    required bool requireFace,
    String? offerId,
  }) async {
    lastError = null;
    try {
      final file = await _pipeline.pick();
      if (file == null) return false;
      if (requireFace && _faces.supported) {
        final ok = await _faces.hasSingleFace(file.path);
        if (!ok) {
          lastError = 'Portrait must show exactly one face';
          notifyListeners();
          return false;
        }
      }
      final policy = AppDomains.byId(domain);
      final processed = await _pipeline.process(file, policy);
      final variants = offerId == null
          ? await _uploader.uploadProfileSlot(
              uid: uid,
              domain: domain,
              slot: slot,
              image: processed,
              requireFace: requireFace,
            )
          : await _uploader.uploadOfferSlot(
              uid: uid,
              domain: domain,
              offerId: offerId,
              slot: slot,
              image: processed,
            );
      urls.add(variants.mediumUrl);
      notifyListeners();
      return true;
    } catch (error) {
      lastError = '$error';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    unawaited(_faces.dispose());
    super.dispose();
  }
}
