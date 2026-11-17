import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A rectangle outline drawn at [width]:[height], so a size like "9 × 12"
/// shows which way it stands (m1-design §3.4). Decorative: the size's text
/// says the same.
class ProportionShape extends StatelessWidget {
  const ProportionShape({
    super.key,
    required this.width,
    required this.height,
    this.size = 18,
    this.color,
  });

  final double width;
  final double height;

  /// The longer side, in logical pixels.
  final double size;

  /// Defaults to the current icon color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final longer = math.max(width, height);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Container(
            width: size * width / longer,
            height: size * height / longer,
            decoration: BoxDecoration(
              border: Border.all(
                color: color ?? IconTheme.of(context).color ?? Colors.black,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
