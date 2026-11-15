import 'dart:ui' show PlatformDispatcher;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'length_unit.dart';

part 'unit_preference.g.dart';

/// Regions where canvas sizes are usually given in inches.
const _inchRegions = {'US', 'LR', 'MM'};

/// Inches for the US, Liberia, and Myanmar; centimeters elsewhere.
LengthUnit lengthUnitForRegion(String? countryCode) =>
    _inchRegions.contains(countryCode?.toUpperCase())
    ? LengthUnit.inches
    : LengthUnit.centimeters;

/// Unit for new physical sizes, from the device's region. The Units setting
/// (M1 T14) will take precedence over this.
@riverpod
LengthUnit preferredLengthUnit(Ref ref) =>
    lengthUnitForRegion(PlatformDispatcher.instance.locale.countryCode);
