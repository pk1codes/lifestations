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
  });
  final Uint8List thumb;
  final Uint8List medium;
  final Uint8List large;
  final String mimeType;
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
      // Already small — preserve detail; WebP still shrinks vs JPEG/PNG.
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

  Future<XFile?> pick() => _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 100,
    requestFullMetadata: false,
  );

  Future<ProcessedImage> process(XFile source, DomainPolicy policy) async {
    final bytes = await source.readAsBytes();
    if (bytes.length > maxUploadBytes) {
      throw const FormatException('Image must be 5 MiB or smaller');
    }
    final ladder = CompressionLadder.forSourceBytes(bytes.length);
    final variants = await Future.wait([
      _compress(bytes, thumbWidth, ladder.thumbQuality),
      _compress(bytes, mediumWidth, ladder.mediumQuality),
      _compress(bytes, largeWidth, ladder.largeQuality),
    ]);
    if (variants.any((bytes) => bytes.isEmpty)) {
      throw const FormatException('Image could not be processed');
    }
    return ProcessedImage(
      thumb: variants[0],
      medium: variants[1],
      large: variants[2],
      mimeType: 'image/webp',
    );
  }

  Future<Uint8List> _compress(Uint8List source, int width, int quality) async {
    final result = await FlutterImageCompress.compressWithList(
      source,
      minWidth: width,
      quality: quality,
      format: CompressFormat.webp,
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
}
