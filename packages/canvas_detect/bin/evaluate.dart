// Evaluates the detector on the fixtures (m1-design §6.5). Run from
// packages/canvas_detect:
//
//   dart run bin/evaluate.dart [--runs N]        print the table
//   dart run bin/evaluate.dart --check           also fail below the baseline
//   dart run bin/evaluate.dart --write-baseline  record the current result
//
// Each photo is downscaled to the size the app passes the detector, then the
// detected corners are compared with test/fixtures/expected.json. Error is
// the largest corner distance as a percentage of the photo's diagonal; at
// most 2% is a success.
//
// Each photo is run N times (default 10): once as decoded, then with
// different invisible ±1 noise. The detector is sensitive to tiny pixel
// differences (another platform's JPEG decoder, Android's decoder in the
// app), so one run per photo would measure luck. The success rate is over
// all runs.

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

/// --check passes down to this far below the baseline rate: decoders differ
/// between platforms (CI runs on Linux, the baseline is recorded on a Mac).
const _tolerance = 0.05;

void main(List<String> args) {
  final check = args.contains('--check');
  final writeBaseline = args.contains('--write-baseline');
  final runsAt = args.indexOf('--runs');
  final runs = runsAt >= 0 ? int.parse(args[runsAt + 1]) : 10;
  final expected = (jsonDecode(
    File('$_fixtures/expected.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();

  const detector = OpenCvCanvasDetector();
  final results = <_Result>[];
  for (final entry in expected) {
    final file = entry['file']! as String;
    final truth = [
      for (final c in (entry['corners']! as List).cast<List>())
        ((c[0] as num).toDouble(), (c[1] as num).toDouble()),
    ];
    final result = _Result(file);
    for (var run = 0; run < runs; run++) {
      final image = _load('$_fixtures/$file', noiseSeed: run == 0 ? null : run);
      final sw = Stopwatch()..start();
      final detection = detector.detectSync(image);
      result.ms.add(sw.elapsedMilliseconds);
      result.errors.add(
        _maxErrorPercent(detection.quad, truth, image.width, image.height),
      );
      result.confidences.add(detection.confidence);
    }
    results.add(result);
  }

  stdout.writeln(
    'photo          passed  median error %  worst error %  confidence    ms',
  );
  for (final r in results) {
    stdout.writeln(
      '${r.file.padRight(14)} ${'${r.passes}/$runs'.padLeft(6)}'
      '${_median(r.errors).toStringAsFixed(2).padLeft(16)}'
      '${r.errors.reduce(math.max).toStringAsFixed(2).padLeft(15)}'
      '${_mean(r.confidences).toStringAsFixed(2).padLeft(12)}'
      '${_mean(r.ms).round().toString().padLeft(6)}',
    );
  }
  final passes = results.map((r) => r.passes).reduce((a, b) => a + b);
  final total = results.length * runs;
  final rate = passes / total;
  final medianError = _median([for (final r in results) ..._sorted(r.errors)]);
  stdout.writeln(
    '\n$passes / $total runs within $_successPercent% '
    '(${(100 * rate).toStringAsFixed(1)}%), '
    'median error ${medianError.toStringAsFixed(2)}%, '
    'mean ${_mean([for (final r in results) ...r.ms]).round()} ms',
  );

  if (writeBaseline) {
    File(_baselinePath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'successRate': double.parse(rate.toStringAsFixed(3)), 'runs': runs, 'photos': results.length})}\n',
    );
    stdout.writeln('Baseline written to $_baselinePath.');
  }
  if (check) {
    final baseline = jsonDecode(
      File(_baselinePath).readAsStringSync(),
    ) as Map<String, Object?>;
    final required = (baseline['successRate']! as num) - _tolerance;
    if (rate < required) {
      stderr.writeln(
        'FAIL: success rate ${(100 * rate).toStringAsFixed(1)}%, below '
        'the baseline ${baseline['successRate']} minus $_tolerance. '
        'If the drop is intended, rerun with --write-baseline.',
      );
      exitCode = 1;
    } else {
      stdout.writeln(
        'OK: baseline ${baseline['successRate']} (minimum '
        '${required.toStringAsFixed(3)}).',
      );
    }
  }
}

class _Result {
  _Result(this.file);

  final String file;
  final errors = <double>[];
  final confidences = <double>[];
  final ms = <int>[];

  int get passes => errors.where((e) => e <= _successPercent).length;
}

double _mean(List<num> v) => v.fold<double>(0, (a, b) => a + b) / v.length;

List<double> _sorted(List<double> v) => [...v]..sort();

double _median(List<double> v) {
  final s = _sorted(v);
  return s.length.isOdd
      ? s[s.length ~/ 2]
      : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
}

/// The fixture as the app would pass it: RGBA, long edge ≤ [_appLongEdge],
/// with ±1 noise from [noiseSeed] if given.
DetectorImage _load(String path, {int? noiseSeed}) {
  final bgr = cv.imread(path, flags: cv.IMREAD_COLOR);
  final scale = math.min(1.0, _appLongEdge / math.max(bgr.cols, bgr.rows));
  final small = scale < 1
      ? cv.resize(bgr, (
          (bgr.cols * scale).round(),
          (bgr.rows * scale).round(),
        ), interpolation: cv.INTER_AREA)
      : bgr;
  final rgba = cv.cvtColor(small, cv.COLOR_BGR2RGBA);
  if (noiseSeed != null) {
    final r = math.Random(noiseSeed);
    final d = rgba.data;
    for (var i = 0; i < d.length; i++) {
      if (i % 4 != 3) d[i] = (d[i] + r.nextInt(3) - 1).clamp(0, 255);
    }
  }
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
