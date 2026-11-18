import 'dart:ui' as ui;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/imaging/palette.dart';
import '../domain/view_aids.dart';

part 'tone_shader.g.dart';

/// The viewing-aid shader (`shaders/view_aids.frag`, m2-design §5.3),
/// loaded once.
@Riverpod(keepAlive: true)
Future<ui.FragmentProgram> toneProgram(Ref ref) =>
    ui.FragmentProgram.fromAsset('shaders/view_aids.frag');

/// The tone part of what the shader draws: one tone aid with its settings,
/// or [ToneParams.plain] for none (Compare alone).
class ToneParams {
  const ToneParams.plain() : mode = ToneAid.none, bands = 0, palette = null;

  const ToneParams.gray() : mode = ToneAid.gray, bands = 0, palette = null;

  const ToneParams.values(this.bands)
    : mode = ToneAid.valueBands,
      palette = null;

  const ToneParams.colors(Palette this.palette)
    : mode = ToneAid.colors,
      bands = 0;

  final ToneAid mode;
  final int bands;

  /// Colors: this photo's palette.
  final Palette? palette;

  /// Most palette colors the shader takes.
  static const maxColors = 16;

  @override
  bool operator ==(Object other) =>
      other is ToneParams &&
      other.mode == mode &&
      other.bands == bands &&
      other.palette == palette;

  @override
  int get hashCode => Object.hash(mode, bands, palette);
}

/// Compare (m2-design §3.4): the other photo blended at [opacity]. With
/// Colors on, [palette] is the other photo's own palette.
class CompareParams {
  const CompareParams({required this.opacity, this.palette});

  /// 0 shows only this photo, 1 only the other.
  final double opacity;
  final Palette? palette;

  @override
  bool operator ==(Object other) =>
      other is CompareParams &&
      other.opacity == opacity &&
      other.palette == palette;

  @override
  int get hashCode => Object.hash(opacity, palette);
}

/// Everything the shader draws: the tone, and optionally a compare photo
/// (whose image is set as the second sampler).
class AidParams {
  const AidParams(this.tone, {this.compare});

  final ToneParams tone;
  final CompareParams? compare;

  /// Sets [shader]'s uniforms to draw an image of [size] (in the canvas's
  /// local coordinates) with these settings. The image samplers are set
  /// separately.
  void applyTo(ui.FragmentShader shader, ui.Size size) {
    var i = 0;
    void set(double v) => shader.setFloat(i++, v);

    // uCount, then uLab[16] and uRgb[16], each a vec4 (w unused).
    void palette(Palette? palette) {
      final colors = palette?.colors ?? const [];
      final count = colors.length.clamp(0, ToneParams.maxColors);
      set(count.toDouble());
      final rgb = palette?.srgb8 ?? const [];
      for (var c = 0; c < ToneParams.maxColors; c++) {
        final lab = c < count ? colors[c] : null;
        set(lab?.l ?? 0);
        set(lab?.a ?? 0);
        set(lab?.b ?? 0);
        set(0);
      }
      for (var c = 0; c < ToneParams.maxColors; c++) {
        final (r, g, b) = c < count ? rgb[c] : (0, 0, 0);
        set(r / 255);
        set(g / 255);
        set(b / 255);
        set(0);
      }
    }

    set(size.width);
    set(size.height);
    set(switch (tone.mode) {
      ToneAid.gray => 0,
      ToneAid.valueBands => 1,
      ToneAid.colors => 2,
      ToneAid.none => 3,
    });
    set(tone.bands.toDouble());
    palette(tone.palette);
    final compare = this.compare;
    set(compare == null ? 0 : 1);
    set(compare?.opacity.clamp(0.0, 1.0) ?? 0);
    palette(compare?.palette);
  }

  @override
  bool operator ==(Object other) =>
      other is AidParams && other.tone == tone && other.compare == compare;

  @override
  int get hashCode => Object.hash(tone, compare);
}
