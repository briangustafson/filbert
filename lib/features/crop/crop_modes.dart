import 'dart:math' as math;

import '../../core/imaging/crop_geometry.dart';
import '../../core/imaging/edits.dart';
import '../autocrop/review_geometry.dart';

/// The crop screen's two ways of cropping (m1-design §3.7).
enum CropMode {
  /// An upright rectangle with straighten and ratio locks.
  rectangle,

  /// Four corners moved freely; Apply corrects the perspective.
  corners,
}

/// Corners mode's starting point from [edits]: the crop's corners as
/// displayed (turned by [Edits.quarterTurns]), or the whole photo.
List<ReviewCorner> cornersFromEdits(Edits edits) {
  final crop = edits.crop;
  return crop == null
      ? fullImageCorners
      : quadToDisplayed(crop.quad, edits.quarterTurns);
}

/// Rectangle mode's starting point from corners: the smallest upright
/// rectangle containing [corners] (displayed, turned by [quarterTurns]),
/// grown to [aspect] if locked, then fitted inside the photo.
CropState rectangleAround(
  List<ReviewCorner> corners, {
  required int quarterTurns,
  required int sourceWidth,
  required int sourceHeight,
  required CropAspect? aspect,
}) {
  final frame = CropFrame(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    quarterTurns: quarterTurns,
  );
  final w = frame.displayWidth, h = frame.displayHeight;
  // Display space is centred on the photo's centre, in pixels.
  double x(double nx) => (nx - 0.5) * w;
  double y(double ny) => (ny - 0.5) * h;
  var rect = CropRect(
    x(corners.map((c) => c.x).reduce(math.min)),
    y(corners.map((c) => c.y).reduce(math.min)),
    x(corners.map((c) => c.x).reduce(math.max)),
    y(corners.map((c) => c.y).reduce(math.max)),
  );
  if (aspect != null) {
    final c = rect.center;
    rect = rect.width / rect.height < aspect.ratio
        ? CropRect.centered(c.x, c.y, rect.height * aspect.ratio, rect.height)
        : CropRect.centered(c.x, c.y, rect.width, rect.width / aspect.ratio);
  }
  return CropState(frame: frame, rect: frame.fit(rect), aspect: aspect);
}

/// [corners] (displayed) after turning the photo a quarter turn clockwise:
/// each point turns with it, and the top-left corner is now the one that
/// was bottom-left.
List<ReviewCorner> turnCornersClockwise(List<ReviewCorner> corners) {
  final turned = List<ReviewCorner>.filled(4, (x: 0, y: 0));
  for (var i = 0; i < 4; i++) {
    final c = corners[i];
    turned[(i + 1) % 4] = (x: 1 - c.y, y: c.x);
  }
  return turned;
}
