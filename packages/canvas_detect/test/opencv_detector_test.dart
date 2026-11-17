import 'dart:math' as math;
import 'dart:typed_data';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:test/test.dart';

const w = 800, h = 600;
const corners = [(180, 110), (640, 140), (610, 500), (160, 470)];

/// A tilted canvas ([canvas] colour, BGR) on a textured background.
Uint8List scene({
  required cv.Scalar background,
  required cv.Scalar texture,
  required cv.Scalar canvas,
}) {
  final bgr = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3)..setTo(background);
  final random = math.Random(1);
  for (var i = 0; i < 300; i++) {
    final x = random.nextInt(w), y = random.nextInt(h);
    cv.line(
      bgr,
      cv.Point(x, y),
      cv.Point(x + random.nextInt(40) - 20, y + random.nextInt(40) - 20),
      texture,
    );
  }
  cv.fillPoly(
    bgr,
    cv.VecVecPoint.fromList([
      [for (final (x, y) in corners) cv.Point(x, y)],
    ]),
    canvas,
  );
  final rgba = cv.cvtColor(bgr, cv.COLOR_BGR2RGBA);
  return Uint8List.fromList(rgba.data);
}

/// [rgba] with ±1 noise on every colour channel.
Uint8List noisy(Uint8List rgba, int seed) {
  final random = math.Random(seed);
  return Uint8List.fromList([
    for (var i = 0; i < rgba.length; i++)
      i % 4 == 3 ? rgba[i] : (rgba[i] + random.nextInt(3) - 1).clamp(0, 255),
  ]);
}

/// Largest corner distance from [corners], as a fraction of the diagonal.
double maxError(Detection d) {
  var worst = 0.0;
  for (var i = 0; i < 4; i++) {
    final (x, y) = corners[i];
    final c = d.quad.corners[i];
    worst = math.max(
      worst,
      math.sqrt(math.pow(c.x * w - x, 2) + math.pow(c.y * h - y, 2)),
    );
  }
  return worst / math.sqrt(w * w + h * h);
}

Detection detect(Uint8List rgba) => const OpenCvCanvasDetector().detectSync(
  DetectorImage(width: w, height: h, rgba: rgba),
);

void main() {
  test('finds a tilted canvas on a textured background', () {
    final rgba = scene(
      background: cv.Scalar(90, 110, 120),
      texture: cv.Scalar(60, 80, 100),
      canvas: cv.Scalar(200, 190, 170),
    );
    expect(maxError(detect(rgba)), lessThan(0.01));
  });

  test('a dark scene gives the same answer with invisible noise', () {
    // Dark areas are where noise used to turn into edges (HSV saturation
    // divides by brightness; m1-design §6.2).
    final rgba = scene(
      background: cv.Scalar(18, 20, 24),
      texture: cv.Scalar(10, 14, 16),
      canvas: cv.Scalar(70, 60, 55),
    );
    expect(maxError(detect(rgba)), lessThan(0.01));
    for (final seed in [1, 2, 3]) {
      expect(
        maxError(detect(noisy(rgba, seed))),
        lessThan(0.01),
        reason: 'noise seed $seed',
      );
    }
  });
}
