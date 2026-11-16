import 'dart:typed_data';

/// A corner in normalized image coordinates (0–1, origin top-left, y down).
class Corner {
  const Corner(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is Corner && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// Four corners of a canvas: top-left, top-right, bottom-right, bottom-left.
class Quad {
  Quad(List<Corner> corners) : corners = List.unmodifiable(corners) {
    if (corners.length != 4) {
      throw ArgumentError.value(corners.length, 'corners', 'Must have 4');
    }
  }

  final List<Corner> corners;

  /// The `corners` of an evaluation-set entry (m1-design §6.4).
  List<List<double>> toJson() => [
    for (final c in corners) [c.x, c.y],
  ];

  @override
  bool operator ==(Object other) =>
      other is Quad &&
      Iterable<int>.generate(4).every((i) => other.corners[i] == corners[i]);

  @override
  int get hashCode => Object.hashAll(corners);

  @override
  String toString() => 'Quad($corners)';
}

/// Decoded pixels to detect in: 8-bit RGBA, row by row, EXIF orientation
/// already applied. Corners are relative to this image.
class DetectorImage {
  DetectorImage({
    required this.width,
    required this.height,
    required this.rgba,
  }) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError('Expected ${width * height * 4} bytes of RGBA');
    }
  }

  final int width;
  final int height;
  final Uint8List rgba;
}

/// What a detector found.
class Detection {
  const Detection({required this.quad, required this.confidence});

  /// Below this, the review screen treats the result as a guess
  /// (m1-design §3.8).
  static const lowConfidenceThreshold = 0.5;

  final Quad quad;

  /// 0–1.
  final double confidence;

  bool get isLowConfidence => confidence < lowConfidenceThreshold;

  @override
  String toString() => 'Detection($quad, confidence: $confidence)';
}

/// Finds the corners of a painting in a photo.
abstract interface class CanvasDetector {
  /// [aspectHint] is the painting's expected width/height, if known (the
  /// project's size), as a soft preference.
  Future<Detection> detect(DetectorImage image, {double? aspectHint});
}
