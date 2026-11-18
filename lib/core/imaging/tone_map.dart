import 'dart:typed_data';

import 'palette.dart';
import 'tone.dart';

/// The tone aids as fast per-pixel maps on 8-bit pixels, for the
/// full-resolution export (m2-design §5.4). Built from `tone.dart`'s
/// formulas, so they agree with it (and so with the live shader) without a
/// `pow` per pixel:
///
/// - luminance is a sum of three table lookups (linear light per level);
/// - Gray and Values compare it with precomputed luminance thresholds;
/// - Colors remembers the nearest palette color of each distinct color.
///
/// Pixels are 3 bytes each, in OpenCV's BGR order, changed in place.
sealed class ToneMap {
  const ToneMap();

  /// The Gray aid.
  factory ToneMap.gray() = _GrayMap;

  /// The Values aid in [bands] bands.
  factory ToneMap.values(int bands) = _ValuesMap;

  /// The Colors aid with [palette] (not empty).
  factory ToneMap.colors(Palette palette) = _ColorsMap;

  /// Maps every pixel of [bgr] (3 bytes per pixel) in place.
  void apply(Uint8List bgr);
}

/// Linear light of each 8-bit sRGB level.
final Float64List _linear = Float64List.fromList([
  for (var i = 0; i < 256; i++) srgbToLinear(i / 255),
]);

const _yr = 0.2126, _yg = 0.7152, _yb = 0.0722;

/// Luminance of a BGR pixel; the same sum as [luminance].
double _y(int b, int g, int r) =>
    _yr * _linear[r] + _yg * _linear[g] + _yb * _linear[b];

/// How many of the increasing [thresholds] are at or below [y].
int _countBelow(Float64List thresholds, double y) {
  var lo = 0, hi = thresholds.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (thresholds[mid] <= y) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

int _to8(double c) => (c * 255).round().clamp(0, 255);

class _GrayMap extends ToneMap {
  _GrayMap();

  /// Gray level k + 1 starts where `linearToSrgb(y) * 255` reaches k + 0.5,
  /// so counting thresholds gives `_to8(grayOf(…))`.
  static final Float64List _thresholds = Float64List.fromList([
    for (var k = 0; k < 255; k++) srgbToLinear((k + 0.5) / 255),
  ]);

  @override
  void apply(Uint8List bgr) {
    final t = _thresholds;
    for (var i = 0; i + 2 < bgr.length; i += 3) {
      final g = _countBelow(t, _y(bgr[i], bgr[i + 1], bgr[i + 2]));
      bgr[i] = g;
      bgr[i + 1] = g;
      bgr[i + 2] = g;
    }
  }
}

class _ValuesMap extends ToneMap {
  _ValuesMap(this.bands)
    : _thresholds = Float64List.fromList([
        // Band k starts at L* = k · 100 / bands.
        for (var k = 1; k < bands; k++) yFromLStar(k * 100 / bands),
      ]),
      _grays = Uint8List.fromList([
        for (var k = 0; k < bands; k++) _to8(bandGray(k, bands)),
      ]);

  final int bands;
  final Float64List _thresholds;
  final Uint8List _grays;

  @override
  void apply(Uint8List bgr) {
    final t = _thresholds;
    for (var i = 0; i + 2 < bgr.length; i += 3) {
      final g = _grays[_countBelow(t, _y(bgr[i], bgr[i + 1], bgr[i + 2]))];
      bgr[i] = g;
      bgr[i + 1] = g;
      bgr[i + 2] = g;
    }
  }
}

class _ColorsMap extends ToneMap {
  _ColorsMap(this.palette) : _rgb = palette.srgb8 {
    if (palette.colors.isEmpty) throw ArgumentError('Empty palette');
  }

  final Palette palette;
  final List<(int, int, int)> _rgb;

  @override
  void apply(Uint8List bgr) {
    final labs = palette.colors;
    final rgb = _rgb;
    // The nearest color's index + 1 for each 24-bit color seen; 0 = not
    // yet. 16 MB, but each distinct color is matched only once.
    final nearest = Uint8List(1 << 24);
    for (var i = 0; i + 2 < bgr.length; i += 3) {
      final b = bgr[i], g = bgr[i + 1], r = bgr[i + 2];
      final key = (r << 16) | (g << 8) | b;
      var n = nearest[key];
      if (n == 0) {
        n =
            nearestColor(
              linearToLab(_linear[r], _linear[g], _linear[b]),
              labs,
            ) +
            1;
        nearest[key] = n;
      }
      final (pr, pg, pb) = rgb[n - 1];
      bgr[i] = pb;
      bgr[i + 1] = pg;
      bgr[i + 2] = pr;
    }
  }
}

/// Compare (m2-design §3.4): mixes [other] into [dst] at [opacity] (0 keeps
/// [dst], 1 gives [other]), channel by channel as displayed (sRGB), as the
/// live shader does. Same-length byte buffers; [dst] changes in place.
void mixInto(Uint8List dst, Uint8List other, double opacity) {
  if (dst.length != other.length) {
    throw ArgumentError('Sizes differ: ${dst.length} vs ${other.length}');
  }
  final o = opacity.clamp(0.0, 1.0);
  if (o == 0) return;
  if (o == 1) {
    dst.setAll(0, other);
    return;
  }
  // Fixed point: weight out of 2^16.
  final w = (o * 65536).round();
  for (var i = 0; i < dst.length; i++) {
    final a = dst[i];
    dst[i] = a + (((other[i] - a) * w + 32768) >> 16);
  }
}
