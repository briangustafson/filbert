// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(syncSettingsStore)
final syncSettingsStoreProvider = SyncSettingsStoreProvider._();

final class SyncSettingsStoreProvider
    extends
        $FunctionalProvider<
          SyncSettingsStore,
          SyncSettingsStore,
          SyncSettingsStore
        >
    with $Provider<SyncSettingsStore> {
  SyncSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<SyncSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncSettingsStore create(Ref ref) {
    return syncSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncSettingsStore>(value),
    );
  }
}

String _$syncSettingsStoreHash() => r'bd6356501357841d6a9939eb054c7991995df96a';

@ProviderFor(syncSettings)
final syncSettingsProvider = SyncSettingsProvider._();

final class SyncSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncSettings>,
          SyncSettings,
          Stream<SyncSettings>
        >
    with $FutureModifier<SyncSettings>, $StreamProvider<SyncSettings> {
  SyncSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncSettingsHash();

  @$internal
  @override
  $StreamProviderElement<SyncSettings> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SyncSettings> create(Ref ref) {
    return syncSettings(ref);
  }
}

String _$syncSettingsHash() => r'04f04f314de244f549de9338e2fe56d2275646ea';

@ProviderFor(syncSetup)
final syncSetupProvider = SyncSetupProvider._();

final class SyncSetupProvider
    extends $FunctionalProvider<SyncSetup, SyncSetup, SyncSetup>
    with $Provider<SyncSetup> {
  SyncSetupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncSetupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncSetupHash();

  @$internal
  @override
  $ProviderElement<SyncSetup> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncSetup create(Ref ref) {
    return syncSetup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncSetup value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncSetup>(value),
    );
  }
}

String _$syncSetupHash() => r'a1934b7d7405cb0c6aa7a7ae139fbfd2a02e117d';
