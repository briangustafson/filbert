import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:material_ui/material_ui.dart';

import '../autocrop/review_geometry.dart';

/// The photo (turned as displayed) with the four corners over it. Dragging
/// a corner shows a magnifier loupe above the finger; drags that would make
/// an invalid quad are refused.
class CornersCanvas extends StatefulWidget {
  const CornersCanvas({
    super.key,
    required this.photo,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.quarterTurns,
    required this.corners,
    required this.onChanged,
  });

  final File photo;
  final int sourceWidth;
  final int sourceHeight;
  final int quarterTurns;
  final List<ReviewCorner> corners;
  final ValueChanged<List<ReviewCorner>> onChanged;

  static const margin = 32.0;
  static const reach = 48.0;
  static const loupeSize = 120.0;
  static const loupeLift = 110.0;

  @override
  State<CornersCanvas> createState() => _CornersCanvasState();
}

class _CornersCanvasState extends State<CornersCanvas> {
  int? _active;
  ReviewCorner? _startCorner;
  Offset _startPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final turned = widget.quarterTurns.isOdd;
    final w = (turned ? widget.sourceHeight : widget.sourceWidth).toDouble();
    final h = (turned ? widget.sourceWidth : widget.sourceHeight).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        const m = CornersCanvas.margin;
        final k = math.min(
          (constraints.maxWidth - 2 * m) / w,
          (constraints.maxHeight - 2 * m) / h,
        );
        final frame = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero),
          width: w * k,
          height: h * k,
        );
        Offset toScreen(ReviewCorner c) =>
            frame.topLeft + Offset(c.x * frame.width, c.y * frame.height);
        final points = [for (final c in widget.corners) toScreen(c)];

        final active = _active;
        Widget? loupe;
        if (active != null) {
          final p = points[active];
          const s = CornersCanvas.loupeSize, lift = CornersCanvas.loupeLift;
          // Above the finger, or below it near the top.
          final above = p.dy - lift - s / 2 >= 0;
          // Kept on screen sideways; it still magnifies the corner.
          final center = Offset(
            p.dx.clamp(s / 2, constraints.maxWidth - s / 2),
            p.dy + (above ? -lift : lift),
          );
          loupe = Positioned(
            left: center.dx - s / 2,
            top: center.dy - s / 2,
            child: RawMagnifier(
              size: const Size(s, s),
              magnificationScale: 2.5,
              focalPointOffset: p - center,
              decoration: const MagnifierDecoration(
                shape: CircleBorder(
                  side: BorderSide(color: Colors.white, width: 2),
                ),
              ),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) {
            final i = _nearest(points, d.localPosition);
            if (i == null) return;
            setState(() {
              _active = i;
              _startCorner = widget.corners[i];
              _startPosition = d.localPosition;
            });
          },
          onPanUpdate: (d) {
            final i = _active, start = _startCorner;
            if (i == null || start == null) return;
            final delta = d.localPosition - _startPosition;
            final moved = (
              x: (start.x + delta.dx / frame.width).clamp(0.0, 1.0),
              y: (start.y + delta.dy / frame.height).clamp(0.0, 1.0),
            );
            final next = [...widget.corners]..[i] = moved;
            if (isValidReviewQuad(next)) widget.onChanged(next);
          },
          onPanEnd: (_) => setState(() => _active = null),
          onPanCancel: () => setState(() => _active = null),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: frame,
                child: RotatedBox(
                  quarterTurns: widget.quarterTurns,
                  child: Image.file(
                    widget.photo,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              CustomPaint(
                painter: CornersOverlayPainter(
                  corners: points,
                  active: _active,
                ),
              ),
              ?loupe,
            ],
          ),
        );
      },
    );
  }

  static int? _nearest(List<Offset> points, Offset p) {
    int? best;
    var bestDistance = CornersCanvas.reach;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i] - p).distance;
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }
}

/// The quad outline with the outside dimmed, and round corner handles.
class CornersOverlayPainter extends CustomPainter {
  const CornersOverlayPainter({required this.corners, this.active});

  /// Corners in screen coordinates (exposed for tests).
  final List<Offset> corners;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final quad = Path()..addPolygon(corners, true);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        quad,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      quad,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < corners.length; i++) {
      final r = i == active ? 16.0 : 12.0;
      canvas
        ..drawCircle(
          corners[i],
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        )
        ..drawCircle(
          corners[i],
          r,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
    }
  }

  @override
  bool shouldRepaint(CornersOverlayPainter old) =>
      !listEquals(old.corners, corners) || old.active != active;
}
