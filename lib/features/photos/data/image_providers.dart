import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/project_image.dart';
import 'image_repository.dart';

part 'image_providers.g.dart';

/// Live images of a project, most recently added first.
@riverpod
Stream<List<ProjectImage>> projectImages(Ref ref, String projectId) =>
    ref.watch(imageRepositoryProvider).watchForProject(projectId);

/// Cover image of each live project, by project id (m1-design §3.2).
@riverpod
Stream<Map<String, ProjectImage>> projectCovers(Ref ref) =>
    ref.watch(imageRepositoryProvider).watchCovers();
