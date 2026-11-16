import 'dart:math' as math;

import 'edits.dart';

/// Geometry of the manual crop (m1-design §3.7, §4.2). Pure arithmetic in
/// pixels of the EXIF-oriented original, so it is unit-tested without UI.
///
/// Three coordinate spaces, all centred on the image centre:
/// - **original**: the photo as stored (y down);
/// - **straightened**: the original rotated clockwise by [CropFrame.angle];
/// - **display**: the straightened space turned clockwise by
///   [CropFrame.quarterTurns] quarter turns — what the crop screen shows.
///
/// The crop is an axis-aligned [CropRect] in display space. It is stored as
/// the quad of its corners in the original (normalized, ordered as the warp
/// sees them: straightened space), plus the quarter turns.

/// A point in one of the centred spaces.
typedef CropPoint = ({double x, double y});

/// An axis-aligned rectangle in display space (centred coordinates, pixels).
class CropRect {
  const CropRect(this.left, this.top, this.right, this.bottom);

  /// Centred on (cx, cy).
  factory CropRect.centered(
    double cx,
    double cy,
    double width,
    double height,
  ) => CropRect(
    cx - width / 2,
    cy - height / 2,
    cx + width / 2,
    cy + height / 2,
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  CropPoint get center => (x: (left + right) / 2, y: (top + bottom) / 2);

  List<CropPoint> get corners => [
    (x: left, y: top),
    (x: right, y: top),
    (x: right, y: bottom),
    (x: left, y: bottom),
  ];

  /// Linear interpolation towards [other] (t = 0: this; t = 1: other).
  CropRect lerp(CropRect other, double t) => CropRect(
    left + (other.left - left) * t,
    top + (other.top - top) * t,
    right + (other.right - right) * t,
    bottom + (other.bottom - bottom) * t,
  );

  CropRect translate(double dx, double dy) =>
      CropRect(left + dx, top + dy, right + dx, bottom + dy);

  /// Scaled by [s] about its centre.
  CropRect scale(double s) {
    final c = center;
    return CropRect.centered(c.x, c.y, width * s, height * s);
  }

  /// Turned clockwise by a quarter turn about the space's origin.
  CropRect turnClockwise() => _bounds([for (final p in corners) _cw(p)]);

  bool closeTo(CropRect other, double tolerance) =>
      (left - other.left).abs() <= tolerance &&
      (top - other.top).abs() <= tolerance &&
      (right - other.right).abs() <= tolerance &&
      (bottom - other.bottom).abs() <= tolerance;

  @override
  bool operator ==(Object other) =>
      other is CropRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'CropRect(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)})';
}

/// An aspect ratio as a width:height pair (e.g. 4:5), kept as given so it
/// can be stored and labelled exactly.
class CropAspect {
  const CropAspect(this.w, this.h);

  final double w;
  final double h;

  double get ratio => w / h;
  CropAspect get flipped => CropAspect(h, w);
  bool get isSquare => w == h;
  bool get isLandscape => w > h;

  @override
  bool operator ==(Object other) =>
      other is CropAspect && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(w, h);

  @override
  String toString() => 'CropAspect($w:$h)';
}

/// The photo as the crop screen shows it: straightened by [angle] (radians,
/// clockwise) and turned by [quarterTurns]. Answers whether a crop fits, and
/// converts crops to and from [Edits].
class CropFrame {
  CropFrame({
    required this.sourceWidth,
    required this.sourceHeight,
    this.angle = 0,
    this.quarterTurns = 0,
  }) : assert(sourceWidth > 0 && sourceHeight > 0),
       assert(quarterTurns >= 0 && quarterTurns <= 3);

  /// Straighten range of the slider.
  static const maxAngle = math.pi / 4;

  final int sourceWidth;
  final int sourceHeight;
  final double angle;
  final int quarterTurns;

  CropFrame copyWith({double? angle, int? quarterTurns}) => CropFrame(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    angle: angle ?? this.angle,
    quarterTurns: quarterTurns ?? this.quarterTurns,
  );

