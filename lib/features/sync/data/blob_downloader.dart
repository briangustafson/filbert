import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sync_engine/sync_engine.dart';

import '../../../core/db/app_database.dart';
import '../../../core/files/file_store.dart';
import '../../../core/imaging/image_metadata.dart';

/// Downloads the originals other devices uploaded (m3-design §6.5): Drive
/// thumbnails of every waiting photo first, so grids fill in, then the
/// originals, newest project first. One file at a time; a photo someone
/// opens ([prioritize]) goes next.
class BlobDownloader {
  BlobDownloader({
    required this._db,
    required this._files,
    required this._remote,
    required this._local,
  });

  final AppDatabase _db;
  final FileStore _files;
  final RemoteStore _remote;
  final LocalStore _local;

  final _updates = StreamController<String>.broadcast();
  final _active = StreamController<bool>.broadcast();
  final _priority = <String>{};

  /// Thumbnails Drive doesn't have; not asked for again this session.
  final _noThumb = <String>{};
  Future<void>? _running;

  /// The blob ids whose files changed here: a thumbnail or the original
  /// arrived, or the original turned out to be gone.
  Stream<String> get updates => _updates.stream;

  /// True while downloading.
  Stream<bool> get active => _active.stream;
  bool get isActive => _running != null;

  /// Downloads until nothing is waiting or Drive is unavailable. Calls while
  /// running share the run.
  Future<void> run() {
    final running = _running;
    if (running != null) return running;
    _active.add(true);
    return _running = _loop().whenComplete(() {
      _running = null;
      _active.add(false);
    });
  }

  /// Downloads [blobId]'s original next.
  void prioritize(String blobId) {
    _priority.add(blobId);
    unawaited(run());
  }

  Future<void> _loop() async {
    while (true) {
      final waiting = await _waiting();
      if (waiting.isEmpty) return;
      final next = waiting
          .where((b) => _priority.contains(b.blobId))
          .firstOrNull;
      final thumbFirst = next == null
          ? waiting
                .where(
                  (b) =>
                      !_noThumb.contains(b.blobId) &&
                      !_files.blobThumbFile(b.blobId).existsSync(),
                )
                .firstOrNull
          : null;
      try {
        if (thumbFirst != null) {
          await _downloadThumb(thumbFirst);
        } else {
          await _downloadOriginal(next ?? waiting.first);
        }
      } on RemoteUnavailable catch (e) {
        debugPrint('Downloads paused: $e');
        return;
      } on Exception catch (e) {
        // A full disk, say: try again after the next pass.
        debugPrint('Download failed: $e');
        return;
      }
    }
  }

  Future<void> _downloadThumb(_Waiting blob) async {
    final id =
        blob.thumbFileId ??
        (await _remote.findByName(thumbFileName(blob.blobId))).firstOrNull?.id;
    if (id == null) {
      _noThumb.add(blob.blobId);
      return;
    }
    try {
      await _files.putBlobThumb(blob.blobId, await _remote.download(id));
      _updates.add(blob.blobId);
    } on RemoteNotFound {
      _noThumb.add(blob.blobId);
    }
  }

  Future<void> _downloadOriginal(_Waiting blob) async {
    _priority.remove(blob.blobId);
    final extension = extensionForMimeType[blob.mimeType] ?? 'jpg';
    final id =
        blob.fileId ??
        (await _remote.findByName(blobFileName(blob.blobId, blob.mimeType)))
            .firstOrNull
            ?.id;
    Uint8List? bytes;
    if (id != null) {
      try {
        bytes = await _remote.download(id);
      } on RemoteNotFound {
        bytes = null;
      }
    }
    if (bytes == null) {
      // Purged on Drive (§6.5): "This photo is no longer available".
      await _local.apply(
        LocalBatch()
          ..blobs.add(BlobSync(blobId: blob.blobId, state: BlobState.missing)),
      );
    } else {
      await _files.putBlobBytes(blob.blobId, extension, bytes);
      await _local.apply(
        LocalBatch()
          ..blobs.add(
            BlobSync(
              blobId: blob.blobId,
              state: BlobState.synced,
              fileId: id,
              thumbFileId: blob.thumbFileId,
            ),
          ),
      );
      await _files.deleteBlobThumb(blob.blobId);
    }
    _updates.add(blob.blobId);
  }

  /// Originals waiting to download, newest project first, of live images.
  Future<List<_Waiting>> _waiting() async {
    final rows = await _db
        .customSelect(
          'SELECT b.blob_id, b.drive_file_id, b.thumb_file_id, '
          'MIN(i.mime_type) AS mime_type, '
          'MAX(p.updated_at) AS project_updated, '
          'MAX(i.created_at) AS image_created '
          'FROM blob_sync b '
          'JOIN images i ON i.blob_id = b.blob_id '
          'JOIN projects p ON p.id = i.project_id '
          "WHERE b.state = 'remoteOnly' "
          'AND i.deleted_at IS NULL AND p.deleted_at IS NULL '
          'GROUP BY b.blob_id '
          'ORDER BY project_updated DESC, image_created DESC',
          readsFrom: {_db.blobSyncs, _db.images, _db.projects},
        )
        .get();
    return [
      for (final r in rows)
        _Waiting(
          blobId: r.read<String>('blob_id'),
          mimeType: r.read<String>('mime_type'),
          fileId: r.readNullable<String>('drive_file_id'),
          thumbFileId: r.readNullable<String>('thumb_file_id'),
        ),
    ];
  }

  void dispose() {
    _updates.close();
    _active.close();
  }
}

class _Waiting {
  const _Waiting({
    required this.blobId,
    required this.mimeType,
    this.fileId,
    this.thumbFileId,
  });

  final String blobId;
  final String mimeType;
  final String? fileId;
  final String? thumbFileId;
}
