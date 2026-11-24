// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_thumbnail.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The cached thumbnail file of [image]'s edited view, rendering it if
/// needed. Keyed by the whole image, so new edits give a new thumbnail.

@ProviderFor(thumbnailFile)
final thumbnailFileProvider = ThumbnailFileFamily._();

/// The cached thumbnail file of [image]'s edited view, rendering it if
/// needed. Keyed by the whole image, so new edits give a new thumbnail.

final class ThumbnailFileProvider
    extends $FunctionalProvider<AsyncValue<File>, File, FutureOr<File>>
    with $FutureModifier<File>, $FutureProvider<File> {
  /// The cached thumbnail file of [image]'s edited view, rendering it if
  /// needed. Keyed by the whole image, so new edits give a new thumbnail.
  ThumbnailFileProvider._({
    required ThumbnailFileFamily super.from,
    required ProjectImage super.argument,
  }) : super(
         retry: null,
         name: r'thumbnailFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$thumbnailFileHash();

  @override
  String toString() {
    return r'thumbnailFileProvider'
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
    return thumbnailFile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ThumbnailFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$thumbnailFileHash() => r'0c37bcdd00d193215e100eb434767b452f349899';

/// The cached thumbnail file of [image]'s edited view, rendering it if
/// needed. Keyed by the whole image, so new edits give a new thumbnail.

final class ThumbnailFileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<File>, ProjectImage> {
  ThumbnailFileFamily._()
    : super(
        retry: null,
        name: r'thumbnailFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The cached thumbnail file of [image]'s edited view, rendering it if
  /// needed. Keyed by the whole image, so new edits give a new thumbnail.

  ThumbnailFileProvider call(ProjectImage image) =>
      ThumbnailFileProvider._(argument: image, from: this);

  @override
  String toString() => r'thumbnailFileProvider';
}
