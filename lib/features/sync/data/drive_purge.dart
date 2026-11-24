import 'package:drift/drift.dart';
import 'package:sync_engine/sync_engine.dart';

import '../../../core/clock/clock.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/app_meta_keys.dart';

/// Deletes from Drive the originals and thumbnails of photos deleted more
/// than [retention] ago (m3-design §6.5). Local purge is at 30 days, so for
/// a month after that a device can still restore a photo from Drive. The
/// records stay; the photo is then "no longer available".
class DrivePurge {
  DrivePurge({
    required this._db,
    required this._remote,
    required this._local,
    required this._clock,
  });

  static const retention = Duration(days: 60);
  static const minInterval = Duration(days: 1);

  final AppDatabase _db;
  final RemoteStore _remote;
  final LocalStore _local;
  final Clock _clock;

  /// Runs [run] unless it ran within [minInterval]. Returns the number of
  /// photos purged.
  Future<int> runIfDue() async {
    final now = _clock.now().millisecondsSinceEpoch;
    final last =
        (await (_db.select(_db.appMeta)
                  ..where((m) => m.key.equals(AppMetaKeys.lastDrivePurgeAt)))
                .getSingleOrNull())
            ?.value;
    final lastMs = int.tryParse(last ?? '');
    if (lastMs != null && now - lastMs < minInterval.inMilliseconds) return 0;
    final purged = await run();
    await _db
        .into(_db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(
            key: AppMetaKeys.lastDrivePurgeAt,
            value: '$now',
          ),
        );
    return purged;
  }

  /// Purges now. A failed request stops it; the next run carries on.
  Future<int> run() async {
    final cutoff = _clock.now().subtract(retention).millisecondsSinceEpoch;
    var purged = 0;
    for (final blob in await _purgeable(cutoff)) {
      final names = [
        blobFileName(blob.blobId, blob.mimeType),
        thumbFileName(blob.blobId),
      ];
      final ids = {
        ?blob.fileId,
        ?blob.thumbFileId,
        for (final name in names)
          for (final file in await _remote.findByName(name)) file.id,
      };
      for (final id in ids) {
        try {
          await _remote.delete(id);
        } on RemoteNotFound {
          // Already gone.
        }
      }
      await _local.apply(
        LocalBatch()
          ..blobs.add(BlobSync(blobId: blob.blobId, state: BlobState.missing)),
      );
      purged++;
    }
    return purged;
  }

  /// Blobs on Drive whose every image has been deleted (itself or with its
  /// project) since before [cutoff]. No live image may use one.
  Future<List<_Blob>> _purgeable(int cutoff) async {
    final rows = await _db
        .customSelect(
          'SELECT b.blob_id, b.drive_file_id, b.thumb_file_id, i.mime_type, '
          'i.deleted_at AS image_deleted, p.deleted_at AS project_deleted '
          'FROM blob_sync b '
          'JOIN images i ON i.blob_id = b.blob_id '
          'LEFT JOIN projects p ON p.id = i.project_id '
          "WHERE b.state IN ('synced', 'remoteOnly')",
          readsFrom: {_db.blobSyncs, _db.images, _db.projects},
        )
        .get();
    final byBlob = <String, List<QueryRow>>{};
    for (final r in rows) {
      byBlob.putIfAbsent(r.read<String>('blob_id'), () => []).add(r);
    }
    return [
      for (final MapEntry(key: blobId, value: images) in byBlob.entries)
        if (images.every((r) {
          final deletedAt = [
            r.readNullable<int>('image_deleted'),
            r.readNullable<int>('project_deleted'),
          ].nonNulls;
          return deletedAt.isNotEmpty &&
              deletedAt.reduce((a, b) => a < b ? a : b) < cutoff;
        }))
          _Blob(
            blobId: blobId,
            mimeType: images.first.read<String>('mime_type'),
            fileId: images.first.readNullable<String>('drive_file_id'),
            thumbFileId: images.first.readNullable<String>('thumb_file_id'),
          ),
    ];
  }
}

class _Blob {
  const _Blob({
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
