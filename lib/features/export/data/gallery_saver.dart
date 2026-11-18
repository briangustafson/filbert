import 'dart:io';

import 'package:gal/gal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_saver.g.dart';

/// Saves files to the device's photo gallery (m2-design §5.5).
abstract interface class GallerySaver {
  /// Saves the JPEG [file] in [album] as [fileName]. Throws
  /// [GallerySaveException].
  Future<void> save(
    File file, {
    required String album,
    required String fileName,
  });
}

enum GallerySaveFailure { permissionDenied, notEnoughSpace, other }

class GallerySaveException implements Exception {
  const GallerySaveException(this.failure, [this.detail]);

  final GallerySaveFailure failure;
  final Object? detail;

  @override
  String toString() => 'GallerySaveException(${failure.name}, $detail)';
}

/// [GallerySaver] with the `gal` package. Android 10 and later need no
/// permission; on 7–10 `gal` asks for storage access the first time.
class GalGallerySaver implements GallerySaver {
  const GalGallerySaver();

  @override
  Future<void> save(
    File file, {
    required String album,
    required String fileName,
  }) async {
    // The gallery takes the name from the file, so save a copy named so.
    final dir = await Directory.systemTemp.createTemp('gallery');
    try {
      final named = await file.copy('${dir.path}/$fileName');
      if (!await Gal.hasPermission(toAlbum: true) &&
          !await Gal.requestPermission(toAlbum: true)) {
        throw const GallerySaveException(GallerySaveFailure.permissionDenied);
      }
      await Gal.putImage(named.path, album: album);
    } on GalException catch (e) {
      throw GallerySaveException(switch (e.type) {
        GalExceptionType.permissionDenied =>
          GallerySaveFailure.permissionDenied,
        GalExceptionType.notEnoughSpace => GallerySaveFailure.notEnoughSpace,
        _ => GallerySaveFailure.other,
      }, e);
    } finally {
      await dir.delete(recursive: true);
    }
  }
}

@Riverpod(keepAlive: true)
GallerySaver gallerySaver(Ref ref) => const GalGallerySaver();
