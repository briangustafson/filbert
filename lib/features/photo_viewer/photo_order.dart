import '../photos/domain/project_image.dart';

/// The order the photo screen swipes through (m1-design §3.5): the live
/// reference first, then the grid order ([images] is newest first).
List<ProjectImage> photoOrder(
  String? referenceImageId,
  List<ProjectImage> images,
) => [
  ...images.where((i) => i.id == referenceImageId),
  ...images.where((i) => i.id != referenceImageId),
];

/// Which photo to show after [deletedId] is removed: the next one, else the
/// previous one; null if it was the only one.
String? neighbourAfterDelete(List<String> ids, String deletedId) {
  final i = ids.indexOf(deletedId);
  if (i < 0) return null;
  if (i + 1 < ids.length) return ids[i + 1];
  if (i > 0) return ids[i - 1];
  return null;
}
