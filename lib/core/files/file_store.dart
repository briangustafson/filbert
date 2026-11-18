import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_store.g.dart';

/// On-disk storage for image originals ("blobs") and render caches
/// (m1-design §4.4). Originals are written once and never modified.
abstract interface class FileStore {
  /// Copies [source] into blob storage as `<blobId>.<extension>`. Atomic:
  /// the blob either appears complete or not at all.
  Future<File> putBlob(String blobId, String extension, File source);

  File blobFile(String blobId, String extension);

  /// Deletes a blob. No-op if it doesn't exist.
  Future<void> deleteBlob(String blobId, String extension);

  /// Thumbnails of edited views: `<imageId>-<editsHash>-<px>.jpg`.
  Directory get thumbsDir;

  /// Display renders: `<imageId>-<editsHash>.jpg`.
  Directory get previewsDir;

  /// Exports with aids (m2-design §5.4): one-off files, kept only while
  /// the app runs.
  Directory get exportsDir;

  /// Deletes every export; called at launch.
  Future<void> clearExports();

  /// Deletes every cached render of [imageId].
  Future<void> deleteCachesFor(String imageId);
}

class LocalFileStore implements FileStore {
  LocalFileStore({required Directory supportDir, required Directory cacheDir})
    : _blobsDir = Directory('${supportDir.path}/blobs'),
      thumbsDir = Directory('${cacheDir.path}/thumbs'),
      previewsDir = Directory('${cacheDir.path}/previews'),
      exportsDir = Directory('${cacheDir.path}/exports');

  /// The app's real directories, created if needed.
  static Future<LocalFileStore> open() async {
    final store = LocalFileStore(
      supportDir: await getApplicationSupportDirectory(),
      cacheDir: await getApplicationCacheDirectory(),
    );
    await store._ensureDirs();
    return store;
  }

  final Directory _blobsDir;

  @override
  final Directory thumbsDir;

  @override
  final Directory previewsDir;

  @override
  final Directory exportsDir;

  @override
  Future<void> clearExports() async {
    if (await exportsDir.exists()) await exportsDir.delete(recursive: true);
  }

  Future<void> _ensureDirs() async {
    for (final dir in [_blobsDir, thumbsDir, previewsDir]) {
      await dir.create(recursive: true);
    }
  }

  @override
  File blobFile(String blobId, String extension) =>
      File('${_blobsDir.path}/$blobId.$extension');

  @override
  Future<File> putBlob(String blobId, String extension, File source) async {
    await _blobsDir.create(recursive: true);
    final target = blobFile(blobId, extension);
    // Temp file in the same directory, so the rename is atomic.
    final temp = File('${_blobsDir.path}/.$blobId.$extension.tmp');
    try {
      await source.copy(temp.path);
      final handle = await temp.open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
      return await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  @override
  Future<void> deleteBlob(String blobId, String extension) async {
    final file = blobFile(blobId, extension);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteCachesFor(String imageId) async {
    for (final dir in [thumbsDir, previewsDir]) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File && name.startsWith('$imageId-')) {
          await entity.delete();
        }
      }
    }
  }
}

/// Opened before `runApp` and supplied as an override (see `main.dart`).
@Riverpod(keepAlive: true)
FileStore fileStore(Ref ref) => throw UnimplementedError(
  'fileStoreProvider must be overridden with an opened FileStore',
);
