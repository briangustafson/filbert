import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sync_engine/sync_engine.dart';

import '../../../core/db/app_database.dart';
import '../../../core/files/file_store.dart';
import '../../photos/data/image_renderer.dart';
import '../../photos/data/image_repository.dart';
import '../../photos/domain/project_image.dart';
import 'drift_local_store.dart';

part 'sync_providers.g.dart';

/// The sync engine's view of this device (m3-design §6.1). Drive thumbnails
/// are of the unedited original (§6.5).
@Riverpod(keepAlive: true)
LocalStore localStore(Ref ref) {
  final db = ref.watch(databaseProvider);
  final renderer = ref.watch(imageRendererProvider);
  return DriftLocalStore(
    db: db,
    files: ref.watch(fileStoreProvider),
    thumbnail: (blobId) async {
      final row =
          await (db.select(db.images)
                ..where((t) => t.blobId.equals(blobId))
                ..limit(1))
              .getSingleOrNull();
      if (row == null) return null;
      final original = DriftImageRepository.toProjectImage(row)
          .withEdits(Edits.none);
      final file = await renderer.thumbnail(original, standardThumbnailPx);
      return file.readAsBytes();
    },
  );
}
