// The export's fast tone maps agree with tone.dart, the reference the live
// shader is also pinned to (m2-design §5.1, §5.4).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:filbert/core/imaging/palette.dart';
import 'package:filbert/core/imaging/tone.dart';
import 'package:filbert/core/imaging/tone_map.dart';
import 'package:flutter_test/flutter_test.dart';

int to8(double c) => (c * 255).round().clamp(0, 255);

void main() {
  // Every gray, a 32-step walk through the cube, and random colors.
  final colors = <(int, int, int)>[
    for (var v = 0; v < 256; v++) (v, v, v),
    for (var r = 0; r < 256; r += 8)
      for (var g = 0; g < 256; g += 8)
        for (var b = 0; b < 256; b += 8) (r, g, b),
  ];
  final random = math.Random(7);
  for (var i = 0; i < 20000; i++) {
    colors.add((random.nextInt(256), random.nextInt(256), random.nextInt(256)));
  }

  Uint8List bgr() => Uint8List.fromList([
    for (final (r, g, b) in colors) ...[b, g, r],
  ]);

  void expectMap(
    ToneMap map,
    (int, int, int) Function(int r, int g, int b) expected, {
    int tolerance = 0,
  }) {
    final pixels = bgr();
    map.apply(pixels);
    final misses = <String>[];
    for (final (i, (r, g, b)) in colors.indexed) {
      final (er, eg, eb) = expected(r, g, b);
      final got = (pixels[i * 3 + 2], pixels[i * 3 + 1], pixels[i * 3]);
      final d = [
        (got.$1 - er).abs(),
        (got.$2 - eg).abs(),
        (got.$3 - eb).abs(),
      ].reduce(math.max);
      if (d > tolerance && misses.length < 5) {
        misses.add('($r, $g, $b) → $got, expected ($er, $eg, $eb)');
      }
    }
    expect(misses, isEmpty);
  }

  test('gray matches grayOf (within rounding)', () {
    expectMap(ToneMap.gray(), (r, g, b) {
      final v = to8(grayOf(r / 255, g / 255, b / 255));
      return (v, v, v);
    }, tolerance: 1);
  });

  test('gray keeps every gray level', () {
    final pixels = Uint8List.fromList([
      for (var v = 0; v < 256; v++) ...[v, v, v],
    ]);
    ToneMap.gray().apply(pixels);
    for (var v = 0; v < 256; v++) {
      expect(pixels[v * 3], v, reason: 'level $v');
    }
  });

  for (final bands in [2, 3, 5, 9]) {
    test('values in $bands bands match valueBand exactly', () {
      expectMap(ToneMap.values(bands), (r, g, b) {
        final band = valueBand(lStar(r / 255, g / 255, b / 255), bands);
        final v = to8(bandGray(band, bands));
        return (v, v, v);
      });
    });
  }

  test('colors match nearestColor exactly', () {
    final source = Uint8List.fromList([
      for (final (r, g, b) in colors) ...[r, g, b, 255],
    ]);
    for (final count in [2, 8, 16]) {
      final palette = computePalette(source, count: count);
      final rgb = palette.srgb8;
      expectMap(
        ToneMap.colors(palette),
        (r, g, b) =>
            rgb[nearestColor(
              srgbToLab(r / 255, g / 255, b / 255),
              palette.colors,
            )],
      );
    }
  });

  group('mixInto', () {
    test('0 keeps this photo, 1 gives the other', () {
      final a = Uint8List.fromList([0, 100, 255]);
      final b = Uint8List.fromList([255, 0, 10]);
      mixInto(a, b, 0);
      expect(a, [0, 100, 255]);
      mixInto(a, b, 1);
      expect(a, [255, 0, 10]);
    });

    test('in between: the rounded linear mix of the levels', () {
      final rnd = math.Random(3);
      final a = Uint8List.fromList([
        for (var i = 0; i < 3000; i++) rnd.nextInt(256),
      ]);
      final b = Uint8List.fromList([
        for (var i = 0; i < 3000; i++) rnd.nextInt(256),
      ]);
      for (final o in [0.3, 0.5, 0.86]) {
        final out = Uint8List.fromList(a);
        mixInto(out, b, o);
        for (var i = 0; i < a.length; i++) {
          final expected = a[i] + (b[i] - a[i]) * o;
          expect((out[i] - expected).abs(), lessThanOrEqualTo(0.5 + 1e-6));
        }
      }
    });
  });
}
