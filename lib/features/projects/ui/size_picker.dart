import 'package:material_ui/material_ui.dart';

import '../domain/project.dart';
import '../domain/size_presets.dart';

/// Opens the size picker (m1-design §3.4). Presets and None save and close in
/// one tap; Custom saves on **Save**; the orientation toggle re-saves the
/// current size right away. Closing the sheet otherwise changes nothing.
Future<void> showSizePicker(
  BuildContext context, {
  required ProjectSize initial,
  required LengthUnit defaultUnit,
  required ValueChanged<ProjectSize> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SizePickerSheet(
      initial: initial,
      defaultUnit: defaultUnit,
      onChanged: onChanged,
    ),
  );
}

enum SizeMode { physical, ratio, none }

class SizePickerSheet extends StatefulWidget {
  const SizePickerSheet({
    super.key,
    required this.initial,
    required this.defaultUnit,
    required this.onChanged,
  });

  final ProjectSize initial;
  final LengthUnit defaultUnit;
  final ValueChanged<ProjectSize> onChanged;

  @override
  State<SizePickerSheet> createState() => _SizePickerSheetState();
}

class _SizePickerSheetState extends State<SizePickerSheet> {
  late ProjectSize _current = widget.initial;
  late SizeMode _mode = switch (widget.initial) {
    NoSize() => SizeMode.none,
    RatioSize() => SizeMode.ratio,
    PhysicalSize() => SizeMode.physical,
  };
  late LengthUnit _unit = switch (widget.initial) {
    PhysicalSize(:final unit) => unit,
    _ => widget.defaultUnit,
  };
  late CanvasOrientation _orientation = switch (dimsOf(widget.initial)) {
    (final w, final h)
        when orientationOf(w, h) == CanvasOrientation.landscape =>
      CanvasOrientation.landscape,
    _ => CanvasOrientation.portrait,
  };
  final _widthText = TextEditingController();
  final _heightText = TextEditingController();
  var _custom = false;

  @override
  void initState() {
    super.initState();
    _resetCustom();
    _widthText.addListener(_rebuild);
    _heightText.addListener(_rebuild);
  }

