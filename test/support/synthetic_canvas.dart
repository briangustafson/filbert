import 'dart:io';
import 'dart:math' as math;

import 'package:dartcv4/dartcv.dart' as cv;

/// A generated "photo of a painting" for tests that need a real JPEG the
/// detector can find: a tilted light canvas with some painted shapes on a
/// textured wall. No real photo, so no metadata or private content.
class SyntheticCanvas {
  static const width = 1600, height = 1200;

  /// The canvas corners in pixels: top-left, top-right, bottom-right,
  /// bottom-left.
  static const corners = [(360, 220), (1280, 280), (1220, 1000), (320, 940)];

  /// [corners] normalized to 0–1.
  static List<(double, double)> get normalizedCorners => [
    for (final (x, y) in corners) (x / width, y / height),
  ];

  /// Writes the JPEG to [path] and returns the file.
  static File write(String path) {
    final bgr = cv.Mat.zeros(height, width, cv.MatType.CV_8UC3)
      ..setTo(cv.Scalar(90, 110, 120));
    final random = math.Random(1);
    for (var i = 0; i < 1200; i++) {
      final x = random.nextInt(width), y = random.nextInt(height);
      cv.line(
        bgr,
        cv.Point(x, y),
        cv.Point(x + random.nextInt(80) - 40, y + random.nextInt(80) - 40),
        cv.Scalar(60, 80, 100),
        thickness: 2,
      );
    }
    cv.fillPoly(
      bgr,
      cv.VecVecPoint.fromList([
        [for (final (x, y) in corners) cv.Point(x, y)],
      ]),
      cv.Scalar(200, 190, 170),
    );
    // A few painted shapes well inside the canvas.
    cv.rectangle(
      bgr,
      cv.Rect(560, 450, 300, 200),
      cv.Scalar(150, 120, 80),
      thickness: -1,
    );
    cv.circle(
      bgr,
      cv.Point(980, 560),
      110,
      cv.Scalar(70, 140, 190),
      thickness: -1,
    );
    final (ok, jpeg) = cv.imencode(
      '.jpg',
      bgr,
      params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 90]),
    );
    bgr.dispose();
    if (!ok) throw StateError('JPEG encoding failed');
    return File(path)..writeAsBytesSync(jpeg);
  }
}
