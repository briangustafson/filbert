// Golden tests of the export pipeline (m2-design §5.4, §7): each aid,
// compare and the grid on synthetic patterns, so the input is identical on
// every OS. Goldens are lossless PNGs of the pixels before JPEG encoding,
// compared with the M1 render tolerance (max channel diff 8, mean < 0.5).
//
// The tone tests use unedited photos (an exact identity warp), so a
// one-step difference in OpenCV's interpolation between CPUs can't push a
// pixel across a band edge.
//
// Update with: flutter test --update-goldens test/features/export/export_pipeline_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dartcv4/dartcv.dart' as cv;
import 'package:filbert/core/imaging/edits.dart';
import 'package:filbert/core/imaging/palette.dart';
import 'package:filbert/core/imaging/render_geometry.dart';
import 'package:filbert/core/imaging/tone.dart';
import 'package:filbert/core/imaging/tone_map.dart';
import 'package:filbert/features/export/data/export_pipeline.dart';
import 'package:filbert/features/view_aids/domain/grid_layout.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 240, _h = 180;

/// Hue across, lightness down: every tone aid shows on it.
Uint8List _hues(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final hue = x / w * 6;
      final v = 1 - y / h;
      final f = hue - hue.floor();
      final (r, g, b) = switch (hue.floor() % 6) {
        0 => (1.0, f, 0.0),
        1 => (1 - f, 1.0, 0.0),
        2 => (0.0, 1.0, f),
        3 => (0.0, 1 - f, 1.0),
        4 => (f, 0.0, 1.0),
        _ => (1.0, 0.0, 1 - f),
      };
      out.setAll((y * w + x) * 4, [
        (r * v * 255).round(),
        (g * v * 255).round(),
        (b * v * 255).round(),
        255,
      ]);
    }
  }
  return out;
}

/// A different photo: soft rings of warm and cool colors.
Uint8List _rings(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = math.sqrt(math.pow(x - w / 2, 2) + math.pow(y - h / 2, 2));
      final t = (math.sin(d / w * 20) + 1) / 2;
      out.setAll((y * w + x) * 4, [
        (40 + 200 * t).round(),
        (80 + 60 * (1 - t)).round(),
        (200 - 160 * t).round(),
        255,
      ]);
    }
  }
  return out;
}

RenderPlan _plain(int w, int h) => RenderPlan.forEdits(
  sourceWidth: w,
  sourceHeight: h,
  edits: Edits.none,
  maxLongEdge: 6000,
);

cv.Mat _layer(Uint8List rgba, {ToneMap? tone, int w = _w, int h = _h}) =>
    renderLayer(rgba, _plain(w, h), tone: tone, size: (_w, _h));

ExportGrid _grid(GridPrefs prefs, {double? canvasW, double? canvasH}) =>
    ExportGrid(
      layout: GridLayout.of(
        prefs,
        photoWidth: _w * 1.0,
        photoHeight: _h * 1.0,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
      ),
      argb: gridColorArgb(prefs.color),
      widthPx: gridLineExportPx(prefs.width, _w),
    );

void _expectGolden(cv.Mat actual, String name) {
  final file = File('test/goldens/export/$name.png');
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
  final hues = _hues(_w, _h);
  final rings = _rings(_w, _h);

  test('no aids: the edited view unchanged', () {
    final out = _layer(hues);
    expect(out.data, [
      for (var i = 0; i < _w * _h; i++) ...[
        hues[i * 4 + 2],
        hues[i * 4 + 1],
        hues[i * 4],
      ],
    ]);
    out.dispose();
  });

  test('gray', () {
    final out = _layer(hues, tone: ToneMap.gray());
    _expectGolden(out, 'gray');
    out.dispose();
  });

  test('values in 5 bands', () {
    final out = _layer(hues, tone: ToneMap.values(5));
    // Exactly the band grays.
    final grays = {for (var k = 0; k < 5; k++) (bandGray(k, 5) * 255).round()};
    expect(out.data.toSet().difference(grays), isEmpty);
    _expectGolden(out, 'values_5');
    out.dispose();
  });

  test('colors with 8 colors', () {
    final palette = computePalette(hues, count: 8);
    final out = _layer(hues, tone: ToneMap.colors(palette));
    final allowed = {for (final (r, g, b) in palette.srgb8) (r, g, b)};
    final data = out.data;
    for (var i = 0; i < data.length; i += 3) {
      expect(allowed, contains((data[i + 2], data[i + 1], data[i])));
    }
    _expectGolden(out, 'colors_8');
    out.dispose();
  });

  test('compare: values of both, mixed at 50 %', () {
    final out = _layer(hues, tone: ToneMap.values(4));
    final other = _layer(rings, tone: ToneMap.values(4));
    compose(out, other: other.data, opacity: 0.5);
    _expectGolden(out, 'compare_values_50');
    out.dispose();
    other.dispose();
  });

  test('compare: a smaller photo is stretched to this frame', () {
    // A 160 × 160 photo over a 240 × 180 one.
    final out = _layer(hues);
    final other = _layer(_rings(160, 160), w: 160, h: 160);
    expect((other.cols, other.rows), (_w, _h));
    compose(out, other: other.data, opacity: 0.4);
    _expectGolden(out, 'compare_stretched');
    out.dispose();
    other.dispose();
  });

  test('compare at 0 % and 100 %', () {
    final out = _layer(hues);
    final other = _layer(rings);
    final before = Uint8List.fromList(out.data);
    compose(out, other: other.data, opacity: 0);
    expect(out.data, before);
    compose(out, other: other.data, opacity: 1);
    expect(out.data, other.data);
    out.dispose();
    other.dispose();
  });

  test('grid: divisions with diagonals, thin white', () {
    final out = _layer(hues);
    compose(
      out,
      grid: _grid(const GridPrefs(rows: 3, cols: 4, diagonals: true)),
    );
    _expectGolden(out, 'grid_divisions');
    out.dispose();
  });

  test('grid: spacing with partial cells, thick red', () {
    final out = _layer(hues);
    compose(
      out,
      grid: _grid(
        const GridPrefs(
          mode: GridMode.spacing,
          spacing: 2,
          color: GridColor.red,
          width: GridLineWidth.thick,
        ),
        canvasW: 11,
        canvasH: 8,
      ),
    );
    _expectGolden(out, 'grid_spacing');
    out.dispose();
  });

  test('everything: values, compare and grid', () {
    final out = _layer(hues, tone: ToneMap.values(3));
    final other = _layer(rings, tone: ToneMap.values(3));
    compose(
      out,
      other: other.data,
      opacity: 0.3,
      grid: _grid(const GridPrefs(color: GridColor.black)),
    );
    _expectGolden(out, 'everything');
    out.dispose();
    other.dispose();
  });

  test('export line width scales with the image', () {
    expect(gridLineExportPx(GridLineWidth.thin, 800), 1);
    expect(gridLineExportPx(GridLineWidth.thick, 6000), 22.5);
  });

  test('JPEG at quality 92', () {
    final out = _layer(hues);
    final jpeg = encodeExportJpeg(out);
    expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
    final back = cv.imdecode(jpeg, cv.IMREAD_COLOR);
    expect((back.cols, back.rows), (_w, _h));
    back.dispose();
    out.dispose();
  });
}
