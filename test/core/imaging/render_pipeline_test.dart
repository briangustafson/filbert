import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:canvas_detect/safe_cv.dart' as safe_cv;
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:filbert/core/imaging/edits.dart';
import 'package:filbert/core/imaging/render_geometry.dart';
import 'package:filbert/core/imaging/render_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

// Golden tests for the warp stage (m1-design §8), on a synthetic test pattern
// so the input is identical on every OS. Goldens are lossless PNGs of the
// warped pixels, before JPEG encoding. Compared with a small tolerance, since
// OpenCV's optimised code paths may differ by a step between CPUs.
//
// Update with: flutter test --update-goldens test/core/imaging/render_pipeline_test.dart

const _w = 400, _h = 300;

/// Coloured quadrants (TL red, TR green, BR blue, BL yellow) under a 25 px
/// black grid, so crops, rotation and turns are visible at a glance.
cv.Mat _pattern() {
  final m = cv.Mat.zeros(_h, _w, cv.MatType.CV_8UC3);
  void fill(int x, int y, int w, int h, cv.Scalar c) =>
      cv.rectangle(m, cv.Rect(x, y, w, h), c, thickness: -1);
  fill(0, 0, _w ~/ 2, _h ~/ 2, _red);
  fill(_w ~/ 2, 0, _w ~/ 2, _h ~/ 2, _green);
  fill(_w ~/ 2, _h ~/ 2, _w ~/ 2, _h ~/ 2, _blue);
  fill(0, _h ~/ 2, _w ~/ 2, _h ~/ 2, _yellow);
  for (var x = 0; x <= _w; x += 25) {
    cv.line(m, cv.Point(x, 0), cv.Point(x, _h), _black, thickness: 2);
  }
  for (var y = 0; y <= _h; y += 25) {
    cv.line(m, cv.Point(0, y), cv.Point(_w, y), _black, thickness: 2);
  }
  return m;
}

// BGR.
final _red = cv.Scalar(0, 0, 255);
final _green = cv.Scalar(0, 255, 0);
final _blue = cv.Scalar(255, 0, 0);
final _yellow = cv.Scalar(0, 255, 255);
final _black = cv.Scalar(0, 0, 0);

const _redBgr = [0, 0, 255], _greenBgr = [0, 255, 0];
const _blueBgr = [255, 0, 0], _yellowBgr = [0, 255, 255];

Edits _crop(List<(double, double)> c, {OutputAspect? output, int turns = 0}) =>
    Edits(
      crop: CropEdit(
        quad: [for (final (x, y) in c) NormPoint(x, y)],
        output: output,
      ),
      quarterTurns: turns,
    );

RenderPlan _plan(Edits edits, {int w = _w, int h = _h}) => RenderPlan.forEdits(
  sourceWidth: w,
  sourceHeight: h,
  edits: edits,
  maxLongEdge: 1000,
);

/// Asserts the colour near each output corner: the average of a 15×15 block
/// one grid cell in, ignoring grid-line (dark) pixels.
void _expectCorners(cv.Mat m, List<List<int>> tlTrBrBl) {
  const inset = 20, half = 7;
  final centres = [
    (inset, inset),
    (m.cols - 1 - inset, inset),
    (m.cols - 1 - inset, m.rows - 1 - inset),
    (inset, m.rows - 1 - inset),
  ];
  for (var i = 0; i < 4; i++) {
    final (cx, cy) = centres[i];
    final sum = [0, 0, 0];
    var n = 0;
    for (var y = cy - half; y <= cy + half; y++) {
      for (var x = cx - half; x <= cx + half; x++) {
        final px = m.atPixel(y, x);
        if (px[0] + px[1] + px[2] < 200) continue; // grid line
        for (var c = 0; c < 3; c++) {
          sum[c] += px[c].toInt();
        }
        n++;
      }
    }
    expect(n, greaterThan(50), reason: 'corner $i is mostly grid line');
    final avg = [for (final v in sum) v / n];
    for (var c = 0; c < 3; c++) {
      expect(
        (avg[c] - tlTrBrBl[i][c]).abs(),
        lessThan(40),
        reason: 'corner $i near ($cx, $cy) is $avg, expected ${tlTrBrBl[i]}',
      );
    }
  }
}

void _expectGolden(cv.Mat actual, String name) {
  final file = File('test/goldens/render/$name.png');
  if (autoUpdateGoldenFiles) {
    file.parent.createSync(recursive: true);
    cv.imwrite(file.path, actual);
    return;
  }
  expect(file.existsSync(), isTrue, reason: 'missing golden ${file.path}');
  final golden = cv.imread(file.path, flags: cv.IMREAD_COLOR);
  expect((actual.cols, actual.rows), (golden.cols, golden.rows));
  final diff = cv.absDiff(actual, golden);
  final (_, maxDiff, _, _) = cv.minMaxLoc(diff.reshape(1, 0));
  final mean = cv.mean(diff);
  expect(maxDiff, lessThanOrEqualTo(8), reason: '$name: max channel diff');
  expect(
    [mean.val1, mean.val2, mean.val3].reduce(math.max),
    lessThan(0.5),
    reason: '$name: mean diff',
  );
  diff.dispose();
  golden.dispose();
}

