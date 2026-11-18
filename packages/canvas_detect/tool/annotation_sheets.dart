// Helps annotate the evaluation set (m1-design §6.4). Run from
// packages/canvas_detect:
//
//   dart run tool/annotation_sheets.dart grid <photo.jpg> <out.jpg>
//     The photo with a labelled 100 px grid, for reading rough positions.
//
//   dart run tool/annotation_sheets.dart review <corners.json> <out-dir>
//     One review sheet per entry: the photo with the quad drawn, and the
//     four corners zoomed 3× with a crosshair and 10 px ticks.
//
// corners.json is expected.json's format (normalized "corners"); entries may
// use "cornersPx" (pixels of the fixture) instead while drafting.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:canvas_detect/safe_cv.dart' as safe_cv;
import 'package:dartcv4/dartcv.dart' as cv;

const _fixtures = 'test/fixtures';

void main(List<String> args) {
  switch (args) {
    case ['grid', final photo, final out]:
      _grid(photo, out);
    case ['review', final json, final outDir]:
      _review(json, outDir);
    case ['contact', final json, final out]:
      _contact(json, out);
    default:
      stderr.writeln(
        'usage: annotation_sheets.dart grid <photo> <out> | '
        'review <corners.json> <out-dir>',
      );
      exitCode = 64;
  }
}

final _yellow = cv.Scalar(0, 255, 255);
final _magenta = cv.Scalar(255, 0, 255);
final _white = cv.Scalar(255, 255, 255);
final _black = cv.Scalar(0, 0, 0);

void _grid(String photo, String out) {
  final image = cv.imread(photo, flags: cv.IMREAD_COLOR);
  for (var x = 0; x < image.cols; x += 100) {
    cv.line(image, cv.Point(x, 0), cv.Point(x, image.rows), _yellow);
    _label(image, '$x', cv.Point(x + 3, 18));
  }
  for (var y = 0; y < image.rows; y += 100) {
    cv.line(image, cv.Point(0, y), cv.Point(image.cols, y), _yellow);
    _label(image, '$y', cv.Point(3, y - 4));
  }
  cv.imwrite(out, image);
}

