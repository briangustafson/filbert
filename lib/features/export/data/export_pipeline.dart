import 'dart:typed_data';

import 'package:canvas_detect/safe_cv.dart' as safe_cv;
import 'package:dartcv4/dartcv.dart' as cv;

import '../../../core/imaging/render_geometry.dart';
import '../../../core/imaging/render_pipeline.dart';
import '../../../core/imaging/tone_map.dart';
import '../../view_aids/domain/grid_layout.dart';

/// The OpenCV half of exporting with aids (m2-design §5.4): plain Dart, so
/// it runs in a background isolate and under `flutter test`.
///
/// ```
/// edited view ─▶ tone ─▶ compare mix ─▶ grid ─▶ JPEG
/// ```

/// JPEG quality of exports (higher than previews: these are kept).
const exportJpegQuality = 92;

/// One photo's edited view rendered by [plan] from its decoded [rgba]
/// pixels, stretched to [size] (width, height) if given, with [tone]
/// applied. Returns BGR; the caller disposes it.
cv.Mat renderLayer(
  Uint8List rgba,
  RenderPlan plan, {
  ToneMap? tone,
  (int, int)? size,
}) {
  final source = bgrFromRgba(rgba, plan.decodeWidth, plan.decodeHeight);
  cv.Mat out;
  try {
    out = warpForPlan(source, plan);
  } finally {
    source.dispose();
  }
  if (size != null && (out.cols != size.$1 || out.rows != size.$2)) {
    final shrinking = size.$1 <= out.cols && size.$2 <= out.rows;
    final resized = safe_cv.resize(
      out,
      size,
      interpolation: shrinking ? cv.INTER_AREA : cv.INTER_LINEAR,
    );
    out.dispose();
    out = resized;
  }
  tone?.apply(out.data);
  return out;
}

/// The grid of an export: where the lines go, their color (0xAARRGGBB) and
/// width in pixels.
class ExportGrid {
  const ExportGrid({
    required this.layout,
    required this.argb,
    required this.widthPx,
  });

  final GridLayout layout;
  final int argb;
  final double widthPx;
}

/// Sub-pixel precision for OpenCV drawing: coordinates × 2^4.
const _shift = 4;

/// Draws [grid] over [bgr] in place, antialiased (m2-design §3.3).
void drawGrid(cv.Mat bgr, ExportGrid grid) {
  final w = bgr.cols.toDouble(), h = bgr.rows.toDouble();
  final color = cv.Scalar(
    (grid.argb & 0xFF).toDouble(),
    (grid.argb >> 8 & 0xFF).toDouble(),
    (grid.argb >> 16 & 0xFF).toDouble(),
  );
  final thickness = grid.widthPx.round().clamp(1, 1 << 12);
  // A fraction f of the width is the edge at f · w; OpenCV's coordinates
  // are pixel centres, half a pixel in from the edges.
  int fx(double f) => ((f * w - 0.5) * (1 << _shift)).round();
  int fy(double f) => ((f * h - 0.5) * (1 << _shift)).round();
  void line(int x1, int y1, int x2, int y2) {
    final a = cv.Point(x1, y1), b = cv.Point(x2, y2);
    cv.line(
      bgr,
      a,
      b,
      color,
      thickness: thickness,
      lineType: cv.LINE_AA,
      shift: _shift,
    );
    a.dispose();
    b.dispose();
  }

  final layout = grid.layout;
  try {
    for (final f in layout.innerXs) {
      line(fx(f), fy(0), fx(f), fy(1));
    }
    for (final f in layout.innerYs) {
      line(fx(0), fy(f), fx(1), fy(f));
    }
    if (layout.diagonals) {
      for (var i = 0; i + 1 < layout.xs.length; i++) {
        for (var j = 0; j + 1 < layout.ys.length; j++) {
          final l = fx(layout.xs[i]), r = fx(layout.xs[i + 1]);
          final t = fy(layout.ys[j]), b = fy(layout.ys[j + 1]);
          line(l, t, r, b);
          line(r, t, l, b);
        }
      }
    }
  } finally {
    color.dispose();
  }
}

/// Mixes [other] (BGR, same size) into [bgr] at [opacity] and draws
/// [grid]: the steps after each photo's layer.
void compose(
  cv.Mat bgr, {
  Uint8List? other,
  double opacity = 0,
  ExportGrid? grid,
}) {
  if (other != null) mixInto(bgr.data, other, opacity);
  if (grid != null) drawGrid(bgr, grid);
}

/// [bgr] as JPEG bytes at [exportJpegQuality].
Uint8List encodeExportJpeg(cv.Mat bgr) {
  final params = cv.VecI32.fromList([
    cv.IMWRITE_JPEG_QUALITY,
    exportJpegQuality,
  ]);
  try {
    final (ok, bytes) = cv.imencode('.jpg', bgr, params: params);
    if (!ok) throw StateError('JPEG encoding failed');
    return bytes;
  } finally {
    params.dispose();
  }
}
