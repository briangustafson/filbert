import 'dart:io';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/features/autocrop/canvas_detection.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Records what it was given.
class _RecordingDetector implements CanvasDetector {
  DetectorImage? image;
  double? hint;

  @override
  Future<Detection> detect(DetectorImage image, {double? aspectHint}) {
    this.image = image;
    hint = aspectHint;
    return const StubCanvasDetector().detect(image);
  }
}

void main() {
  late Directory root;
  late LocalFileStore files;

  setUp(() {
    root = Directory.systemTemp.createTempSync('filbert_detect');
    files = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<ProjectImage> stored(String fixture) async {
    await files.putBlob('b', 'jpg', fixtureImage(fixture));
    return ProjectImage(
      id: 'i',
      projectId: 'p',
      blobId: 'b',
      mimeType: 'image/jpeg',
      width: 0,
      height: 0,
      origin: ImageOrigin.device,
      capturedAt: null,
      edits: Edits.none,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      updatedByDeviceId: 'd',
    );
  }

  test('decodes the original EXIF-oriented and passes it on', () async {
    final detector = _RecordingDetector();
    final detection = PlatformCanvasDetection(files: files, detector: detector);
    // Stored 40×30 with orientation 6: shown 30×40.
    final result = await detection.detect(
      await stored('orientation_6.jpg'),
      aspectHint: 0.8,
    );
    expect((detector.image!.width, detector.image!.height), (30, 40));
    expect(detector.image!.rgba.length, 30 * 40 * 4);
    expect(detector.hint, 0.8);
    expect(result.isLowConfidence, isTrue);
  });
}
