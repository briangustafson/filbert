import 'package:material_ui/material_ui.dart';

/// Draws the crop rectangle over the photo: the area outside dimmed, a rule
/// of thirds grid, and handles at the corners and edge midpoints.
class CropOverlayPainter extends CustomPainter {
  const CropOverlayPainter({required this.crop, required this.frame});

  /// The crop, in screen coordinates (exposed for tests).
  final Rect crop;

  /// The photo's frame on screen.
  final Rect frame;

  static const handleLength = 22.0;
  static const handleThickness = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(crop),
      ),
      dim,
    );

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas
        ..drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid)
        ..drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }

    canvas.drawRect(
      crop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final handle = Paint()
      ..color = Colors.white
      ..strokeWidth = handleThickness
      ..strokeCap = StrokeCap.square;
    const l = handleLength;
    for (final (corner, sx, sy) in [
      (crop.topLeft, 1.0, 1.0),
      (crop.topRight, -1.0, 1.0),
      (crop.bottomRight, -1.0, -1.0),
      (crop.bottomLeft, 1.0, -1.0),
    ]) {
      canvas
        ..drawLine(corner, corner + Offset(l * sx, 0), handle)
        ..drawLine(corner, corner + Offset(0, l * sy), handle);
    }
    for (final (mid, horizontal) in [
      (crop.topCenter, true),
      (crop.bottomCenter, true),
      (crop.centerLeft, false),
      (crop.centerRight, false),
    ]) {
      final half = horizontal ? const Offset(l / 2, 0) : const Offset(0, l / 2);
      canvas.drawLine(mid - half, mid + half, handle);
    }
  }

  @override
  bool shouldRepaint(CropOverlayPainter old) =>
      old.crop != crop || old.frame != frame;
}
