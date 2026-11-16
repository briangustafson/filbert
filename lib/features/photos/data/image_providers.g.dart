// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live images of a project, most recently added first.

@ProviderFor(projectImages)
final projectImagesProvider = ProjectImagesFamily._();

/// Live images of a project, most recently added first.

final class ProjectImagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProjectImage>>,
          List<ProjectImage>,
          Stream<List<ProjectImage>>
        >
    with
        $FutureModifier<List<ProjectImage>>,
        $StreamProvider<List<ProjectImage>> {
  /// Live images of a project, most recently added first.
  ProjectImagesProvider._({
    required ProjectImagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectImagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectImagesHash();

  @override
  String toString() {
    return r'projectImagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ProjectImage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProjectImage>> create(Ref ref) {
    final argument = this.argument as String;
    return projectImages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectImagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectImagesHash() => r'503edf2f04004e596b72bf3c3ecc014cbd038c38';

/// Live images of a project, most recently added first.

final class ProjectImagesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ProjectImage>>, String> {
  ProjectImagesFamily._()
    : super(
        retry: null,
        name: r'projectImagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live images of a project, most recently added first.

  ProjectImagesProvider call(String projectId) =>
      ProjectImagesProvider._(argument: projectId, from: this);

  @override
  String toString() => r'projectImagesProvider';
}

/// Cover image of each live project, by project id (m1-design §3.2).

@ProviderFor(projectCovers)
final projectCoversProvider = ProjectCoversProvider._();

/// Cover image of each live project, by project id (m1-design §3.2).

final class ProjectCoversProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ProjectImage>>,
          Map<String, ProjectImage>,
          Stream<Map<String, ProjectImage>>
        >
    with
        $FutureModifier<Map<String, ProjectImage>>,
        $StreamProvider<Map<String, ProjectImage>> {
  /// Cover image of each live project, by project id (m1-design §3.2).
  ProjectCoversProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectCoversProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectCoversHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, ProjectImage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, ProjectImage>> create(Ref ref) {
    return projectCovers(ref);
  }
}

String _$projectCoversHash() => r'49863df7bc4e951d150b34cab5da89e403a79fa7';

/// Whether an image's edits can be undone or redone, live.

@ProviderFor(editHistory)
final editHistoryProvider = EditHistoryFamily._();

/// Whether an image's edits can be undone or redone, live.

final class EditHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<EditHistory>,
          EditHistory,
          Stream<EditHistory>
        >
    with $FutureModifier<EditHistory>, $StreamProvider<EditHistory> {
  /// Whether an image's edits can be undone or redone, live.
  EditHistoryProvider._({
    required EditHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'editHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$editHistoryHash();

  @override
  String toString() {
    return r'editHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<EditHistory> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<EditHistory> create(Ref ref) {
    final argument = this.argument as String;
    return editHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EditHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$editHistoryHash() => r'a7a318a2b3f5d25819a8753b0f8674e1eb124e4e';

/// Whether an image's edits can be undone or redone, live.

final class EditHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<EditHistory>, String> {
  EditHistoryFamily._()
    : super(
        retry: null,
        name: r'editHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether an image's edits can be undone or redone, live.

  EditHistoryProvider call(String imageId) =>
      EditHistoryProvider._(argument: imageId, from: this);

  @override
  String toString() => r'editHistoryProvider';
}
