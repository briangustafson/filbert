import 'package:drift/drift.dart' show BooleanExpressionOperators, Value, Variable;

import '../../../core/clock/clock.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/app_meta_keys.dart';
import '../../../core/files/file_store.dart';
import '../../../core/imaging/image_metadata.dart';

/// Deletes the files (originals and caches) of images that have been
/// deleted, or whose project has been deleted, for longer than [retention]
/// (m1-design §4.4). Records are kept: they're small and sync needs them.
/// An original that is also on Drive becomes "on Drive only"
/// (`remoteOnly`), so if another device restores the photo, this one
/// downloads it again (m3-design §6.5).
class PurgeJob {
  PurgeJob({required this._db, required this._files, required this._clock});

  static const retention = Duration(days: 5);
  static const minInterval = Duration(days: 1);

  final AppDatabase _db;
  final FileStore _files;
  final Clock _clock;

  /// Runs [run] unless it already ran within [minInterval]. Returns the
  /// number of images purged.
  Future<int> runIfDue() async {
    final now = _clock.now();
    final last = await _lastRun();
    if (last != null && now.difference(last) < minInterval) return 0;
    final purged = await run();
    await _db
        .into(_db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(
            key: AppMetaKeys.lastPurgeAt,
            value: now.millisecondsSinceEpoch.toString(),
          ),
        );
    return purged;
  }

  /// Purges now. Returns the number of images whose files were deleted
  /// (including ones already purged earlier).
  Future<int> run() async {
    final cutoff = _clock.now().subtract(retention).millisecondsSinceEpoch;
    final rows = await _db
        .customSelect(
          'SELECT i.id, i.blob_id, i.mime_type FROM images i '
          'LEFT JOIN projects p ON p.id = i.project_id '
          'WHERE (i.deleted_at IS NOT NULL AND i.deleted_at < ?1) '
          'OR (p.deleted_at IS NOT NULL AND p.deleted_at < ?1)',
          variables: [Variable.withInt(cutoff)],
          readsFrom: {_db.images, _db.projects},
        )
        .get();
    for (final row in rows) {
      final extension = extensionForMimeType[row.read<String>('mime_type')];
      if (extension != null) {
        await _files.deleteBlob(row.read<String>('blob_id'), extension);
      }
      await (_db.update(_db.blobSyncs)..where(
            (b) =>
                b.blobId.equals(row.read<String>('blob_id')) &
                b.state.equals('synced'),
          ))
          .write(const BlobSyncsCompanion(state: Value('remoteOnly')));
      await _files.deleteCachesFor(row.read<String>('id'));
    }
    return rows.length;
  }

  Future<DateTime?> _lastRun() async {
    final row = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(AppMetaKeys.lastPurgeAt))).getSingleOrNull();
    final ms = row == null ? null : int.tryParse(row.value);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
}
