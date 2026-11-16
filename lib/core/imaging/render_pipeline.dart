import 'dart:typed_data';

import 'package:dartcv4/dartcv.dart' as cv;

import 'render_geometry.dart';

/// The OpenCV half of rendering (m1-design §5.1): warp the decoded original
/// to the crop, apply quarter turns, encode. Plain Dart (no Flutter), so it
/// runs in a background isolate and under `dart test`.

/// JPEG quality for previews and thumbnails.
const renderJpegQuality = 90;

/// Warps [source] (8-bit BGR, sized `plan.decodeWidth` × `plan.decodeHeight`)
/// by [plan] and returns the BGR result. The caller disposes both.
cv.Mat warpForPlan(cv.Mat source, RenderPlan plan) {
  if (source.cols != plan.decodeWidth || source.rows != plan.decodeHeight) {
    throw ArgumentError(
      'Source is ${source.cols}x${source.rows}, plan expects '
      '${plan.decodeWidth}x${plan.decodeHeight}',
    );
  }
  cv.VecPoint2f corners(List<(double, double)> points) =>
      cv.VecPoint2f.fromList([for (final (x, y) in points) cv.Point2f(x, y)]);
  final src = corners(plan.sourceCorners);
  final dst = corners(plan.destinationCorners);
  final homography = cv.getPerspectiveTransform2f(src, dst);
  try {
    final warped = cv.warpPerspective(
      source,
      homography,
      (plan.warpWidth, plan.warpHeight),
      flags: cv.INTER_LINEAR,
      // Corners exactly on the image edge sample just outside it; repeat the
      // edge pixels there instead of blending in black.
      borderMode: cv.BORDER_REPLICATE,
    );
    final rotateCode = switch (plan.quarterTurns) {
      0 => null,
      1 => cv.ROTATE_90_CLOCKWISE,
      2 => cv.ROTATE_180,
      3 => cv.ROTATE_90_COUNTERCLOCKWISE,
      _ => throw ArgumentError.value(plan.quarterTurns, 'quarterTurns'),
    };
    if (rotateCode == null) return warped;
    final rotated = cv.rotate(warped, rotateCode);
    warped.dispose();
    return rotated;
  } finally {
    homography.dispose();
    src.dispose();
    dst.dispose();
  }
}

/// Wraps 8-bit RGBA pixels (as Flutter's decoder produces) as a BGR Mat.
cv.Mat bgrFromRgba(Uint8List rgba, int width, int height) {
  if (rgba.length != width * height * 4) {
    throw ArgumentError('Expected ${width * height * 4} bytes of RGBA');
  }
  final rgbaMat = cv.Mat.zeros(height, width, cv.MatType.CV_8UC4);
  try {
    rgbaMat.data.setAll(0, rgba);
    return cv.cvtColor(rgbaMat, cv.COLOR_RGBA2BGR);
  } finally {
    rgbaMat.dispose();
  }
}

/// Full isolate job: RGBA pixels at the plan's decode size → JPEG bytes.
Uint8List renderJpeg(Uint8List rgba, RenderPlan plan) {
  final source = bgrFromRgba(rgba, plan.decodeWidth, plan.decodeHeight);
  final cv.Mat out;
  try {
    out = warpForPlan(source, plan);
  } finally {
    source.dispose();
  }
  try {
    final params = cv.VecI32.fromList([
      cv.IMWRITE_JPEG_QUALITY,
      renderJpegQuality,
    ]);
    final (ok, bytes) = cv.imencode('.jpg', out, params: params);
    params.dispose();
    if (!ok) throw StateError('JPEG encoding failed');
    return bytes;
  } finally {
    out.dispose();
  }
}
