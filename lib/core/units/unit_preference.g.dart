// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_preference.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Unit for new physical sizes: the Units setting, or with Automatic (the
/// default) the device's region.

@ProviderFor(preferredLengthUnit)
final preferredLengthUnitProvider = PreferredLengthUnitProvider._();

/// Unit for new physical sizes: the Units setting, or with Automatic (the
/// default) the device's region.

final class PreferredLengthUnitProvider
    extends $FunctionalProvider<LengthUnit, LengthUnit, LengthUnit>
    with $Provider<LengthUnit> {
  /// Unit for new physical sizes: the Units setting, or with Automatic (the
  /// default) the device's region.
  PreferredLengthUnitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferredLengthUnitProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferredLengthUnitHash();

  @$internal
  @override
  $ProviderElement<LengthUnit> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LengthUnit create(Ref ref) {
    return preferredLengthUnit(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LengthUnit value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LengthUnit>(value),
    );
  }
}

String _$preferredLengthUnitHash() =>
    r'6cf16d434b183ae7bdc77cf357b98f10be807a8e';
