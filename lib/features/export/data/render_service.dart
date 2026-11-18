import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/files/file_store.dart';
import '../../../core/imaging/edits_hash.dart';
import '../../../core/imaging/image_metadata.dart';
import '../../../core/imaging/render_geometry.dart';
import '../../../core/imaging/tone_map.dart';
import '../../photos/data/image_renderer.dart';
import '../../photos/domain/project_image.dart';
import '../../view_aids/data/palette_service.dart';
import '../../view_aids/domain/grid_layout.dart';
import '../../view_aids/domain/view_aids.dart';
import '../domain/export_options.dart';
import 'export_pipeline.dart';

part 'render_service.g.dart';

/// Full-resolution exports with the viewing aids burned in (m2-design
/// §5.4).
abstract interface class RenderService {
  /// [image]'s edited view at full size (long edge at most
  /// [OpenCvRenderService.maxLongEdge]) with [options], as a JPEG in the
  /// exports cache. The same image and options give the same file while the
  /// app runs.
  Future<File> export(ProjectImage image, ExportOptions options);
}

class OpenCvRenderService implements RenderService {
  OpenCvRenderService({required this._files, required this._palettes});

  /// Longest edge of an export, in pixels.
  static const maxLongEdge = 6000;

  final FileStore _files;
  final PaletteService _palettes;
  final _inFlight = <String, Future<File>>{};

  @override
  Future<File> export(ProjectImage image, ExportOptions options) {
    final name =
        '${image.id}-${editsHash(image.edits)}-${options.cacheKey}.jpg';
    final pending = _inFlight[name];
    if (pending != null) return pending;
    final future =
        _export(
          image,
          options,
          File('${_files.exportsDir.path}/$name'),
        ).whenComplete(() {
          // A block: returning the removed future would make whenComplete wait
          // for itself.
          _inFlight.remove(name);
        });
    _inFlight[name] = future;
    return future;
  }

  Future<File> _export(
    ProjectImage image,
    ExportOptions options,
    File target,
  ) async {
    if (await target.exists()) return target;
    final (w, h) = RenderPlan.forEdits(
      sourceWidth: image.width,
      sourceHeight: image.height,
      edits: image.edits,
      maxLongEdge: maxLongEdge,
    ).outputSize;

    // The compare photo first, toned and stretched to this photo's size, so
    // only one decoded original is in memory at a time.
    TransferableTypedData? other;
    final compareWith = options.compareWith;
    if (compareWith != null) {
      final tone = await _toneFor(compareWith, options);
      final (rgba, plan) = await _decode(compareWith);
      other = await _layerInIsolate(rgba, plan, tone, (w, h));
    }

    final tone = await _toneFor(image, options);
    final grid = options.grid;
    final exportGrid = grid == null
        ? null
        : ExportGrid(
            layout: GridLayout.of(
              grid,
              photoWidth: w.toDouble(),
              photoHeight: h.toDouble(),
              canvasWidth: options.canvas?.width,
              canvasHeight: options.canvas?.height,
            ),
            argb: gridColorArgb(grid.color),
            widthPx: gridLineExportPx(grid.width, math.max(w, h)),
          );
    final (rgba, plan) = await _decode(image);
    if (plan.outputSize != (w, h)) {
      throw StateError('Planned $w×$h, decoded for ${plan.outputSize}');
    }
    final jpeg = await _composeInIsolate(
      rgba,
      plan,
      tone,
      other,
      options.opacity,
      exportGrid,
    );
    return _writeAtomically(target, jpeg);
  }

  Future<ToneMap?> _toneFor(ProjectImage image, ExportOptions options) async =>
      switch (options.tone) {
        ToneAid.none => null,
        ToneAid.gray => ToneMap.gray(),
        ToneAid.valueBands => ToneMap.values(options.bands),
        // The live view's palette (same cache), so the colors match.
        ToneAid.colors => ToneMap.colors(
          await _palettes.palette(image, options.colors),
        ),
      };

  Future<(Uint8List, RenderPlan)> _decode(ProjectImage image) async {
    final extension = extensionForMimeType[image.mimeType];
    if (extension == null) {
      throw UnsupportedImageException('Unknown type ${image.mimeType}');
    }
    final bytes = await _files.blobFile(image.blobId, extension).readAsBytes();
    return decodeForRender(bytes, image.edits, maxLongEdge);
  }

  Future<File> _writeAtomically(File target, Uint8List bytes) async {
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      return await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }
}

/// Top-level so the isolate closures capture only sendable values.
Future<TransferableTypedData> _layerInIsolate(
  Uint8List rgba,
  RenderPlan plan,
  ToneMap? tone,
  (int, int) size,
) {
  final input = TransferableTypedData.fromList([rgba]);
  return Isolate.run(() {
    final layer = renderLayer(
      input.materialize().asUint8List(),
      plan,
      tone: tone,
      size: size,
    );
    try {
      return TransferableTypedData.fromList([layer.data]);
    } finally {
      layer.dispose();
    }
  }, debugName: 'export layer');
}

Future<Uint8List> _composeInIsolate(
  Uint8List rgba,
  RenderPlan plan,
  ToneMap? tone,
  TransferableTypedData? other,
  double opacity,
  ExportGrid? grid,
) {
  final input = TransferableTypedData.fromList([rgba]);
  return Isolate.run(() {
    final layer = renderLayer(
      input.materialize().asUint8List(),
      plan,
      tone: tone,
    );
    try {
      compose(
        layer,
        other: other?.materialize().asUint8List(),
        opacity: opacity,
        grid: grid,
      );
      return encodeExportJpeg(layer);
    } finally {
      layer.dispose();
    }
  }, debugName: 'export');
}

@Riverpod(keepAlive: true)
RenderService renderService(Ref ref) => OpenCvRenderService(
  files: ref.watch(fileStoreProvider),
  palettes: ref.watch(paletteServiceProvider),
);
