import 'package:filbert/features/projects/domain/project.dart';
import 'package:filbert/features/projects/domain/size_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every preset is portrait and within bounds', () {
    for (final (w, h) in [
      ...imperialSizePresets,
      ...metricSizePresets,
      ...ratioPresets,
    ]) {
      expect(w <= h, isTrue, reason: '$w×$h');
      expect(w >= minDimension && h <= maxDimension, isTrue);
    }
  });

  test('presets by unit', () {
    expect(sizePresetsFor(LengthUnit.inches), contains((11.0, 14.0)));
    expect(sizePresetsFor(LengthUnit.centimeters), contains((50.0, 70.0)));
  });

  test('labels', () {
    expect(sizeLabel(const NoSize()), 'No size');
    expect(sizeLabel(const RatioSize(4, 5)), '4:5');
    expect(sizeLabel(const RatioSize(1.618, 1)), '1.618:1');
    expect(
      sizeLabel(const PhysicalSize(11, 14, LengthUnit.inches)),
      '11 × 14 in',
    );
    expect(
      sizeLabel(const PhysicalSize(70, 40.5, LengthUnit.centimeters)),
      '70 × 40.5 cm',
    );
  });

  test('formatDimension trims trailing zeros', () {
    expect(formatDimension(11), '11');
    expect(formatDimension(40.5), '40.5');
    expect(formatDimension(0.1), '0.1');
    expect(formatDimension(1.23456), '1.235');
  });

  test('parseDimension accepts 0.1–1000, with . or ,', () {
    expect(parseDimension('12'), 12);
    expect(parseDimension(' 40.5 '), 40.5);
    expect(parseDimension('40,5'), 40.5);
    expect(parseDimension('0.1'), 0.1);
    expect(parseDimension('1000'), 1000);
    for (final bad in ['', 'abc', '0', '0.05', '-3', '1000.1', 'NaN', 'inf']) {
      expect(parseDimension(bad), isNull, reason: bad);
    }
  });

  test('orientation', () {
    expect(orientationOf(8, 10), CanvasOrientation.portrait);
    expect(orientationOf(10, 8), CanvasOrientation.landscape);
    expect(orientationOf(12, 12), CanvasOrientation.square);

    expect(orient((8, 10), CanvasOrientation.landscape), (10.0, 8.0));
    expect(orient((10, 8), CanvasOrientation.portrait), (8.0, 10.0));
    expect(orient((5, 5), CanvasOrientation.landscape), (5.0, 5.0));
    expect(sameDims((8, 10), (10, 8)), isTrue);
    expect(sameDims((8, 10), (8, 12)), isFalse);
  });

  test('withOrientation keeps kind and unit', () {
    expect(
      withOrientation(
        const PhysicalSize(11, 14, LengthUnit.inches),
        CanvasOrientation.landscape,
      ),
      const PhysicalSize(14, 11, LengthUnit.inches),
    );
    expect(
      withOrientation(const RatioSize(5, 4), CanvasOrientation.portrait),
      const RatioSize(4, 5),
    );
    expect(
      withOrientation(const NoSize(), CanvasOrientation.landscape),
      const NoSize(),
    );
    expect(dimsOf(const NoSize()), isNull);
    expect(dimsOf(const RatioSize(4, 5)), (4.0, 5.0));
  });
}
