import '../../../core/units/length_unit.dart';

export '../../../core/units/length_unit.dart';

/// A painting project (m1-design §4.1). Immutable; change it through
/// `ProjectRepository.update`.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.nameIsDefault,
    required this.size,
    required this.startNotes,
    required this.referenceImageId,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByDeviceId,
  });

  final String id;
  final String name;

  /// True until the user edits the name (m1-design §4.3).
  final bool nameIsDefault;
  final ProjectSize size;
  final String startNotes;

  /// The project's reference image, if any. Set via `ImageRepository`.
  final String? referenceImageId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedByDeviceId;

  @override
  bool operator ==(Object other) =>
      other is Project &&
      other.id == id &&
      other.name == name &&
      other.nameIsDefault == nameIsDefault &&
      other.size == size &&
      other.startNotes == startNotes &&
      other.referenceImageId == referenceImageId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.updatedByDeviceId == updatedByDeviceId;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameIsDefault,
    size,
    startNotes,
    referenceImageId,
    createdAt,
    updatedAt,
    updatedByDeviceId,
  );

  @override
  String toString() => 'Project($id, "$name", $size)';
}

/// The painting's size, its aspect ratio only, or nothing (m1-design §3.4).
/// Stored already oriented: width and height as displayed.
sealed class ProjectSize {
  const ProjectSize();

  /// Throws [ArgumentError] if any dimension is not a positive finite number.
  void validate();
}

class NoSize extends ProjectSize {
  const NoSize();

  @override
  void validate() {}

  @override
  bool operator ==(Object other) => other is NoSize;

  @override
  int get hashCode => (NoSize).hashCode;

  @override
  String toString() => 'NoSize';
}

class RatioSize extends ProjectSize {
  const RatioSize(this.w, this.h);

  final double w;
  final double h;

  @override
  void validate() {
    _checkPositive(w, 'w');
    _checkPositive(h, 'h');
  }

  @override
  bool operator ==(Object other) =>
      other is RatioSize && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(RatioSize, w, h);

  @override
  String toString() => 'RatioSize($w:$h)';
}

class PhysicalSize extends ProjectSize {
  const PhysicalSize(this.width, this.height, this.unit);

  final double width;
  final double height;
  final LengthUnit unit;

  @override
  void validate() {
    _checkPositive(width, 'width');
    _checkPositive(height, 'height');
  }

  @override
  bool operator ==(Object other) =>
      other is PhysicalSize &&
      other.width == width &&
      other.height == height &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(PhysicalSize, width, height, unit);

  @override
  String toString() => 'PhysicalSize($width×$height ${unit.code})';
}

void _checkPositive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Must be a positive number');
  }
}
