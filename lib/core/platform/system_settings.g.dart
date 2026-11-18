// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(systemSettings)
final systemSettingsProvider = SystemSettingsProvider._();

final class SystemSettingsProvider
    extends $FunctionalProvider<SystemSettings, SystemSettings, SystemSettings>
    with $Provider<SystemSettings> {
  SystemSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemSettingsHash();

  @$internal
  @override
  $ProviderElement<SystemSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SystemSettings create(Ref ref) {
    return systemSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemSettings>(value),
    );
  }
}

String _$systemSettingsHash() => r'fe154ad6b5f4689d84626ed94f4c70bbbf9a3b9e';
