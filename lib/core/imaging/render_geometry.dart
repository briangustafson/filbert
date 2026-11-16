import 'dart:math' as math;

import 'edits.dart';

/// Sizes and corner positions for one render (m1-design §4.2, §5.1).
///
/// Pure arithmetic, so it is unit-tested without OpenCV or a decoder.
class RenderPlan {
  const RenderPlan({
    required this.decodeWidth,
    required this.decodeHeight,
    required this.warpWidth,
    required this.warpHeight,
    required this.quarterTurns,
    required this.quad,
  });

  /// Plans rendering an original of [sourceWidth] × [sourceHeight] (after
  /// EXIF orientation) with [edits], so the output's long edge is at most
  /// [maxLongEdge]. Never upscales past the original's resolution.
  ///
  /// The original is decoded at the scale the output needs (so the warp
  /// works at roughly 1:1), but never above [maxDecodeLongEdge], which bounds
  /// memory when a small crop of a large photo is viewed.
  factory RenderPlan.forEdits({
    required int sourceWidth,
    required int sourceHeight,
    required Edits edits,
    required int maxLongEdge,
    int maxDecodeLongEdge = defaultMaxDecodeLongEdge,
  }) {
    if (sourceWidth < 1 || sourceHeight < 1) {
      throw ArgumentError('Source size must be positive');
    }
    if (maxLongEdge < 1 || maxDecodeLongEdge < 1) {
      throw ArgumentError('Size limits must be positive');
    }
    final quad = edits.crop?.quad ?? fullQuad;
    final (w, h) = naturalOutputSize(
      sourceWidth,
      sourceHeight,
      quad,
      edits.crop?.output,
    );

    // Output scale relative to the original; ≤ 1 (no upscaling).
    final scale = math.min(1.0, maxLongEdge / math.max(w, h));
    final sourceLong = math.max(sourceWidth, sourceHeight);
    final decodeScale = math.min(scale, maxDecodeLongEdge / sourceLong);

    return RenderPlan(
      decodeWidth: _atLeastOne(sourceWidth * decodeScale),
      decodeHeight: _atLeastOne(sourceHeight * decodeScale),
      warpWidth: _atLeastOne(w * scale),
      warpHeight: _atLeastOne(h * scale),
      quarterTurns: edits.quarterTurns,
      quad: quad,
    );
  }

  static const defaultMaxDecodeLongEdge = 4096;

  /// The whole image, as a quad.
  static const fullQuad = [
    NormPoint(0, 0),
    NormPoint(1, 0),
    NormPoint(1, 1),
    NormPoint(0, 1),
  ];

  /// Size to decode the original at (EXIF-oriented).
  final int decodeWidth;
  final int decodeHeight;

  /// Size of the warped image, before quarter turns.
  final int warpWidth;
  final int warpHeight;

  final int quarterTurns;

  /// Normalized corners in the original, TL, TR, BR, BL.
  final List<NormPoint> quad;

  /// Size of the final output, after quarter turns.
  (int, int) get outputSize =>
      quarterTurns.isOdd ? (warpHeight, warpWidth) : (warpWidth, warpHeight);

  /// Source corners in decoded-pixel coordinates, for the homography.
  ///
  /// Normalized 0 and 1 are the image's outer edges, while OpenCV puts pixel
  /// centres at integer coordinates, so edges sit at −0.5 and size − 0.5.
  List<(double, double)> get sourceCorners => [
    for (final p in quad) (p.x * decodeWidth - 0.5, p.y * decodeHeight - 0.5),
  ];

  /// Destination corners: the warp rectangle, in the same convention.
  List<(double, double)> get destinationCorners => [
    (-0.5, -0.5),
    (warpWidth - 0.5, -0.5),
    (warpWidth - 0.5, warpHeight - 0.5),
    (-0.5, warpHeight - 0.5),
  ];

  @override
  String toString() =>
      'RenderPlan(decode ${decodeWidth}x$decodeHeight, '
      'warp ${warpWidth}x$warpHeight, turns $quarterTurns)';
}

/// Output size at the original's resolution, before quarter turns
/// (m1-design §6.3).
///
/// Without [output], the size is estimated from the quad: the average of
/// opposite edge lengths. With [output], the same area is kept at that
/// aspect ratio.
(double, double) naturalOutputSize(
  int sourceWidth,
  int sourceHeight,
  List<NormPoint> quad,
  OutputAspect? output,
) {
  double dist(NormPoint a, NormPoint b) {
    final dx = (a.x - b.x) * sourceWidth, dy = (a.y - b.y) * sourceHeight;
    return math.sqrt(dx * dx + dy * dy);
  }

  final [tl, tr, br, bl] = quad;
  final w = (dist(tl, tr) + dist(bl, br)) / 2;
  final h = (dist(tl, bl) + dist(tr, br)) / 2;
  if (output == null) return (w, h);
  final aspect = output.aspectW / output.aspectH;
  final area = w * h;
  return (math.sqrt(area * aspect), math.sqrt(area / aspect));
}

int _atLeastOne(double v) => math.max(1, v.round());
