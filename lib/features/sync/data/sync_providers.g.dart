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

/// Drive (m3-design §6.2), with the signed-in user's token.

@ProviderFor(remoteStore)
final remoteStoreProvider = RemoteStoreProvider._();

/// Drive (m3-design §6.2), with the signed-in user's token.

final class RemoteStoreProvider
    extends $FunctionalProvider<RemoteStore, RemoteStore, RemoteStore>
    with $Provider<RemoteStore> {
  /// Drive (m3-design §6.2), with the signed-in user's token.
  RemoteStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteStoreHash();

  @$internal
  @override
  $ProviderElement<RemoteStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RemoteStore create(Ref ref) {
    return remoteStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteStore>(value),
    );
  }
}

String _$remoteStoreHash() => r'ac05808e0f2d6a8705632f7f12c3de479af22227';

/// One sync pass between this device and Drive. The sync controller (T9)
/// runs it; until then, Settings → Sync's debug button does.

@ProviderFor(syncEngine)
final syncEngineProvider = SyncEngineProvider._();

/// One sync pass between this device and Drive. The sync controller (T9)
/// runs it; until then, Settings → Sync's debug button does.

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  /// One sync pass between this device and Drive. The sync controller (T9)
  /// runs it; until then, Settings → Sync's debug button does.
  SyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @$internal
  @override
  $ProviderElement<SyncEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEngine create(Ref ref) {
    return syncEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEngine>(value),
    );
  }
}

String _$syncEngineHash() => r'92ecfee782b868aa0fba029ad38ee792f262406b';
