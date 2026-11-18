// The viewing-aid shader matches the reference math in tone.dart
// (m2-design §5.1, §7): every pixel of a test image, drawn through the
// shader, within [tolerance] levels of the CPU result. With Compare, a
// second image is toned too and the two mixed in sRGB at the opacity
// (§3.4).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:filbert/core/imaging/palette.dart';
import 'package:filbert/core/imaging/tone.dart';
import 'package:filbert/features/view_aids/ui/tone_shader.dart';
import 'package:flutter_test/flutter_test.dart';

/// GPU float math and 8-bit rounding.
const tolerance = 2;

void main() {
  late ui.FragmentProgram program;
  late ui.Image image, otherImage;
  late Uint8List source, other;
  const w = 32, h = 32;

  setUpAll(() async {
    program = await ui.FragmentProgram.fromAsset('shaders/view_aids.frag');
    // Every pixel a different color: an even walk through the sRGB cube,
    // including black, white, grays and saturated primaries.
    source = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      final r = (i % 16) * 17, g = (i ~/ 16 % 8) * 36, b = (i ~/ 128) * 36;
      source.setAll(i * 4, [r, g.clamp(0, 255), b.clamp(0, 255), 255]);
    }
    for (final (i, gray) in [0, 64, 128, 192, 255].indexed) {
      source.setAll((w * h - 5 + i) * 4, [gray, gray, gray, 255]);
    }
    // The compare photo: the same colors in reverse order, so every pixel
    // pairs two different colors.
    other = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      other.setAll(i * 4, source.sublist((w * h - 1 - i) * 4, (w * h - i) * 4));
    }
    image = await _toImage(source, w, h);
    otherImage = await _toImage(other, w, h);
  });

  Future<Uint8List> shade(ToneParams tone, {CompareParams? compare}) async {
    final shader = program.fragmentShader();
    AidParams(
      tone,
      compare: compare,
    ).applyTo(shader, const ui.Size(w * 1.0, h * 1.0));
    shader.setImageSampler(0, image);
    shader.setImageSampler(1, compare == null ? image : otherImage);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, w * 1.0, h * 1.0),
      ui.Paint()..shader = shader,
    );
    final out = await recorder.endRecording().toImage(w, h);
    final data = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  }

  void expectMatches(
    Uint8List actual,
    (int, int, int) Function(int r, int g, int b) expected, {
    // Compare: the other photo's expected pixel and its weight.
    (int, int, int) Function(int r, int g, int b)? expectedOther,
    double opacity = 0,
  }) {
    var worst = 0;
    final misses = <String>[];
    for (var i = 0; i < w * h; i++) {
      final (r, g, b) = (source[i * 4], source[i * 4 + 1], source[i * 4 + 2]);
      var (er, eg, eb) = expected(r, g, b);
      if (expectedOther != null) {
        final (or, og, ob) = expectedOther(
          other[i * 4],
          other[i * 4 + 1],
          other[i * 4 + 2],
        );
        int mix(int a, int b) => (a + (b - a) * opacity).round();
        (er, eg, eb) = (mix(er, or), mix(eg, og), mix(eb, ob));
      }
      final got = (actual[i * 4], actual[i * 4 + 1], actual[i * 4 + 2]);
      final diff = [
        (got.$1 - er).abs(),
        (got.$2 - eg).abs(),
        (got.$3 - eb).abs(),
      ].reduce((x, y) => x > y ? x : y);
      if (diff > worst) worst = diff;
      if (diff > tolerance && misses.length < 5) {
        misses.add('($r, $g, $b) → $got, expected ($er, $eg, $eb)');
      }
    }
    expect(misses, isEmpty, reason: 'worst difference $worst');
  }

  int to8(double c) => (c * 255).round().clamp(0, 255);

  test('gray keeps each pixel\'s luminance', () async {
    expectMatches(await shade(const ToneParams.gray()), (r, g, b) {
      final gray = to8(grayOf(r / 255, g / 255, b / 255));
      return (gray, gray, gray);
    });
  });

  for (final bands in [2, 5, 9]) {
    test('values in $bands bands', () async {
      expectMatches(await shade(ToneParams.values(bands)), (r, g, b) {
        final band = valueBand(lStar(r / 255, g / 255, b / 255), bands);
        final gray = to8(bandGray(band, bands));
        return (gray, gray, gray);
      });
    });
  }

  test('colors take the nearest palette color', () async {
    // A spread palette, so nearest-color ties are rare.
    final palette = computePalette(source, count: 12);
    final labs = palette.colors;
    final rgb = palette.srgb8;
    expectMatches(await shade(ToneParams.colors(palette)), (r, g, b) {
      return rgb[nearestColor(srgbToLab(r / 255, g / 255, b / 255), labs)];
    });
  });

  test('colors with the most palette colors', () async {
    final palette = computePalette(source, count: ToneParams.maxColors);
    expect(palette.colors, hasLength(ToneParams.maxColors));
    final rgb = palette.srgb8;
    expectMatches(await shade(ToneParams.colors(palette)), (r, g, b) {
      return rgb[nearestColor(
        srgbToLab(r / 255, g / 255, b / 255),
        palette.colors,
      )];
    });
  });

  group('compare', () {
    (int, int, int) plain(int r, int g, int b) => (r, g, b);
    (int, int, int) gray(int r, int g, int b) {
      final v = to8(grayOf(r / 255, g / 255, b / 255));
      return (v, v, v);
    }

    for (final opacity in [0.0, 0.5, 1.0]) {
      test('plain photos mixed at ${(opacity * 100).round()} %', () async {
        expectMatches(
          await shade(
            const ToneParams.plain(),
            compare: CompareParams(opacity: opacity),
          ),
          plain,
          expectedOther: plain,
          opacity: opacity,
        );
      });

      test('gray applied to each before mixing at '
          '${(opacity * 100).round()} %', () async {
        expectMatches(
          await shade(
            const ToneParams.gray(),
            compare: CompareParams(opacity: opacity),
          ),
          gray,
          expectedOther: gray,
          opacity: opacity,
        );
      });
    }

    test('values in each photo, mixed at 30 %', () async {
      (int, int, int) values(int r, int g, int b) {
        final v = to8(
          bandGray(valueBand(lStar(r / 255, g / 255, b / 255), 4), 4),
        );
        return (v, v, v);
      }

      expectMatches(
        await shade(
          const ToneParams.values(4),
          compare: const CompareParams(opacity: 0.3),
        ),
        values,
        expectedOther: values,
        opacity: 0.3,
      );
    });

    test('colors: each photo with its own palette', () async {
      final mine = computePalette(source, count: 6);
      // A different palette for the other photo: only its darker half.
      final theirs = computePalette(
        Uint8List.fromList([
          for (var i = 0; i < w * h; i++)
            if (lStar(
                  other[i * 4] / 255,
                  other[i * 4 + 1] / 255,
                  other[i * 4 + 2] / 255,
                ) <
                50)
              ...other.sublist(i * 4, i * 4 + 4),
        ]),
        count: 5,
      );
      expect(theirs, isNot(mine));
      (int, int, int) Function(int, int, int) nearestIn(Palette p) =>
          (r, g, b) =>
              p.srgb8[nearestColor(
                srgbToLab(r / 255, g / 255, b / 255),
                p.colors,
              )];
      expectMatches(
        await shade(
          ToneParams.colors(mine),
          compare: CompareParams(opacity: 0.5, palette: theirs),
        ),
        nearestIn(mine),
        expectedOther: nearestIn(theirs),
        opacity: 0.5,
      );
    });
  });
}

Future<ui.Image> _toImage(Uint8List rgba, int w, int h) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  return (await (await descriptor.instantiateCodec()).getNextFrame()).image;
}
