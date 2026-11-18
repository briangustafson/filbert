import 'dart:convert';

import '../../../core/units/length_unit.dart';
import 'view_aids.dart';

/// A project's viewing-aid settings, stored as `view_prefs.prefs_json`
/// (m2-design §4.2), including which aids are on ([on]); which panel is
/// open is per photo-screen visit (§3.1).
///
/// Parsing is lenient: settings are not worth blocking on. Missing, malformed
/// or out-of-range fields take defaults or are clamped, unknown fields are
/// ignored, and an unknown `v` gives all defaults.
class ViewPrefs {
  const ViewPrefs({
    this.grid = const GridPrefs(),
    this.values = const ValuesPrefs(),
    this.colors = const ColorsPrefs(),
    this.compare = const ComparePrefs(),
    this.on = AidsOn.off,
  });

  static const defaults = ViewPrefs();

  /// The only format version this build understands.
  static const currentVersion = 1;

  final GridPrefs grid;
  final ValuesPrefs values;
  final ColorsPrefs colors;
  final ComparePrefs compare;

  /// Which aids are on; they stay on until turned off.
  final AidsOn on;

  ViewPrefs copyWith({
    GridPrefs? grid,
    ValuesPrefs? values,
    ColorsPrefs? colors,
    ComparePrefs? compare,
    AidsOn? on,
  }) => ViewPrefs(
    grid: grid ?? this.grid,
    values: values ?? this.values,
    colors: colors ?? this.colors,
    compare: compare ?? this.compare,
    on: on ?? this.on,
  );

