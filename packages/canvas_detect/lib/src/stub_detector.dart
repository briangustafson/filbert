import 'detector.dart';

/// Placeholder until the OpenCV detector (M1 T13): the whole image, inset a
/// little, with no confidence — so the review screen asks the user to drag
/// the corners.
class StubCanvasDetector implements CanvasDetector {
  const StubCanvasDetector({this.inset = 0.05});

  /// Fraction of the width and height kept clear on each side.
  final double inset;

  @override
  Future<Detection> detect(DetectorImage image, {double? aspectHint}) async {
    final a = inset, b = 1 - inset;
    return Detection(
      quad: Quad([Corner(a, a), Corner(b, a), Corner(b, b), Corner(a, b)]),
      confidence: 0,
    );
  }
}
