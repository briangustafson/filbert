import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:filbert/core/imaging/palette.dart';
import 'package:filbert/core/imaging/tone.dart';
import 'package:flutter_test/flutter_test.dart';

/// RGBA pixels: each color covers its share of [size] pixels, optionally with
/// per-channel noise of up to ±[noise] levels.
Uint8List flatColors(
  List<(int, int, int, int share)> colors, {
  int size = 10000,
  int noise = 0,
  int seed = 1,
}) {
  final random = math.Random(seed);
  final total = colors.fold(0, (sum, c) => sum + c.$4);
  final out = BytesBuilder();
  for (final (r, g, b, share) in colors) {
    for (var i = 0; i < size * share ~/ total; i++) {
      int jitter(int v) => noise == 0
          ? v
          : (v + random.nextInt(2 * noise + 1) - noise).clamp(0, 255);
      out.add([jitter(r), jitter(g), jitter(b), 255]);
    }
  }
  return out.toBytes();
}

double deltaE(Lab x, Lab y) => math.sqrt(x.distanceSquaredTo(y));

Lab lab8(int r, int g, int b) => srgbToLab(r / 255, g / 255, b / 255);

void main() {
  // A dark umber, a cadmium red, a sky blue and a warm white, in uneven
  // amounts; listed dark to light.
  const paints = [
    (60, 40, 30, 4),
    (200, 40, 30, 2),
    (120, 170, 220, 3),
    (245, 240, 225, 1),
  ];

  test('recovers the colors of a flat-color image, dark to light', () {
    final palette = computePalette(flatColors(paints), count: 4);
    expect(palette.colors, hasLength(4));
    for (final (i, (r, g, b, _)) in paints.indexed) {
      expect(deltaE(palette.colors[i], lab8(r, g, b)), lessThan(1e-6));
    }
    expect(palette.srgb8, [for (final (r, g, b, _) in paints) (r, g, b)]);
  });

  test('recovers them through noise', () {
    final palette = computePalette(flatColors(paints, noise: 6), count: 4);
    for (final (i, (r, g, b, _)) in paints.indexed) {
      expect(deltaE(palette.colors[i], lab8(r, g, b)), lessThan(1));
    }
  });

  test('fewer distinct colors than asked gives fewer swatches', () {
    expect(computePalette(flatColors(paints), count: 8).colors, hasLength(4));
    final one = computePalette(flatColors([(90, 90, 90, 1)]), count: 8);
    expect(one.srgb8, [(90, 90, 90)]);
  });

  test('is deterministic', () {
    final pixels = flatColors(paints, noise: 40, seed: 3);
    final first = computePalette(pixels, count: 6);
    for (var i = 0; i < 3; i++) {
      expect(computePalette(pixels, count: 6), first);
    }
    expect(first.colors, hasLength(6));
  });

  test('colors are ordered by L*', () {
    final palette = computePalette(
      flatColors(paints, noise: 40, seed: 4),
      count: 12,
    );
    final ls = [for (final c in palette.colors) c.l];
    expect(ls, [...ls]..sort());
  });

  test('ignores a 4th channel and accepts 3 channels', () {
    final rgba = flatColors(paints);
    final rgb = Uint8List.fromList([
      for (var i = 0; i < rgba.length; i += 4) ...rgba.sublist(i, i + 3),
    ]);
    expect(
      computePalette(rgb, count: 4, channels: 3),
      computePalette(rgba, count: 4),
    );
  });

  test('splits a dominant color only when it must', () {
    // 2 colors asked of 3 clumps, one tiny: the tiny one joins its nearest.
    final palette = computePalette(
      flatColors([(20, 20, 20, 50), (230, 230, 230, 49), (235, 225, 225, 1)]),
      count: 2,
    );
    expect(deltaE(palette.colors[0], lab8(20, 20, 20)), lessThan(1e-6));
    expect(palette.colors[1].l, closeTo(lab8(230, 230, 230).l, 0.5));
  });

  test('rejects bad input', () {
    final pixels = flatColors(paints);
    expect(() => computePalette(pixels, count: 0), throwsArgumentError);
    expect(
      () => computePalette(pixels, count: 4, channels: 2),
      throwsArgumentError,
    );
    expect(() => computePalette(Uint8List(0), count: 4), throwsArgumentError);
    expect(() => computePalette(Uint8List(6), count: 4), throwsArgumentError);
  });

  group('JSON', () {
    final palette = computePalette(flatColors(paints), count: 4);

    test('round-trips', () {
      expect(
        Palette.tryFromJson(jsonDecode(jsonEncode(palette.toJson()))),
        palette,
      );
    });

    test('rejects other versions and damaged data', () {
      final json = palette.toJson();
      expect(Palette.tryFromJson({...json, 'v': 2}), isNull);
      expect(Palette.tryFromJson({'v': 1, 'colors': []}), isNull);
      expect(
        Palette.tryFromJson({
          'v': 1,
          'colors': [
            [1, 2],
          ],
        }),
        isNull,
      );
      expect(
        Palette.tryFromJson({
          'v': 1,
          'colors': [
            [1, 'x', 3],
          ],
        }),
        isNull,
      );
      expect(Palette.tryFromJson('palette'), isNull);
    });
  });
}
