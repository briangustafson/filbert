import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/imaging/render_geometry.dart';
import '../../photos/domain/project_image.dart';
import '../../projects/data/project_providers.dart';
import '../../projects/domain/project.dart';
import '../domain/grid_layout.dart';
import '../domain/view_prefs.dart';
import 'aid_toolbar.dart';

/// The Grid panel (m2-design §3.2): Divisions or Spacing (Spacing only for
/// a project with a physical size), diagonals, color, width; then the rows
/// and columns, or the spacing in the project's unit.
class GridPanel extends ConsumerWidget {
  const GridPanel({
    super.key,
    required this.image,
    required this.grid,
    required this.onChanged,
  });

  /// The photo shown: its proportions decide the "crop for an exact grid"
  /// note.
  final ProjectImage image;
  final GridPrefs grid;
  final ValueChanged<GridPrefs> onChanged;

  /// Spacing steps: half inches, whole centimetres.
  static double spacingStep(LengthUnit unit) => switch (unit) {
    LengthUnit.inches => 0.5,
    LengthUnit.centimeters => 1,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(projectProvider(image.projectId)).value?.size;
    final canvas = size is PhysicalSize ? size : null;
    // Without a physical size, a saved spacing grid shows as divisions.
    final mode = canvas == null ? GridMode.divisions : grid.mode;

    final options = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (canvas != null) ...[
          for (final m in GridMode.values)
            _Choice(
              key: ValueKey('grid-mode-${m.name}'),
              label: m == GridMode.divisions ? 'Divisions' : 'Spacing',
              selected: mode == m,
              onTap: () => onChanged(grid.copyWith(mode: m)),
            ),
          const SizedBox(width: 6),
        ],
        _Choice(
          key: const ValueKey('grid-diagonals'),
          label: 'Diagonals',
          selected: grid.diagonals,
          onTap: () => onChanged(grid.copyWith(diagonals: !grid.diagonals)),
        ),
        const SizedBox(width: 6),
        for (final c in GridColor.values)
          _ColorDot(
            color: c,
            selected: grid.color == c,
            onTap: () => onChanged(grid.copyWith(color: c)),
          ),
        const SizedBox(width: 6),
        for (final w in GridLineWidth.values)
          _WidthChoice(
            width: w,
            selected: grid.width == w,
            onTap: () => onChanged(grid.copyWith(width: w)),
          ),
      ],
    );

    final Widget amounts;
    if (mode == GridMode.spacing && canvas != null) {
      final unit = canvas.unit;
      final step = spacingStep(unit);
      final maxSteps = math.max(
        1,
        (math.min(canvas.width, canvas.height) / step).floor(),
      );
      final current = (grid.spacingIn(unit) / step).round().clamp(1, maxSteps);
      amounts = AidStepper(
        label: 'Every',
        value: current,
        min: 1,
        max: maxSteps,
        format: (n) => '${_number(n * step)} ${unit.code}',
        valueWidth: 64,
        less: 'Smaller squares',
        more: 'Bigger squares',
        onChanged: (n) => onChanged(grid.copyWith(spacing: () => n * step)),
      );
    } else {
      amounts = Wrap(
        spacing: 8,
        children: [
          AidStepper(
            label: 'Rows',
            value: grid.rows,
            min: GridPrefs.minDivisions,
            max: GridPrefs.maxDivisions,
            onChanged: (n) => onChanged(grid.copyWith(rows: n)),
          ),
          AidStepper(
            label: 'Columns',
            value: grid.cols,
            min: GridPrefs.minDivisions,
            max: GridPrefs.maxDivisions,
            onChanged: (n) => onChanged(grid.copyWith(cols: n)),
          ),
        ],
      );
    }

    final mismatch =
        mode == GridMode.spacing &&
        canvas != null &&
        _layout(grid, canvas).aspectMismatch;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        options,
        if (mismatch)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              "Crop to the project's size for an exact grid.",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        // Last, so the steppers keep their place above the toolbar.
        amounts,
      ],
    );
  }

  GridLayout _layout(GridPrefs grid, PhysicalSize canvas) {
    final (w, h) = RenderPlan.forEdits(
      sourceWidth: image.width,
      sourceHeight: image.height,
      edits: image.edits,
      maxLongEdge: 1 << 20,
    ).outputSize;
    return GridLayout.of(
      grid,
      photoWidth: w.toDouble(),
      photoHeight: h.toDouble(),
      canvasWidth: canvas.width,
      canvasHeight: canvas.height,
      defaultSpacing: GridPrefs.defaultSpacing(canvas.unit),
    );
  }

  /// 2 → "2", 2.5 → "2.5".
  static String _number(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

/// A pill that is filled when selected, like the toolbar's buttons.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white54),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final GridColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = switch (color) {
      GridColor.white => 'White',
      GridColor.black => 'Black',
      GridColor.gray => 'Gray',
      GridColor.red => 'Red',
    };
    return Tooltip(
      message: '$name lines',
      child: Semantics(
        button: true,
        selected: selected,
        child: InkResponse(
          key: ValueKey('grid-color-${color.name}'),
          onTap: onTap,
          radius: 18,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(gridColorArgb(color)),
                border: Border.all(color: Colors.white38),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WidthChoice extends StatelessWidget {
  const _WidthChoice({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final GridLineWidth width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = switch (width) {
      GridLineWidth.thin => 'Thin',
      GridLineWidth.medium => 'Medium',
      GridLineWidth.thick => 'Thick',
    };
    return Tooltip(
      message: '$name lines',
      child: Semantics(
        button: true,
        selected: selected,
        child: InkResponse(
          key: ValueKey('grid-width-${width.name}'),
          onTap: onTap,
          radius: 18,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            // A line sample, exaggerated so the three read apart at a
            // glance (the lines themselves are 1–3 dp).
            child: Container(
              width: 18,
              height: gridLineDp(width) * 2,
              color: selected ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
