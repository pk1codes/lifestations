import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Requires exactly one face for Marriage/Jobs portraits on supported platforms.
class FaceDetectionService {
  FaceDetectionService([this._detector]);

  FaceDetector? _detector;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> hasSingleFace(String absolutePath) async {
    if (!supported) return true;
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableTracking: false,
      ),
    );
    final input = InputImage.fromFilePath(absolutePath);
    final faces = await _detector!.processImage(input);
    return faces.length == 1;
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
