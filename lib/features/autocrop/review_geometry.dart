import '../../core/imaging/edits.dart';

/// Corners on the auto-crop review screen (m1-design §3.8).
///
/// The screen shows the original turned by the image's `quarterTurns`, so
/// the user drags corners on the photo as they see it. Corners here are
/// normalized (0–1) in that **displayed** photo, ordered top-left,
/// top-right, bottom-right, bottom-left as displayed. Stored quads are in
/// the unturned original, ordered as the warp sees them (the turn is applied
/// to its output).
typedef ReviewCorner = ({double x, double y});

/// The whole photo, as displayed.
const List<ReviewCorner> fullImageCorners = [
  (x: 0, y: 0),
  (x: 1, y: 0),
  (x: 1, y: 1),
  (x: 0, y: 1),
];

/// A point of the original as displayed after [turns] clockwise turns.
ReviewCorner originalToDisplayed(NormPoint p, int turns) {
  var x = p.x, y = p.y;
  for (var i = 0; i < turns; i++) {
    (x, y) = (1 - y, x);
  }
  return (x: x, y: y);
}

/// A displayed point back in the original.
NormPoint displayedToOriginal(ReviewCorner p, int turns) {
  var x = p.x, y = p.y;
  for (var i = 0; i < turns; i++) {
    (x, y) = (y, 1 - x);
  }
  return NormPoint(x, y);
}

/// Displayed corners of a stored [quad]. After a clockwise turn, the warp's
/// top-left corner shows as the top-right one, and so on round.
List<ReviewCorner> quadToDisplayed(List<NormPoint> quad, int turns) {
  final displayed = List<ReviewCorner>.filled(4, (x: 0, y: 0));
  for (var i = 0; i < 4; i++) {
    displayed[(i + turns) % 4] = originalToDisplayed(quad[i], turns);
  }
  return displayed;
}

/// The stored quad for displayed [corners].
List<NormPoint> displayedToQuad(List<ReviewCorner> corners, int turns) => [
  for (var i = 0; i < 4; i++)
    displayedToOriginal(corners[(i + turns) % 4], turns),
];

/// The edits the review's Apply saves. Corners on the photo's own corners
/// mean no crop; [aspect] (width/height as displayed, from the project)
/// fixes the output ratio.
Edits reviewEdits(
  List<ReviewCorner> corners, {
  required int quarterTurns,
  ({double w, double h})? aspect,
}) {
  if (_isFullImage(corners)) return Edits(quarterTurns: quarterTurns);
  final output = aspect == null
      ? null
      : (quarterTurns.isOdd
            ? OutputAspect(aspect.h, aspect.w)
            : OutputAspect(aspect.w, aspect.h));
  return Edits(
    crop: CropEdit(
      quad: displayedToQuad(corners, quarterTurns),
      output: output,
    ),
    quarterTurns: quarterTurns,
  );
}

bool _isFullImage(List<ReviewCorner> corners) {
  for (var i = 0; i < 4; i++) {
    if ((corners[i].x - fullImageCorners[i].x).abs() > 1e-6 ||
        (corners[i].y - fullImageCorners[i].y).abs() > 1e-6) {
      return false;
    }
  }
  return true;
}

/// Whether [corners] form a quad the edits accept: inside the photo,
/// ordered clockwise, convex, not degenerate. Drags that would break this
/// are refused.
bool isValidReviewQuad(List<ReviewCorner> corners) {
  for (final c in corners) {
    if (c.x < 0 || c.x > 1 || c.y < 0 || c.y > 1) return false;
  }
  try {
    CropEdit(quad: [for (final c in corners) NormPoint(c.x, c.y)]).validate();
    return true;
  } on ArgumentError {
    return false;
  }
}

/// Corners [inset] from the photo's edges: the starting point when
/// detection is unsure.
List<ReviewCorner> insetCorners(double inset) => [
  (x: inset, y: inset),
  (x: 1 - inset, y: inset),
  (x: 1 - inset, y: 1 - inset),
  (x: inset, y: 1 - inset),
];
