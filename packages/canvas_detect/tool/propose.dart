// Runs the OpenCV detector on every fixture and writes its corners in
// expected.json's format, for review sheets (tool/annotation_sheets.dart):
//
//   dart run tool/propose.dart <out.json>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:dartcv4/dartcv.dart' as cv;

void main(List<String> args) {
  final files =
      Directory('test/fixtures')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  const detector = OpenCvCanvasDetector();
  final out = <Map<String, Object?>>[];
  for (final f in files) {
    final bgr = cv.imread(f.path, flags: cv.IMREAD_COLOR);
    final rgba = cv.cvtColor(bgr, cv.COLOR_BGR2RGBA);
    final sw = Stopwatch()..start();
    final d = detector.detectSync(
      DetectorImage(
        width: rgba.cols,
        height: rgba.rows,
        rgba: Uint8List.fromList(rgba.data),
      ),
    );
    final name = f.uri.pathSegments.last;
    stdout.writeln(
      '$name confidence ${d.confidence.toStringAsFixed(2)} '
      '${sw.elapsedMilliseconds} ms',
    );
    out.add({
      'file': name,
      'corners': [
        for (final c in d.quad.corners)
          [
            double.parse(c.x.toStringAsFixed(4)),
            double.parse(c.y.toStringAsFixed(4)),
          ],
      ],
      'notes':
          'detector proposal, confidence ${d.confidence.toStringAsFixed(2)}',
    });
  }
  File(args[0])
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
}
