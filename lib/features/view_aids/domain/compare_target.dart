import '../../photos/domain/project_image.dart';

/// Which photo Compare overlays on the shown one (m2-design §3.4).
class CompareTarget {
  const CompareTarget._(this.photo, {required this.isShown});

  /// The photo to overlay; null when the project has no other photo.
  final ProjectImage? photo;

  /// The shown photo is the compare photo itself: no overlay, and the panel
  /// says so.
  final bool isShown;

  /// The overlay to draw on the shown photo, if any.
  ProjectImage? get overlay => isShown ? null : photo;

  @override
  bool operator ==(Object other) =>
      other is CompareTarget &&
      other.photo == photo &&
      other.isShown == isShown;

  @override
  int get hashCode => Object.hash(photo, isShown);

  /// Resolves the compare photo for [shown].
  ///
  /// [savedId] is the photo chosen in the panel (`ViewPrefs.compare`); when
  /// null, or no longer one of [photos] (deleted), the default applies: the
  /// reference, or when [shown] is the reference or there is none, the most
  /// recent other photo. [photos] are the project's live photos, newest
  /// first.
  factory CompareTarget.resolve({
    required String? savedId,
    required ProjectImage shown,
    required List<ProjectImage> photos,
    required String? referenceId,
  }) {
    final saved = photos.where((p) => p.id == savedId).firstOrNull;
    if (saved != null) {
      return CompareTarget._(saved, isShown: saved.id == shown.id);
    }
    final others = photos.where((p) => p.id != shown.id);
    final reference = others.where((p) => p.id == referenceId).firstOrNull;
    return CompareTarget._(reference ?? others.firstOrNull, isShown: false);
  }
}
