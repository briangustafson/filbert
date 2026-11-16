import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/imaging/crop_geometry.dart';
import '../../core/imaging/edits.dart';

/// What a drag on the crop screen moves.
enum CropHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  move;

  bool get isCorner =>
      this == topLeft ||
      this == topRight ||
      this == bottomRight ||
      this == bottomLeft;
}

/// State and rules of the manual crop screen (m1-design §3.7), kept apart
/// from the widgets: the crop rectangle, aspect lock, straighten angle and
/// quarter turns, all in display-space pixels of the original photo.
class CropEditor extends ChangeNotifier {
  CropEditor({
    required CropState initial,
    required this.defaultAspect,
    required this.resetFrame,
  }) : _frame = initial.frame,
       _rect = initial.rect,
       _aspect = initial.aspect;

  /// Starts on a photo that has no crop (or one manual crop can't express):
  /// the largest crop of [defaultAspect] (the project's ratio, if any).
  factory CropEditor.fresh({
    required CropFrame frame,
    required CropAspect? defaultAspect,
  }) => CropEditor(
    initial: CropState(
      frame: frame,
      rect: frame.largest(defaultAspect),
      aspect: defaultAspect,
    ),
    defaultAspect: defaultAspect,
    resetFrame: frame.copyWith(angle: 0, quarterTurns: 0),
  );

