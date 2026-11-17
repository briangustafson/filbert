import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dartcv4/dartcv.dart' as cv;

import 'detector.dart';
import 'edge_map.dart';
import 'geometry.dart';
import 'refine.dart';
import 'scoring.dart';

/// Canvas detection with OpenCV (m1-design §6.2): edge maps from brightness
/// and saturation, candidate quads from contours and from detected lines,
/// pure-Dart scoring, then sides refined to the edges at full resolution.
///
/// [detect] runs in a background isolate; [detectSync] runs here.
class OpenCvCanvasDetector implements CanvasDetector {
  const OpenCvCanvasDetector({this.params = const ScoringParams()});

  /// Candidates are found on a copy this size (long edge).
  static const workLongEdge = 1000;

  final ScoringParams params;

  @override
  Future<Detection> detect(DetectorImage image, {double? aspectHint}) {
    final params = this.params;
    return Isolate.run(
      () =>
          OpenCvCanvasDetector(params: params)
              .detectSync(image, aspectHint: aspectHint),
      debugName: 'canvas detect',
    );
  }

  /// Debugging: the scored candidates (best first, work-image pixels) and
  /// the work scale, without refinement.
  (List<ScoredCandidate>, double) debugCandidates(
    DetectorImage image, {
    double? aspectHint,
  }) {
    final full = _bgr(image);
    final scale = math.min(
      1.0,
      workLongEdge / math.max(image.width, image.height),
    );
    final work = cv.resize(full, (
      (image.width * scale).round(),
      (image.height * scale).round(),
    ), interpolation: cv.INTER_AREA);
    final binary = _binaryEdges(work);
    final candidates = [
      ..._contourCandidates(binary, work.cols, work.rows),
      ..._lineCandidates(binary, work.cols, work.rows),
    ];
    final scorer = Scorer(
      edgeMapOf(work),
      params: params,
      aspectHint: aspectHint,
    );
    final scored = [for (final c in candidates) ?scorer.score(c)]
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final m in [full, work, binary]) {
      m.dispose();
    }
    return (scored, scale);
  }

  Detection detectSync(DetectorImage image, {double? aspectHint}) {
    final full = _bgr(image);
    final scale = math.min(
      1.0,
      workLongEdge / math.max(image.width, image.height),
    );
    final work = scale < 1
        ? cv.resize(full, (
            (image.width * scale).round(),
            (image.height * scale).round(),
          ), interpolation: cv.INTER_AREA)
        : full.clone();
    try {
      final workEdges = edgeMapOf(work);
      final binary = _binaryEdges(work);
      final candidates = [
        ..._contourCandidates(binary, work.cols, work.rows),
        ..._lineCandidates(binary, work.cols, work.rows),
      ];
      binary.dispose();

      final scorer = Scorer(workEdges, params: params, aspectHint: aspectHint);
      final scored = [for (final c in candidates) ?scorer.score(c)]
        ..sort((a, b) => b.score.compareTo(a.score));
      if (scored.isEmpty) return _unsure;
      final best = pickBest(scored, params: params);

      // Refine at full resolution, coarse then fine.
      final fullEdges = scale < 1 ? edgeMapOf(full) : workEdges;
      final diag = math.sqrt(
        image.width * image.width + image.height * image.height.toDouble(),
      );
      var corners = [for (final p in best.candidate.corners) p * (1 / scale)];
      for (final search in [diag * 0.008, diag * 0.003]) {
        corners = refineQuad(
          fullEdges,
          corners,
          search: math.max(3, search),
          borderSides: best.candidate.borderSides,
        );
      }
      if (!isConvexClockwise(corners)) {
        corners = [for (final p in best.candidate.corners) p * (1 / scale)];
      }
      // Err inside the canvas: its edge pixels blend into the background.
      corners = insetQuad(corners, diag * params.inset);
      return Detection(
        quad: Quad([
          for (final p in corners)
            Corner(
              (p.x / image.width).clamp(0.0, 1.0),
              (p.y / image.height).clamp(0.0, 1.0),
            ),
        ]),
        confidence: confidenceFor(best),
      );
    } finally {
      full.dispose();
      work.dispose();
    }
  }

  static final _unsure = Detection(
    quad: Quad(const [
      Corner(0.05, 0.05),
      Corner(0.95, 0.05),
      Corner(0.95, 0.95),
      Corner(0.05, 0.95),
    ]),
    confidence: 0,
  );

  static cv.Mat _bgr(DetectorImage image) {
    final rgba = cv.Mat.zeros(image.height, image.width, cv.MatType.CV_8UC4);
    rgba.data.setAll(0, image.rgba);
    final bgr = cv.cvtColor(rgba, cv.COLOR_RGBA2BGR);
    rgba.dispose();
    return bgr;
  }

  /// Gradients of brightness and saturation; per pixel, the stronger one.
  static EdgeMap edgeMapOf(cv.Mat bgr) {
    final (gray, sat) = _channels(bgr);
    final (gx1, gy1) = _gradients(gray);
    final (gx2, gy2) = _gradients(sat);
    gray.dispose();
    sat.dispose();
    final n = gx1.length;
    final gx = Float32List(n), gy = Float32List(n);
    for (var i = 0; i < n; i++) {
      final m1 = gx1[i] * gx1[i] + gy1[i] * gy1[i];
      final m2 = gx2[i] * gx2[i] + gy2[i] * gy2[i];
      if (m1 >= m2) {
        gx[i] = gx1[i];
        gy[i] = gy1[i];
      } else {
        gx[i] = gx2[i];
        gy[i] = gy2[i];
      }
    }
    return EdgeMap(width: bgr.cols, height: bgr.rows, gx: gx, gy: gy);
  }

  /// Blurred grayscale and saturation channels.
  static (cv.Mat, cv.Mat) _channels(cv.Mat bgr) {
    final grayRaw = cv.cvtColor(bgr, cv.COLOR_BGR2GRAY);
    final hsv = cv.cvtColor(bgr, cv.COLOR_BGR2HSV);
    final parts = cv.split(hsv);
    final gray = cv.gaussianBlur(grayRaw, (5, 5), 0);
    final sat = cv.gaussianBlur(parts[1], (5, 5), 0);
    grayRaw.dispose();
    hsv.dispose();
    return (gray, sat);
  }

  /// Sobel gradients (scaled to roughly 0–255 for a full-contrast step).
  static (Float32List, Float32List) _gradients(cv.Mat channel) {
    Float32List read(int dx, int dy) {
      final m = cv.sobel(channel, cv.MatType.CV_32F, dx, dy, scale: 0.25);
      final copy = Float32List.fromList(Float32List.sublistView(m.data));
      m.dispose();
      return copy;
    }

    return (read(1, 0), read(0, 1));
  }

  /// Canny edges of brightness and saturation (median-based thresholds),
  /// combined and slightly dilated.
  static cv.Mat _binaryEdges(cv.Mat bgr) {
    final (gray, sat) = _channels(bgr);
    cv.Mat cannyOf(cv.Mat m) {
      final med = _median(m);
      final lo = math.max(10.0, 0.66 * med), hi = math.max(30.0, 1.33 * med);
      return cv.canny(m, math.min(lo, 60), math.min(hi, 150));
    }

    final e1 = cannyOf(gray), e2 = cannyOf(sat);
    final both = cv.bitwiseOR(e1, e2);
    final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
    final dilated = cv.dilate(both, kernel);
    for (final m in [gray, sat, e1, e2, both, kernel]) {
      m.dispose();
    }
    return dilated;
  }

  static double _median(cv.Mat m) {
    final counts = List.filled(256, 0);
    final data = m.data;
    for (var i = 0; i < data.length; i += 7) {
      counts[data[i]]++;
    }
    final half = counts.reduce((a, b) => a + b) / 2;
    var seen = 0;
    for (var v = 0; v < 256; v++) {
      seen += counts[v];
      if (seen >= half) return v.toDouble();
    }
    return 128;
  }

  /// Convex quadrilaterals among the edge contours.
  static List<Candidate> _contourCandidates(cv.Mat edges, int w, int h) {
    final (contours, hierarchy) = cv.findContours(
      edges,
      cv.RETR_LIST,
      cv.CHAIN_APPROX_SIMPLE,
    );
    final minArea = 0.1 * w * h;
    final out = <Candidate>[];
    for (var i = 0; i < contours.length; i++) {
      final c = contours[i];
      if (cv.contourArea(c) < minArea * 0.5 && c.length < 50) continue;
      final hullMat = cv.convexHull(c);
      final hull = cv.VecPoint.fromMat(hullMat);
      if (cv.contourArea(hull) >= minArea) {
        final perimeter = cv.arcLength(hull, true);
        for (final eps in [0.015, 0.025, 0.04]) {
          final approx = cv.approxPolyDP(hull, eps * perimeter, true);
          if (approx.length == 4) {
            out.add(
              Candidate(
                orderCorners([
                  for (var j = 0; j < 4; j++)
                    V(approx[j].x.toDouble(), approx[j].y.toDouble()),
                ]),
              ),
            );
          }
          approx.dispose();
        }
      }
      hull.dispose();
      hullMat.dispose();
    }
    contours.dispose();
    hierarchy.dispose();
    return out;
  }

  /// Quads from pairs of near-horizontal and near-vertical lines (handles
  /// edges broken by clamps, hands or frames). The photo's borders count as
  /// lines too, for canvases that run off the photo.
  static List<Candidate> _lineCandidates(cv.Mat edges, int w, int h) {
    final minSide = math.min(w, h);
    final linesMat = cv.HoughLinesP(
      edges,
      1,
      math.pi / 180,
      math.max(40, minSide ~/ 12),
      minLineLength: minSide * 0.08,
      maxLineGap: minSide * 0.015,
    );
    final raw = Int32List.sublistView(linesMat.data);
    final segments = <(V, V)>[
      for (var i = 0; i + 3 < raw.length; i += 4)
        (
          V(raw[i].toDouble(), raw[i + 1].toDouble()),
          V(raw[i + 2].toDouble(), raw[i + 3].toDouble()),
        ),
    ];
    linesMat.dispose();

    final horizontal = _clusters(
      segments.where((s) => Line.through(s.$1, s.$2).angleDegrees.abs() < 35),
      w,
      h,
    );
    final vertical = _clusters(
      segments.where((s) => Line.through(s.$1, s.$2).angleDegrees.abs() > 55),
      w,
      h,
    );

    for (final l in _houghLines(edges, w, h)) {
      final list = l.angleDegrees.abs() < 35 ? horizontal : vertical;
      final mid = l.p;
      if (!list.any(
        (c) =>
            (c.angleDegrees - l.angleDegrees).abs() < 3 &&
            c.distance(mid).abs() < math.sqrt(w * w + h * h.toDouble()) * 0.008,
      )) {
        list.add(l);
      }
    }

    final W = w.toDouble(), H = h.toDouble();
    final top = (line: Line(const V(0, 0), const V(1, 0)), border: true);
    final bottom = (line: Line(V(0, H), const V(1, 0)), border: true);
    final left = (line: Line(const V(0, 0), const V(0, 1)), border: true);
    final right = (line: Line(V(W, 0), const V(0, 1)), border: true);
    final hs = [
      top,
      ...horizontal.map((l) => (line: l, border: false)),
      bottom,
    ];
    final vs = [left, ...vertical.map((l) => (line: l, border: false)), right];

    // Position at the image centre, for ordering.
    double yAt(Line l) => l.intersect(Line(V(W / 2, 0), const V(0, 1)))?.y ?? 0;
    double xAt(Line l) => l.intersect(Line(V(0, H / 2), const V(1, 0)))?.x ?? 0;

    final out = <Candidate>[];
    final margin = 0.02 * math.max(W, H);
    bool inside(V p) =>
        p.x >= -margin &&
        p.y >= -margin &&
        p.x <= W + margin &&
        p.y <= H + margin;
    V clamp(V p) => V(p.x.clamp(0, W), p.y.clamp(0, H));
    for (var a = 0; a < hs.length; a++) {
      for (var b = 0; b < hs.length; b++) {
        if (yAt(hs[a].line) >= yAt(hs[b].line) - minSide * 0.2) continue;
        for (var c = 0; c < vs.length; c++) {
          for (var d = 0; d < vs.length; d++) {
            if (xAt(vs[c].line) >= xAt(vs[d].line) - minSide * 0.2) continue;
            final t = hs[a], bo = hs[b], l = vs[c], r = vs[d];
            final corners = [
              t.line.intersect(l.line),
              t.line.intersect(r.line),
              bo.line.intersect(r.line),
              bo.line.intersect(l.line),
            ];
            if (corners.any((p) => p == null || !inside(p))) continue;
            final border = {
              if (t.border) 0,
              if (r.border) 1,
              if (bo.border) 2,
              if (l.border) 3,
            };
            out.add(
              Candidate([
                for (final p in corners) clamp(p!),
              ], borderSides: border),
            );
          }
        }
      }
    }
    return out;
  }

  /// The strongest whole-image lines (standard Hough), up to [perGroup]
  /// near-horizontal and near-vertical ones, skipping near-duplicates.
  /// Finds long edges that are faint or broken into short segments.
  static List<Line> _houghLines(
    cv.Mat edges,
    int w,
    int h, {
    int perGroup = 7,
  }) {
    final linesMat = cv.HoughLines(
      edges,
      1,
      math.pi / 360,
      (0.12 * math.min(w, h)).round(),
    );
    final raw = Float32List.sublistView(linesMat.data);
    linesMat.dispose();
    final long = math.max(w, h).toDouble();
    final vertical = <(double, double)>[], horizontal = <(double, double)>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      var rho = raw[i].toDouble(), theta = raw[i + 1].toDouble();
      final isVertical = theta < math.pi / 4 || theta > 3 * math.pi / 4;
      if (isVertical && theta > math.pi / 2) {
        rho = -rho;
        theta -= math.pi;
      }
      final group = isVertical ? vertical : horizontal;
      if (group.length >= perGroup) continue;
      if (group.any(
        (g) =>
            (rho - g.$1).abs() < 0.02 * long &&
            (theta - g.$2).abs() < 4 * math.pi / 180,
      )) {
        continue;
      }
      group.add((rho, theta));
      if (vertical.length >= perGroup && horizontal.length >= perGroup) break;
    }
    return [
      for (final (rho, theta) in [...vertical, ...horizontal])
        Line(
          V(rho * math.cos(theta), rho * math.sin(theta)),
          V(-math.sin(theta), math.cos(theta)),
        ),
    ];
  }

  /// Merges near-collinear segments into lines; the longest [keep] by total
  /// length.
  static List<Line> _clusters(
    Iterable<(V, V)> segments,
    int w,
    int h, {
    int keep = 9,
  }) {
    final diag = math.sqrt(w * w + h * h.toDouble());
    final clusters = <({List<V> points, double length, Line line})>[];
    final sorted = segments.toList()
      ..sort((a, b) => (b.$2 - b.$1).length.compareTo((a.$2 - a.$1).length));
    for (final (p, q) in sorted) {
      final seg = Line.through(p, q);
      final mid = (p + q) * 0.5;
      final len = (q - p).length;
      final i = clusters.indexWhere(
        (c) =>
            (c.line.angleDegrees - seg.angleDegrees).abs() < 3 &&
            c.line.distance(mid).abs() < diag * 0.008,
      );
      if (i < 0) {
        clusters.add((points: [p, q], length: len, line: seg));
      } else {
        final c = clusters[i];
        final points = [...c.points, p, q];
        clusters[i] = (
          points: points,
          length: c.length + len,
          line: fitLine(points) ?? c.line,
        );
      }
    }
    clusters.sort((a, b) => b.length.compareTo(a.length));
    return [for (final c in clusters.take(keep)) c.line];
  }
}