  @override
  void dispose() {
    _widthText.dispose();
    _heightText.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// The saved size, if it belongs to the visible mode (and unit).
  (double, double)? get _currentDimsInMode => switch ((_mode, _current)) {
    (SizeMode.ratio, RatioSize(:final w, :final h)) => (w, h),
    (SizeMode.physical, PhysicalSize(:final width, :final height, :final unit))
        when unit == _unit =>
      (width, height),
    _ => null,
  };

  List<(double, double)> get _presets => switch (_mode) {
    SizeMode.physical => sizePresetsFor(_unit),
    SizeMode.ratio => ratioPresets,
    SizeMode.none => const [],
  };

  /// Opens Custom (pre-filled) when the saved size isn't one of the presets.
  void _resetCustom() {
    final dims = _currentDimsInMode;
    _custom = dims != null && !_presets.any((p) => sameDims(p, dims));
    _widthText.text = dims == null || !_custom ? '' : formatDimension(dims.$1);
    _heightText.text = dims == null || !_custom ? '' : formatDimension(dims.$2);
  }

  ProjectSize _make((double, double) dims) => switch (_mode) {
    SizeMode.physical => PhysicalSize(dims.$1, dims.$2, _unit),
    SizeMode.ratio => RatioSize(dims.$1, dims.$2),
    SizeMode.none => const NoSize(),
  };

  void _saveAndClose(ProjectSize size) {
    if (size != _current) widget.onChanged(size);
    Navigator.pop(context);
  }

  void _setMode(SizeMode mode) {
    if (mode == SizeMode.none) {
      if (_current is! NoSize) _saveAndClose(const NoSize());
      return;
    }
    setState(() {
      _mode = mode;
      _resetCustom();
    });
  }

  void _setUnit(LengthUnit unit) => setState(() {
    _unit = unit;
    _resetCustom();
  });

  void _setOrientation(CanvasOrientation orientation) {
    setState(() {
      _orientation = orientation;
      final w = _widthText.text, h = _heightText.text;
      final wv = parseDimension(w), hv = parseDimension(h);
      if (wv != null && hv != null) {
        final (a, b) = orient((wv, hv), orientation);
        _widthText.text = formatDimension(a);
        _heightText.text = formatDimension(b);
      }
    });
    final dims = _currentDimsInMode;
    if (dims == null || orientationOf(dims.$1, dims.$2) == orientation) return;
    if (orientationOf(dims.$1, dims.$2) == CanvasOrientation.square) return;
    final turned = withOrientation(_current, orientation);
    widget.onChanged(turned);
    setState(() => _current = turned);
  }

  String _dimsLabel((double, double) dims) {
    final (a, b) = orient(dims, _orientation);
    return _mode == SizeMode.ratio
        ? '${formatDimension(a)}:${formatDimension(b)}'
        : '${formatDimension(a)} × ${formatDimension(b)}';
  }

  String? _errorFor(TextEditingController c) =>
      c.text.trim().isEmpty || parseDimension(c.text) != null
      ? null
      : 'Enter ${formatDimension(minDimension)}–${formatDimension(maxDimension)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentDims = _currentDimsInMode;
    final customW = parseDimension(_widthText.text);
    final customH = parseDimension(_heightText.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Canvas size', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<SizeMode>(
              segments: const [
                ButtonSegment(value: SizeMode.physical, label: Text('Size')),
                ButtonSegment(
                  value: SizeMode.ratio,
                  label: Text('Aspect ratio'),
                ),
                ButtonSegment(value: SizeMode.none, label: Text('None')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _setMode(s.single),
            ),
            if (_mode == SizeMode.none) ...[
              const SizedBox(height: 24),
              Text(
                'No size set. Choose Size or Aspect ratio to crop photos to '
                'your canvas shape.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SegmentedButton<CanvasOrientation>(
                    segments: const [
                      ButtonSegment(
                        value: CanvasOrientation.portrait,
                        icon: Icon(Icons.crop_portrait),
                        label: Text('Portrait'),
                      ),
                      ButtonSegment(
                        value: CanvasOrientation.landscape,
                        icon: Icon(Icons.crop_landscape),
                        label: Text('Landscape'),
                      ),
                    ],
                    selected: {_orientation},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => _setOrientation(s.single),
                  ),
                  if (_mode == SizeMode.physical)
                    SegmentedButton<LengthUnit>(
                      segments: const [
                        ButtonSegment(
                          value: LengthUnit.inches,
                          label: Text('in'),
                        ),
                        ButtonSegment(
                          value: LengthUnit.centimeters,
                          label: Text('cm'),
                        ),
                      ],
                      selected: {_unit},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => _setUnit(s.single),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _presets)
                    ChoiceChip(
                      label: Text(_dimsLabel(preset)),
                      selected:
                          !_custom &&
                          currentDims != null &&
                          sameDims(preset, currentDims),
                      onSelected: (_) =>
                          _saveAndClose(_make(orient(preset, _orientation))),
                    ),
                  ChoiceChip(
                    label: const Text('Custom'),
                    selected: _custom,
                    onSelected: (_) => setState(() => _custom = true),
                  ),
                ],
              ),
              if (_custom) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('custom-width'),
                        controller: _widthText,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Width',
                          errorText: _errorFor(_widthText),
                          suffixText: _mode == SizeMode.physical
                              ? _unit.code
                              : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                      child: Text(_mode == SizeMode.ratio ? ':' : '×'),
                    ),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('custom-height'),
                        controller: _heightText,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Height',
                          errorText: _errorFor(_heightText),
                          suffixText: _mode == SizeMode.physical
                              ? _unit.code
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(
                    onPressed: customW == null || customH == null
                        ? null
                        : () => _saveAndClose(_make((customW, customH))),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
