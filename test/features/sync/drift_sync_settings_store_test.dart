import 'package:drift/native.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/db/app_meta_keys.dart';
import 'package:filbert/features/sync/data/sync_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftSyncSettingsStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftSyncSettingsStore(db);
  });
  tearDown(() => db.close());

  Future<void> put(String key, String value) => db
      .into(db.appMeta)
      .insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));

  Future<Map<String, String>> meta() async => {
    for (final r in await db.select(db.appMeta).get()) r.key: r.value,
  };

  /// Bookkeeping from syncing with some account's Drive.
  Future<void> syncedBefore(String account) async {
    await put(AppMetaKeys.syncAccount, account);
    await put(AppMetaKeys.changesPageToken, '42');
    await put(AppMetaKeys.lastSyncAt, '1000');
    await db
        .into(db.syncStates)
        .insert(
          SyncStatesCompanion.insert(
            kind: 'project',
            recordId: 'p1',
            driveFileId: 'f1',
            remoteVersion: 3,
          ),
        );
    await db
        .into(db.blobSyncs)
        .insert(BlobSyncsCompanion.insert(blobId: 'b1', state: 'synced'));
    await db
        .into(db.syncConflicts)
        .insert(
          SyncConflictsCompanion.insert(
            kind: 'image',
            recordId: 'i1',
            driveFileId: 'f2',
            remoteJson: '{}',
            remoteVersion: 1,
            detectedAt: 1,
          ),
        );
  }

  Future<int> bookkeepingRows() async =>
      (await db.select(db.syncStates).get()).length +
      (await db.select(db.blobSyncs).get()).length +
      (await db.select(db.syncConflicts).get()).length;

  test('watch reads the settings from app_meta', () async {
    await put(AppMetaKeys.deviceName, 'Pixel 11');
    expect(
      await store.watch().first,
      const SyncSettings(deviceName: 'Pixel 11'),
    );
    await store.turnOn('painter@example.com');
    expect(
      await store.watch().first,
      const SyncSettings(
        enabled: true,
        account: 'painter@example.com',
        deviceName: 'Pixel 11',
      ),
    );
  });

  test(
    'turning on again with the same account keeps the bookkeeping',
    () async {
      await syncedBefore('painter@example.com');
      await store.turnOff();
      await store.turnOn('painter@example.com');
      expect(await bookkeepingRows(), 3);
      expect((await meta())[AppMetaKeys.changesPageToken], '42');
    },
  );

  test('another account clears the bookkeeping, not the data', () async {
    await syncedBefore('old@example.com');
    await put(AppMetaKeys.deviceName, 'Pixel 11');
    await store.turnOn('painter@example.com');

    expect(await bookkeepingRows(), 0);
    final values = await meta();
    expect(values[AppMetaKeys.changesPageToken], isNull);
    expect(values[AppMetaKeys.lastSyncAt], isNull);
    expect(values[AppMetaKeys.syncAccount], 'painter@example.com');
    expect(values[AppMetaKeys.syncEnabled], 'true');
    expect(values[AppMetaKeys.deviceName], 'Pixel 11');
  });

  test('turn off keeps the account; the device name is saved', () async {
    await store.turnOn('painter@example.com');
    await store.turnOff();
    await store.setDeviceName('Studio Mac');
    expect(
      await store.watch().first,
      const SyncSettings(
        account: 'painter@example.com',
        deviceName: 'Studio Mac',
      ),
    );
  });
}
