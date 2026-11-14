/// Route paths (m1-design §3.1). Routes use ids only, so they stay valid
/// across renames and can be deep-linked later.
abstract final class Routes {
  static const projectList = '/';
  static const settings = '/settings';

  static String project(String projectId) => '/projects/$projectId';

  static String photo(String projectId, String imageId) =>
      '${project(projectId)}/images/$imageId';

  static String crop(String projectId, String imageId) =>
      '${photo(projectId, imageId)}/crop';

  static String autocrop(String projectId, String imageId) =>
      '${photo(projectId, imageId)}/autocrop';
}
