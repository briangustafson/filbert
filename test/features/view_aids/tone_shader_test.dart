// The viewing-aid shader matches the reference math in tone.dart
// (m2-design §5.1, §7): every pixel of a test image, drawn through the
// shader, within [tolerance] levels of the CPU result.

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
  late ui.Image image;
  late Uint8List source;
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
    final buffer = await ui.ImmutableBuffer.fromUint8List(source);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    image = (await (await descriptor.instantiateCodec()).getNextFrame()).image;
  });

  Future<Uint8List> shade(ToneParams params) async {
    final shader = program.fragmentShader();
    params.applyTo(shader, const ui.Size(w * 1.0, h * 1.0));
    shader.setImageSampler(0, image);
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
    (int, int, int) Function(int r, int g, int b) expected,
  ) {
    var worst = 0;
    final misses = <String>[];
    for (var i = 0; i < w * h; i++) {
      final (r, g, b) = (source[i * 4], source[i * 4 + 1], source[i * 4 + 2]);
      final (er, eg, eb) = expected(r, g, b);
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
}
