import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/files/file_store.dart';
import '../../../core/imaging/image_metadata.dart';
import '../../photos/domain/project_image.dart';
import 'sync_providers.dart';

part 'blob_availability.g.dart';

/// Which of a photo's files are on this device (m3-design §6.5).
enum BlobAvailability {
  /// The original: everything works.
  original,

  /// Only Drive's thumbnail: shown cropped; Crop and Export wait.
  thumbnail,

  /// Neither yet: a placeholder until the thumbnail arrives.
  waiting,

  /// Gone from Drive and not here: "This photo is no longer available".
  missing,
}

/// The original isn't here, and it isn't coming.
class PhotoMissingException implements Exception {
  const PhotoMissingException(this.blobId);

  final String blobId;

  @override
  String toString() => 'PhotoMissingException($blobId)';
}

abstract interface class BlobAvailabilityService {
  /// The photo's availability now and after every change.
  Stream<BlobAvailability> watch(String blobId, String mimeType);
}

/// Reads the files and `blob_sync`; [updates] says when a download changed
/// a blob's files.
class DriftBlobAvailabilityService implements BlobAvailabilityService {
  DriftBlobAvailabilityService({
    required this._db,
    required this._files,
    required this._updates,
  });

  final AppDatabase _db;
  final FileStore _files;
  final Stream<String> _updates;

  @override
  Stream<BlobAvailability> watch(String blobId, String mimeType) async* {
    final extension = extensionForMimeType[mimeType];
    // An unknown type is the renderer's error to report.
    if (extension == null ||
        await _files.blobFile(blobId, extension).exists()) {
      yield BlobAvailability.original;
      return;
    }
    // Rare: a photo from another device. Watch until its original lands.
    final changes = StreamController<void>();
    final rows =
        (_db.select(_db.blobSyncs)..where((b) => b.blobId.equals(blobId)))
            .watchSingleOrNull()
            .listen((_) => changes.add(null));
    final downloads = _updates
        .where((id) => id == blobId)
        .listen((_) => changes.add(null));
    try {
      await for (final _ in changes.stream) {
        final now = await _current(blobId, extension);
        yield now;
        if (now == BlobAvailability.original) return;
      }
    } finally {
      await rows.cancel();
      await downloads.cancel();
      await changes.close();
    }
  }

  Future<BlobAvailability> _current(String blobId, String extension) async {
    if (await _files.blobFile(blobId, extension).exists()) {
      return BlobAvailability.original;
    }
    final row = await (_db.select(
      _db.blobSyncs,
    )..where((b) => b.blobId.equals(blobId))).getSingleOrNull();
    if (row == null || row.state == 'missing') return BlobAvailability.missing;
    if (await _files.blobThumbFile(blobId).exists()) {
      return BlobAvailability.thumbnail;
    }
    return BlobAvailability.waiting;
  }
}

@Riverpod(keepAlive: true)
BlobAvailabilityService blobAvailabilityService(Ref ref) =>
    DriftBlobAvailabilityService(
      db: ref.watch(databaseProvider),
      files: ref.watch(fileStoreProvider),
      updates: ref.watch(blobDownloaderProvider).updates,
    );

@riverpod
Stream<BlobAvailability> blobAvailability(
  Ref ref,
  String blobId,
  String mimeType,
) => ref.watch(blobAvailabilityServiceProvider).watch(blobId, mimeType);

/// Waits until [image] can be rendered: from its original or, until that
/// arrives, its Drive thumbnail (m3-design §6.5). A render provider calls
/// this first, so it renders again when the original lands. Throws
/// [PhotoMissingException] if the photo is gone; stays loading while
/// neither file is here.
Future<void> whenRenderable(Ref ref, ProjectImage image) async {
  final availability = await ref.watch(
    blobAvailabilityProvider(image.blobId, image.mimeType).future,
  );
  switch (availability) {
    case BlobAvailability.original || BlobAvailability.thumbnail:
      return;
    case BlobAvailability.missing:
      throw PhotoMissingException(image.blobId);
    case BlobAvailability.waiting:
      await Completer<void>().future;
  }
}