  /// Opens [edits] for editing, or null if they hold a crop manual crop can't
  /// express (a perspective crop).
  static CropEditor? forEdits(
    Edits edits, {
    required int sourceWidth,
    required int sourceHeight,
    required CropAspect? defaultAspect,
  }) {
    final state = CropFrame.fromEdits(
      edits,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    if (state == null) return null;
    final reset = CropFrame(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    // No crop yet: propose the default ratio straight away. The project's
    // ratio describes the painting as seen, so it applies to the displayed
    // (turned) photo as is.
    if (edits.crop == null) {
      return CropEditor(
        initial: CropState(
          frame: state.frame,
          rect: state.frame.largest(defaultAspect),
          aspect: defaultAspect,
        ),
        defaultAspect: defaultAspect,
        resetFrame: reset,
      );
    }
    return CropEditor(
      initial: state,
      defaultAspect: defaultAspect,
      resetFrame: reset,
    );
  }

  /// The project's ratio as the painting is seen (portrait or landscape),
  /// if the project has a size or ratio.
  final CropAspect? defaultAspect;

  /// The frame Reset returns to: unstraightened, unturned.
  final CropFrame resetFrame;

  CropFrame _frame;
  CropRect _rect;
  CropAspect? _aspect;

  CropFrame get frame => _frame;
  CropRect get rect => _rect;

  /// The locked ratio as displayed; null for freeform.
  CropAspect? get aspect => _aspect;

  /// The edits Apply would save.
  Edits get edits => _frame.toEdits(_rect, aspect: _aspect);

  // --- Aspect lock ---

  /// Locks to [aspect] (null: freeform). Locking keeps the crop's centre and
  /// makes it as large as fits.
  void setAspect(CropAspect? aspect) {
    _aspect = aspect;
    if (aspect != null) {
      _rect = _frame.largest(aspect, center: _rect.center);
    }
    notifyListeners();
  }

  /// Portrait ↔ landscape for the locked ratio.
  void flipAspect() {
    final a = _aspect;
    if (a == null || a.isSquare) return;
    setAspect(a.flipped);
  }

  // --- Straighten and turn ---

  CropRect? _beforeStraighten;

  void startStraighten() => _beforeStraighten = _rect;

  /// Straightens to [angle] radians (clamped to ±45°). The crop shrinks
  /// about its centre to stay inside the tilted photo; within one slider
  /// gesture it grows back when the angle returns.
  void setAngle(double angle) {
    final a = angle.clamp(-CropFrame.maxAngle, CropFrame.maxAngle);
    _frame = _frame.copyWith(angle: a);
    _rect = _frame.fit(_beforeStraighten ?? _rect);
    notifyListeners();
  }

  void endStraighten() => _beforeStraighten = null;

  /// Turns the photo (and the crop with it) a quarter turn clockwise.
  void rotate90() {
    _frame = _frame.copyWith(quarterTurns: (_frame.quarterTurns + 1) % 4);
    _rect = _frame.fit(_rect.turnClockwise());
    _aspect = _aspect?.flipped;
    notifyListeners();
  }

  /// Back to the uncropped photo, with the default ratio proposed.
  void reset() {
    _frame = resetFrame;
    _aspect = defaultAspect;
    _rect = _frame.largest(defaultAspect);
    notifyListeners();
  }

  // --- Dragging ---

  CropHandle? _handle;
  CropRect? _dragStart;

  CropHandle? get activeHandle => _handle;

  void startDrag(CropHandle handle) {
    _handle = handle;
    _dragStart = _rect;
  }

  /// Applies a drag of ([dx], [dy]) display pixels since [startDrag]. The
  /// crop never gets smaller than [minSize] and stops at the photo's edges.
  void updateDrag(double dx, double dy, {required double minSize}) {
    final handle = _handle, start = _dragStart;
    if (handle == null || start == null) return;
    final candidate = handle == CropHandle.move
        ? start.translate(dx, dy)
        : (_aspect == null
              ? _resizeFree(start, handle, dx, dy, minSize)
              : _resizeLocked(start, handle, dx, dy, minSize, _aspect!.ratio));
    if (handle == CropHandle.move || _aspect == null) {
      // Horizontal and vertical parts separately, so a drag into one edge
      // still slides along it.
      final cur = _rect;
      final x = _frame.toward(
        cur,
        CropRect(candidate.left, cur.top, candidate.right, cur.bottom),
      );
      _rect = _frame.toward(
        x,
        CropRect(x.left, candidate.top, x.right, candidate.bottom),
      );
    } else {
      // Locked: width and height are tied, so one step.
      _rect = _frame.toward(_rect, candidate);
    }
    notifyListeners();
  }

  void endDrag() {
    _handle = null;
    _dragStart = null;
    notifyListeners();
  }

  static CropRect _resizeFree(
    CropRect s,
    CropHandle h,
    double dx,
    double dy,
    double min,
  ) {
    var l = s.left, t = s.top, r = s.right, b = s.bottom;
    if (h == CropHandle.left ||
        h == CropHandle.topLeft ||
        h == CropHandle.bottomLeft) {
      l = math.min(l + dx, r - min);
    }
    if (h == CropHandle.right ||
        h == CropHandle.topRight ||
        h == CropHandle.bottomRight) {
      r = math.max(r + dx, l + min);
    }
    if (h == CropHandle.top ||
        h == CropHandle.topLeft ||
        h == CropHandle.topRight) {
      t = math.min(t + dy, b - min);
    }
    if (h == CropHandle.bottom ||
        h == CropHandle.bottomLeft ||
        h == CropHandle.bottomRight) {
      b = math.max(b + dy, t + min);
    }
    return CropRect(l, t, r, b);
  }

  /// Corners: the opposite corner stays put. Edges: the opposite edge stays
  /// put and the crop grows around the dragged edge's middle.
  static CropRect _resizeLocked(
    CropRect s,
    CropHandle h,
    double dx,
    double dy,
    double min,
    double ratio,
  ) {
    // Smallest allowed size at this ratio.
    final minW = math.max(min, min * ratio);
    if (h.isCorner) {
      final right = h == CropHandle.topRight || h == CropHandle.bottomRight;
      final bottom = h == CropHandle.bottomLeft || h == CropHandle.bottomRight;
      final ax = right ? s.left : s.right;
      final ay = bottom ? s.top : s.bottom;
      final px = (right ? s.right : s.left) + dx;
      final py = (bottom ? s.bottom : s.top) + dy;
      final sx = right ? 1.0 : -1.0, sy = bottom ? 1.0 : -1.0;
      var w = math.max(sx * (px - ax), sy * (py - ay) * ratio);
      w = math.max(w, minW);
      final hgt = w / ratio;
      return CropRect(
        math.min(ax, ax + sx * w),
        math.min(ay, ay + sy * hgt),
        math.max(ax, ax + sx * w),
        math.max(ay, ay + sy * hgt),
      );
    }
    final c = s.center;
    switch (h) {
      case CropHandle.left || CropHandle.right:
        final w = math.max(
          h == CropHandle.right ? s.width + dx : s.width - dx,
          minW,
        );
        final hgt = w / ratio;
        return h == CropHandle.right
            ? CropRect(s.left, c.y - hgt / 2, s.left + w, c.y + hgt / 2)
            : CropRect(s.right - w, c.y - hgt / 2, s.right, c.y + hgt / 2);
      default:
        final hgt = math.max(
          h == CropHandle.bottom ? s.height + dy : s.height - dy,
          minW / ratio,
        );
        final w = hgt * ratio;
        return h == CropHandle.bottom
            ? CropRect(c.x - w / 2, s.top, c.x + w / 2, s.top + hgt)
            : CropRect(c.x - w / 2, s.bottom - hgt, c.x + w / 2, s.bottom);
    }
  }
}
