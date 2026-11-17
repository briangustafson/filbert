import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';

/// Image gradients for scoring and refinement: per pixel, the stronger of
/// the brightness and saturation gradients (canvas and wall often differ
/// more in saturation than brightness, m1-design §6.2).
class EdgeMap {
  EdgeMap({
    required this.width,
    required this.height,
    required this.gx,
    required this.gy,
  }) : assert(gx.length == width * height && gy.length == width * height);

  final int width;
  final int height;
  final Float32List gx;
  final Float32List gy;

  /// Gradient strength across a line with unit normal [n] at [p]
  /// (bilinear-free: nearest pixel); 0 outside the image.
  double across(V p, V n) {
    final x = p.x.round(), y = p.y.round();
    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return 0;
    final i = y * width + x;
    return (gx[i] * n.x + gy[i] * n.y).abs();
  }

  /// Signed gradient across the line (positive: brighter / more saturated
  /// on the normal's side).
  double signedAcross(V p, V n) {
    final x = p.x.round(), y = p.y.round();
    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return 0;
    final i = y * width + x;
    return gx[i] * n.x + gy[i] * n.y;
  }

  /// The [q]-quantile of gradient magnitude, sampled on a grid.
  double magnitudeQuantile(double q) {
    final samples = <double>[];
    final step = math.max(1, math.sqrt(width * height / 20000).floor());
    for (var y = 1; y < height - 1; y += step) {
      for (var x = 1; x < width - 1; x += step) {
        final i = y * width + x;
        samples.add(math.sqrt(gx[i] * gx[i] + gy[i] * gy[i]));
      }
    }
    if (samples.isEmpty) return 0;
    samples.sort();
    return samples[(q * (samples.length - 1)).round()];
  }
}
