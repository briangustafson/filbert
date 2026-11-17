import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_canvas.dart';

/// The integration test (`integration_test/m1_flow_test.dart`) relies on the
/// detector finding this photo confidently; this checks it on the host.
void main() {
  test('the synthetic canvas is detected confidently and accurately', () {
    final dir = Directory.systemTemp.createTempSync('synthetic_canvas');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = SyntheticCanvas.write('${dir.path}/canvas.jpg');

    // Downscaled like the app does before detection (m1-design §6.2).
    final bgr = cv.imread(file.path);
    final small = cv.resize(bgr, (1000, 750), interpolation: cv.INTER_AREA);
    final rgba = cv.cvtColor(small, cv.COLOR_BGR2RGBA);
    final detection = const OpenCvCanvasDetector().detectSync(
      DetectorImage(
        width: rgba.cols,
        height: rgba.rows,
        rgba: Uint8List.fromList(rgba.data),
      ),
    );

    expect(detection.isLowConfidence, isFalse, reason: '$detection');
    final truth = SyntheticCanvas.normalizedCorners;
    for (var i = 0; i < 4; i++) {
      final c = detection.quad.corners[i];
      final (x, y) = truth[i];
      expect(
        math.max((c.x - x).abs(), (c.y - y).abs()),
        lessThan(0.01),
        reason: 'corner $i: $c vs ($x, $y)',
      );
    }
  });
}
