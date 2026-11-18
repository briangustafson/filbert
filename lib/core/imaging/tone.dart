import 'dart:math' as math;

/// The tone math behind the viewing aids (m2-design §5.1): perceived
/// lightness, gray, value bands and CIELAB. This is the reference: the live
/// shader (T5) and the export (T8) implement the same formulas, and tests
/// pin them.
///
/// sRGB channels are 0–1 unless a name says otherwise; L\* is 0–100. Colors
/// are sRGB with the D65 white point.

/// sRGB-encoded channel → linear light.
double srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// Linear light → sRGB-encoded channel. Clamped to 0–1.
double linearToSrgb(double v) {
  final c = v <= 0.0031308
      ? 12.92 * v
      : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
  return c.clamp(0.0, 1.0);
}

/// Relative luminance Y (0–1) of an sRGB color.
double luminance(double r, double g, double b) =>
    _yr * srgbToLinear(r) + _yg * srgbToLinear(g) + _yb * srgbToLinear(b);

/// CIE lightness L\* (0–100) of luminance [y] (white = 1).
double lStarFromY(double y) => 116 * _f(y) - 16;

/// The luminance with lightness [lStar]; the inverse of [lStarFromY].
double yFromLStar(double lStar) => _fInverse((lStar + 16) / 116);

/// Perceived lightness L\* (0–100) of an sRGB color.
double lStar(double r, double g, double b) => lStarFromY(luminance(r, g, b));

/// The sRGB gray (one channel, 0–1) with the same luminance, and so the
/// same L\*, as the color: the Gray aid.
double grayOf(double r, double g, double b) => linearToSrgb(luminance(r, g, b));

/// The sRGB gray (0–1) with lightness [lStar].
double grayForLStar(double lStar) =>
    linearToSrgb(yFromLStar(lStar.clamp(0.0, 100.0)));

/// Which of [bands] equal steps of L\* the lightness [lStar] falls in,
/// 0 (darkest) to `bands - 1`: the Values aid.
int valueBand(double lStar, int bands) =>
    math.min(bands - 1, math.max(0, (lStar * bands / 100).floor()));

/// The L\* a band is shown at: the middle of its step.
double bandMiddleLStar(int band, int bands) => (band + 0.5) * 100 / bands;

/// The sRGB gray (0–1) band [band] of [bands] is shown as.
double bandGray(int band, int bands) =>
    grayForLStar(bandMiddleLStar(band, bands));

/// A color in CIELAB (D65): [l] is L\* (0–100), [a] green–red, [b]
/// blue–yellow.
class Lab {
  const Lab(this.l, this.a, this.b);

  final double l;
  final double a;
  final double b;

  /// Squared ΔE76 (Euclidean distance) to [other].
  double distanceSquaredTo(Lab other) {
    final dl = l - other.l;
    final da = a - other.a;
    final db = b - other.b;
    return dl * dl + da * da + db * db;
  }

  @override
  bool operator ==(Object other) =>
      other is Lab && other.l == l && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(l, a, b);

  @override
  String toString() =>
      'Lab(${l.toStringAsFixed(2)}, ${a.toStringAsFixed(2)}, '
      '${b.toStringAsFixed(2)})';
}

/// An sRGB color in CIELAB.
Lab srgbToLab(double r, double g, double b) =>
    linearToLab(srgbToLinear(r), srgbToLinear(g), srgbToLinear(b));

/// A linear-light RGB color in CIELAB.
Lab linearToLab(double r, double g, double b) {
  final x = (_xr * r + _xg * g + _xb * b) / _whiteX;
  final y = _yr * r + _yg * g + _yb * b;
  final z = (_zr * r + _zg * g + _zb * b) / _whiteZ;
  final fx = _f(x);
  final fy = _f(y);
  final fz = _f(z);
  return Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

/// [lab] as sRGB (0–1 per channel), clamped to the sRGB gamut.
(double r, double g, double b) labToSrgb(Lab lab) {
  final fy = (lab.l + 16) / 116;
  final x = _fInverse(fy + lab.a / 500) * _whiteX;
  final y = _fInverse(fy);
  final z = _fInverse(fy - lab.b / 200) * _whiteZ;
  final m = _xyzToLinear;
  return (
    linearToSrgb(m[0] * x + m[1] * y + m[2] * z),
    linearToSrgb(m[3] * x + m[4] * y + m[5] * z),
    linearToSrgb(m[6] * x + m[7] * y + m[8] * z),
  );
}

/// The index of the color in [palette] nearest to [color] (ΔE76): the
/// Colors aid. [palette] must not be empty.
int nearestColor(Lab color, List<Lab> palette) {
  var best = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < palette.length; i++) {
    final d = color.distanceSquaredTo(palette[i]);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

// Linear sRGB → XYZ (D65). The Y row is the luminance weights of §5.1, so
// L* from Lab equals [lStar]. White's X and Z are the row sums, so white
// maps exactly to a* = b* = 0.
const _xr = 0.4124564, _xg = 0.3575761, _xb = 0.1804375;
const _yr = 0.2126, _yg = 0.7152, _yb = 0.0722;
const _zr = 0.0193339, _zg = 0.1191920, _zb = 0.9503041;
const _whiteX = _xr + _xg + _xb;
const _whiteZ = _zr + _zg + _zb;

/// The inverse of the matrix above, row-major.
final List<double> _xyzToLinear = _invert3([
  _xr, _xg, _xb, //
  _yr, _yg, _yb, //
  _zr, _zg, _zb, //
]);

List<double> _invert3(List<double> m) {
  final a = m[0], b = m[1], c = m[2];
  final d = m[3], e = m[4], f = m[5];
  final g = m[6], h = m[7], i = m[8];
  final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  return [
    (e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det, //
    (f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det, //
    (d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det, //
  ];
}

const _delta = 6 / 29;

double _f(double t) => t > _delta * _delta * _delta
    ? math.pow(t, 1 / 3).toDouble()
    : t / (3 * _delta * _delta) + 4 / 29;

double _fInverse(double f) =>
    f > _delta ? f * f * f : 3 * _delta * _delta * (f - 4 / 29);
