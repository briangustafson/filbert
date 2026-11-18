import 'dart:typed_data';

import 'tone.dart';

/// A photo's limited-colors palette (m2-design §5.2): up to the requested
/// number of colors, ordered dark to light.
class Palette {
  const Palette(this.colors);

  /// Version of [toJson]'s format.
  static const currentVersion = 1;

  /// Palette colors in CIELAB, ordered by L\* (then a\*, b\*).
  final List<Lab> colors;

  /// [colors] as 8-bit sRGB.
  List<(int r, int g, int b)> get srgb8 => [
    for (final c in colors)
      switch (labToSrgb(c)) {
        (final r, final g, final b) => (_to8(r), _to8(g), _to8(b)),
      },
  ];

  Map<String, Object?> toJson() => {
    'v': currentVersion,
    'colors': [
      for (final c in colors) [c.l, c.a, c.b],
    ],
  };

  /// Null if [json] isn't a palette in [currentVersion]'s format (a stale or
  /// damaged cache file: compute it again).
  static Palette? tryFromJson(Object? json) {
    if (json is! Map || json['v'] != currentVersion) return null;
    final colors = json['colors'];
    if (colors is! List || colors.isEmpty) return null;
    final parsed = <Lab>[];
    for (final c in colors) {
      if (c is! List || c.length != 3 || c.any((x) => x is! num)) return null;
      parsed.add(
        Lab(
          (c[0] as num).toDouble(),
          (c[1] as num).toDouble(),
          (c[2] as num).toDouble(),
        ),
      );
    }
    return Palette(parsed);
  }

  @override
  bool operator ==(Object other) =>
      other is Palette &&
      other.colors.length == colors.length &&
      [for (var i = 0; i < colors.length; i++) other.colors[i] == colors[i]]
          .every((same) => same);

  @override
  int get hashCode => Object.hashAll(colors);

  @override
  String toString() => 'Palette($colors)';
}

/// Seed for [computePalette]'s random choices, so the same pixels always
/// give the same palette.
const paletteSeed = 0x5eed;

/// The [count] colors that best summarize [pixels] (8-bit sRGB, [channels]
/// bytes per pixel with red, green, blue first; any 4th byte is ignored):
/// k-means in CIELAB (m2-design §5.2).
///
/// Starts from k-means++ choices made with a fixed [seed], so the result is
/// deterministic; runs [attempts] times from different starts and keeps the
/// tightest result; each run stops after [maxIterations] rounds or once no
/// color moves more than [tolerance] (ΔE). Identical pixels are grouped and
/// weighted, so a flat-color image costs little. If the image has fewer
/// distinct colors than [count], the palette has that many.
Palette computePalette(
  Uint8List pixels, {
  required int count,
  int channels = 4,
  int seed = paletteSeed,
  int attempts = 3,
  int maxIterations = 20,
  double tolerance = 0.1,
}) {
  if (count < 1) throw ArgumentError.value(count, 'count', 'Must be ≥ 1');
  if (channels < 3) {
    throw ArgumentError.value(channels, 'channels', 'Must be ≥ 3');
  }
  if (pixels.isEmpty || pixels.length % channels != 0) {
    throw ArgumentError('pixels must hold whole pixels');
  }

  // Distinct colors and how many pixels have each.
  final weights = <int, int>{};
  for (var i = 0; i < pixels.length; i += channels) {
    final key = pixels[i] << 16 | pixels[i + 1] << 8 | pixels[i + 2];
    weights[key] = (weights[key] ?? 0) + 1;
  }
  final linear = Float64List.fromList([
    for (var c = 0; c < 256; c++) srgbToLinear(c / 255),
  ]);
  final n = weights.length;
  final points = Float64List(n * 3);
  final weight = Float64List(n);
  var p = 0;
  for (final MapEntry(:key, :value) in weights.entries) {
    final lab = linearToLab(
      linear[key >> 16],
      linear[key >> 8 & 0xff],
      linear[key & 0xff],
    );
    points[p * 3] = lab.l;
    points[p * 3 + 1] = lab.a;
    points[p * 3 + 2] = lab.b;
    weight[p] = value.toDouble();
    p++;
  }

  final k = count < n ? count : n;
  final km = _KMeans(points, weight, k);
  Float64List? best;
  var bestCost = double.infinity;
  for (var attempt = 0; attempt < attempts; attempt++) {
    final centers = km.seed(_Random(seed + attempt));
    final cost = km.refine(centers, maxIterations, tolerance);
    if (cost < bestCost) {
      bestCost = cost;
      best = centers;
    }
  }

  final colors = [
    for (var c = 0; c < k; c++)
      Lab(best![c * 3], best[c * 3 + 1], best[c * 3 + 2]),
  ]..sort(_byLightness);
  return Palette(colors);
}

int _byLightness(Lab x, Lab y) {
  final l = x.l.compareTo(y.l);
  if (l != 0) return l;
  final a = x.a.compareTo(y.a);
  return a != 0 ? a : x.b.compareTo(y.b);
}

int _to8(double c) => (c * 255).round().clamp(0, 255);

