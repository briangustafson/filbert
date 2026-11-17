import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:canvas_detect/canvas_detect.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/files/file_store.dart';
import '../../core/imaging/image_metadata.dart';
import '../photos/domain/project_image.dart';

part 'canvas_detection.g.dart';

/// Finds the canvas in a project photo (m1-design §6): decodes the original
/// and runs the [CanvasDetector] on it. Corners are normalized in the
/// EXIF-oriented original.
abstract interface class CanvasDetection {
  Future<Detection> detect(ProjectImage image, {double? aspectHint});
}

class PlatformCanvasDetection implements CanvasDetection {
  PlatformCanvasDetection({required this._files, required this._detector});

  /// Detection works on a downscaled copy (m1-design §6.2).
  static const maxLongEdge = 1000;

  final FileStore _files;
  final CanvasDetector _detector;

  @override
  Future<Detection> detect(ProjectImage image, {double? aspectHint}) async {
    final extension = extensionForMimeType[image.mimeType];
    if (extension == null) {
      throw UnsupportedImageException('Unknown type ${image.mimeType}');
    }
    final bytes = await _files.blobFile(image.blobId, extension).readAsBytes();
    final pixels = await _decode(bytes);
    return _detector.detect(pixels, aspectHint: aspectHint);
  }

  /// Platform decoder (reads HEIC, applies EXIF orientation), downscaled.
  static Future<DetectorImage> _decode(List<int> encoded) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      encoded is Uint8List ? encoded : Uint8List.fromList(encoded),
    );
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        maxLongEdge / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      decoded = (await codec.getNextFrame()).image;
      final data = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Could not read decoded pixels');
      return DetectorImage(
        width: decoded.width,
        height: decoded.height,
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

/// The detector in use (runs in a background isolate).
@Riverpod(keepAlive: true)
CanvasDetector canvasDetector(Ref ref) => const OpenCvCanvasDetector();

@Riverpod(keepAlive: true)
CanvasDetection canvasDetection(Ref ref) => PlatformCanvasDetection(
  files: ref.watch(fileStoreProvider),
  detector: ref.watch(canvasDetectorProvider),
);
