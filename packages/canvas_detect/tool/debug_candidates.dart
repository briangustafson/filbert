// Prints the best-scoring candidates for one fixture, for tuning:
//
//   dart run tool/debug_candidates.dart photo-04.jpg [count]
//
// Corners are in fixture pixels; support is per side (top, right, bottom,
// left).

import 'dart:io';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:canvas_detect/src/geometry.dart';
import 'package:dartcv4/dartcv.dart' as cv;

void main(List<String> args) {
  final count = args.length > 1 ? int.parse(args[1]) : 8;
  final bgr = cv.imread('test/fixtures/${args[0]}', flags: cv.IMREAD_COLOR);
  final rgba = cv.cvtColor(bgr, cv.COLOR_BGR2RGBA);
  final (scored, scale) = const OpenCvCanvasDetector().debugCandidates(
    DetectorImage(width: rgba.cols, height: rgba.rows, rgba: rgba.data),
  );
  for (final s in scored.take(count)) {
    final corners = [
      for (final p in s.candidate.corners)
        '(${(p.x / scale).round()},${(p.y / scale).round()})',
    ].join(' ');
    final support = [for (final v in s.sideSupport) v.toStringAsFixed(2)]
        .join(' ');
    final long = (rgba.cols > rgba.rows ? rgba.cols : rgba.rows) * scale;
    final focal = rectangleError(
      s.candidate.corners,
      V(rgba.cols * scale / 2, rgba.rows * scale / 2),
      long * 0.6,
      long * 1.6,
    ).toStringAsFixed(1);
    stdout.writeln(
      '${s.score.toStringAsFixed(3)}  rect $focal°  $corners  support $support'
      '${s.candidate.borderSides.isEmpty ? '' : '  border ${s.candidate.borderSides}'}',
    );
  }
}
