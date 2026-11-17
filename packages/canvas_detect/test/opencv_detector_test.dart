import 'dart:math' as math;

import 'package:canvas_detect/canvas_detect.dart';
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:test/test.dart';

void main() {
  test('finds a tilted canvas on a textured background', () {
    const w = 800, h = 600;
    final bgr = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3)
      ..setTo(cv.Scalar(90, 110, 120));
    // Background texture.
    final random = math.Random(1);
    for (var i = 0; i < 300; i++) {
      final x = random.nextInt(w), y = random.nextInt(h);
      cv.line(
        bgr,
        cv.Point(x, y),
        cv.Point(x + random.nextInt(40) - 20, y + random.nextInt(40) - 20),
        cv.Scalar(60, 80, 100),
      );
    }
    const corners = [(180, 110), (640, 140), (610, 500), (160, 470)];
    cv.fillPoly(
      bgr,
      cv.VecVecPoint.fromList([
        [for (final (x, y) in corners) cv.Point(x, y)],
      ]),
      cv.Scalar(200, 190, 170),
    );
    final rgba = cv.cvtColor(bgr, cv.COLOR_BGR2RGBA);

    final d = const OpenCvCanvasDetector().detectSync(
      DetectorImage(width: w, height: h, rgba: rgba.data),
    );

    final diagonal = math.sqrt(w * w + h * h);
    for (var i = 0; i < 4; i++) {
      final (x, y) = corners[i];
      final c = d.quad.corners[i];
      final error = math.sqrt(
        math.pow(c.x * w - x, 2) + math.pow(c.y * h - y, 2),
      );
      expect(error / diagonal, lessThan(0.01), reason: 'corner $i');
    }
  });
}
