import 'package:filbert/features/view_aids/domain/grid_layout.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Matcher closeToAll(List<double> expected) => pairwiseCompare(
    expected,
    (double e, double a) => (e - a).abs() < 1e-9,
    'within 1e-9 of',
  );

  group('divisions', () {
    test('equal cells, edges included', () {
      final g = GridLayout.of(
        const GridPrefs(rows: 3, cols: 4),
        photoWidth: 400,
        photoHeight: 300,
      );
      expect(g.xs, closeToAll([0, .25, .5, .75, 1]));
      expect(g.ys, closeToAll([0, 1 / 3, 2 / 3, 1]));
      expect(g.innerXs, closeToAll([.25, .5, .75]));
      expect(g.innerYs, closeToAll([1 / 3, 2 / 3]));
      expect(g.aspectMismatch, isFalse);
    });

    test('one division has no inner lines', () {
      final g = GridLayout.of(
        const GridPrefs(rows: 1, cols: 1, diagonals: true),
        photoWidth: 10,
        photoHeight: 10,
      );
      expect(g.innerXs, isEmpty);
      expect(g.innerYs, isEmpty);
      expect(g.diagonals, isTrue);
    });

    test('spacing mode without a canvas size falls back', () {
      final g = GridLayout.of(
        const GridPrefs(mode: GridMode.spacing, spacing: 2),
        photoWidth: 400,
        photoHeight: 300,
      );
      expect(g.xs, hasLength(5), reason: 'the default 4 × 4');
    });
  });

  group('spacing', () {
    test('square cells from the canvas width, partial last cells', () {
      // 12 × 9 in canvas, 2 in cells: 6 across, 4.5 down.
      final g = GridLayout.of(
        const GridPrefs(mode: GridMode.spacing, spacing: 2),
        photoWidth: 1200,
        photoHeight: 900,
        canvasWidth: 12,
        canvasHeight: 9,
      );
      expect(g.xs, closeToAll([0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1]));
      expect(g.ys, closeToAll([0, 2 / 9, 4 / 9, 6 / 9, 8 / 9, 1]));
      expect(g.aspectMismatch, isFalse);
      // Square on the photo: 200 px across and down.
      expect((g.xs[1] * 1200), closeTo(200, 1e-9));
      expect((g.ys[1] * 900), closeTo(200, 1e-9));
    });

    test('an exact fit adds no sliver at the edge', () {
      final g = GridLayout.of(
        const GridPrefs(mode: GridMode.spacing, spacing: 3),
        photoWidth: 900,
        photoHeight: 900,
        canvasWidth: 9,
        canvasHeight: 9,
      );
      expect(g.xs, closeToAll([0, 1 / 3, 2 / 3, 1]));
    });

    test('the canvas\'s longer side goes with the photo\'s', () {
      // A 9 × 12 (portrait) canvas photographed in landscape.
      final g = GridLayout.of(
        const GridPrefs(mode: GridMode.spacing, spacing: 3),
        photoWidth: 1200,
        photoHeight: 900,
        canvasWidth: 9,
        canvasHeight: 12,
      );
      expect(g.xs, closeToAll([0, .25, .5, .75, 1]));
      expect(g.aspectMismatch, isFalse);
    });

    test('the default spacing applies when none is set', () {
      final g = GridLayout.of(
        const GridPrefs(mode: GridMode.spacing),
        photoWidth: 1000,
        photoHeight: 1000,
        canvasWidth: 10,
        canvasHeight: 10,
        defaultSpacing: 5,
      );
      expect(g.xs, closeToAll([0, .5, 1]));
    });

    test('flags proportions that differ from the canvas by over 2%', () {
      GridLayout layout(double photoWidth) => GridLayout.of(
        const GridPrefs(mode: GridMode.spacing, spacing: 1),
        photoWidth: photoWidth,
        photoHeight: 1000,
        canvasWidth: 10,
        canvasHeight: 10,
      );
      expect(layout(1015).aspectMismatch, isFalse);
      expect(layout(1030).aspectMismatch, isTrue);
      expect(layout(900).aspectMismatch, isTrue);
      // Mismatched or not, the cells stay square by the width.
      final wide = layout(1500);
      expect(wide.ys[1] * 1000, closeTo(wide.xs[1] * 1500, 1e-9));
    });

    test('a tiny spacing is coarsened to a sane number of lines', () {
      final g = GridLayout.of(
        const GridPrefs(mode: GridMode.spacing, spacing: 0.01),
        photoWidth: 1000,
        photoHeight: 1000,
        canvasWidth: 100,
        canvasHeight: 100,
      );
      expect(g.xs.length, lessThanOrEqualTo(GridLayout.maxCellsPerSide + 1));
    });
  });

  test('line widths: on screen and in exports', () {
    expect(gridLineDp(GridLineWidth.thin), 1);
    expect(gridLineDp(GridLineWidth.thick), 3);
    // An 800 px export matches a phone screen; 6000 px scales up.
    expect(gridLineExportPx(GridLineWidth.medium, 800), 2);
    expect(gridLineExportPx(GridLineWidth.thin, 6000), 7.5);
  });
}
