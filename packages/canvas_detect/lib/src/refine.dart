import 'dart:math' as math;

import 'edge_map.dart';
import 'geometry.dart';

/// Corner refinement (m1-design §6.2 step 6). Instead of refining each
/// corner on its own (corners are often covered by clamps or the easel),
/// each side is fitted to the edge it lies on and the corners are taken as
/// the intersections of neighbouring sides. Pure Dart.

/// Refines quad [q] (TL, TR, BR, BL, pixels of [edges]) whose sides are
/// within about [search] px of the true edges. Sides in [borderSides] (on
/// the photo's border) are kept as the border. Corners are clamped to the
/// image.
///
/// Where a side has several strong edges nearby (the canvas's face and its
/// side, or its shadow), the innermost one at least [innerPeak] times as
/// strong as the strongest wins: a crop slightly inside the canvas is better
/// than one showing the background.
List<V> refineQuad(
  EdgeMap edges,
  List<V> q, {
  required double search,
  Set<int> borderSides = const {},
  double cornerSkip = 0.1,
  double innerPeak = 0.6,
}) {
  final threshold = math.max(edges.magnitudeQuantile(0.75), 6.0);
  final lines = <Line>[];
  for (var s = 0; s < 4; s++) {
    final a = q[s], b = q[(s + 1) % 4];
    final original = Line.through(a, b);
    if (borderSides.contains(s)) {
      lines.add(original);
      continue;
    }
    lines.add(
      _fitSide(edges, a, b, search, threshold, cornerSkip, innerPeak) ??
          original,
    );
  }
  final refined = <V>[];
  for (var i = 0; i < 4; i++) {
    // Corner i is where side i−1 meets side i.
    final p = lines[(i + 3) % 4].intersect(lines[i]);
    // Implausible jumps (nearly parallel neighbours) keep the original.
    refined.add(p == null || (p - q[i]).length > search * 4 ? q[i] : p);
  }
  return [
    for (final p in refined)
      V(
        p.x.clamp(0.0, edges.width.toDouble()),
        p.y.clamp(0.0, edges.height.toDouble()),
      ),
  ];
}

/// The line through the strongest edge points near side a→b, or null if
/// too few are found.
Line? _fitSide(
  EdgeMap edges,
  V a,
  V b,
  double search,
  double threshold,
  double cornerSkip,
  double innerPeak,
) {
  final dir = b - a;
  final length = dir.length;
  if (length < 8) return null;
  // Points inward for a clockwise quad.
  final n = dir.unit.perp;
  final samples = math.max(16, (length / 3).round());
  final points = <V>[];
  final steps = search.ceil();
  for (var i = 0; i <= samples; i++) {
    final t = cornerSkip + (1 - 2 * cornerSkip) * i / samples;
    final p = a + dir * t;
    var best = 0.0, bestOffset = 0.0;
    for (var o = -steps; o <= steps; o++) {
      final v = edges.across(p + n * o.toDouble(), n);
      if (v > best) {
        best = v;
        bestOffset = o.toDouble();
      }
    }
    if (best < threshold) continue;
    // The innermost local peak nearly as strong.
    for (var o = steps - 1; o > bestOffset; o--) {
      final v = edges.across(p + n * o.toDouble(), n);
      if (v >= best * innerPeak &&
          v >= edges.across(p + n * (o - 1.0), n) &&
          v >= edges.across(p + n * (o + 1.0), n)) {
        best = v;
        bestOffset = o.toDouble();
        break;
      }
    }
    // Sub-pixel: parabola through the peak and its neighbours.
    final l = edges.across(p + n * (bestOffset - 1), n);
    final r = edges.across(p + n * (bestOffset + 1), n);
    final denom = l - 2 * best + r;
    final sub = denom.abs() < 1e-9
        ? 0.0
        : (0.5 * (l - r) / denom).clamp(-0.5, 0.5);
    points.add(p + n * (bestOffset + sub));
  }
  return fitLineRobust(
    points,
    maxResidual: 1.5,
    minPoints: math.max(6, samples ~/ 5),
  );
}

/// Quad [q] (TL, TR, BR, BL, clockwise) with every side moved [distance]
/// px inward.
List<V> insetQuad(List<V> q, double distance) {
  final lines = [
    for (var s = 0; s < 4; s++)
      () {
        final a = q[s], b = q[(s + 1) % 4];
        final shift = (b - a).unit.perp * distance;
        return Line.through(a + shift, b + shift);
      }(),
  ];
  return [
    for (var i = 0; i < 4; i++) lines[(i + 3) % 4].intersect(lines[i]) ?? q[i],
  ];
}