  /// Display size of the unstraightened photo (turned): the frame the crop
  /// must also stay inside.
  double get displayWidth =>
      (quarterTurns.isOdd ? sourceHeight : sourceWidth).toDouble();
  double get displayHeight =>
      (quarterTurns.isOdd ? sourceWidth : sourceHeight).toDouble();

  /// The whole frame, as a crop.
  CropRect get full => CropRect.centered(0, 0, displayWidth, displayHeight);

  /// The photo's own aspect, as displayed.
  CropAspect get originalAspect => CropAspect(displayWidth, displayHeight);

  double get _epsilon => 1e-9 * math.max(sourceWidth, sourceHeight);

  // --- Space conversions (centred coordinates) ---

  CropPoint _displayToStraightened(CropPoint p) {
    var q = p;
    for (var i = 0; i < quarterTurns; i++) {
      q = _ccw(q);
    }
    return q;
  }

  /// Straightened → original pixels (origin top-left).
  CropPoint _straightenedToOriginal(CropPoint p) {
    final c = math.cos(-angle), s = math.sin(-angle);
    return (
      x: p.x * c - p.y * s + sourceWidth / 2,
      y: p.x * s + p.y * c + sourceHeight / 2,
    );
  }

  /// Original pixels → straightened.
  CropPoint _originalToStraightened(CropPoint p) {
    final c = math.cos(angle), s = math.sin(angle);
    final x = p.x - sourceWidth / 2, y = p.y - sourceHeight / 2;
    return (x: x * c - y * s, y: x * s + y * c);
  }

  CropPoint _displayToOriginal(CropPoint p) =>
      _straightenedToOriginal(_displayToStraightened(p));

  // --- Fitting ---

  bool _pointFits(CropPoint p) {
    final e = _epsilon;
    if (p.x.abs() > displayWidth / 2 + e) return false;
    if (p.y.abs() > displayHeight / 2 + e) return false;
    final o = _displayToOriginal(p);
    return o.x >= -e &&
        o.y >= -e &&
        o.x <= sourceWidth + e &&
        o.y <= sourceHeight + e;
  }

  /// Whether [rect] lies within the photo and the frame. Both are convex,
  /// so checking the corners is enough.
  bool contains(CropRect rect) =>
      rect.width > 0 && rect.height > 0 && rect.corners.every(_pointFits);

  /// [rect] made to fit: its centre moved towards the middle if outside,
  /// then shrunk about its centre as little as needed. Keeps the aspect.
  CropRect fit(CropRect rect) {
    if (contains(rect)) return rect;
    var r = rect;
    final c = r.center;
    if (!_pointFits(c)) {
      final t = _search(
        (t) => _pointFits((x: c.x * (1 - t), y: c.y * (1 - t))),
      );
      r = r.translate(-c.x * t, -c.y * t);
    }
    final s = _searchMax((s) => contains(r.scale(s)));
    return r.scale(s);
  }

  /// As far from [from] (which fits) towards [to] as stays inside: for
  /// drags, so a handle stops at the edge instead of the crop jumping.
  CropRect toward(CropRect from, CropRect to) {
    if (contains(to)) return to;
    final t = _searchMax((t) => contains(from.lerp(to, t)));
    return from.lerp(to, t);
  }

  /// The largest crop of [aspect] (null: the whole frame) centred as near
  /// [center] as fits.
  CropRect largest(CropAspect? aspect, {CropPoint center = (x: 0, y: 0)}) {
    if (aspect == null) return fit(full);
    final big = math.max(displayWidth, displayHeight) * 2;
    final start = aspect.ratio >= 1
        ? CropRect.centered(center.x, center.y, big, big / aspect.ratio)
        : CropRect.centered(center.x, center.y, big * aspect.ratio, big);
    return fit(start);
  }

  // --- Edits ---

