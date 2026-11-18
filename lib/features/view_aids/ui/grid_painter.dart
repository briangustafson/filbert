import 'package:material_ui/material_ui.dart';

import '../domain/grid_layout.dart';

/// Draws a [GridLayout] over the photo occupying [photoRect] (m2-design
/// §3.3). [photoRect] is where the photo is on screen after zooming, so the
/// painter sits outside the zoom transform and lines stay [strokeWidth]
/// logical pixels wide at any zoom. Clipped to the painted area.
class GridPainter extends CustomPainter {
  GridPainter({
    required this.layout,
    required this.photoRect,
    required this.color,
    required this.strokeWidth,
    super.repaint,
  });

  final GridLayout layout;

  /// Where the photo is, in this painter's coordinates. A function so the
  /// painter can follow zoom through [repaint] without rebuilding.
  final Rect Function() photoRect;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = photoRect();
    if (rect.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    double x(double f) => rect.left + f * rect.width;
    double y(double f) => rect.top + f * rect.height;

    for (final f in layout.innerXs) {
      canvas.drawLine(Offset(x(f), rect.top), Offset(x(f), rect.bottom), paint);
    }
    for (final f in layout.innerYs) {
      canvas.drawLine(Offset(rect.left, y(f)), Offset(rect.right, y(f)), paint);
    }
    if (layout.diagonals) {
      final path = Path();
      for (var i = 0; i + 1 < layout.xs.length; i++) {
        for (var j = 0; j + 1 < layout.ys.length; j++) {
          final l = x(layout.xs[i]), r = x(layout.xs[i + 1]);
          final t = y(layout.ys[j]), b = y(layout.ys[j + 1]);
          path
            ..moveTo(l, t)
            ..lineTo(r, b)
            ..moveTo(r, t)
            ..lineTo(l, b);
        }
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.layout != layout ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.photoRect() != photoRect();
}
