/// Unit of a physical canvas size.
enum LengthUnit {
  inches('in'),
  centimeters('cm');

  const LengthUnit(this.code);

  /// Stored value.
  final String code;

  static LengthUnit fromCode(String code) => values.firstWhere(
    (u) => u.code == code,
    orElse: () => throw ArgumentError.value(code, 'code', 'Unknown unit'),
  );
}
