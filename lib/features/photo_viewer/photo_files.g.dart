// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_files.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The display render of [image] (m1-design §5.1). Keyed by the whole
/// image, so new edits give a new file; pass `image.withEdits(Edits.none)`
/// for the original.

@ProviderFor(previewFile)
final previewFileProvider = PreviewFileFamily._();

/// The display render of [image] (m1-design §5.1). Keyed by the whole
/// image, so new edits give a new file; pass `image.withEdits(Edits.none)`
/// for the original.

final class PreviewFileProvider
    extends $FunctionalProvider<AsyncValue<File>, File, FutureOr<File>>
    with $FutureModifier<File>, $FutureProvider<File> {
  /// The display render of [image] (m1-design §5.1). Keyed by the whole
  /// image, so new edits give a new file; pass `image.withEdits(Edits.none)`
  /// for the original.
  PreviewFileProvider._({
    required PreviewFileFamily super.from,
    required ProjectImage super.argument,
  }) : super(
         retry: null,
         name: r'previewFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$previewFileHash();

  @override
  String toString() {
    return r'previewFileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<File> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<File> create(Ref ref) {
    final argument = this.argument as ProjectImage;
    return previewFile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PreviewFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$previewFileHash() => r'63e68f840a73206f4c89164e17f10ef3b7009272';

/// The display render of [image] (m1-design §5.1). Keyed by the whole
/// image, so new edits give a new file; pass `image.withEdits(Edits.none)`
/// for the original.

final class PreviewFileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<File>, ProjectImage> {
  PreviewFileFamily._()
    : super(
        retry: null,
        name: r'previewFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The display render of [image] (m1-design §5.1). Keyed by the whole
  /// image, so new edits give a new file; pass `image.withEdits(Edits.none)`
  /// for the original.

  PreviewFileProvider call(ProjectImage image) =>
      PreviewFileProvider._(argument: image, from: this);

  @override
  String toString() => r'previewFileProvider';
}

/// The sharper render used when zoomed in past the preview's resolution.

@ProviderFor(detailFile)
final detailFileProvider = DetailFileFamily._();

/// The sharper render used when zoomed in past the preview's resolution.

final class DetailFileProvider
    extends $FunctionalProvider<AsyncValue<File>, File, FutureOr<File>>
    with $FutureModifier<File>, $FutureProvider<File> {
  /// The sharper render used when zoomed in past the preview's resolution.
  DetailFileProvider._({
    required DetailFileFamily super.from,
    required ProjectImage super.argument,
  }) : super(
         retry: null,
         name: r'detailFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$detailFileHash();

  @override
  String toString() {
    return r'detailFileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<File> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<File> create(Ref ref) {
    final argument = this.argument as ProjectImage;
    return detailFile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DetailFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$detailFileHash() => r'a76c28a1777a318e5ddf1e26a58f79a909363b7e';

/// The sharper render used when zoomed in past the preview's resolution.

final class DetailFileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<File>, ProjectImage> {
  DetailFileFamily._()
    : super(
        retry: null,
        name: r'detailFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The sharper render used when zoomed in past the preview's resolution.

  DetailFileProvider call(ProjectImage image) =>
      DetailFileProvider._(argument: image, from: this);

  @override
  String toString() => r'detailFileProvider';
}
