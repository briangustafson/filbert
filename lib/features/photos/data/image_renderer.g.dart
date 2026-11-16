// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_renderer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(imageRenderer)
final imageRendererProvider = ImageRendererProvider._();

final class ImageRendererProvider
    extends $FunctionalProvider<ImageRenderer, ImageRenderer, ImageRenderer>
    with $Provider<ImageRenderer> {
  ImageRendererProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageRendererProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageRendererHash();

  @$internal
  @override
  $ProviderElement<ImageRenderer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImageRenderer create(Ref ref) {
    return imageRenderer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageRenderer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageRenderer>(value),
    );
  }
}

String _$imageRendererHash() => r'9f0b00d57a71e6ac9876422de61b89810b2baf91';
