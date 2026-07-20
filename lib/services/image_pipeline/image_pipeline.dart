import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_domain.dart';

class ProcessedImage {
  const ProcessedImage({
    required this.thumb,
    required this.medium,
    required this.large,
    required this.mimeType,
    required this.extension,
  });
  final Uint8List thumb;
  final Uint8List medium;
  final Uint8List large;
  final String mimeType;
  final String extension;
}

/// Quality ladder keyed by source byte size. Small sources keep higher
/// quality (avoid generation loss); large sources step quality down so
/// upload / storage / egress stay cheap.
@immutable
class CompressionLadder {
  const CompressionLadder({
    required this.thumbQuality,
    required this.mediumQuality,
    required this.largeQuality,
  });

  final int thumbQuality;
  final int mediumQuality;
  final int largeQuality;

  /// Picks qualities from the raw source size before any resize.
  static CompressionLadder forSourceBytes(int bytes) {
    if (bytes < 200 * 1024) {
      return const CompressionLadder(
        thumbQuality: 72,
        mediumQuality: 84,
        largeQuality: 90,
      );
    }
    if (bytes < 1024 * 1024) {
      return const CompressionLadder(
        thumbQuality: 60,
        mediumQuality: 72,
        largeQuality: 80,
      );
    }
    if (bytes < 3 * 1024 * 1024) {
      return const CompressionLadder(
        thumbQuality: 55,
        mediumQuality: 65,
        largeQuality: 74,
      );
    }
    return const CompressionLadder(
      thumbQuality: 48,
      mediumQuality: 58,
      largeQuality: 68,
    );
  }
}

class ImagePipeline {
  ImagePipeline({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maxUploadBytes = 5 * 1024 * 1024;
  static const thumbWidth = 320;
  static const mediumWidth = 960;
  static const largeWidth = 1800;

  final ImagePicker _picker;

  Future<XFile?> pick(ImageSource source) => _picker.pickImage(
    source: source,
    imageQuality: 100,
    requestFullMetadata: false,
    preferredCameraDevice: CameraDevice.front,
  );

  Future<ProcessedImage> process(XFile source, DomainPolicy policy) async {
    final bytes = await source.readAsBytes();
    if (bytes.length > maxUploadBytes) {
      throw const FormatException('Photo is too large. Choose a smaller one.');
    }
    final ladder = CompressionLadder.forSourceBytes(bytes.length);
    // Prefer WebP; on web fall back to JPEG if WebP/pica fails.
    try {
      return await _encode(bytes, ladder, CompressFormat.webp, 'image/webp', 'webp');
    } catch (_) {
      if (!kIsWeb) rethrow;
      return _encode(bytes, ladder, CompressFormat.jpeg, 'image/jpeg', 'jpg');
    }
  }

  Future<ProcessedImage> _encode(
    Uint8List bytes,
    CompressionLadder ladder,
    CompressFormat format,
    String mimeType,
    String extension,
  ) async {
    final variants = await Future.wait([
      _compress(bytes, thumbWidth, ladder.thumbQuality, format),
      _compress(bytes, mediumWidth, ladder.mediumQuality, format),
      _compress(bytes, largeWidth, ladder.largeQuality, format),
    ]);
    if (variants.any((part) => part.isEmpty)) {
      throw const FormatException('Could not prepare photo. Try another image.');
    }
    return ProcessedImage(
      thumb: variants[0],
      medium: variants[1],
      large: variants[2],
      mimeType: mimeType,
      extension: extension,
    );
  }

  Future<Uint8List> _compress(
    Uint8List source,
    int width,
    int quality,
    CompressFormat format,
  ) async {
    final result = await FlutterImageCompress.compressWithList(
      source,
      minWidth: width,
      quality: quality,
      format: format,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    return Uint8List.fromList(result);
  }

  static void enforceSlots(
    DomainPolicy policy,
    int count, {
    required bool creating,
  }) {
    final minimum = creating ? policy.minPhotos : 0;
    if (count < minimum || count > policy.maxPhotos) {
      throw RangeError('Expected $minimum–${policy.maxPhotos} photos');
    }
  }

  static bool get faceDetectionSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Maps raw plugin/Firebase errors into short user-facing lines.
  static String friendlyError(Object error) {
    final text = '$error'.toLowerCase();
    final code = error is FirebaseException
        ? error.code.toLowerCase()
        : '';
    if (text.contains('one face') || text.contains('portrait must')) {
      return 'Use a clear photo of one face.';
    }
    if (text.contains('too large') || text.contains('5 mib')) {
      return 'Photo is too large. Choose a smaller one.';
    }
    if (text.contains('safesearch')) {
      return 'This photo cannot be used. Try another.';
    }
    if (code == 'unauthorized' ||
        code == 'permission-denied' ||
        text.contains('permission-denied') ||
        text.contains('unauthorized') ||
        text.contains('app check') ||
        text.contains('app-check')) {
      return 'Upload blocked. Close the form and try again.';
    }
    if (text.contains('firebase_storage') &&
        (text.contains('retry') || text.contains('canceled'))) {
      return 'Upload interrupted. Try again.';
    }
    if (text.contains('camera') &&
        (text.contains('permission') || text.contains('access'))) {
      return 'Allow camera access to take a photo.';
    }
    if (text.contains('photo') && text.contains('permission')) {
      return 'Allow photo access to choose a picture.';
    }
    if (text.contains('pica') ||
        text.contains('compress') ||
        text.contains('prepare photo') ||
        text.contains("type 'function'")) {
      return 'Could not prepare photo. Try another image.';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('unavailable') ||
        code == 'unavailable') {
      return 'Network problem. Try again.';
    }
    return 'Could not add photo. Try again.';
  }
}
