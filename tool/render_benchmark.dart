// Preview-render latency benchmark (m1-design §9). Run on a device:
//
//   flutter run --profile -d <device> -t tool/render_benchmark.dart
//
// It replaces the Filbert app installed on the device (same app, this file as
// the entry point); reinstall the app afterwards with `flutter run --release`.
// Being a profile build, it leaves a dartcv4 keep-list behind: clear it
// afterwards (m1-design §7).
//
// Prints timings to the console, then shows "done" on screen. Synthetic
// photos (12 MP and 48 MP JPEGs) are generated on the device first. Also
// times canvas detection (m1-design §6.2, target < 500 ms).

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:canvas_detect/safe_cv.dart' as safe_cv;
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/features/autocrop/canvas_detection.dart';
import 'package:filbert/features/photos/data/image_renderer.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:flutter/widgets.dart';

import '../test/support/synthetic_canvas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const Center(child: Text('rendering…', textDirection: TextDirection.ltr)),
  );

  final root = Directory('${Directory.systemTemp.path}/render_benchmark');
  if (root.existsSync()) root.deleteSync(recursive: true);
  final files = LocalFileStore(
    supportDir: Directory('${root.path}/support'),
    cacheDir: Directory('${root.path}/cache'),
  );

  final perspective = Edits(
    crop: CropEdit(
      quad: const [
        NormPoint(0.08, 0.05),
        NormPoint(0.93, 0.10),
        NormPoint(0.90, 0.95),
        NormPoint(0.05, 0.92),
      ],
      output: const OutputAspect(4, 3),
    ),
  );

  // One-time costs, measured separately from the renders below.
  final warmup = Stopwatch()..start();
  await Isolate.run(() => cv.Mat.zeros(1, 1, cv.MatType.CV_8UC3).cols);
  debugPrint(
    'BENCH first OpenCV call in an isolate: ${warmup.elapsedMilliseconds} ms',
  );

  for (final (label, w, h) in [('12 MP', 4000, 3000), ('48 MP', 8000, 6000)]) {
    final blobId = 'bench-$w';
    final source = File('${root.path}/$blobId.jpg');
    source.parent.createSync(recursive: true);
    source.writeAsBytesSync(_syntheticJpeg(w, h));
    await files.putBlob(blobId, 'jpg', source);
    final bytes = source.readAsBytesSync();
    for (final (name, edits) in [
      ('full', Edits.none),
      ('perspective', perspective),
    ]) {
      final sw = Stopwatch()..start();
      await decodeForRender(bytes, edits, OpenCvImageRenderer.previewLongEdge);
      debugPrint(
        'BENCH $label $name decode only: ${sw.elapsedMilliseconds} ms',
      );
    }

    for (final (name, edits) in [
      ('full', Edits.none),
      ('perspective', perspective),
    ]) {
      final times = <int>[];
      for (var run = 0; run < 4; run++) {
        final image = _image(blobId, edits, run);
        await files.deleteCachesFor(image.id);
        // A fresh renderer each run, so nothing is cached in memory.
        final renderer = OpenCvImageRenderer(files: files);
        final sw = Stopwatch()..start();
        await renderer.preview(image);
        times.add(sw.elapsedMilliseconds);
      }
      // The first run includes one-time warm-up; report the rest.
      final warm = times.skip(1).toList()..sort();
      debugPrint(
        'BENCH $label $name: first ${times.first} ms, '
        'median ${warm[warm.length ~/ 2]} ms (runs $times)',
      );
    }
  }
  await _benchmarkDetection(root, files);
  debugPrint('BENCH done');
  runApp(const Center(child: Text('done', textDirection: TextDirection.ltr)));
}

/// Canvas detection as the review screen runs it: platform decode and
/// downscale, then the detector in an isolate. The photo is the synthetic
/// canvas scaled up, so the detector sees a canvas-like scene.
Future<void> _benchmarkDetection(Directory root, FileStore files) async {
  const detector = OpenCvCanvasDetector();
  final detection = PlatformCanvasDetection(files: files, detector: detector);
  final canvas = SyntheticCanvas.write('${root.path}/canvas.jpg');
  for (final (label, w, h) in [('12 MP', 4000, 3000), ('48 MP', 8000, 6000)]) {
    final blobId = 'canvas-$w';
    final source = File('${root.path}/$blobId.jpg');
    final original = cv.imread(canvas.path);
    final scaled = safe_cv.resize(original, (
      w,
      h,
    ), interpolation: cv.INTER_CUBIC);
    final (ok, bytes) = cv.imencode(
      '.jpg',
      scaled,
      params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 92]),
    );
    if (!ok) throw StateError('encode failed');
    original.dispose();
    scaled.dispose();
    source.writeAsBytesSync(bytes);
    await files.putBlob(blobId, 'jpg', source);

    final total = <int>[];
    for (var run = 0; run < 5; run++) {
      final sw = Stopwatch()..start();
      final result = await detection.detect(_image(blobId, Edits.none, run));
      total.add(sw.elapsedMilliseconds);
      if (run == 0) {
        debugPrint(
          'BENCH detect $label confidence ${result.confidence.toStringAsFixed(2)}',
        );
      }
    }

    // The detector alone, on the downscaled pixels detection works on.
    final small = safe_cv.resize(cv.imread(canvas.path), (
      PlatformCanvasDetection.maxLongEdge,
      PlatformCanvasDetection.maxLongEdge * 3 ~/ 4,
    ), interpolation: cv.INTER_AREA);
    final rgba = cv.cvtColor(small, cv.COLOR_BGR2RGBA);
    final pixels = DetectorImage(
      width: rgba.cols,
      height: rgba.rows,
      rgba: Uint8List.fromList(rgba.data),
    );
    final detectorOnly = <int>[];
    for (var run = 0; run < 5; run++) {
      final sw = Stopwatch()..start();
      await detector.detect(pixels);
      detectorOnly.add(sw.elapsedMilliseconds);
    }
    debugPrint(
      'BENCH detect $label: median ${_median(total)} ms with decode, '
      '${_median(detectorOnly)} ms detector only '
      '(runs $total / $detectorOnly)',
    );
  }
}

int _median(List<int> times) => (times.toList()..sort())[times.length ~/ 2];

ProjectImage _image(String blobId, Edits edits, int run) => ProjectImage(
  id: '$blobId-$run',
  projectId: 'bench',
  blobId: blobId,
  mimeType: 'image/jpeg',
  width: 0,
  height: 0,
  origin: ImageOrigin.device,
  capturedAt: null,
  edits: edits,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedByDeviceId: 'bench',
);

/// A photo-like JPEG: smooth gradients plus noise, so it doesn't compress
/// unrealistically well.
Uint8List _syntheticJpeg(int w, int h) {
  final small = cv.Mat.zeros(h ~/ 8, w ~/ 8, cv.MatType.CV_8UC3);
  cv.randu(small, cv.Scalar.all(0), cv.Scalar.all(255));
  final blurred = safe_cv.gaussianBlur(small, (31, 31), 0);
  final big = safe_cv.resize(blurred, (w, h), interpolation: cv.INTER_CUBIC);
  final noise = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3);
  cv.randn(noise, cv.Scalar.all(0), cv.Scalar.all(12));
  final photo = cv.add(big, noise);
  final (ok, bytes) = cv.imencode(
    '.jpg',
    photo,
    params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 92]),
  );
  if (!ok) throw StateError('encode failed');
  for (final m in [small, blurred, big, noise, photo]) {
    m.dispose();
  }
  return bytes;
}
