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
  /// (m1-design §3.6), with Skip, returning to the project. [queue]: opened
  /// from the auto-crop review of new photos (Crop manually, §3.8); Apply
  /// and Skip go on to the next photo's review.
  static String crop(
    String projectId,
    String imageId, {
    bool afterAdd = false,
    ReviewQueue? queue,
  }) {
    final query = {if (afterAdd) 'after': 'add', ...?queue?.toQuery()};
    return Uri(
      path: '${photo(projectId, imageId)}/crop',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

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
