import 'package:filbert/core/units/length_unit.dart';
import 'package:filbert/core/units/unit_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inches in the US, Liberia, and Myanmar', () {
    for (final code in ['US', 'us', 'LR', 'MM']) {
      expect(lengthUnitForRegion(code), LengthUnit.inches, reason: code);
    }
  });

  test('centimeters elsewhere and when the region is unknown', () {
    for (final code in ['GB', 'CA', 'DE', 'JP', null]) {
      expect(lengthUnitForRegion(code), LengthUnit.centimeters, reason: code);
    }
  });
}
