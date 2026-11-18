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

/// What the shader draws: one tone aid with its settings.
class ToneParams {
  const ToneParams.gray() : mode = ToneAid.gray, bands = 0, palette = null;

  const ToneParams.values(this.bands)
    : mode = ToneAid.valueBands,
      palette = null;

  const ToneParams.colors(Palette this.palette)
    : mode = ToneAid.colors,
      bands = 0;

  /// Gray, values or colors (never none).
  final ToneAid mode;
  final int bands;
  final Palette? palette;

  /// Most palette colors the shader takes.
  static const maxColors = 16;

  /// Sets [shader]'s uniforms to draw an image of [size] (in the canvas's
  /// local coordinates) with these settings. The image sampler is set
  /// separately.
  void applyTo(ui.FragmentShader shader, ui.Size size) {
    var i = 0;
    void set(double v) => shader.setFloat(i++, v);
    set(size.width);
    set(size.height);
    set(switch (mode) {
      ToneAid.gray || ToneAid.none => 0,
      ToneAid.valueBands => 1,
      ToneAid.colors => 2,
    });
    set(bands.toDouble());
    final colors = palette?.colors ?? const [];
    final count = colors.length.clamp(0, maxColors);
    set(count.toDouble());
    final rgb = palette?.srgb8 ?? const [];
    // uLab[16], then uRgb[16], each a vec4 (w unused).
    for (var c = 0; c < maxColors; c++) {
      final lab = c < count ? colors[c] : null;
      set(lab?.l ?? 0);
      set(lab?.a ?? 0);
      set(lab?.b ?? 0);
      set(0);
    }
    for (var c = 0; c < maxColors; c++) {
      final (r, g, b) = c < count ? rgb[c] : (0, 0, 0);
      set(r / 255);
      set(g / 255);
      set(b / 255);
      set(0);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ToneParams &&
      other.mode == mode &&
      other.bands == bands &&
      other.palette == palette;

  @override
  int get hashCode => Object.hash(mode, bands, palette);
}