  Map<String, Object?> toJson() => {
    'v': currentVersion,
    'grid': grid.toJson(),
    'values': values.toJson(),
    'colors': colors.toJson(),
    'compare': compare.toJson(),
    'on': on.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory ViewPrefs.fromJson(Object? json) {
    if (json is! Map || json['v'] != currentVersion) return defaults;
    return ViewPrefs(
      grid: GridPrefs.fromJson(json['grid']),
      values: ValuesPrefs.fromJson(json['values']),
      colors: ColorsPrefs.fromJson(json['colors']),
      compare: ComparePrefs.fromJson(json['compare']),
      on: AidsOn.fromJson(json['on']),
    );
  }

  /// Defaults if [source] isn't valid JSON.
  factory ViewPrefs.fromJsonString(String source) {
    try {
      return ViewPrefs.fromJson(jsonDecode(source));
    } on FormatException {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ViewPrefs &&
      other.grid == grid &&
      other.values == values &&
      other.colors == colors &&
      other.compare == compare &&
      other.on == on;

  @override
  int get hashCode => Object.hash(grid, values, colors, compare, on);

  @override
  String toString() => 'ViewPrefs(${toJsonString()})';
}

/// How grid lines are placed (m2-design §3).
enum GridMode { divisions, spacing }

enum GridColor { white, black, gray, red }

enum GridLineWidth { thin, medium, thick }

class GridPrefs {
  const GridPrefs({
    this.mode = GridMode.divisions,
    this.rows = 4,
    this.cols = 4,
    this.spacing,
    this.diagonals = false,
    this.color = GridColor.white,
    this.width = GridLineWidth.thin,
  });

  static const minDivisions = 1;
  static const maxDivisions = 20;

  /// [GridMode.spacing] needs a project with a physical size; without one,
  /// the grid falls back to divisions (§3).
  final GridMode mode;

  /// Number of rows and columns of cells, [minDivisions]–[maxDivisions].
  final int rows;
  final int cols;

  /// Distance between lines in the project's unit; null means
  /// [defaultSpacing] for that unit.
  final double? spacing;

  final bool diagonals;
  final GridColor color;
  final GridLineWidth width;

  /// 2 in or 5 cm.
  static double defaultSpacing(LengthUnit unit) => switch (unit) {
    LengthUnit.inches => 2,
    LengthUnit.centimeters => 5,
  };

  double spacingIn(LengthUnit unit) => spacing ?? defaultSpacing(unit);

  /// [spacing] takes a function so it can be set back to null (the default).
  GridPrefs copyWith({
    GridMode? mode,
    int? rows,
    int? cols,
    double? Function()? spacing,
    bool? diagonals,
    GridColor? color,
    GridLineWidth? width,
  }) => GridPrefs(
    mode: mode ?? this.mode,
    rows: rows ?? this.rows,
    cols: cols ?? this.cols,
    spacing: spacing == null ? this.spacing : spacing(),
    diagonals: diagonals ?? this.diagonals,
    color: color ?? this.color,
    width: width ?? this.width,
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'rows': rows,
    'cols': cols,
    if (spacing != null) 'spacing': spacing,
    'diagonals': diagonals,
    'color': color.name,
    'width': width.name,
  };

  factory GridPrefs.fromJson(Object? json) {
    const d = GridPrefs();
    if (json is! Map) return d;
    final spacing = json['spacing'];
    return GridPrefs(
      mode: _enum(GridMode.values, json['mode'], d.mode),
      rows: _int(json['rows'], d.rows, minDivisions, maxDivisions),
      cols: _int(json['cols'], d.cols, minDivisions, maxDivisions),
      spacing: spacing is num && spacing.isFinite && spacing > 0
          ? spacing.toDouble()
          : null,
      diagonals: _bool(json['diagonals'], d.diagonals),
      color: _enum(GridColor.values, json['color'], d.color),
      width: _enum(GridLineWidth.values, json['width'], d.width),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GridPrefs &&
      other.mode == mode &&
      other.rows == rows &&
      other.cols == cols &&
      other.spacing == spacing &&
      other.diagonals == diagonals &&
      other.color == color &&
      other.width == width;

  @override
  int get hashCode =>
      Object.hash(mode, rows, cols, spacing, diagonals, color, width);
}

/// Limited values: equal steps of perceived lightness (§2).
class ValuesPrefs {
  const ValuesPrefs({this.bands = 5});

  static const minBands = 2;
  static const maxBands = 9;

  final int bands;

  Map<String, Object?> toJson() => {'bands': bands};

  factory ValuesPrefs.fromJson(Object? json) {
    const d = ValuesPrefs();
    if (json is! Map) return d;
    return ValuesPrefs(bands: _int(json['bands'], d.bands, minBands, maxBands));
  }

  @override
  bool operator ==(Object other) =>
      other is ValuesPrefs && other.bands == bands;

  @override
  int get hashCode => bands.hashCode;
}

/// Limited colors: a k-means palette (§2).
class ColorsPrefs {
  const ColorsPrefs({this.count = 8});

  static const minCount = 2;
  static const maxCount = 16;

  final int count;

  Map<String, Object?> toJson() => {'count': count};

  factory ColorsPrefs.fromJson(Object? json) {
    const d = ColorsPrefs();
    if (json is! Map) return d;
    return ColorsPrefs(count: _int(json['count'], d.count, minCount, maxCount));
  }

  @override
  bool operator ==(Object other) =>
      other is ColorsPrefs && other.count == count;

  @override
  int get hashCode => count.hashCode;
}

/// Compare: another photo of the project overlaid at [opacity] (§2).
class ComparePrefs {
  const ComparePrefs({this.imageId, this.opacity = 0.5});

  /// The photo to overlay; null means the default (the reference, §3). One
  /// that is no longer a live photo of the project also means the default;
  /// the photo screen checks that, as it knows the project's photos.
  final String? imageId;

  /// 0–1.
  final double opacity;

  /// [imageId] takes a function so it can be set back to null (the default).
  ComparePrefs copyWith({String? Function()? imageId, double? opacity}) =>
      ComparePrefs(
        imageId: imageId == null ? this.imageId : imageId(),
        opacity: opacity ?? this.opacity,
      );

  Map<String, Object?> toJson() => {
    if (imageId != null) 'imageId': imageId,
    'opacity': opacity,
  };

  factory ComparePrefs.fromJson(Object? json) {
    const d = ComparePrefs();
    if (json is! Map) return d;
    final imageId = json['imageId'];
    final opacity = json['opacity'];
    return ComparePrefs(
      imageId: imageId is String && imageId.isNotEmpty ? imageId : null,
      opacity: opacity is num && opacity.isFinite
          ? opacity.toDouble().clamp(0.0, 1.0)
          : d.opacity,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ComparePrefs &&
      other.imageId == imageId &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(imageId, opacity);
}

/// Which aids are on (m2-design §3.1): saved per project, so they are on
/// again the next time any photo of the project is opened. Missing means
/// all off (rows written before this field existed).
class AidsOn {
  const AidsOn({
    this.grid = false,
    this.tone = ToneAid.none,
    this.compare = false,
  });

  static const off = AidsOn();

  final bool grid;
  final ToneAid tone;
  final bool compare;

  static const _toneNames = {
    ToneAid.none: 'none',
    ToneAid.gray: 'gray',
    ToneAid.valueBands: 'values',
    ToneAid.colors: 'colors',
  };

  Map<String, Object?> toJson() => {
    'grid': grid,
    'tone': _toneNames[tone],
    'compare': compare,
  };

  factory AidsOn.fromJson(Object? json) {
    if (json is! Map) return off;
    final tone = json['tone'];
    return AidsOn(
      grid: _bool(json['grid'], false),
      tone:
          _toneNames.entries.where((e) => e.value == tone).firstOrNull?.key ??
          ToneAid.none,
      compare: _bool(json['compare'], false),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AidsOn &&
      other.grid == grid &&
      other.tone == tone &&
      other.compare == compare;

  @override
  int get hashCode => Object.hash(grid, tone, compare);
}

/// [value] rounded and clamped to [min]–[max]; [fallback] if not a number.
int _int(Object? value, int fallback, int min, int max) =>
    value is num && value.isFinite ? value.round().clamp(min, max) : fallback;

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
