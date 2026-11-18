import 'dart:math' as math;

import 'package:filbert/core/imaging/tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lightness', () {
    test('black, white and middle gray', () {
      expect(lStar(0, 0, 0), closeTo(0, 1e-9));
      expect(lStar(1, 1, 1), closeTo(100, 1e-9));
      // 18% reflectance is L* 50, sRGB ≈ 119/255.
      expect(lStarFromY(0.18419), closeTo(50, 0.01));
      expect(grayForLStar(50) * 255, closeTo(119, 0.5));
    });

    test('the sRGB primaries (published L* values)', () {
      expect(lStar(1, 0, 0), closeTo(53.23, 0.05));
      expect(lStar(0, 1, 0), closeTo(87.74, 0.05));
      expect(lStar(0, 0, 1), closeTo(32.30, 0.05));
    });

    test('sRGB transfer round-trips and is continuous at the knee', () {
      for (var c = 0; c <= 255; c++) {
        expect(linearToSrgb(srgbToLinear(c / 255)), closeTo(c / 255, 1e-12));
      }
      expect(srgbToLinear(0.04045), closeTo(0.04045 / 12.92, 1e-12));
    });

    test('L* and luminance invert each other on both sides of the knee', () {
      for (final l in [0.0, 2.0, 7.9, 8.1, 25.0, 50.0, 99.0, 100.0]) {
        expect(lStarFromY(yFromLStar(l)), closeTo(l, 1e-9));
      }
    });
  });

  group('gray', () {
    test('keeps the color\'s L*', () {
      final random = math.Random(1);
      for (var i = 0; i < 200; i++) {
        final (r, g, b) = (
          random.nextDouble(),
          random.nextDouble(),
          random.nextDouble(),
        );
        final gray = grayOf(r, g, b);
        expect(lStar(gray, gray, gray), closeTo(lStar(r, g, b), 1e-9));
      }
    });

    test('a gray stays itself', () {
      expect(grayOf(0.3, 0.3, 0.3), closeTo(0.3, 1e-12));
    });
  });

  group('value bands', () {
    test('equal steps of L*, edges going up', () {
      expect(
        [
          for (final l in [0.0, 19.99, 20.0, 39.99, 40.0, 79.99, 80.0, 100.0])
            valueBand(l, 5),
        ],
        [0, 0, 1, 1, 2, 3, 4, 4],
      );
      expect(valueBand(-1, 5), 0);
      expect(valueBand(101, 5), 4);
      expect(valueBand(49.9, 2), 0);
      expect(valueBand(50, 2), 1);
    });

    test('each band is shown at the middle of its step', () {
      expect(
        [for (var k = 0; k < 5; k++) bandMiddleLStar(k, 5)],
        [10, 30, 50, 70, 90],
      );
      expect(bandGray(2, 5), closeTo(grayForLStar(50), 1e-12));
      final g = bandGray(0, 9);
      expect(lStar(g, g, g), closeTo(100 / 18, 1e-9));
    });
  });

  group('CIELAB', () {
    void expectLab(Lab lab, double l, double a, double b, {double tol = 0.1}) {
      expect(lab.l, closeTo(l, tol), reason: '$lab L*');
      expect(lab.a, closeTo(a, tol), reason: '$lab a*');
      expect(lab.b, closeTo(b, tol), reason: '$lab b*');
    }

    test('white and gray are neutral', () {
      expectLab(srgbToLab(1, 1, 1), 100, 0, 0, tol: 1e-9);
      expectLab(srgbToLab(0, 0, 0), 0, 0, 0, tol: 1e-9);
      expectLab(
        srgbToLab(0.5, 0.5, 0.5),
        lStar(0.5, 0.5, 0.5),
        0,
        0,
        tol: 1e-9,
      );
    });

    test('the sRGB primaries (published Lab values)', () {
      expectLab(srgbToLab(1, 0, 0), 53.24, 80.09, 67.20);
      expectLab(srgbToLab(0, 1, 0), 87.73, -86.18, 83.18);
      expectLab(srgbToLab(0, 0, 1), 32.30, 79.19, -107.86);
    });

    test('L* in Lab equals lStar()', () {
      expect(srgbToLab(0.2, 0.6, 0.9).l, closeTo(lStar(0.2, 0.6, 0.9), 1e-9));
    });

    test('round-trips through sRGB', () {
      final random = math.Random(2);
      for (var i = 0; i < 200; i++) {
        final rgb = (
          random.nextDouble(),
          random.nextDouble(),
          random.nextDouble(),
        );
        final (r, g, b) = labToSrgb(srgbToLab(rgb.$1, rgb.$2, rgb.$3));
        expect(r, closeTo(rgb.$1, 1e-9));
        expect(g, closeTo(rgb.$2, 1e-9));
        expect(b, closeTo(rgb.$3, 1e-9));
      }
    });

    test('colors outside sRGB are clamped', () {
      final (r, g, b) = labToSrgb(const Lab(50, 120, 0));
      for (final c in [r, g, b]) {
        expect(c, inInclusiveRange(0, 1));
      }
    });

    test('nearest palette color by ΔE76', () {
      const palette = [Lab(10, 0, 0), Lab(50, 40, 0), Lab(90, 0, -20)];
      expect(nearestColor(const Lab(12, 3, 3), palette), 0);
      expect(nearestColor(const Lab(55, 30, 5), palette), 1);
      expect(nearestColor(const Lab(80, 0, -30), palette), 2);
      // Ties go to the first.
      expect(nearestColor(const Lab(30, 20, 0), palette), 0);
    });
  });
}
