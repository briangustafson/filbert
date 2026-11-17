import 'dart:math' as math;

import 'edge_map.dart';
import 'geometry.dart';

/// Candidate scoring (m1-design §6.2 step 5). Pure Dart.

/// Tunables, in one place so the evaluation can report what it ran with.
class ScoringParams {
  const ScoringParams({
    this.minAreaFraction = 0.15,
    this.angleTolerance = 18,
    this.borderSupport = 0.3,
    this.borderFactor = 0.75,
    this.supportSearch = 2,
    this.cornerSkip = 0.08,
    this.edgeQuantile = 0.80,
    this.areaExponent = 0.3,
    this.consistencyWeight = 0,
    this.nestedTolerance = 0.06,
    this.nestedMinArea = 0.8,
    this.rectangleTolerance = 3,
    this.inset = 0.001,
  });

  /// Candidates smaller than this fraction of the image are rejected.
  final double minAreaFraction;

  /// Corner angles within 90° ± this are fine under perspective; beyond,
  /// they're penalised.
  final double angleTolerance;

  /// Support credited to a side lying on the photo's border (the canvas
  /// runs off the photo there, so its edge can't be seen).
  final double borderSupport;

  /// Penalty for each side on the border.
  final double borderFactor;

  /// Pixels either side of a candidate side searched for its edge.
  final int supportSearch;

  /// Fraction at each end of a side ignored (corners are often covered by
  /// clamps or the easel).
  final double cornerSkip;

  /// A sample counts as on an edge above this gradient quantile.
  final double edgeQuantile;

  /// Larger quads score higher, by area to this power. Kept low: a strong
  /// background line (a post, a fence board) just outside the canvas must
  /// not win on size alone.
  final double areaExponent;

  /// How much a side's support drops when its contrast flips direction
  /// along it (0: not at all). Partial, because a real canvas edge flips
  /// too where the background behind it changes.
  final double consistencyWeight;

  /// A quad nested just inside the best one wins if it scores within this
  /// fraction of it: the outer one is usually a ledge, the canvas's side or
  /// a frame, and a crop slightly inside the canvas beats one outside it.
  final double nestedTolerance;

  /// ...but only if it keeps at least this fraction of the area (a thin
  /// step inward, not a shape painted in the picture).
  final double nestedMinArea;

  /// Degrees a quad may be from the image of a rectangle through a phone
  /// camera ([rectangleError]) before it's penalised (lens distortion and
  /// slightly warped canvases).
  final double rectangleTolerance;

  /// The final quad is moved this fraction of the photo's diagonal inside
  /// the detected edges: a crop showing a sliver of background looks worse
  /// than one missing a sliver of canvas.
  final double inset;
}

/// A candidate quad (TL, TR, BR, BL, pixels) and how it was found.
class Candidate {
  Candidate(this.corners, {this.borderSides = const {}});

  final List<V> corners;

  /// Indexes of sides (0 top, 1 right, 2 bottom, 3 left) on the photo's
  /// border.
  final Set<int> borderSides;
}

class ScoredCandidate {
  ScoredCandidate(this.candidate, this.score, this.sideSupport);

  final Candidate candidate;
  final double score;
  final List<double> sideSupport;
}

/// Scores candidates for one image.
class Scorer {
  Scorer(this.edges, {this.params = const ScoringParams(), this.aspectHint})
    : _threshold = math.max(edges.magnitudeQuantile(params.edgeQuantile), 8);

  final EdgeMap edges;
  final ScoringParams params;

  /// Expected width/height of the painting, if known.
  final double? aspectHint;

  final double _threshold;