  /// The crop as stored edits. [aspect] (as displayed) fixes the output
  /// ratio when the crop was ratio-locked. The whole, unrotated photo is
  /// stored as no crop.
  Edits toEdits(CropRect rect, {CropAspect? aspect}) {
    if (angle == 0 && rect.closeTo(full, 0.5)) {
      return Edits(quarterTurns: quarterTurns);
    }
    // Corners in straightened space, ordered as the warp sees them.
    final s = _bounds([
      for (final p in rect.corners) _displayToStraightened(p),
    ]);
    final quad = [
      for (final p in s.corners) _normalized(_straightenedToOriginal(p)),
    ];
    final outputAspect = aspect == null
        ? null
        : (quarterTurns.isOdd ? aspect.flipped : aspect);
    return Edits(
      crop: CropEdit(
        quad: quad,
        output: outputAspect == null
            ? null
            : OutputAspect(outputAspect.w, outputAspect.h),
      ),
      quarterTurns: quarterTurns,
    );
  }

  NormPoint _normalized(CropPoint p) => NormPoint(
    (p.x / sourceWidth).clamp(0.0, 1.0),
    (p.y / sourceHeight).clamp(0.0, 1.0),
  );

  /// Reads [edits] back for the crop screen. Null if the crop isn't a
  /// straightened rectangle within the slider's range (e.g. a perspective
  /// crop from auto-crop).
  static CropState? fromEdits(
    Edits edits, {
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final base = CropFrame(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      quarterTurns: edits.quarterTurns,
    );
    final crop = edits.crop;
    if (crop == null) {
      return CropState(frame: base, rect: base.full, aspect: null);
    }
    final p = [
      for (final n in crop.quad) (x: n.x * sourceWidth, y: n.y * sourceHeight),
    ];
    final top = _sub(p[1], p[0]), bottom = _sub(p[2], p[3]);
    final left = _sub(p[3], p[0]), right = _sub(p[2], p[1]);
    final size = math.sqrt(_dot(top, top)) + math.sqrt(_dot(left, left));
    final tolerance = 1e-3 * size;
    final isRectangle =
        _length(_sub(top, bottom)) <= tolerance &&
        _length(_sub(left, right)) <= tolerance &&
        _dot(top, left).abs() <=
            tolerance *
                (math.sqrt(_dot(top, top)) + math.sqrt(_dot(left, left)));
    final angle = math.atan2(-top.y, top.x);
    if (!isRectangle || angle.abs() > maxAngle + 1e-6) return null;

    final frame = base.copyWith(angle: angle);
    var rect = _bounds([for (final q in p) frame._originalToStraightened(q)]);
    for (var i = 0; i < frame.quarterTurns; i++) {
      rect = rect.turnClockwise();
    }
    final output = crop.output;
    final aspect = output == null
        ? null
        : (frame.quarterTurns.isOdd
              ? CropAspect(output.aspectH, output.aspectW)
              : CropAspect(output.aspectW, output.aspectH));
    return CropState(frame: frame, rect: rect, aspect: aspect);
  }
}

/// A crop as the crop screen holds it.
class CropState {
  const CropState({required this.frame, required this.rect, this.aspect});

  final CropFrame frame;
  final CropRect rect;

  /// The locked ratio (as displayed); null for freeform.
  final CropAspect? aspect;
}

// --- Helpers ---

/// Clockwise quarter turn (y down): right → down.
CropPoint _cw(CropPoint p) => (x: -p.y, y: p.x);
CropPoint _ccw(CropPoint p) => (x: p.y, y: -p.x);

CropRect _bounds(List<CropPoint> points) => CropRect(
  points.map((p) => p.x).reduce(math.min),
  points.map((p) => p.y).reduce(math.min),
  points.map((p) => p.x).reduce(math.max),
  points.map((p) => p.y).reduce(math.max),
);

CropPoint _sub(CropPoint a, CropPoint b) => (x: a.x - b.x, y: a.y - b.y);
double _dot(CropPoint a, CropPoint b) => a.x * b.x + a.y * b.y;
double _length(CropPoint a) => math.sqrt(_dot(a, a));

/// Largest t in [0, 1] with [ok] true (ok(0) assumed true; monotone).
double _searchMax(bool Function(double) ok) {
  if (ok(1)) return 1;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (ok(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Smallest t in [0, 1] with [ok] true (ok(1) assumed true; monotone).
double _search(bool Function(double) ok) {
  if (ok(0)) return 0;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (ok(mid)) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}
