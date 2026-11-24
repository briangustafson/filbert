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

/// Downloads other devices' originals (m3-design §6.5).

@ProviderFor(blobDownloader)
final blobDownloaderProvider = BlobDownloaderProvider._();

/// Downloads other devices' originals (m3-design §6.5).

final class BlobDownloaderProvider
    extends $FunctionalProvider<BlobDownloader, BlobDownloader, BlobDownloader>
    with $Provider<BlobDownloader> {
  /// Downloads other devices' originals (m3-design §6.5).
  BlobDownloaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blobDownloaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blobDownloaderHash();

  @$internal
  @override
  $ProviderElement<BlobDownloader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BlobDownloader create(Ref ref) {
    return blobDownloader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlobDownloader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlobDownloader>(value),
    );
  }
}

String _$blobDownloaderHash() => r'81385bc2a2f1e9c89479a0459649f2da9d09d997';

/// True while originals are downloading: the project list's progress bar.

@ProviderFor(downloading)
final downloadingProvider = DownloadingProvider._();

/// True while originals are downloading: the project list's progress bar.

final class DownloadingProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// True while originals are downloading: the project list's progress bar.
  DownloadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadingHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return downloading(ref);
  }
}

String _$downloadingHash() => r'252c4ca3b0b60ed7f46aa549fedd69c1610ef50f';

/// Fires on every write to synced records: projects, images, view prefs
/// (m3-design §6.6, the debounced trigger). A pass's own writes fire too;
/// the controller ignores those.

@ProviderFor(localChanges)
final localChangesProvider = LocalChangesProvider._();

/// Fires on every write to synced records: projects, images, view prefs
/// (m3-design §6.6, the debounced trigger). A pass's own writes fire too;
/// the controller ignores those.

final class LocalChangesProvider
    extends
        $FunctionalProvider<
          Raw<Stream<void>>,
          Raw<Stream<void>>,
          Raw<Stream<void>>
        >
    with $Provider<Raw<Stream<void>>> {
  /// Fires on every write to synced records: projects, images, view prefs
  /// (m3-design §6.6, the debounced trigger). A pass's own writes fire too;
  /// the controller ignores those.
  LocalChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localChangesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localChangesHash();

  @$internal
  @override
  $ProviderElement<Raw<Stream<void>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Raw<Stream<void>> create(Ref ref) {
    return localChanges(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Raw<Stream<void>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Raw<Stream<void>>>(value),
    );
  }
}

String _$localChangesHash() => r'1e83021106415e2bf328d63eaf5cbf830ba49137';

@ProviderFor(drivePurge)
final drivePurgeProvider = DrivePurgeProvider._();

final class DrivePurgeProvider
    extends $FunctionalProvider<DrivePurge, DrivePurge, DrivePurge>
    with $Provider<DrivePurge> {
  DrivePurgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'drivePurgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$drivePurgeHash();

  @$internal
  @override
  $ProviderElement<DrivePurge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DrivePurge create(Ref ref) {
    return drivePurge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DrivePurge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DrivePurge>(value),
    );
  }
}

String _$drivePurgeHash() => r'25afd844e32e19c334e2d331811b4c08023387aa';
