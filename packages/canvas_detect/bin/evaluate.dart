// Evaluates the detector on the fixtures (m1-design §6.5). Run from
// packages/canvas_detect:
//
//   dart run bin/evaluate.dart                   print the table
//   dart run bin/evaluate.dart --check           also fail below the baseline
//   dart run bin/evaluate.dart --write-baseline  record the current result
//
// Each photo is downscaled to the size the app passes the detector, then the
// detected corners are compared with test/fixtures/expected.json. Error is
// the largest corner distance as a percentage of the photo's diagonal; at
// most 2% is a success.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:canvas_detect/canvas_detect.dart';
import 'package:dartcv4/dartcv.dart' as cv;

const _fixtures = 'test/fixtures';
const _baselinePath = '$_fixtures/baseline.json';

/// The app decodes photos to this long edge before detection
/// (PlatformCanvasDetection.maxLongEdge).
const _appLongEdge = 1000;

/// Success threshold: max corner error, % of the diagonal.
const _successPercent = 2.0;

void main(List<String> args) {
  final check = args.contains('--check');
  final writeBaseline = args.contains('--write-baseline');
  final expected = (jsonDecode(
    File('$_fixtures/expected.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();

  const detector = OpenCvCanvasDetector();
  final results = <_Result>[];
  for (final entry in expected) {
    final file = entry['file']! as String;
    final image = _load('$_fixtures/$file');
    final sw = Stopwatch()..start();
    final detection = detector.detectSync(image);
    final ms = sw.elapsedMilliseconds;
    final truth = [
      for (final c in (entry['corners']! as List).cast<List>())
        ((c[0] as num).toDouble(), (c[1] as num).toDouble()),
    ];
    results.add(
      _Result(
        file,
        _maxErrorPercent(detection.quad, truth, image.width, image.height),
        detection.confidence,
        ms,
      ),
    );
  }

  stdout.writeln('photo           error %  confidence    ms');
  for (final r in results) {
    stdout.writeln(
      '${r.file.padRight(14)} ${r.error.toStringAsFixed(2).padLeft(8)}'
      '${r.confidence.toStringAsFixed(2).padLeft(12)}'
      '${r.ms.toString().padLeft(6)}'
      '${r.success ? '' : '   ✗'}',
    );
  }
  final successes = results.where((r) => r.success).length;
  final meanError =
      results.map((r) => r.error).reduce((a, b) => a + b) / results.length;
  final meanMs =
      results.map((r) => r.ms).reduce((a, b) => a + b) / results.length;
  stdout.writeln(
    '\n$successes / ${results.length} within $_successPercent% '
    '(${(100 * successes / results.length).toStringAsFixed(0)}%), '
    'mean error ${meanError.toStringAsFixed(2)}%, '
    'mean ${meanMs.round()} ms',
  );

  if (writeBaseline) {
    File(_baselinePath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'successes': successes, 'total': results.length, 'meanErrorPercent': double.parse(meanError.toStringAsFixed(2))})}\n',
    );
    stdout.writeln('Baseline written to $_baselinePath.');
  }
  if (check) {
    final baseline = jsonDecode(
      File(_baselinePath).readAsStringSync(),
    ) as Map<String, Object?>;
    final required = baseline['successes']! as int;
    if (successes < required) {
      stderr.writeln(
        'FAIL: $successes successes, baseline is $required. '
        'If the drop is intended, rerun with --write-baseline.',
      );
      exitCode = 1;
    } else {
      stdout.writeln('OK: baseline is $required.');
    }
  }
}

class _Result {
  _Result(this.file, this.error, this.confidence, this.ms);

  final String file;
  final double error;
  final double confidence;
  final int ms;

  bool get success => error <= _successPercent;
}

/// The fixture as the app would pass it: RGBA, long edge ≤ [_appLongEdge].
DetectorImage _load(String path) {
  final bgr = cv.imread(path, flags: cv.IMREAD_COLOR);
  final scale = math.min(1.0, _appLongEdge / math.max(bgr.cols, bgr.rows));
  final small = scale < 1
      ? cv.resize(bgr, (
          (bgr.cols * scale).round(),
          (bgr.rows * scale).round(),
        ), interpolation: cv.INTER_AREA)
      : bgr;
  final rgba = cv.cvtColor(small, cv.COLOR_BGR2RGBA);
  return DetectorImage(width: rgba.cols, height: rgba.rows, rgba: rgba.data);
}

double _maxErrorPercent(
  Quad quad,
  List<(double, double)> truth,
  int width,
  int height,
) {
  final diagonal = math.sqrt(width * width + height * height.toDouble());
  var worst = 0.0;
  for (var i = 0; i < 4; i++) {
    final c = quad.corners[i];
    final (x, y) = truth[i];
    final d = math.sqrt(
      math.pow((c.x - x) * width, 2) + math.pow((c.y - y) * height, 2),
    );
    worst = math.max(worst, d / diagonal * 100);
  }
  return worst;
}
