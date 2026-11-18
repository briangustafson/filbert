import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;

import 'view_prefs.dart';

/// Where a grid's lines fall on a photo (m2-design §3.3): pure geometry,
/// shared by the live overlay and the export.
///
/// Positions are fractions of the photo's width ([xs]) and height ([ys]),
/// so the same layout serves any display or output size.
class GridLayout {
  const GridLayout({
    required this.xs,
    required this.ys,
    required this.diagonals,
    this.aspectMismatch = false,
  });

  /// Cell boundaries across, from 0 to 1 inclusive, increasing. Lines are
  /// drawn at the inner ones; diagonals use them all.
  final List<double> xs;

  /// Cell boundaries down, from 0 to 1 inclusive, increasing.
  final List<double> ys;

  /// Whether each cell gets both its diagonals.
  final bool diagonals;

  /// Spacing mode only: the photo's proportions differ from the canvas's,
  /// so the squares can't be exact ("Crop to the project's size…").
  final bool aspectMismatch;

  @override
  bool operator ==(Object other) =>
      other is GridLayout &&
      listEquals(other.xs, xs) &&
      listEquals(other.ys, ys) &&
      other.diagonals == diagonals &&
      other.aspectMismatch == aspectMismatch;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(xs),
    Object.hashAll(ys),
    diagonals,
    aspectMismatch,
  );

  /// Inner vertical lines (excluding the photo's edges).
  Iterable<double> get innerXs => xs.skip(1).take(xs.length - 2);

  /// Inner horizontal lines (excluding the photo's edges).
  Iterable<double> get innerYs => ys.skip(1).take(ys.length - 2);

  /// Most cells along one side; spacing finer than this is coarsened, so a
  /// tiny spacing on a big canvas can't produce thousands of lines.
  static const maxCellsPerSide = 200;

  /// Proportions that differ by more than this count as a mismatch (2%).
  static const aspectTolerance = 0.02;

  /// The grid for a photo of [photoWidth] × [photoHeight] (any unit, only
  /// the ratio matters).
  ///
  /// [canvasWidth] × [canvasHeight] is the project's physical size, in the
  /// same unit as [GridPrefs.spacing]; without it, spacing mode falls back
  /// to divisions. The canvas's longer side goes with the photo's longer
  /// side, so a portrait canvas photographed in landscape still gets square
  /// cells of the right size.
  factory GridLayout.of(
    GridPrefs grid, {
    required double photoWidth,
    required double photoHeight,
    double? canvasWidth,
    double? canvasHeight,
    double? defaultSpacing,
  }) {
    if (grid.mode == GridMode.spacing &&
        canvasWidth != null &&
        canvasHeight != null &&
        canvasWidth > 0 &&
        canvasHeight > 0) {
      final landscape = photoWidth >= photoHeight;
      final longer = math.max(canvasWidth, canvasHeight);
      final shorter = math.min(canvasWidth, canvasHeight);
      final canvasAcross = landscape ? longer : shorter;
      final canvasDown = landscape ? shorter : longer;
      final spacing = grid.spacing ?? defaultSpacing ?? 0;
      if (spacing > 0) {
        // Square cells measured along the width: a cell is spacing ÷ canvas
        // width of the photo's width, and the same number of pixels down.
        final stepX = spacing / canvasAcross;
        final stepY = stepX * photoWidth / photoHeight;
        final photoAspect = photoWidth / photoHeight;
        final canvasAspect = canvasAcross / canvasDown;
        return GridLayout(
          xs: _steps(stepX),
          ys: _steps(stepY),
          diagonals: grid.diagonals,
          aspectMismatch:
              (photoAspect / canvasAspect - 1).abs() > aspectTolerance,
        );
      }
    }
    return GridLayout(
      xs: [for (var i = 0; i <= grid.cols; i++) i / grid.cols],
      ys: [for (var i = 0; i <= grid.rows; i++) i / grid.rows],
      diagonals: grid.diagonals,
    );
  }

  /// 0, step, 2·step, … then 1; the last cell may be partial.
  static List<double> _steps(double step) {
    final s = math.max(step, 1 / maxCellsPerSide);
    final out = <double>[0];
    // A boundary within a hair of the edge is the edge (rounding).
    for (var x = s; x < 1 - 1e-9; x += s) {
      out.add(x);
    }
    out.add(1);
    return out;
  }
}

/// On-screen line widths in logical pixels (m2-design §3.3).
double gridLineDp(GridLineWidth width) => switch (width) {
  GridLineWidth.thin => 1,
  GridLineWidth.medium => 2,
  GridLineWidth.thick => 3,
};

/// The line width in an exported image: the same fraction of the image as
/// on a phone screen, about 800 dp across (m2-design §3.3).
double gridLineExportPx(GridLineWidth width, int longEdgePx) =>
    gridLineDp(width) * longEdgePx / 800;

/// Grid line colors as 0xAARRGGBB.
int gridColorArgb(GridColor color) => switch (color) {
  GridColor.white => 0xFFFFFFFF,
  GridColor.black => 0xFF000000,
  GridColor.gray => 0xFF808080,
  GridColor.red => 0xFFE53935,
};
