import 'dart:math' as math;

import 'package:canvas_detect/canvas_detect.dart';
import 'package:canvas_detect/src/geometry.dart';
import 'package:test/test.dart';

void main() {
  test('fitLineRobust ignores outliers', () {
    final points = [
      for (var x = 0; x <= 20; x++) V(x.toDouble(), 10 + 0.5 * x),
      const V(5, 40),
      const V(15, -20),
    ];
    final line = fitLineRobust(points)!;
    expect(line.distance(const V(8, 14)).abs(), lessThan(1e-6));
    expect(line.angleDegrees, closeTo(math.atan(0.5) * 180 / math.pi, 1e-6));
  });

  test('orderCorners and isConvexClockwise', () {
    final q = orderCorners(const [V(90, 80), V(10, 10), V(10, 90), V(100, 5)]);
    expect(q, hasLength(4));
    expect((q[0].x, q[0].y), (10, 10));
    expect((q[1].x, q[1].y), (100, 5));
    expect((q[2].x, q[2].y), (90, 80));
    expect((q[3].x, q[3].y), (10, 90));
    expect(isConvexClockwise(q), isTrue);
    expect(isConvexClockwise(q.reversed.toList()), isFalse);
  });

  group('rectangleError', () {
    const size = 1000.0, centre = V(500, 400);

    /// A 0.6 × 0.8 rectangle 2 units in front of a camera with focal [f],
    /// turned [yaw]° about the vertical and [pitch]° about the horizontal.
    List<V> projected(double f, double yaw, double pitch) {
      final cy = math.cos(yaw * math.pi / 180),
          sy = math.sin(yaw * math.pi / 180);
      final cp = math.cos(pitch * math.pi / 180),
          sp = math.sin(pitch * math.pi / 180);
      return [
        for (final (x, y) in const [
          (-0.3, -0.4),
          (0.3, -0.4),
          (0.3, 0.4),
          (-0.3, 0.4),
        ])
          () {
            // Yaw, then pitch, then push 2 units away.
            final x1 = cy * x, z1 = -sy * x;
            final y2 = cp * y - sp * z1, z2 = sp * y + cp * z1 + 2;
            return V(centre.x + f * x1 / z2, centre.y + f * y2 / z2);
          }(),
      ];
    }

    test('is zero for a rectangle seen through a phone-like camera', () {
      for (final (yaw, pitch) in const [
        (0.0, 0.0),
        (25.0, 0.0),
        (15.0, -20.0),
      ]) {
        final q = projected(0.8 * size, yaw, pitch);
        expect(
          rectangleError(q, centre, 0.6 * size, 1.6 * size),
          lessThan(0.5),
          reason: 'yaw $yaw pitch $pitch',
        );
      }
    });

    test('is large for one side upright and the other leaning', () {
      const q = [V(300, 100), V(700, 100), V(600, 700), V(300, 700)];
      // Penalised: above ScoringParams.rectangleTolerance.
      expect(
        rectangleError(q, centre, 0.6 * size, 1.6 * size),
        greaterThan(const ScoringParams().rectangleTolerance),
      );
    });
  });
}