void main() {
  late cv.Mat pattern;
  setUp(() => pattern = _pattern());
  tearDown(() => pattern.dispose());

  cv.Mat render(Edits edits) {
    final plan = _plan(edits);
    expect((plan.decodeWidth, plan.decodeHeight), (_w, _h));
    return warpForPlan(pattern, plan);
  }

  test('no edits: identical to the source', () {
    final out = render(Edits.none);
    expect((out.cols, out.rows), (_w, _h));
    final diff = cv.absDiff(out, pattern);
    final (_, maxDiff, _, _) = cv.minMaxLoc(diff.reshape(1, 0));
    expect(maxDiff, 0);
  });

  test('axis-aligned crop', () {
    // The middle of the pattern: all four quadrants, each a 100×75 piece.
    final out = render(
      _crop([(0.25, 0.25), (0.75, 0.25), (0.75, 0.75), (0.25, 0.75)]),
    );
    expect((out.cols, out.rows), (200, 150));
    _expectCorners(out, [_redBgr, _greenBgr, _blueBgr, _yellowBgr]);
    _expectGolden(out, 'axis_aligned_crop');
  });

  test('straightened crop (rotated rectangle)', () {
    // A 200×150 rectangle around the centre, rotated 10° clockwise.
    const angle = 10 * math.pi / 180;
    final corners = [
      for (final (dx, dy) in [(-100, -75), (100, -75), (100, 75), (-100, 75)])
        (
          (200 + dx * math.cos(angle) - dy * math.sin(angle)) / _w,
          (150 + dx * math.sin(angle) + dy * math.cos(angle)) / _h,
        ),
    ];
    final out = render(_crop(corners, output: const OutputAspect(4, 3)));
    expect((out.cols, out.rows), (200, 150));
    _expectCorners(out, [_redBgr, _greenBgr, _blueBgr, _yellowBgr]);
    _expectGolden(out, 'straightened_crop');
  });

  test('perspective quad recovers the flat pattern', () {
    // Simulate a photo of the pattern taken at an angle: project it onto a
    // quad in a larger grey frame, then crop back with that quad.
    const fw = 600, fh = 450;
    const quad = [(80.0, 40.0), (540.0, 90.0), (500.0, 400.0), (60.0, 420.0)];
    final photo = cv.Mat.zeros(fh, fw, cv.MatType.CV_8UC3)
      ..setTo(cv.Scalar(128, 128, 128));
    final forward = cv.getPerspectiveTransform2f(
      cv.VecPoint2f.fromList([
        cv.Point2f(-0.5, -0.5),
        cv.Point2f(_w - 0.5, -0.5),
        cv.Point2f(_w - 0.5, _h - 0.5),
        cv.Point2f(-0.5, _h - 0.5),
      ]),
      cv.VecPoint2f.fromList([for (final (x, y) in quad) cv.Point2f(x, y)]),
    );
    safe_cv.warpPerspective(
      pattern,
      forward,
      (fw, fh),
      dst: photo,
      borderMode: cv.BORDER_TRANSPARENT,
    );

    final edits = _crop([
      for (final (x, y) in quad) (x / fw, y / fh),
    ], output: const OutputAspect(4, 3));
    final plan = RenderPlan.forEdits(
      sourceWidth: fw,
      sourceHeight: fh,
      edits: edits,
      maxLongEdge: _w,
    );
    // The renderer decodes at the plan's size; the decoder downscales.
    final decoded = safe_cv.resize(photo, (
      plan.decodeWidth,
      plan.decodeHeight,
    ), interpolation: cv.INTER_AREA);
    final out = warpForPlan(decoded, plan);
    expect((out.cols, out.rows), (_w, _h));
    _expectCorners(out, [_redBgr, _greenBgr, _blueBgr, _yellowBgr]);

    // Two resamplings blur the grid lines, so compare on average.
    final diff = cv.absDiff(out, pattern);
    final mean = cv.mean(diff);
    expect([mean.val1, mean.val2, mean.val3].reduce(math.max), lessThan(12));
    _expectGolden(out, 'perspective_quad');
  });

  group('quarter turns', () {
    final full = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)];
    for (final (turns, size, corners) in [
      (1, (_h, _w), [_yellowBgr, _redBgr, _greenBgr, _blueBgr]),
      (2, (_w, _h), [_blueBgr, _yellowBgr, _redBgr, _greenBgr]),
      (3, (_h, _w), [_greenBgr, _blueBgr, _yellowBgr, _redBgr]),
    ]) {
      test('$turns × 90° clockwise', () {
        final out = render(_crop(full, turns: turns));
        expect((out.cols, out.rows), size);
        _expectCorners(out, corners);
        _expectGolden(out, 'quarter_turns_$turns');
      });
    }

    test('after a crop', () {
      final out = render(
        _crop([(0.0, 0.0), (0.5, 0.0), (0.5, 0.5), (0.0, 0.5)], turns: 1),
      );
      // The red quadrant, 200×150, turned: 150×200.
      expect((out.cols, out.rows), (150, 200));
      _expectGolden(out, 'crop_then_quarter_turn');
    });
  });

  group('renderJpeg', () {
    test('RGBA in, JPEG out at the output size', () {
      final rgba = cv.cvtColor(pattern, cv.COLOR_BGR2RGBA);
      final plan = _plan(const Edits(quarterTurns: 1));
      final jpeg = renderJpeg(rgba.data, plan);
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      final decoded = cv.imdecode(jpeg, cv.IMREAD_COLOR);
      expect((decoded.cols, decoded.rows), (_h, _w));
      _expectCorners(decoded, [_yellowBgr, _redBgr, _greenBgr, _blueBgr]);
    });

    test('rejects pixels of the wrong size', () {
      final plan = _plan(Edits.none);
      expect(
        () => bgrFromRgba(Uint8List(10), plan.decodeWidth, plan.decodeHeight),
        throwsArgumentError,
      );
    });
  });
}
