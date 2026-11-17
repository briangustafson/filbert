import 'dart:math' as math;

/// A point or vector in pixels (y down).
class V {
  const V(this.x, this.y);

  final double x;
  final double y;

  V operator +(V o) => V(x + o.x, y + o.y);
  V operator -(V o) => V(x - o.x, y - o.y);
  V operator *(double k) => V(x * k, y * k);
  double dot(V o) => x * o.x + y * o.y;
  double cross(V o) => x * o.y - y * o.x;
  double get length => math.sqrt(x * x + y * y);
  V get unit => this * (1 / length);

  /// Rotated 90° (a normal of this direction).
  V get perp => V(-y, x);

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// An infinite line through [p] along unit direction [d].
class Line {
  Line(this.p, V d) : d = d.unit;

  /// Through two points.
  factory Line.through(V a, V b) => Line(a, b - a);

  final V p;
  final V d;

  V get normal => d.perp;

  /// Signed distance of [q] from the line.
  double distance(V q) => (q - p).dot(normal);

  /// Angle of the direction in degrees, folded to (−90, 90].
  double get angleDegrees {
    var a = math.atan2(d.y, d.x) * 180 / math.pi;
    if (a <= -90) a += 180;
    if (a > 90) a -= 180;
    return a;
  }

  /// Intersection with [o]; null if (nearly) parallel.
  V? intersect(Line o) {
    final denom = d.cross(o.d);
    if (denom.abs() < 1e-9) return null;
    final t = (o.p - p).cross(o.d) / denom;
    return p + d * t;
  }
}

/// Least-squares line through [points] (total least squares, so any
/// orientation works). Null for fewer than two distinct points.
Line? fitLine(List<V> points) {
  if (points.length < 2) return null;
  var mx = 0.0, my = 0.0;
  for (final p in points) {
    mx += p.x;
    my += p.y;
  }
  mx /= points.length;
  my /= points.length;
  var sxx = 0.0, sxy = 0.0, syy = 0.0;
  for (final p in points) {
    final dx = p.x - mx, dy = p.y - my;
    sxx += dx * dx;
    sxy += dx * dy;
    syy += dy * dy;
  }
  // Principal direction of the scatter.
  final angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
  final d = V(math.cos(angle), math.sin(angle));
  if (sxx + syy == 0) return null;
  return Line(V(mx, my), d);
}

/// [fitLine], repeatedly dropping points further than [maxResidual] from
/// the fit. Null if fewer than [minPoints] remain.
Line? fitLineRobust(
  List<V> points, {
  double maxResidual = 1.5,
  int minPoints = 6,
}) {
  var inliers = points;
  Line? line = fitLine(inliers);
  for (var i = 0; i < 4 && line != null; i++) {
    final fit = line;
    // Looser first, so one bad first fit doesn't discard the real edge.
    final limit = maxResidual * (i == 0 ? 4 : (i == 1 ? 2 : 1));
    final next = [
      for (final p in inliers)
        if (fit.distance(p).abs() <= limit) p,
    ];
    if (next.length < minPoints) return null;
    inliers = next;
    line = fitLine(inliers);
  }
  return inliers.length >= minPoints ? line : null;
}

/// Interior angles (degrees) of quad [q] (TL, TR, BR, BL).
List<double> interiorAngles(List<V> q) => [
  for (var i = 0; i < 4; i++)
    _angleBetween(q[(i + 3) % 4] - q[i], q[(i + 1) % 4] - q[i]),
];

double _angleBetween(V a, V b) {
  final c = (a.dot(b) / (a.length * b.length)).clamp(-1.0, 1.0);
  return math.acos(c) * 180 / math.pi;
}

/// Area of a simple polygon (shoelace), positive.
double polygonArea(List<V> q) {
  var s = 0.0;
  for (var i = 0; i < q.length; i++) {
    s += q[i].cross(q[(i + 1) % q.length]);
  }
  return s.abs() / 2;
}

/// Whether [q] (TL, TR, BR, BL, y down) is convex and turns the same way at
/// every corner.
bool isConvexClockwise(List<V> q) {
  for (var i = 0; i < 4; i++) {
    final a = q[i], b = q[(i + 1) % 4], c = q[(i + 2) % 4];
    if ((b - a).cross(c - b) <= 0) return false;
  }
  return true;
}

/// Orders four points TL, TR, BR, BL (clockwise from top-left on screen).
List<V> orderCorners(List<V> pts) {
  final cx = pts.map((p) => p.x).reduce((a, b) => a + b) / 4;
  final cy = pts.map((p) => p.y).reduce((a, b) => a + b) / 4;
  final sorted = [...pts]
    ..sort(
      (a, b) => math
          .atan2(a.y - cy, a.x - cx)
          .compareTo(math.atan2(b.y - cy, b.x - cx)),
    );
  // atan2 ascending from −π: TL-ish first after rotating so the corner with
  // the smallest x + y leads.
  var start = 0;
  for (var i = 1; i < 4; i++) {
    if (sorted[i].x + sorted[i].y < sorted[start].x + sorted[start].y) {
      start = i;
    }
  }
  return [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
}

/// How far (degrees) quad [q] (TL, TR, BR, BL) is from the image of a
/// rectangle, for a camera centred at [centre] with a focal length between
/// [focalMin] and [focalMax] pixels: the deviation from 90° of the angle
/// between the rectangle's sides in 3D (Zhang & He, whiteboard scanning).
/// A quad along unrelated lines (a post beside the canvas, a fence board)
/// usually can't be a rectangle seen by any phone camera.
double rectangleError(List<V> q, V centre, double focalMin, double focalMax) {
  // Homogeneous corners in the paper's order: m1 TL, m2 TR, m3 BL, m4 BR.
  List<double> h(V p) => [p.x - centre.x, p.y - centre.y, 1];
  final m1 = h(q[0]), m2 = h(q[1]), m3 = h(q[3]), m4 = h(q[2]);
  List<double> cross(List<double> a, List<double> b) => [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
  double dot(List<double> a, List<double> b) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  final m14 = cross(m1, m4);
  final k2 = dot(m14, m3) / dot(cross(m2, m4), m3);
  final k3 = dot(m14, m2) / dot(cross(m3, m4), m2);
  // The rectangle's two side directions, up to the camera matrix.
  final n2 = [for (var i = 0; i < 3; i++) k2 * m2[i] - m1[i]];
  final n3 = [for (var i = 0; i < 3; i++) k3 * m3[i] - m1[i]];
  double errorAt(double f) {
    final a = [n2[0] / f, n2[1] / f, n2[2]];
    final b = [n3[0] / f, n3[1] / f, n3[2]];
    final c = dot(a, b) / math.sqrt(dot(a, a) * dot(b, b));
    return (math.acos(c.clamp(-1.0, 1.0)) * 180 / math.pi - 90).abs();
  }

  // The angle's cosine is A/f² + B: zero at f² = −A/B if that's in range.
  final aTerm = n2[0] * n3[0] + n2[1] * n3[1], bTerm = n2[2] * n3[2];
  if (bTerm != 0) {
    final f2 = -aTerm / bTerm;
    if (f2 >= focalMin * focalMin && f2 <= focalMax * focalMax) return 0;
  }
  return math.min(errorAt(focalMin), errorAt(focalMax));
}
