import 'project.dart';

/// Size presets and display helpers for the size picker (m1-design §3.4).
/// Presets are portrait: `(width, height)` with width ≤ height.

const imperialSizePresets = <(double, double)>[
  (8, 10),
  (9, 12),
  (11, 14),
  (12, 16),
  (16, 20),
  (18, 24),
  (24, 30),
  (24, 36),
  (30, 40),
];

const metricSizePresets = <(double, double)>[
  (20, 25),
  (30, 40),
  (40, 50),
  (50, 70),
  (60, 80),
];

const ratioPresets = <(double, double)>[
  (1, 1),
  (4, 5),
  (3, 4),
  (2, 3),
  (5, 7),
  (9, 16),
];

/// Bounds for custom sizes and ratio terms.
const minDimension = 0.1;
const maxDimension = 1000.0;

List<(double, double)> sizePresetsFor(LengthUnit unit) => switch (unit) {
  LengthUnit.inches => imperialSizePresets,
  LengthUnit.centimeters => metricSizePresets,
};

enum CanvasOrientation { portrait, landscape, square }

CanvasOrientation orientationOf(double width, double height) => width == height
    ? CanvasOrientation.square
    : width < height
    ? CanvasOrientation.portrait
    : CanvasOrientation.landscape;

/// [dims] (any orientation) turned to [orientation]; squares are unchanged.
(double, double) orient((double, double) dims, CanvasOrientation orientation) {
  final (a, b) = dims;
  final short = a < b ? a : b;
  final long = a < b ? b : a;
  return orientation == CanvasOrientation.landscape
      ? (long, short)
      : (short, long);
}

/// Whether [a] and [b] are the same dimensions, ignoring orientation.
bool sameDims((double, double) a, (double, double) b) =>
    orient(a, CanvasOrientation.portrait) ==
    orient(b, CanvasOrientation.portrait);

/// The width/height (or ratio terms) of [size]; null for [NoSize].
(double, double)? dimsOf(ProjectSize size) => switch (size) {
  NoSize() => null,
  RatioSize(:final w, :final h) => (w, h),
  PhysicalSize(:final width, :final height) => (width, height),
};

/// [size] turned to [orientation]. [NoSize] and squares are unchanged.
ProjectSize withOrientation(ProjectSize size, CanvasOrientation orientation) {
  return switch (size) {
    NoSize() => size,
    RatioSize(:final w, :final h) => switch (orient((w, h), orientation)) {
      (final a, final b) => RatioSize(a, b),
    },
    PhysicalSize(:final width, :final height, :final unit) => switch (orient((
      width,
      height,
    ), orientation)) {
      (final a, final b) => PhysicalSize(a, b, unit),
    },
  };
}

/// e.g. "11 × 14 in", "50 × 70 cm", "4:5", "No size".
String sizeLabel(ProjectSize size) => switch (size) {
  NoSize() => 'No size',
  RatioSize(:final w, :final h) =>
    '${formatDimension(w)}:${formatDimension(h)}',
  PhysicalSize(:final width, :final height, :final unit) =>
    '${formatDimension(width)} × ${formatDimension(height)} ${unit.code}',
};

/// Up to three decimals, without trailing zeros: 11 → "11", 40.5 → "40.5".
String formatDimension(double value) {
  var text = value.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

/// Parses a user-entered dimension. Returns null unless it is a number
/// within [minDimension]–[maxDimension].
double? parseDimension(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite) return null;
  if (value < minDimension || value > maxDimension) return null;
  return value;
}
