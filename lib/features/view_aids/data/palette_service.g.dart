// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'palette_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paletteService)
final paletteServiceProvider = PaletteServiceProvider._();

final class PaletteServiceProvider
    extends $FunctionalProvider<PaletteService, PaletteService, PaletteService>
    with $Provider<PaletteService> {
  PaletteServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paletteServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paletteServiceHash();

  @$internal
  @override
  $ProviderElement<PaletteService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PaletteService create(Ref ref) {
    return paletteService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaletteService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaletteService>(value),
    );
  }
}

String _$paletteServiceHash() => r'73e55a8ca55702e86f9cb69517cf8896440d4069';
