import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:canvas_detect/safe_cv.dart' as safe_cv;
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/files/file_store.dart';
import '../../../core/imaging/edits_hash.dart';
import '../../../core/imaging/palette.dart';
import '../../photos/data/image_renderer.dart';
import '../../photos/domain/project_image.dart';

part 'palette_service.g.dart';

/// Limited-colors palettes for photos (m2-design §5.2).
abstract interface class PaletteService {
  /// The photo's palette of up to [count] colors, as edited. Cached in memory
  /// and on disk per (image, edits, count).
  Future<Palette> palette(ProjectImage image, int count);
}

class IsolatePaletteService implements PaletteService {
  IsolatePaletteService({
    required this._files,
    required this._renderer,
    this.memoryEntries = 32,
  });

  /// The palette is computed from the preview downscaled to this long edge.
  static const sampleLongEdge = 256;

  final FileStore _files;
  final ImageRenderer _renderer;

  /// Palettes kept in memory, least recently used dropped first.
  final int memoryEntries;

  final _memory = <String, Palette>{}; // Insertion-ordered.
  final _inFlight = <String, Future<Palette>>{};

  @override
  Future<Palette> palette(ProjectImage image, int count) {
    if (count < 1) throw ArgumentError.value(count, 'count', 'Must be ≥ 1');
    final key = '${image.id}-${editsHash(image.edits)}-palette-$count';
    final cached = _memory.remove(key);
    if (cached != null) {
      _memory[key] = cached; // Most recently used.
      return SynchronousFuture(cached);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;
    // A block body: see OpenCvImageRenderer._render.
    final future = _load(key, image, count).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<Palette> _load(String key, ProjectImage image, int count) async {
    final file = File('${_files.previewsDir.path}/$key.json');
    var palette = await _read(file);
    if (palette == null) {
      final preview = await _renderer.preview(image);
      final bytes = await preview.readAsBytes();
      palette = await Isolate.run<Palette>(
        () => paletteFromEncoded(bytes, count),
        debugName: 'palette',
      );
      await _write(file, palette);
    }
    _memory[key] = palette;
    while (_memory.length > memoryEntries) {
      _memory.remove(_memory.keys.first);
    }
    return palette;
  }

  /// Null if there's no usable cache file.
  static Future<Palette?> _read(File file) async {
    try {
      if (!await file.exists()) return null;
      return Palette.tryFromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static Future<void> _write(File file, Palette palette) async {
    await file.parent.create(recursive: true);
    final name = file.uri.pathSegments.last;
    final temp = File('${file.parent.path}/.$name.tmp');
    try {
      await temp.writeAsString(jsonEncode(palette.toJson()), flush: true);
      await temp.rename(file.path);
    } on FileSystemException catch (e) {
      // The palette is still returned; it's computed again next time.
      debugPrint('Caching palette ${file.path} failed: $e');
      if (await temp.exists()) await temp.delete();
    }
  }
}

/// Decodes an image file ([encoded]: a JPEG or PNG without EXIF rotation,
/// such as a preview), downscales it to
/// [IsolatePaletteService.sampleLongEdge] with area averaging, and computes
/// its palette. Runs OpenCV, so call it in a background isolate.
Palette paletteFromEncoded(Uint8List encoded, int count) {
  final bgr = cv.imdecode(encoded, cv.IMREAD_COLOR);
  if (bgr.isEmpty) {
    bgr.dispose();
    throw const FormatException('Could not decode the image');
  }
  final scale = math.min(
    1.0,
    IsolatePaletteService.sampleLongEdge / math.max(bgr.cols, bgr.rows),
  );
  final small = scale < 1
      ? safe_cv.resize(bgr, (
          math.max(1, (bgr.cols * scale).round()),
          math.max(1, (bgr.rows * scale).round()),
        ), interpolation: cv.INTER_AREA)
      : bgr.clone();
  final rgb = cv.cvtColor(small, cv.COLOR_BGR2RGB);
  try {
    // A copy: the Mat's memory is freed below.
    final pixels = Uint8List.fromList(rgb.data);
    return computePalette(pixels, count: count, channels: 3);
  } finally {
    for (final m in [bgr, small, rgb]) {
      m.dispose();
    }
  }
}

@Riverpod(keepAlive: true)
PaletteService paletteService(Ref ref) => IsolatePaletteService(
  files: ref.watch(fileStoreProvider),
  renderer: ref.watch(imageRendererProvider),
);
