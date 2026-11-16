import 'dart:typed_data';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:test/test.dart';

void main() {
  final image = DetectorImage(width: 4, height: 3, rgba: Uint8List(4 * 3 * 4));

  test('the stub returns an inset quad with no confidence', () async {
    final d = await const StubCanvasDetector().detect(image);
    expect(d.quad.corners, const [
      Corner(0.05, 0.05),
      Corner(0.95, 0.05),
      Corner(0.95, 0.95),
      Corner(0.05, 0.95),
    ]);
    expect(d.confidence, 0);
    expect(d.isLowConfidence, isTrue);
  });

  test('confidence threshold', () {
    final quad = Quad(const [
      Corner(0, 0),
      Corner(1, 0),
      Corner(1, 1),
      Corner(0, 1),
    ]);
    expect(Detection(quad: quad, confidence: 0.49).isLowConfidence, isTrue);
    expect(Detection(quad: quad, confidence: 0.5).isLowConfidence, isFalse);
  });

  test('quads have four corners and serialize as [x, y] pairs', () {
    expect(() => Quad(const [Corner(0, 0)]), throwsArgumentError);
    final quad = Quad(const [
      Corner(0.1, 0.2),
      Corner(0.9, 0.2),
      Corner(0.9, 0.8),
      Corner(0.1, 0.8),
    ]);
    expect(quad.toJson(), [
      [0.1, 0.2],
      [0.9, 0.2],
      [0.9, 0.8],
      [0.1, 0.8],
    ]);
  });

  test('images must have the right number of bytes', () {
    expect(
      () => DetectorImage(width: 2, height: 2, rgba: Uint8List(3)),
      throwsArgumentError,
    );
  });
}
