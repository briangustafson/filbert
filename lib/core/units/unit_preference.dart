import 'dart:ui' show PlatformDispatcher;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../settings/app_settings.dart';
import 'length_unit.dart';

part 'unit_preference.g.dart';

/// Regions where canvas sizes are usually given in inches.
const _inchRegions = {'US', 'LR', 'MM'};

/// Inches for the US, Liberia, and Myanmar; centimeters elsewhere.
LengthUnit lengthUnitForRegion(String? countryCode) =>
    _inchRegions.contains(countryCode?.toUpperCase())
    ? LengthUnit.inches
    : LengthUnit.centimeters;

/// Unit for new physical sizes: the Units setting, or with Automatic (the
/// default) the device's region.
@riverpod
LengthUnit preferredLengthUnit(Ref ref) {
  final setting =
      ref.watch(appSettingsProvider).value?.units ?? UnitsSetting.automatic;
  return switch (setting) {
    UnitsSetting.inches => LengthUnit.inches,
    UnitsSetting.centimeters => LengthUnit.centimeters,
    UnitsSetting.automatic => lengthUnitForRegion(
      PlatformDispatcher.instance.locale.countryCode,
    ),
  };
}
