/// Canvas (painting) corner detection (m1-design §6).
///
/// The [CanvasDetector] interface is pure Dart; the OpenCV implementation
/// arrives in M1 T13.
library;

export 'src/detector.dart';
export 'src/opencv_detector.dart';
export 'src/scoring.dart' show ScoringParams;
export 'src/stub_detector.dart';
