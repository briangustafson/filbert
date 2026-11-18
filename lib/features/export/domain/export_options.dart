import 'dart:convert';

import '../../../core/imaging/edits_hash.dart';
import '../../photos/domain/project_image.dart';
import '../../projects/domain/project.dart';
import '../../view_aids/domain/view_aids.dart';
import '../../view_aids/domain/view_prefs.dart';

/// What an export includes (m2-design §3.5, §5.4): the tone aid, the grid,
/// the compare overlay. Without any, it's the plain edited view at full
/// size.
class ExportOptions {
  const ExportOptions({
    this.tone = ToneAid.none,
    this.bands = 5,
    this.colors = 8,
    this.grid,
    this.canvas,
    this.compareWith,
    this.opacity = 0.5,
  });

  /// The aids that are on, with the project's settings. [compareWith] is
  /// the photo Compare overlays (resolved by the photo screen), [size] the
  /// project's size (for a spacing grid).
  factory ExportOptions.fromAids(
    ViewAids aids,
    ViewPrefs prefs, {
    ProjectSize? size,
    ProjectImage? compareWith,
  }) => ExportOptions(
    tone: aids.tone,
    bands: prefs.values.bands,
    colors: prefs.colors.count,
    grid: aids.grid ? prefs.grid : null,
    canvas: size is PhysicalSize ? size : null,
    compareWith: aids.compare ? compareWith : null,
    opacity: prefs.compare.opacity,
  );

  /// Gray, Values (in [bands] bands), Colors (with [colors] colors) or none.
  final ToneAid tone;
  final int bands;
  final int colors;

  /// The grid to draw; null for none.
  final GridPrefs? grid;

  /// The project's physical size, for a spacing grid.
  final PhysicalSize? canvas;

  /// The photo to overlay; null for no Compare.
  final ProjectImage? compareWith;
  final double opacity;

  bool get hasAids =>
      tone != ToneAid.none || grid != null || compareWith != null;

  /// These options without the parts turned off in the export sheet.
  ExportOptions without({
    bool tone = false,
    bool grid = false,
    bool compare = false,
  }) => ExportOptions(
    tone: tone ? ToneAid.none : this.tone,
    bands: bands,
    colors: colors,
    grid: grid ? null : this.grid,
    canvas: canvas,
    compareWith: compare ? null : compareWith,
    opacity: opacity,
  );

  /// What decides the output, as canonical JSON: only the settings in use.
  Map<String, Object?> toJson() => {
    if (tone != ToneAid.none) 'tone': tone.name,
    if (tone == ToneAid.valueBands) 'bands': bands,
    if (tone == ToneAid.colors) 'colors': colors,
    if (grid != null) 'grid': grid!.toJson(),
    if (grid != null && canvas != null)
      'canvas': [canvas!.width, canvas!.height, canvas!.unit.name],
    if (compareWith != null) ...{
      'compare': compareWith!.id,
      'compareEdits': editsHash(compareWith!.edits),
      'opacity': opacity,
    },
  };

  /// What a photo saved from an export of [source] records about where it
  /// came from (`images.derived_from_json`, m2-design §4.3).
  String derivedFromJson(ProjectImage source) => jsonEncode({
    'v': 1,
    'imageId': source.id,
    'edits': source.edits.toJson(),
    'aids': {
      if (tone != ToneAid.none)
        'tone': switch (tone) {
          ToneAid.valueBands => 'values',
          _ => tone.name,
        },
      if (tone == ToneAid.valueBands) 'bands': bands,
      if (tone == ToneAid.colors) 'colors': colors,
      if (grid != null) 'grid': grid!.toJson(),
      if (compareWith != null) ...{
        'compareImageId': compareWith!.id,
        'opacity': opacity,
      },
    },
  });

  /// A short, stable hash of [toJson], for the export cache.
  String get cacheKey => stableHash(jsonEncode(toJson()));

  @override
  bool operator ==(Object other) =>
      other is ExportOptions &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}
