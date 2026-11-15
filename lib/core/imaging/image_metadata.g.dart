// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_metadata.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(imageMetadataReader)
final imageMetadataReaderProvider = ImageMetadataReaderProvider._();

final class ImageMetadataReaderProvider
    extends
        $FunctionalProvider<
          ImageMetadataReader,
          ImageMetadataReader,
          ImageMetadataReader
        >
    with $Provider<ImageMetadataReader> {
  ImageMetadataReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageMetadataReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageMetadataReaderHash();

  @$internal
  @override
  $ProviderElement<ImageMetadataReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImageMetadataReader create(Ref ref) {
    return imageMetadataReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageMetadataReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageMetadataReader>(value),
    );
  }
}

String _$imageMetadataReaderHash() =>
    r'70ee13fa5d994df7ff07b12cb42e3045fc389919';