/// All entries' overviews in one image (6 per row), quads drawn.
void _contact(String jsonPath, String out) {
  final entries = (jsonDecode(File(jsonPath).readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  const cell = 300, cols = 6;
  final rows = (entries.length / cols).ceil();
  final sheet = cv.Mat.zeros(rows * cell, cols * cell, cv.MatType.CV_8UC3)
    ..setTo(cv.Scalar(40, 40, 40));
  for (var k = 0; k < entries.length; k++) {
    final entry = entries[k];
    final file = entry['file']! as String;
    final image = cv.imread('$_fixtures/$file', flags: cv.IMREAD_COLOR);
    final c = _cornersPx(entry, image.cols, image.rows);
    final s = (cell - 8) / math.max(image.cols, image.rows);
    final small = safe_cv.resize(image, (
      (image.cols * s).round(),
      (image.rows * s).round(),
    ), interpolation: cv.INTER_AREA);
    final pts = [
      for (final (x, y) in c) cv.Point((x * s).round(), (y * s).round()),
    ];
    for (var i = 0; i < 4; i++) {
      cv.line(small, pts[i], pts[(i + 1) % 4], _magenta, thickness: 2);
    }
    final x = (k % cols) * cell + (cell - small.cols) ~/ 2;
    final y = (k ~/ cols) * cell + (cell - small.rows) ~/ 2;
    small.copyTo(sheet.region(cv.Rect(x, y, small.cols, small.rows)));
    _label(
      sheet,
      file.replaceAll('photo-', '').replaceAll('.jpg', ''),
      cv.Point((k % cols) * cell + 6, (k ~/ cols) * cell + 22),
      scale: 0.7,
    );
  }
  cv.imwrite(out, sheet);
}

void _review(String jsonPath, String outDir) {
  final entries = (jsonDecode(File(jsonPath).readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  Directory(outDir).createSync(recursive: true);
  for (final entry in entries) {
    final file = entry['file']! as String;
    final image = cv.imread('$_fixtures/$file', flags: cv.IMREAD_COLOR);
    final corners = _cornersPx(entry, image.cols, image.rows);
    cv.imwrite(
      '$outDir/${file.replaceAll('.jpg', '')}-review.jpg',
      _sheet(image, corners, file, entry['notes'] as String?),
    );
  }
}

List<(double, double)> _cornersPx(Map<String, Object?> entry, int w, int h) {
  final px = entry['cornersPx'];
  final list = (px ?? entry['corners'])! as List;
  return [
    for (final c in list.cast<List>())
      px != null
          ? ((c[0] as num).toDouble(), (c[1] as num).toDouble())
          : ((c[0] as num) * w.toDouble(), (c[1] as num) * h.toDouble()),
  ];
}

/// Overview on the left (long edge 900), the four zooms in a 2×2 grid on
/// the right (TL, TR / BL, BR).
cv.Mat _sheet(
  cv.Mat image,
  List<(double, double)> c,
  String file,
  String? notes,
) {
  const overviewLong = 900, zoom = 3, radius = 70, cell = radius * 2 * zoom;
  final s = overviewLong / math.max(image.cols, image.rows);
  final overview = safe_cv.resize(image, (
    (image.cols * s).round(),
    (image.rows * s).round(),
  ), interpolation: cv.INTER_AREA);
  final pts = [
    for (final (x, y) in c) cv.Point((x * s).round(), (y * s).round()),
  ];
  for (var i = 0; i < 4; i++) {
    cv.line(overview, pts[i], pts[(i + 1) % 4], _magenta, thickness: 2);
    cv.circle(overview, pts[i], 6, _magenta, thickness: 2);
    _label(
      overview,
      ['TL', 'TR', 'BR', 'BL'][i],
      cv.Point(pts[i].x + 8, pts[i].y - 8),
    );
  }

  final w = overview.cols + 2 * cell + 30,
      h = math.max(overview.rows, 2 * cell + 10) + 40;
  final sheet = cv.Mat.zeros(h, w, cv.MatType.CV_8UC3)
    ..setTo(cv.Scalar(40, 40, 40));
  overview.copyTo(sheet.region(cv.Rect(10, 40, overview.cols, overview.rows)));
  _label(sheet, '$file  ${notes ?? ''}', cv.Point(10, 26), scale: 0.8);

  // TL, TR, BL, BR positions in the 2×2 grid.
  const order = [0, 1, 3, 2];
  for (var k = 0; k < 4; k++) {
    final i = order[k];
    final (cx, cy) = c[i];
    final z = _zoom(image, cx, cy, radius, zoom, ['TL', 'TR', 'BR', 'BL'][i]);
    final x = overview.cols + 20 + (k % 2) * (cell + 10);
    final y = 40 + (k ~/ 2) * (cell + 10);
    z.copyTo(sheet.region(cv.Rect(x, y, z.cols, z.rows)));
  }
  return sheet;
}

/// [radius] px around (cx, cy), enlarged [zoom]×, with a crosshair on the
/// point and ticks every 10 px (labelled every 50) in fixture pixels.
cv.Mat _zoom(
  cv.Mat image,
  double cx,
  double cy,
  int radius,
  int zoom,
  String name,
) {
  final size = radius * 2;
  final padded = cv.copyMakeBorder(
    image,
    size,
    size,
    size,
    size,
    cv.BORDER_CONSTANT,
    value: cv.Scalar(90, 90, 90),
  );
  final x0 = cx.round() - radius, y0 = cy.round() - radius;
  final crop = padded.region(cv.Rect(x0 + size, y0 + size, size, size)).clone();
  final big = safe_cv.resize(crop, (
    size * zoom,
    size * zoom,
  ), interpolation: cv.INTER_NEAREST);
  int toZ(double v, int origin) => ((v - origin) * zoom).round();
  final px = toZ(cx, x0), py = toZ(cy, y0);
  cv.line(big, cv.Point(px, 0), cv.Point(px, big.rows), _magenta);
  cv.line(big, cv.Point(0, py), cv.Point(big.cols, py), _magenta);
  cv.circle(big, cv.Point(px, py), 10, _magenta, thickness: 2);
  for (var v = (x0 ~/ 10 + 1) * 10; v < x0 + size; v += 10) {
    final t = toZ(v.toDouble(), x0);
    cv.line(
      big,
      cv.Point(t, 0),
      cv.Point(t, v % 50 == 0 ? 16 : 8),
      _yellow,
      thickness: 2,
    );
    if (v % 50 == 0) _label(big, '$v', cv.Point(t + 2, 30));
  }
  for (var v = (y0 ~/ 10 + 1) * 10; v < y0 + size; v += 10) {
    final t = toZ(v.toDouble(), y0);
    cv.line(
      big,
      cv.Point(0, t),
      cv.Point(v % 50 == 0 ? 16 : 8, t),
      _yellow,
      thickness: 2,
    );
    if (v % 50 == 0) _label(big, '$v', cv.Point(18, t + 6));
  }
  _label(
    big,
    '$name (${cx.round()}, ${cy.round()})',
    cv.Point(8, big.rows - 12),
    scale: 0.7,
  );
  return big;
}

void _label(cv.Mat m, String text, cv.Point at, {double scale = 0.5}) {
  cv.putText(m, text, at, cv.FONT_HERSHEY_SIMPLEX, scale, _black, thickness: 4);
  cv.putText(m, text, at, cv.FONT_HERSHEY_SIMPLEX, scale, _white, thickness: 1);
}