/// Weighted k-means over Lab points stored as `[l0, a0, b0, l1, …]`.
class _KMeans {
  _KMeans(this.points, this.weight, this.k)
    : n = weight.length,
      _nearest = Float64List(weight.length),
      _assigned = Int32List(weight.length);

  final Float64List points;
  final Float64List weight;
  final int k;
  final int n;

  /// Per point: squared distance to its nearest center, and which one.
  final Float64List _nearest;
  final Int32List _assigned;

  double _distance(int point, Float64List centers, int center) {
    final dl = points[point * 3] - centers[center * 3];
    final da = points[point * 3 + 1] - centers[center * 3 + 1];
    final db = points[point * 3 + 2] - centers[center * 3 + 2];
    return dl * dl + da * da + db * db;
  }

  void _setCenter(Float64List centers, int center, int point) {
    centers[center * 3] = points[point * 3];
    centers[center * 3 + 1] = points[point * 3 + 1];
    centers[center * 3 + 2] = points[point * 3 + 2];
  }

  /// k-means++: the first center is a pixel drawn at random; each next one
  /// favours pixels far from the centers so far (probability ∝ weight ×
  /// squared distance).
  Float64List seed(_Random random) {
    final centers = Float64List(k * 3);
    _setCenter(centers, 0, _draw(random, weight));
    final score = Float64List(n);
    for (var i = 0; i < n; i++) {
      _nearest[i] = _distance(i, centers, 0);
    }
    for (var c = 1; c < k; c++) {
      for (var i = 0; i < n; i++) {
        score[i] = weight[i] * _nearest[i];
      }
      final chosen = _draw(random, score);
      _setCenter(centers, c, chosen);
      for (var i = 0; i < n; i++) {
        final d = _distance(i, centers, c);
        if (d < _nearest[i]) _nearest[i] = d;
      }
    }
    return centers;
  }

  /// A point index drawn with probability proportional to [score]; the
  /// first point with a positive score if rounding leaves nothing to draw.
  int _draw(_Random random, Float64List score) {
    var total = 0.0;
    for (final s in score) {
      total += s;
    }
    var target = random.nextDouble() * total;
    var last = 0;
    for (var i = 0; i < n; i++) {
      if (score[i] <= 0) continue;
      last = i;
      target -= score[i];
      if (target < 0) return i;
    }
    return last;
  }

  /// Lloyd's rounds: assign each point to its nearest center, move each
  /// center to the weighted mean of its points. Returns the final cost
  /// (weighted sum of squared distances). Updates [centers] in place.
  double refine(Float64List centers, int maxIterations, double tolerance) {
    final sums = Float64List(k * 3);
    final totals = Float64List(k);
    final limit = tolerance * tolerance;
    for (var round = 0; round < maxIterations; round++) {
      _assign(centers);
      sums.fillRange(0, sums.length, 0);
      totals.fillRange(0, k, 0);
      for (var i = 0; i < n; i++) {
        final c = _assigned[i];
        final w = weight[i];
        sums[c * 3] += w * points[i * 3];
        sums[c * 3 + 1] += w * points[i * 3 + 1];
        sums[c * 3 + 2] += w * points[i * 3 + 2];
        totals[c] += w;
      }
      var moved = 0.0;
      for (var c = 0; c < k; c++) {
        double l, a, b;
        if (totals[c] > 0) {
          l = sums[c * 3] / totals[c];
          a = sums[c * 3 + 1] / totals[c];
          b = sums[c * 3 + 2] / totals[c];
        } else {
          // An empty cluster takes the point worst served by the others.
          final far = _farthest();
          l = points[far * 3];
          a = points[far * 3 + 1];
          b = points[far * 3 + 2];
          _nearest[far] = 0;
        }
        final dl = l - centers[c * 3];
        final da = a - centers[c * 3 + 1];
        final db = b - centers[c * 3 + 2];
        final d = dl * dl + da * da + db * db;
        if (d > moved) moved = d;
        centers[c * 3] = l;
        centers[c * 3 + 1] = a;
        centers[c * 3 + 2] = b;
      }
      if (moved <= limit) break;
    }
    _assign(centers);
    var cost = 0.0;
    for (var i = 0; i < n; i++) {
      cost += weight[i] * _nearest[i];
    }
    return cost;
  }

  void _assign(Float64List centers) {
    for (var i = 0; i < n; i++) {
      var best = 0;
      var bestDistance = _distance(i, centers, 0);
      for (var c = 1; c < k; c++) {
        final d = _distance(i, centers, c);
        if (d < bestDistance) {
          bestDistance = d;
          best = c;
        }
      }
      _assigned[i] = best;
      _nearest[i] = bestDistance;
    }
  }

  int _farthest() {
    var far = 0;
    for (var i = 1; i < n; i++) {
      if (_nearest[i] > _nearest[far]) far = i;
    }
    return far;
  }
}

/// xorshift32: a tiny random generator whose sequence is fixed by this
/// code, not by the Dart SDK, so palettes stay the same across SDK versions
/// and platforms (cached palettes would otherwise silently change).
class _Random {
  _Random(int seed) : _state = (seed & _mask) == 0 ? 1 : seed & _mask;

  static const _mask = 0xffffffff;
  int _state;

  /// Uniform in [0, 1).
  double nextDouble() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    _state = x;
    return x / 4294967296;
  }
}
