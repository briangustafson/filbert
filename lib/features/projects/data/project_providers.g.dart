// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live projects, most recently updated first.

@ProviderFor(projectList)
final projectListProvider = ProjectListProvider._();

/// Live projects, most recently updated first.

final class ProjectListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Project>>,
          List<Project>,
          Stream<List<Project>>
        >
    with $FutureModifier<List<Project>>, $StreamProvider<List<Project>> {
  /// Live projects, most recently updated first.
  ProjectListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectListHash();

  @$internal
  @override
  $StreamProviderElement<List<Project>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Project>> create(Ref ref) {
    return projectList(ref);
  }
}

String _$projectListHash() => r'5aac4668a9fb0a6fadce46f24723df34b4580a46';

/// One project, live; null if it doesn't exist or is deleted.

@ProviderFor(project)
final projectProvider = ProjectFamily._();

/// One project, live; null if it doesn't exist or is deleted.

final class ProjectProvider
    extends
        $FunctionalProvider<AsyncValue<Project?>, Project?, Stream<Project?>>
    with $FutureModifier<Project?>, $StreamProvider<Project?> {
  /// One project, live; null if it doesn't exist or is deleted.
  ProjectProvider._({
    required ProjectFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectHash();

  @override
  String toString() {
    return r'projectProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Project?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Project?> create(Ref ref) {
    final argument = this.argument as String;
    return project(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectHash() => r'b9677a35182940a813ca81dbda1218e688815a44';

/// One project, live; null if it doesn't exist or is deleted.

final class ProjectFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Project?>, String> {
  ProjectFamily._()
    : super(
        retry: null,
        name: r'projectProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One project, live; null if it doesn't exist or is deleted.

  ProjectProvider call(String id) =>
      ProjectProvider._(argument: id, from: this);

  @override
  String toString() => r'projectProvider';
}
