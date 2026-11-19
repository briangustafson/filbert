// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The sync engine's view of this device (m3-design §6.1). Drive thumbnails
/// are of the unedited original (§6.5).

@ProviderFor(localStore)
final localStoreProvider = LocalStoreProvider._();

/// The sync engine's view of this device (m3-design §6.1). Drive thumbnails
/// are of the unedited original (§6.5).

final class LocalStoreProvider
    extends $FunctionalProvider<LocalStore, LocalStore, LocalStore>
    with $Provider<LocalStore> {
  /// The sync engine's view of this device (m3-design §6.1). Drive thumbnails
  /// are of the unedited original (§6.5).
  LocalStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localStoreHash();

  @$internal
  @override
  $ProviderElement<LocalStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalStore create(Ref ref) {
    return localStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalStore>(value),
    );
  }
}

String _$localStoreHash() => r'73fd1ca6aa718bea4ace4510e46857ff0fd76b58';
