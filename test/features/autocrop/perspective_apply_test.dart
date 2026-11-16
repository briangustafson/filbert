import 'dart:math' as math;

import 'package:dartcv4/dartcv.dart' as cv;
import 'package:filbert/core/imaging/render_geometry.dart';
import 'package:filbert/core/imaging/render_pipeline.dart';
import 'package:filbert/features/autocrop/review_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

// T12 "done when": a hand-adjusted quad on the review screen produces a
// correct perspective-corrected render. A test pattern (an upright canvas)
// is projected onto a quad in a larger grey "photo"; corners placed where
// the user would drag them go through reviewEdits → RenderPlan → the
// OpenCV warp, and the pattern must come back flat and upright.

const _w = 400, _h = 300; // the canvas
const _photoW = 600, _photoH = 450; // the photo as stored

cv.Mat _pattern() {
  final m = cv.Mat.zeros(_h, _w, cv.MatType.CV_8UC3);
  final colours = [
    cv.Scalar(0, 0, 255), // TL red
    cv.Scalar(0, 255, 0), // TR green
    cv.Scalar(255, 0, 0), // BR blue
    cv.Scalar(0, 255, 255), // BL yellow
  ];
  final origins = [(0, 0), (_w ~/ 2, 0), (_w ~/ 2, _h ~/ 2), (0, _h ~/ 2)];
  for (var i = 0; i < 4; i++) {
    final (x, y) = origins[i];
    cv.rectangle(m, cv.Rect(x, y, _w ~/ 2, _h ~/ 2), colours[i], thickness: -1);
  }
  return m;
}

/// [pattern] projected onto [corners] (pixels) of a grey image.
cv.Mat _project(cv.Mat pattern, int w, int h, List<(double, double)> corners) {
  final photo = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3)
    ..setTo(cv.Scalar(128, 128, 128));
  final m = cv.getPerspectiveTransform2f(
    cv.VecPoint2f.fromList([
      cv.Point2f(-0.5, -0.5),
      cv.Point2f(_w - 0.5, -0.5),
      cv.Point2f(_w - 0.5, _h - 0.5),
      cv.Point2f(-0.5, _h - 0.5),
    ]),
    cv.VecPoint2f.fromList([for (final (x, y) in corners) cv.Point2f(x, y)]),
  );
  cv.warpPerspective(
    pattern,
    m,
    (w, h),
    dst: photo,
    borderMode: cv.BORDER_TRANSPARENT,
  );
  return photo;
}

/// Renders [photo] (as stored) with the review's edits, like the app does.
cv.Mat _render(cv.Mat photo, List<ReviewCorner> displayed, int turns) {
  final edits = reviewEdits(
    displayed,
    quarterTurns: turns,
    aspect: (w: _w.toDouble(), h: _h.toDouble()),
  );
  final plan = RenderPlan.forEdits(
    sourceWidth: _photoW,
    sourceHeight: _photoH,
    edits: edits,
    maxLongEdge: _w,
  );
  final decoded = cv.resize(photo, (
    plan.decodeWidth,
    plan.decodeHeight,
  ), interpolation: cv.INTER_AREA);
  return warpForPlan(decoded, plan);
}

double _meanDiff(cv.Mat a, cv.Mat b) {
  final mean = cv.mean(cv.absDiff(a, b));
  return [mean.val1, mean.val2, mean.val3].reduce(math.max);
}

void main() {
  // Where the canvas's corners appear in the displayed photo (pixels).
  const seen = [(90.0, 50.0), (530.0, 85.0), (505.0, 410.0), (70.0, 390.0)];

  test('unturned photo: the pattern comes back flat', () {
    final pattern = _pattern();
    final photo = _project(pattern, _photoW, _photoH, seen);
    final displayed = [
      for (final (x, y) in seen) (x: x / _photoW, y: y / _photoH),
    ];
    final out = _render(photo, displayed, 0);
    expect((out.cols, out.rows), (_w, _h));
    expect(_meanDiff(out, pattern), lessThan(12));
  });

  test('photo shown turned: the pattern comes back flat and upright', () {
    // The user sees the photo turned a quarter clockwise (600×450 stored,
    // 450×600 shown), with the canvas upright on screen.
    const seenTurned = [
      (60.0, 90.0),
      (400.0, 70.0),
      (420.0, 520.0),
      (40.0, 540.0),
    ];
    final pattern = _pattern();
    final shown = _project(pattern, _photoH, _photoW, seenTurned);
    // The stored photo is the shown one turned back.
    final photo = cv.rotate(shown, cv.ROTATE_90_COUNTERCLOCKWISE);
    expect((photo.cols, photo.rows), (_photoW, _photoH));

    final displayed = [
      for (final (x, y) in seenTurned) (x: x / _photoH, y: y / _photoW),
    ];
    final out = _render(photo, displayed, 1);
    expect((out.cols, out.rows), (_w, _h));
    expect(_meanDiff(out, pattern), lessThan(12));
  });
}
