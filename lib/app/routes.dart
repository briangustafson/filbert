import '../features/autocrop/review_queue.dart';

/// Route paths (m1-design §3.1). Routes use ids only, so they stay valid
/// across renames and can be deep-linked later.
abstract final class Routes {
  static const projectList = '/';
  static const settings = '/settings';

  static String project(String projectId) => '/projects/$projectId';

  static String photo(String projectId, String imageId) =>
      '${project(projectId)}/images/$imageId';

  /// [afterAdd]: opened by the add-photo flow for a new reference
  /// (m1-design §3.6), with Skip, returning to the project.
  static String crop(
    String projectId,
    String imageId, {
    bool afterAdd = false,
  }) => Uri(
    path: '${photo(projectId, imageId)}/crop',
    queryParameters: afterAdd ? {'after': 'add'} : null,
  ).toString();

  /// [queue]: opened by the add-photo flow, reviewing new photos in turn.
  static String autocrop(
    String projectId,
    String imageId, {
    ReviewQueue? queue,
  }) => Uri(
    path: '${photo(projectId, imageId)}/autocrop',
    queryParameters: queue?.toQuery(),
  ).toString();
}
