import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/project.dart';
import 'project_repository.dart';

part 'project_providers.g.dart';

/// Live projects, most recently updated first.
@riverpod
Stream<List<Project>> projectList(Ref ref) =>
    ref.watch(projectRepositoryProvider).watchAll();