  /// Null if the candidate is rejected outright.
  ScoredCandidate? score(Candidate c) {
    final q = c.corners;
    if (!isConvexClockwise(q)) return null;
    final imageArea = edges.width * edges.height.toDouble();
    final area = polygonArea(q) / imageArea;
    if (area < params.minAreaFraction || area > 1.02) return null;
    if (c.borderSides.length > 1) return null;

    final support = [
      for (var s = 0; s < 4; s++)
        c.borderSides.contains(s)
            ? params.borderSupport
            : sideSupport(q[s], q[(s + 1) % 4]),
    ];
    final mean = support.reduce((a, b) => a + b) / 4;
    final min = support.reduce(math.min);
    final supportTerm = 0.5 * mean + 0.5 * min;

    final areaTerm = math.pow(area, params.areaExponent).toDouble();

    var angleTerm = 1.0;
    for (final a in interiorAngles(q)) {
      final over = math.max(0, (a - 90).abs() - params.angleTolerance);
      angleTerm *= math.exp(-math.pow(over / 12, 2));
    }

    final long = math.max(edges.width, edges.height).toDouble();
    final rectError = rectangleError(
      q,
      V(edges.width / 2, edges.height / 2),
      long * 0.6,
      long * 1.6,
    );
    final rectOver = math.max(0, rectError - params.rectangleTolerance);
    angleTerm *= math.exp(-math.pow(rectOver / 4, 2));

    var aspectTerm = 1.0;
    final hint = aspectHint;
    if (hint != null) {
      final w = ((q[1] - q[0]).length + (q[2] - q[3]).length) / 2;
      final h = ((q[3] - q[0]).length + (q[2] - q[1]).length) / 2;
      final diff = math.log((w / h) / hint);
      aspectTerm = 0.7 + 0.3 * math.exp(-diff * diff / (2 * 0.15 * 0.15));
    }

    final borderTerm = math.pow(params.borderFactor, c.borderSides.length);
    return ScoredCandidate(
      c,
      supportTerm * areaTerm * angleTerm * aspectTerm * borderTerm,
      support,
    );
  }

  /// Fraction of points along a→b (ends skipped) lying on an edge running
  /// the same way, discounted when the edge's contrast flips direction along
  /// the side: a canvas edge is one boundary between two surfaces, while a
  /// line through background clutter alternates.
  double sideSupport(V a, V b) {
    final dir = b - a;
    final length = dir.length;
    if (length < 4) return 0;
    final n = dir.unit.perp;
    final samples = math.max(12, (length / 4).round());
    var positive = 0, negative = 0, total = 0;
    for (var i = 0; i <= samples; i++) {
      final t = params.cornerSkip + (1 - 2 * params.cornerSkip) * i / samples;
      final p = a + dir * t;
      var best = 0.0;
      for (var o = -params.supportSearch; o <= params.supportSearch; o++) {
        final v = edges.signedAcross(p + n * o.toDouble(), n);
        if (v.abs() > best.abs()) best = v;
      }
      total++;
      if (best >= _threshold) positive++;
      if (best <= -_threshold) negative++;
    }
    if (total == 0) return 0;
    final hits = positive + negative;
    if (hits == 0) return 0;
    final consistency = (positive - negative).abs() / hits;
    final w = params.consistencyWeight;
    return hits / total * (1 - w + w * consistency);
  }
}

/// The winner among [scored] (best first): the best, or the smallest quad
/// nested just inside it that scores nearly as well
/// ([ScoringParams.nestedTolerance]).
ScoredCandidate pickBest(
  List<ScoredCandidate> scored, {
  ScoringParams params = const ScoringParams(),
}) {
  final best = scored.first;
  final outer = best.candidate.corners;
  final outerArea = polygonArea(outer);
  var chosen = best;
  var chosenArea = outerArea;
  for (final c in scored.skip(1)) {
    if (c.score < best.score * (1 - params.nestedTolerance)) break;
    final q = c.candidate.corners;
    final area = polygonArea(q);
    if (area >= chosenArea || area < outerArea * params.nestedMinArea) {
      continue;
    }
    if (q.every((p) => _inside(outer, p, slack: 2))) {
      chosen = c;
      chosenArea = area;
    }
  }
  return chosen;
}

/// Whether [p] is inside clockwise quad [q], allowing [slack] px outside.
bool _inside(List<V> q, V p, {double slack = 0}) {
  for (var i = 0; i < q.length; i++) {
    final a = q[i], b = q[(i + 1) % q.length];
    final edge = b - a;
    if (edge.cross(p - a) / edge.length < -slack) return false;
  }
  return true;
}

/// Confidence (0–1) from the chosen candidate's score and its weakest side.
/// Not yet calibrated: wrong answers can still score high.
double confidenceFor(ScoredCandidate best) {
  final absolute = ((best.score - 0.25) / 0.4).clamp(0.0, 1.0);
  final minSide = best.sideSupport.reduce(math.min);
  final sides = ((minSide - 0.3) / 0.4).clamp(0.0, 1.0);
  return math.min(absolute, sides);
}
