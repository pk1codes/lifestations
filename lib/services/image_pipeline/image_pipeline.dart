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

class ImagePipeline {
  ImagePipeline({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maxUploadBytes = 5 * 1024 * 1024;
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
    final variants = await Future.wait([
      _compress(bytes, 320, 60),
      _compress(bytes, 960, 72),
      _compress(bytes, 1800, 80),
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
