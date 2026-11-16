import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/files/file_store.dart';
import '../../../core/imaging/edits_hash.dart';
import '../../../core/imaging/image_metadata.dart';
import '../../../core/imaging/render_geometry.dart';
import '../../../core/imaging/render_pipeline.dart';
import '../domain/project_image.dart';

part 'image_renderer.g.dart';

/// Produces the edited view of an image as cached JPEG files
/// (m1-design §4.4, §5.1). Originals are never modified.
abstract interface class ImageRenderer {
  /// Display render, at most [OpenCvImageRenderer.previewLongEdge] px on the
  /// long edge.
  Future<File> preview(ProjectImage image);

  /// Small render, at most [px] on the long edge.
  Future<File> thumbnail(ProjectImage image, int px);
}

/// Decodes with the platform decoder (handles HEIC, applies EXIF
/// orientation), then warps and encodes with OpenCV in a background isolate.
///
/// Cached files are reused; concurrent requests for the same file share one
/// render.
class OpenCvImageRenderer implements ImageRenderer {
  OpenCvImageRenderer({required this._files});

  static const previewLongEdge = 2048;

  final FileStore _files;
  final _inFlight = <String, Future<File>>{};

  @override
  Future<File> preview(ProjectImage image) => _render(
    image,
    previewLongEdge,
    File(
      '${_files.previewsDir.path}/${image.id}-${editsHash(image.edits)}.jpg',
    ),
  );

  @override
  Future<File> thumbnail(ProjectImage image, int px) {
    if (px < 1) throw ArgumentError.value(px, 'px', 'Must be positive');
    return _render(
      image,
      px,
      File(
        '${_files.thumbsDir.path}/'
        '${image.id}-${editsHash(image.edits)}-$px.jpg',
      ),
    );
  }

  Future<File> _render(ProjectImage image, int maxLongEdge, File target) {
    final key = target.path;
    final pending = _inFlight[key];
    if (pending != null) return pending;
    // A block body, not `=>`: whenComplete awaits a returned future, and
    // remove() returns this very future, which would never complete.
    final future = _renderUncached(image, maxLongEdge, target).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<File> _renderUncached(
    ProjectImage image,
    int maxLongEdge,
    File target,
  ) async {
    if (await target.exists()) return target;

    final extension = extensionForMimeType[image.mimeType];
    if (extension == null) {
      throw UnsupportedImageException('Unknown type ${image.mimeType}');
    }
    final bytes = await _files.blobFile(image.blobId, extension).readAsBytes();
    final (rgba, plan) = await decodeForRender(bytes, image.edits, maxLongEdge);

    final jpeg = await _renderInIsolate(rgba, plan);
    return _writeAtomically(target, jpeg);
  }

  Future<File> _writeAtomically(File target, Uint8List bytes) async {
    await target.parent.create(recursive: true);
    final name = target.uri.pathSegments.last;
    final temp = File('${target.parent.path}/.$name.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      return await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }
}

/// Top-level so the isolate closure captures only sendable values.
Future<Uint8List> _renderInIsolate(Uint8List rgba, RenderPlan plan) {
  // Transferable, so the pixels aren't copied again when the isolate starts.
  final transfer = TransferableTypedData.fromList([rgba]);
  return Isolate.run(
    () => renderJpeg(transfer.materialize().asUint8List(), plan),
    debugName: 'render',
  );
}

/// Decodes [encoded] with the platform decoder at the size [edits] need for
/// an output of at most [maxLongEdge], returning RGBA pixels and the plan.
///
/// Must run on the root isolate (Flutter's decoder isn't available in
/// background isolates); the decode itself happens off the UI thread.
Future<(Uint8List, RenderPlan)> decodeForRender(
  Uint8List encoded,
  Edits edits,
  int maxLongEdge,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? decoded;
  try {
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
    } on Exception catch (e) {
      throw UnsupportedImageException('Could not decode image: $e');
    }
    // The descriptor's size is already EXIF-oriented.
    final plan = RenderPlan.forEdits(
      sourceWidth: descriptor.width,
      sourceHeight: descriptor.height,
      edits: edits,
      maxLongEdge: maxLongEdge,
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: plan.decodeWidth,
      targetHeight: plan.decodeHeight,
    );
    decoded = (await codec.getNextFrame()).image;
    if (decoded.width != plan.decodeWidth ||
        decoded.height != plan.decodeHeight) {
      throw StateError(
        'Decoded ${decoded.width}x${decoded.height}, '
        'expected ${plan.decodeWidth}x${plan.decodeHeight}',
      );
    }
    final data = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('Could not read decoded pixels');
    return (
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      plan,
    );
  } finally {
    decoded?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

@Riverpod(keepAlive: true)
ImageRenderer imageRenderer(Ref ref) =>
    OpenCvImageRenderer(files: ref.watch(fileStoreProvider));
