// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_capture.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pendingCaptureStore)
final pendingCaptureStoreProvider = PendingCaptureStoreProvider._();

final class PendingCaptureStoreProvider
    extends
        $FunctionalProvider<
          PendingCaptureStore,
          PendingCaptureStore,
          PendingCaptureStore
        >
    with $Provider<PendingCaptureStore> {
  PendingCaptureStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingCaptureStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingCaptureStoreHash();

  @$internal
  @override
  $ProviderElement<PendingCaptureStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingCaptureStore create(Ref ref) {
    return pendingCaptureStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingCaptureStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingCaptureStore>(value),
    );
  }
}

String _$pendingCaptureStoreHash() =>
    r'5e1d0c933b2d33d90c670109eff182a087148edf';
