// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_info.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loaded before `runApp` and supplied as an override (see `main.dart`), so
/// repositories can read it synchronously.

@ProviderFor(deviceInfo)
final deviceInfoProvider = DeviceInfoProvider._();

/// Loaded before `runApp` and supplied as an override (see `main.dart`), so
/// repositories can read it synchronously.

final class DeviceInfoProvider
    extends $FunctionalProvider<DeviceInfo, DeviceInfo, DeviceInfo>
    with $Provider<DeviceInfo> {
  /// Loaded before `runApp` and supplied as an override (see `main.dart`), so
  /// repositories can read it synchronously.
  DeviceInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceInfoHash();

  @$internal
  @override
  $ProviderElement<DeviceInfo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceInfo create(Ref ref) {
    return deviceInfo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceInfo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceInfo>(value),
    );
  }
}

String _$deviceInfoHash() => r'd76d7a777c428d0d3a86d5731c02ba60d6d388a8';
