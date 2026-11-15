// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_preference.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Unit for new physical sizes, from the device's region. The Units setting
/// (M1 T14) will take precedence over this.

@ProviderFor(preferredLengthUnit)
final preferredLengthUnitProvider = PreferredLengthUnitProvider._();

/// Unit for new physical sizes, from the device's region. The Units setting
/// (M1 T14) will take precedence over this.

final class PreferredLengthUnitProvider
    extends $FunctionalProvider<LengthUnit, LengthUnit, LengthUnit>
    with $Provider<LengthUnit> {
  /// Unit for new physical sizes, from the device's region. The Units setting
  /// (M1 T14) will take precedence over this.
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
    r'eb2fd93f28edcdf66c40fd631b111f0e5a61e9e2';
