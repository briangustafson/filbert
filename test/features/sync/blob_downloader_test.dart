// BlobDownloader, DriftBlobAvailabilityService and DrivePurge (m3-design
// §6.5) on an in-memory database, a temp FileStore and a fake Drive.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/features/sync/data/blob_availability.dart';
import 'package:filbert/features/sync/data/blob_downloader.dart';
import 'package:filbert/features/sync/data/drift_local_store.dart';
import 'package:filbert/features/sync/data/drive_purge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_engine/src/testing/fake_remote_store.dart';
import 'package:sync_engine/sync_engine.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late LocalFileStore files;
  late DriftLocalStore local;
  late FakeRemoteStore remote;
  late BlobDownloader downloader;

  setUp(() {
    root = Directory.systemTemp.createTempSync('filbert_blobs');
    db = AppDatabase(NativeDatabase.memory());
    files = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
    local = DriftLocalStore(db: db, files: files, thumbnail: (_) async => null);
    remote = FakeRemoteStore();
    downloader = BlobDownloader(
      db: db,
      files: files,
      remote: remote,
      local: local,
    );
  });
  tearDown(() async {
    downloader.dispose();
    await db.close();
    root.deleteSync(recursive: true);
  });

  SyncRecord project(String id, {int updatedAt = 2, int? deletedAt}) =>
      SyncRecord(
        kind: RecordKind.project,
        id: id,
        createdAt: 1,
        updatedAt: updatedAt,
        updatedByDeviceId: 'd',
        deletedAt: deletedAt,
        fields: {
          'name': id,
          'nameIsDefault': false,
          'size': {'kind': 'none'},
          'startNotes': '',
          'referenceImageId': null,
        },
      );

  SyncRecord image(String id, String projectId, {int? deletedAt}) => SyncRecord(
    kind: RecordKind.image,
    id: id,
    createdAt: 3,
    updatedAt: 4,
    updatedByDeviceId: 'd',
    deletedAt: deletedAt,
    fields: {
      'projectId': projectId,
      'blobId': 'b-$id',
      'mimeType': 'image/jpeg',
      'width': 400,
      'height': 300,
      'source': 'camera',
      'capturedAt': null,
      'edits': {'v': 1},
      'derivedFrom': null,
    },
  );

  /// A photo another device uploaded: on Drive, `remoteOnly` here.
  Future<void> fromAnotherDevice(String imageId, {bool thumb = true}) async {
    final blobId = 'b-$imageId';
    await remote.upload(
      blobFileName(blobId, 'image/jpeg'),
      Uint8List.fromList([1, 2, 3]),
      'image/jpeg',
    );
    if (thumb) {
      await remote.upload(
        thumbFileName(blobId),
        Uint8List.fromList([9]),
        'image/jpeg',
      );
    }
    await local.apply(
      LocalBatch()
        ..blobs.add(BlobSync(blobId: blobId, state: BlobState.remoteOnly)),
    );
  }

  Future<BlobState?> stateOf(String blobId) async =>
      (await local.blobs())[blobId]?.state;

  File original(String imageId) => files.blobFile('b-$imageId', 'jpg');

  group('BlobDownloader', () {
    test('thumbnails first, newest project first, then originals', () async {
      await local.apply(
        LocalBatch()
          ..records.addAll([
            project('old', updatedAt: 10),
            project('new', updatedAt: 20),
            image('i1', 'old'),
            image('i2', 'new'),
          ]),
      );
      await fromAnotherDevice('i1');
      await fromAnotherDevice('i2');
      final updates = <String>[];
      downloader.updates.listen(updates.add);
      remote.requests.clear();

      await downloader.run();

      final downloads = [
        for (final r in remote.requests)
          if (r.startsWith('findByName')) r.split(' ').last,
      ];
      expect(downloads, [
        'thumb-b-i2.jpg',
        'thumb-b-i1.jpg',
        'blob-b-i2.jpg',
        'blob-b-i1.jpg',
      ]);
      expect(original('i1').readAsBytesSync(), [1, 2, 3]);
      expect(await stateOf('b-i1'), BlobState.synced);
      expect(
        files.blobThumbFile('b-i1').existsSync(),
        isFalse,
        reason: 'deleted once the original is here',
      );
      expect(updates, ['b-i2', 'b-i1', 'b-i2', 'b-i1']);
    });

    test('a photo someone opens goes next', () async {
      await local.apply(
        LocalBatch()
          ..records.addAll([
            project('p', updatedAt: 10),
            image('i1', 'p'),
            image('i2', 'p'),
          ]),
      );
      await fromAnotherDevice('i1');
      await fromAnotherDevice('i2');
      remote.requests.clear();
      downloader.prioritize('b-i1');
      await downloader.run();
      expect(
        remote.requests.firstWhere((r) => r.startsWith('findByName')),
        'findByName blob-b-i1.jpg',
      );
    });

    test('an original gone from Drive is missing', () async {
      await local.apply(
        LocalBatch()..records.addAll([project('p'), image('i1', 'p')]),
      );
      await local.apply(
        LocalBatch()
          ..blobs.add(BlobSync(blobId: 'b-i1', state: BlobState.remoteOnly)),
      );
      await downloader.run();
      expect(await stateOf('b-i1'), BlobState.missing);
    });

    test('Drive unavailable pauses; the next run carries on', () async {
      await local.apply(
        LocalBatch()..records.addAll([project('p'), image('i1', 'p')]),
      );
      await fromAnotherDevice('i1');
      remote.failNext(op: 'download');
      await downloader.run();
      expect(original('i1').existsSync(), isFalse);
      await downloader.run();
      expect(original('i1').existsSync(), isTrue);
    });

    test('deleted photos and projects are skipped', () async {
      await local.apply(
        LocalBatch()
          ..records.addAll([
            project('p'),
            project('gone', deletedAt: 5),
            image('i1', 'p', deletedAt: 5),
            image('i2', 'gone'),
          ]),
      );
      await fromAnotherDevice('i1');
      await fromAnotherDevice('i2');
      remote.requests.clear();
      await downloader.run();
      expect(remote.requests, isEmpty);
    });
  });

  group('DriftBlobAvailabilityService', () {
    late StreamController<String> updates;
    late DriftBlobAvailabilityService service;

    setUp(() {
      updates = StreamController.broadcast();
      service = DriftBlobAvailabilityService(
        db: db,
        files: files,
        updates: updates.stream,
      );
    });
    tearDown(() => updates.close());

    test('a photo taken here is available at once', () async {
      await files.putBlobBytes('b-i1', 'jpg', [1]);
      expect(await service.watch('b-i1', 'image/jpeg').toList(), [
        BlobAvailability.original,
      ]);
    });

    test('waiting, then the thumbnail, then the original', () async {
      await local.apply(
        LocalBatch()..records.addAll([project('p'), image('i1', 'p')]),
      );
      await fromAnotherDevice('i1');
      final seen = <BlobAvailability>[];
      final done = service.watch('b-i1', 'image/jpeg').forEach(seen.add);
      await pumpEventQueue();
      expect(seen, [BlobAvailability.waiting]);

      await files.putBlobThumb('b-i1', [9]);
      updates.add('b-i1');
      await pumpEventQueue();
      expect(seen.last, BlobAvailability.thumbnail);

      await downloader.run();
      updates.add('b-i1');
      await done;
      expect(seen.last, BlobAvailability.original);
    });

    test('missing', () async {
      await local.apply(
        LocalBatch()
          ..blobs.add(BlobSync(blobId: 'b-i1', state: BlobState.missing)),
      );
      expect(
        await service.watch('b-i1', 'image/jpeg').first,
        BlobAvailability.missing,
      );
    });
  });

  group('DrivePurge', () {
    const day = 24 * 60 * 60 * 1000;
    final now = DateTime.utc(2026, 11, 25);
    final today = now.millisecondsSinceEpoch;
    late DrivePurge purge;

    setUp(
      () => purge = DrivePurge(
        db: db,
        remote: remote,
        local: local,
        clock: FakeClock(now),
      ),
    );

    Future<void> onDrive(String imageId) async {
      await fromAnotherDevice(imageId);
      await local.apply(
        LocalBatch()
          ..blobs.add(BlobSync(blobId: 'b-$imageId', state: BlobState.synced)),
      );
    }

    test('deletes photos deleted over 5 days ago from Drive', () async {
      await local.apply(
        LocalBatch()
          ..records.addAll([
            project('p'),
            project('gone', deletedAt: today - 6 * day),
            image('old', 'p', deletedAt: today - 6 * day),
            image('recent', 'p', deletedAt: today - 4 * day),
            image('live', 'p'),
            image('inGone', 'gone'),
          ]),
      );
      for (final id in ['old', 'recent', 'live', 'inGone']) {
        await onDrive(id);
      }

      expect(await purge.run(), 2);

      final names = {for (final f in remote.files.values) f.name};
      expect(names, {
        'blob-b-recent.jpg',
        'thumb-b-recent.jpg',
        'blob-b-live.jpg',
        'thumb-b-live.jpg',
      });
      expect(await stateOf('b-old'), BlobState.missing);
      expect(await stateOf('b-live'), BlobState.synced);
    });

    test('runs at most once a day', () async {
      expect(await purge.runIfDue(), 0);
      await local.apply(
        LocalBatch()
          ..records.addAll([
            project('p'),
            image('old', 'p', deletedAt: today - 6 * day),
          ]),
      );
      await onDrive('old');
      expect(await purge.runIfDue(), 0, reason: 'ran today');
      expect(await purge.run(), 1);
    });
  });
}
