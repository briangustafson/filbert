import 'dart:convert';

/// Non-destructive edit state of an image, stored as `images.edits_json`
/// (m1-design §4.2). Originals are never modified; renders are derived from
/// the original plus these parameters.
class Edits {
  const Edits({this.crop, this.quarterTurns = 0});

  /// No crop, no rotation: the full original.
  static const none = Edits();

  /// The only format version this build understands.
  static const currentVersion = 1;

  /// Crop as a quad in the EXIF-oriented original; null means full image.
  final CropEdit? crop;

  /// Clockwise quarter turns applied to the output, 0–3.
  final int quarterTurns;

  bool get isNone => crop == null && quarterTurns == 0;

  /// Throws [ArgumentError] if any field is out of range.
  void validate() {
    if (quarterTurns < 0 || quarterTurns > 3) {
      throw ArgumentError.value(quarterTurns, 'quarterTurns', 'Must be 0–3');
    }
    crop?.validate();
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'v': currentVersion,
      if (crop != null) 'crop': crop!.toJson(),
      'quarterTurns': quarterTurns,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  /// Parses and validates. Throws [UnsupportedEditsVersionException] for a
  /// version this build doesn't know, and [FormatException] for malformed or
  /// invalid data. Unknown fields are ignored.
  factory Edits.fromJson(Object? json) {
    final map = _asMap(json, 'edits');
    final v = map['v'];
    if (v is! int) throw const FormatException('edits.v must be an integer');
    if (v != currentVersion) throw UnsupportedEditsVersionException(v);

    final cropJson = map['crop'];
    final turns = map['quarterTurns'] ?? 0;
    if (turns is! int) {
      throw const FormatException('edits.quarterTurns must be an integer');
    }
    final edits = Edits(
      crop: cropJson == null ? null : CropEdit._fromJson(cropJson),
      quarterTurns: turns,
    );
    _validateAsFormat(edits.validate);
    return edits;
  }

  factory Edits.fromJsonString(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('edits is not valid JSON: ${e.message}');
    }
    return Edits.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      other is Edits &&
      other.crop == crop &&
      other.quarterTurns == quarterTurns;

  @override
  int get hashCode => Object.hash(crop, quarterTurns);

  @override
  String toString() => 'Edits(crop: $crop, quarterTurns: $quarterTurns)';
}

/// A crop: four corners, normalized 0–1, ordered top-left, top-right,
/// bottom-right, bottom-left (clockwise on screen). Axis-aligned for a plain
/// crop, a rotated rectangle when straightened, any convex quad for auto-crop.
class CropEdit {
  CropEdit({required List<NormPoint> quad, this.output})
    : quad = List.unmodifiable(quad);

  final List<NormPoint> quad;

  /// Fixed output aspect ratio; null means estimate it from the quad.
  final OutputAspect? output;

  void validate() {
    if (quad.length != 4) {
      throw ArgumentError.value(quad.length, 'quad', 'Must have 4 corners');
    }
    for (final p in quad) {
      if (!p.x.isFinite || !p.y.isFinite) {
        throw ArgumentError.value(p, 'quad', 'Corners must be finite');
      }
      if (p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1) {
        throw ArgumentError.value(p, 'quad', 'Corners must be within 0–1');
      }
    }
    // With y pointing down, TL → TR → BR → BL turns the same way at every
    // corner (positive cross product). This rejects wrong ordering,
    // self-intersecting (bow-tie) and concave quads, and collinear corners.
    for (var i = 0; i < 4; i++) {
      final a = quad[i], b = quad[(i + 1) % 4], c = quad[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross <= _epsilon) {
        throw ArgumentError.value(
          quad,
          'quad',
          'Must be convex and ordered top-left, top-right, bottom-right, '
              'bottom-left',
        );
      }
    }
    output?.validate();
  }

  Map<String, Object?> toJson() => {
    'quad': [
      for (final p in quad) [p.x, p.y],
    ],
    if (output != null) 'output': output!.toJson(),
  };

  factory CropEdit._fromJson(Object? json) {
    final map = _asMap(json, 'crop');
    final quadJson = map['quad'];
    if (quadJson is! List) {
      throw const FormatException('crop.quad must be a list');
    }
    final outputJson = map['output'];
    return CropEdit(
      quad: [for (final p in quadJson) NormPoint._fromJson(p)],
      output: outputJson == null ? null : OutputAspect._fromJson(outputJson),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CropEdit &&
      other.output == output &&
      other.quad.length == quad.length &&
      Iterable<int>.generate(quad.length)
          .every((i) => other.quad[i] == quad[i]);

  @override
  int get hashCode => Object.hash(Object.hashAll(quad), output);

  @override
  String toString() => 'CropEdit(quad: $quad, output: $output)';
}

/// A point in normalized image coordinates (0–1; origin top-left, y down).
class NormPoint {
  const NormPoint(this.x, this.y);

  final double x;
  final double y;

  factory NormPoint._fromJson(Object? json) {
    if (json is! List || json.length != 2 || json.any((c) => c is! num)) {
      throw const FormatException('quad corners must be [x, y] numbers');
    }
    return NormPoint((json[0] as num).toDouble(), (json[1] as num).toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is NormPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// Output aspect ratio, e.g. 4:5.
class OutputAspect {
  const OutputAspect(this.aspectW, this.aspectH);

  final double aspectW;
  final double aspectH;

  void validate() {
    for (final (name, value) in [('aspectW', aspectW), ('aspectH', aspectH)]) {
      if (!value.isFinite || value <= 0) {
        throw ArgumentError.value(value, name, 'Must be positive');
      }
    }
  }

  Map<String, Object?> toJson() => {'aspectW': aspectW, 'aspectH': aspectH};

  factory OutputAspect._fromJson(Object? json) {
    final map = _asMap(json, 'crop.output');
    final w = map['aspectW'], h = map['aspectH'];
    if (w is! num || h is! num) {
      throw const FormatException('crop.output aspects must be numbers');
    }
    return OutputAspect(w.toDouble(), h.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is OutputAspect &&
      other.aspectW == aspectW &&
      other.aspectH == aspectH;

  @override
  int get hashCode => Object.hash(aspectW, aspectH);

  @override
  String toString() => '$aspectW:$aspectH';
}

/// The stored edits were written by a newer (or unknown) format version.
class UnsupportedEditsVersionException implements Exception {
  const UnsupportedEditsVersionException(this.version);

  final int version;

  @override
  String toString() =>
      'UnsupportedEditsVersionException: edits version $version is not '
      'supported (this app understands version ${Edits.currentVersion}).';
}

const _epsilon = 1e-9;

Map<String, Object?> _asMap(Object? json, String what) {
  if (json is! Map<String, Object?>) {
    throw FormatException('$what must be a JSON object');
  }
  return json;
}

void _validateAsFormat(void Function() validate) {
  try {
    validate();
  } on ArgumentError catch (e) {
    throw FormatException('Invalid edits: ${e.message} (${e.name})');
  }
}
