import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/imaging/tone.dart';
import '../../photos/domain/project_image.dart';
import '../data/view_aids_providers.dart';
import '../data/view_prefs_repository.dart';
import '../domain/view_aids.dart';
import '../domain/view_prefs.dart';
import 'compare_panel.dart';
import 'grid_panel.dart';

/// The photo screen's bottom bar: Grid · Gray · Values · Colors · Compare
/// (m2-design §3.1). Each button shows whether its aid is on.
class AidToolbar extends StatelessWidget {
  const AidToolbar({
    super.key,
    required this.aids,
    required this.showCompare,
    required this.onTap,
  });

  final ViewAids aids;

  /// Compare needs another photo in the project (§3.4).
  final bool showCompare;
  final ValueChanged<Aid> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final aid in Aid.values)
          if (aid != Aid.compare || showCompare)
            Expanded(
              child: _AidButton(
                key: ValueKey('aid-${aid.name}'),
                aid: aid,
                on: aids.isOn(aid),
                onTap: () => onTap(aid),
              ),
            ),
      ],
    );
  }
}

class _AidButton extends StatelessWidget {
  const _AidButton({
    super.key,
    required this.aid,
    required this.on,
    required this.onTap,
  });

  final Aid aid;
  final bool on;
  final VoidCallback onTap;

  static String labelOf(Aid aid) => switch (aid) {
    Aid.grid => 'Grid',
    Aid.gray => 'Gray',
    Aid.valueBands => 'Values',
    Aid.colors => 'Colors',
    Aid.compare => 'Compare',
  };

  static IconData iconOf(Aid aid) => switch (aid) {
    Aid.grid => Icons.grid_on,
    Aid.gray => Icons.filter_b_and_w,
    Aid.valueBands => Icons.gradient,
    Aid.colors => Icons.palette_outlined,
    Aid.compare => Icons.compare,
  };

  @override
  Widget build(BuildContext context) {
    final color = on ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      toggled: on,
      label: labelOf(aid),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: on ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(iconOf(aid), color: color, size: 22),
              ),
              const SizedBox(height: 2),
              Text(
                labelOf(aid),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The open aid's settings, above the toolbar (m2-design §3.2). Compact, so
/// most of the photo stays visible; wraps on narrow phones.
class AidPanel extends ConsumerWidget {
  const AidPanel({
    super.key,
    required this.projectId,
    required this.image,
    required this.panel,
  });

  final String projectId;

  /// The photo shown; the Colors panel shows its palette.
  final ProjectImage image;
  final Aid panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(viewPrefsProvider(projectId)).value;
    void update(ViewPrefs next) =>
        ref.read(viewPrefsRepositoryProvider).update(projectId, next);

    final Widget content = prefs == null
        ? const SizedBox(height: 48)
        : switch (panel) {
            Aid.valueBands => _ValuesPanel(
              bands: prefs.values.bands,
              onChanged: (bands) =>
                  update(prefs.copyWith(values: ValuesPrefs(bands: bands))),
            ),
            Aid.colors => _ColorsPanel(
              image: image,
              count: prefs.colors.count,
              onChanged: (count) =>
                  update(prefs.copyWith(colors: ColorsPrefs(count: count))),
            ),
            Aid.grid => GridPanel(
              image: image,
              grid: prefs.grid,
              onChanged: (grid) => update(prefs.copyWith(grid: grid)),
            ),
            Aid.compare => ComparePanel(
              image: image,
              compare: prefs.compare,
              onChanged: (compare) => update(prefs.copyWith(compare: compare)),
            ),
            Aid.gray => const SizedBox(height: 8),
          };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: content,
        ),
      ),
    );
  }
}

class _ValuesPanel extends StatelessWidget {
  const _ValuesPanel({required this.bands, required this.onChanged});

  final int bands;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepperRow(
      stepper: AidStepper(
        label: 'Bands',
        value: bands,
        min: ValuesPrefs.minBands,
        max: ValuesPrefs.maxBands,
        onChanged: onChanged,
      ),
      trailing: _Swatches(
        key: const ValueKey('band-swatches'),
        colors: [
          for (var k = 0; k < bands; k++)
            switch ((bandGray(k, bands) * 255).round()) {
              final g => Color.fromARGB(255, g, g, g),
            },
        ],
      ),
    );
  }
}

class _ColorsPanel extends ConsumerWidget {
  const _ColorsPanel({
    required this.image,
    required this.count,
    required this.onChanged,
  });

  final ProjectImage image;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(photoPaletteProvider(image, count));
    return _StepperRow(
      stepper: AidStepper(
        label: 'Colors',
        value: count,
        min: ColorsPrefs.minCount,
        max: ColorsPrefs.maxCount,
        onChanged: onChanged,
      ),
      trailing: switch (palette) {
        AsyncData(:final value) => _Swatches(
          key: const ValueKey('palette-swatches'),
          colors: [
            for (final (r, g, b) in value.srgb8) Color.fromARGB(255, r, g, b),
          ],
        ),
        AsyncError() => const Text("Couldn't make the palette."),
        _ => const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
            semanticsLabel: 'Making the palette',
          ),
        ),
      },
    );
  }
}

/// A stepper with something beside it (swatches). The stepper keeps its
/// place at the bottom left whatever [trailing] does, so repeated taps on
/// its buttons land on them even as the swatches wrap onto more lines.
class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.stepper, required this.trailing});

  final Widget stepper;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        stepper,
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            // Lines the last row of swatches up with the stepper's middle.
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(alignment: Alignment.bottomLeft, child: trailing),
          ),
        ),
      ],
    );
  }
}

/// A row of color chips, dark to light, wrapping when there's no room.
class _Swatches extends StatelessWidget {
  const _Swatches({super.key, required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final c in colors)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white24),
              ),
            ),
        ],
      ),
    );
  }
}

/// − value + for a whole number between [min] and [max]. [format] shows
/// the value differently (a step count as a length, say); [less] and
/// [more] name the buttons for TalkBack and tests.
class AidStepper extends StatelessWidget {
  const AidStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.format,
    this.valueWidth = 24,
    this.less,
    this.more,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String Function(int value)? format;
  final double valueWidth;
  final String? less;
  final String? more;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        IconButton(
          tooltip: less ?? 'Fewer ${label.toLowerCase()}',
          icon: const Icon(Icons.remove),
          color: Colors.white,
          disabledColor: Colors.white38,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Semantics(
          label: label,
          value: format?.call(value) ?? '$value',
          excludeSemantics: true,
          child: SizedBox(
            width: valueWidth,
            child: Text(
              format?.call(value) ?? '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          tooltip: more ?? 'More ${label.toLowerCase()}',
          icon: const Icon(Icons.add),
          color: Colors.white,
          disabledColor: Colors.white38,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
