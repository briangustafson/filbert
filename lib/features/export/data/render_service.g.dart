// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'render_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(renderService)
final renderServiceProvider = RenderServiceProvider._();

final class RenderServiceProvider
    extends $FunctionalProvider<RenderService, RenderService, RenderService>
    with $Provider<RenderService> {
  RenderServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'renderServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$renderServiceHash();

  @$internal
  @override
  $ProviderElement<RenderService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RenderService create(Ref ref) {
    return renderService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RenderService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RenderService>(value),
    );
  }
}

String _$renderServiceHash() => r'02ca167c12ece8828d7ed815e4a16a71515485d7';
