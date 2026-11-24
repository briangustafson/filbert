import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sync_engine/sync_engine.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/clock/clock.dart';
import '../../../core/db/app_database.dart';
import '../../../core/device/device_info.dart';
import '../../../core/files/file_store.dart';
import '../../photos/data/image_renderer.dart';
import '../../photos/data/image_repository.dart';
import '../../photos/domain/project_image.dart';
import '../../settings/settings_screen.dart' show appVersionProvider;
import 'drift_local_store.dart';
import 'drive_client.dart';
import 'drive_remote_store.dart';

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

/// Drive (m3-design §6.2), with the signed-in user's token.
@Riverpod(keepAlive: true)
RemoteStore remoteStore(Ref ref) {
  final client = DriveAuthClient(ref.watch(authServiceProvider));
  ref.onDispose(client.close);
  return DriveRemoteStore(
    client,
    createdBy: () => ref.read(appVersionProvider.future),
  );
}

/// One sync pass between this device and Drive. The sync controller (T9)
/// runs it; until then, Settings → Sync's debug button does.
@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) => SyncEngine(
  local: ref.watch(localStoreProvider),
  remote: ref.watch(remoteStoreProvider),
  deviceId: ref.watch(deviceInfoProvider).deviceId,
  now: () => ref.read(clockProvider).now().millisecondsSinceEpoch,
);
