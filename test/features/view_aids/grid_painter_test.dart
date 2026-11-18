// Golden tests of the grid overlay (engineering guidelines: goldens for
// anything that renders images). Drawn on a plain dark background, so the
// input is the same on every OS; compared with the M1 render tolerance
// (max channel difference 8, mean < 0.5; m1-design §8) since antialiasing
// can differ slightly between hosts.
//
// Update with: flutter test --update-goldens test/features/view_aids/grid_painter_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:filbert/features/view_aids/domain/grid_layout.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:filbert/features/view_aids/ui/grid_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _w = 240, _h = 180;

Future<Uint8List> _paint(GridLayout layout, GridPrefs prefs) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _w * 1.0, _h * 1.0),
    Paint()..color = const Color(0xFF303030),
  );
  GridPainter(
    layout: layout,
    // Inset, as a fitted photo is: nothing is drawn outside it.
    photoRect: () => const Rect.fromLTWH(10, 10, 220, 160),
    color: Color(gridColorArgb(prefs.color)),
    strokeWidth: gridLineDp(prefs.width),
  ).paint(canvas, const Size(_w * 1.0, _h * 1.0));
  final image = await recorder.endRecording().toImage(_w, _h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

Future<Uint8List> _png(Uint8List rgba) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: _w,
    height: _h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final image =
      (await (await descriptor.instantiateCodec()).getNextFrame()).image;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

Future<Uint8List> _decode(Uint8List png) async {
  final image = (await (await ui.instantiateImageCodec(
    png,
  )).getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

Future<void> _expectGolden(String name, Uint8List actual) async {
  final file = File('test/goldens/grid/$name.png');
  if (autoUpdateGoldenFiles) {
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(await _png(actual));
    return;
  }
  expect(file.existsSync(), isTrue, reason: 'missing golden ${file.path}');
  final golden = await _decode(file.readAsBytesSync());
  expect(golden.length, actual.length);
  var maxDiff = 0;
  var sum = 0;
  for (var i = 0; i < actual.length; i++) {
    final d = (actual[i] - golden[i]).abs();
    maxDiff = math.max(maxDiff, d);
    sum += d;
  }
  expect(maxDiff, lessThanOrEqualTo(8), reason: '$name: max channel diff');
  expect(sum / actual.length, lessThan(0.5), reason: '$name: mean diff');
}

void main() {
  test('divisions with diagonals, thin white', () async {
    const prefs = GridPrefs(rows: 3, cols: 4, diagonals: true);
    final layout = GridLayout.of(prefs, photoWidth: 220, photoHeight: 160);
    await _expectGolden('divisions_diagonals', await _paint(layout, prefs));
  });

  test('spacing with partial cells, medium red', () async {
    const prefs = GridPrefs(
      mode: GridMode.spacing,
      spacing: 2,
      color: GridColor.red,
      width: GridLineWidth.medium,
    );
    final layout = GridLayout.of(
      prefs,
      photoWidth: 220,
      photoHeight: 160,
      canvasWidth: 11,
      canvasHeight: 8,
    );
    await _expectGolden('spacing_partial', await _paint(layout, prefs));
  });

  test('thick black and thin gray', () async {
    for (final (name, prefs) in [
      (
        'thick_black',
        const GridPrefs(color: GridColor.black, width: GridLineWidth.thick),
      ),
      ('thin_gray', const GridPrefs(color: GridColor.gray)),
    ]) {
      final layout = GridLayout.of(prefs, photoWidth: 220, photoHeight: 160);
      await _expectGolden(name, await _paint(layout, prefs));
    }
  });

  test('nothing is drawn outside the photo', () async {
    const prefs = GridPrefs(rows: 5, cols: 5, diagonals: true);
    final layout = GridLayout.of(prefs, photoWidth: 220, photoHeight: 160);
    final pixels = await _paint(layout, prefs);
    // The 10 px margin around the photo keeps the background color.
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final inside = x >= 9 && x <= 230 && y >= 9 && y <= 170;
        if (inside) continue;
        final i = (y * _w + x) * 4;
        expect(pixels.sublist(i, i + 3), [
          0x30,
          0x30,
          0x30,
        ], reason: '($x, $y)');
      }
    }
  });
}
