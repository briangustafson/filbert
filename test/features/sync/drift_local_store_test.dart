// DriftLocalStore (m3-design §6.1, T6) on an in-memory database: the record
// format both ways, batches, the sync tables, blobs; then the engine's
// multi-device scenarios with every device on its own Drift database.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/device/device_info.dart';
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:filbert/core/imaging/image_metadata.dart';
import 'package:filbert/features/photos/data/image_repository.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:filbert/features/sync/data/drift_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_engine/sync_engine.dart';
import 'package:sync_engine/testing.dart';

/// [DriftLocalStore] with what the app does to it, for the scenarios.
class DriftDeviceData extends DriftLocalStore implements DeviceData {
  DriftDeviceData(this.db, this.files, this.thumbs)
    : super(db: db, files: files, thumbnail: (id) async => thumbs[id]);

  final AppDatabase db;
  final LocalFileStore files;
  final Map<String, Uint8List> thumbs;

  @override
  Future<void> write(SyncRecord record) =>
      apply(LocalBatch()..records.add(record));

  @override
  Future<void> writeBlob(
    String blobId,
    Uint8List original,
    Uint8List? thumb,
  ) async {
    final file = files.blobFile(blobId, 'jpg');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(original);
    if (thumb != null) thumbs[blobId] = thumb;
  }
}

void main() {
  late Directory root;
  final open = <AppDatabase>[];

  setUp(() => root = Directory.systemTemp.createTempSync('filbert_sync'));
  tearDown(() async {
    for (final db in open) {
      await db.close();
    }
    open.clear();
    root.deleteSync(recursive: true);
  });

  var devices = 0;
  DriftDeviceData newDevice() {
    final db = AppDatabase(NativeDatabase.memory());
    open.add(db);
    final dir = Directory('${root.path}/device${devices++}');
    return DriftDeviceData(
      db,
      LocalFileStore(
        supportDir: Directory('${dir.path}/support'),
        cacheDir: Directory('${dir.path}/cache'),
      ),
      {},
    );
  }

  const codec = RecordCodec();

  SyncRecord project({
    String id = 'p1',
    Map<String, Object?> size = const {'kind': 'none'},
    int? deletedAt,
  }) => SyncRecord(
    kind: RecordKind.project,
    id: id,
    createdAt: 1,
    updatedAt: 2,
    updatedByDeviceId: 'd',
    deletedAt: deletedAt,
    fields: {
      'name': 'Harbour',
      'nameIsDefault': false,
      'size': size,
      'startNotes': 'notes',
      'referenceImageId': 'i1',
    },
  );

  SyncRecord image({
    String id = 'i1',
    Map<String, Object?> edits = const {'v': 1},
    Object? source = 'camera',
  }) => SyncRecord(
    kind: RecordKind.image,
    id: id,
    createdAt: 3,
    updatedAt: 4,
    updatedByDeviceId: 'd',
    fields: {
      'projectId': 'p1',
      'blobId': 'b-$id',
      'mimeType': 'image/jpeg',
      'width': 4000,
      'height': 3000,
      'source': source,
      'capturedAt': 5,
      'edits': edits,
      'derivedFrom': null,
    },
  );

  SyncRecord prefs(String id, {int updatedAt = 2, int? deletedAt}) =>
      SyncRecord(
        kind: RecordKind.viewPrefs,
        id: id,
        createdAt: 1,
        updatedAt: updatedAt,
        updatedByDeviceId: 'd',
        deletedAt: deletedAt,
        fields: {
          'projectId': 'p1',
          'prefs': {'v': 1, 'id': id},
        },
      );

  group('the record format', () {
    for (final (what, record) in [
      ('a project without a size', project()),
      (
        'a project with a ratio',
        project(size: {'kind': 'ratio', 'w': 4, 'h': 5}),
      ),
      (
        'a project with a canvas size',
        project(
          size: {'kind': 'physical', 'width': 16, 'height': 20, 'unit': 'in'},
        ),
      ),
      ('a deleted project', project(deletedAt: 9)),
      (
        'an image with edits',
        image(
          edits: {
            'v': 1,
            'quarterTurns': 1,
            'crop': [
              [0.1, 0.2],
              [0.9, 0.2],
              [0.9, 0.8],
              [0.1, 0.8],
            ],
          },
        ),
      ),
      ('view prefs', prefs('v1')),
    ]) {
      test('$what round-trips with the same hash', () async {
        final store = newDevice();
        if (record.kind != RecordKind.project) {
          await store.write(project());
        }
        await store.write(record);
        final back = (await store.record(record.key))!;
        expect(codec.encode(back), codec.encode(record));
        expect(codec.hash(back), codec.hash(record));
      });
    }

    test("the app's own rows read as stable records", () async {
      final store = newDevice();
      final clock = FakeClock(DateTime.utc(2026, 11, 19));
      final projects = DriftProjectRepository(
        db: store.db,
        clock: clock,
        ids: UuidV7IdGenerator(clock),
        device: const StoredDeviceInfo(deviceId: 'device-a'),
      );
      final p = await projects.create();
      await projects.update(
        p.id,
        size: const PhysicalSize(16, 20, LengthUnit.inches),
      );
      final record = (await store.record((
        kind: RecordKind.project,
        id: p.id,
      )))!;
      expect(record.fields['size'], {
        'kind': 'physical',
        'width': 16.0,
        'height': 20.0,
        'unit': 'in',
      });
      final hash = codec.hash(record);
      // Written back as a pull would, then read again: unchanged.
      await store.write(codec.decode(codec.encode(record)).let);
      expect(
        codec.hash((await store.record(record.key))!),
        hash,
        reason: '16.0 and 16 hash the same (no endless re-push)',
      );
    });

    test(
      'a source this version doesn\'t know reads as a device photo',
      () async {
        final store = newDevice();
        await store.write(project());
        await store.write(image(source: 'googlePhotos'));
        final row = await store.db.select(store.db.images).getSingle();
        expect(row.source, ImageOrigin.device);
      },
    );
  });

  group('batches', () {
    test('a batch is one transaction', () async {
      final store = newDevice();
      final batch = LocalBatch()
        ..records.addAll([project(), prefs('v1'), prefs('v2')])
        ..pageToken = '7';
      await expectLater(store.apply(batch), throwsA(anything));
      expect(await store.records(), isEmpty, reason: 'rolled back');
      expect(await store.pageToken(), isNull);
    });

    test('a tombstone goes in before the record replacing it', () async {
      final store = newDevice();
      await store.write(project());
      await store.write(prefs('v1'));
      await store.apply(
        LocalBatch()
          ..records.addAll([
            prefs('v2', updatedAt: 5),
            prefs('v1', deletedAt: 5),
          ]),
      );
      final rows = await store.db.select(store.db.viewPrefs).get();
      expect({for (final r in rows) r.id: r.deletedAt}, {'v1': 5, 'v2': null});
    });

    test('records go in in dependency order', () async {
      final store = newDevice();
      await store.apply(
        LocalBatch()..records.addAll([prefs('v1'), image(), project()]),
      );
      expect(await store.records(), hasLength(3));
    });

    test('a pulled crop goes into the undo history', () async {
      final store = newDevice();
      final clock = FakeClock(DateTime.utc(2026, 11, 19));
      final images = DriftImageRepository(
        db: store.db,
        files: store.files,
        metadata: const PlatformImageMetadataReader(),
        clock: clock,
        ids: UuidV7IdGenerator(clock),
        device: const StoredDeviceInfo(deviceId: 'device-a'),
      );
      await store.write(project());
      await store.write(image());
      await images.setEdits('i1', const Edits(quarterTurns: 1));
      // Another device's crop arrives.
      await store.apply(
        LocalBatch()..records.add(image(edits: {'v': 1, 'quarterTurns': 2})),
      );
      Future<Edits> edits() async => DriftImageRepository.toProjectImage(
        await store.db.select(store.db.images).getSingle(),
      ).edits;
      expect((await edits()).quarterTurns, 2);
      await images.undo('i1');
      expect((await edits()).quarterTurns, 1, reason: 'back to this device\'s');
      await images.redo('i1');
      expect((await edits()).quarterTurns, 2);
    });
  });

  group('sync tables', () {
    test('states, blobs, conflicts and the page token round-trip', () async {
      final store = newDevice();
      const key = (kind: RecordKind.image, id: 'i1');
      const state = SyncState(
        fileId: 'f1',
        remoteVersion: 3,
        syncedHash: 'abc',
        heldJson: '{"schemaVersion":2}',
      );
      const blob = BlobSync(
        blobId: 'b1',
        state: BlobState.remoteOnly,
        fileId: 'f2',
        thumbFileId: 'f3',
      );
      const conflict = SyncConflict(
        key: key,
        fileId: 'f1',
        remoteJson: '{}',
        remoteVersion: 4,
        detectedAt: 99,
      );
      await store.apply(
        LocalBatch()
          ..states[key] = state
          ..blobs.add(blob)
          ..conflicts.add(conflict)
          ..pageToken = 'token-1',
      );
      expect(await store.syncStates(), {key: state});
      expect(await store.blobs(), {'b1': blob});
      expect((await store.conflicts())[key]!.remoteVersion, 4);
      expect(await store.pageToken(), 'token-1');

      await store.apply(LocalBatch()..resolvedConflicts.add(key));
      expect(await store.conflicts(), isEmpty);
    });

    test(
      'originals come from the file store, thumbnails from the renderer',
      () async {
        final store = newDevice();
        await store.write(project());
        await store.write(image());
        expect(await store.readBlob('b-i1'), isNull, reason: 'not here');
        await store.writeBlob(
          'b-i1',
          Uint8List.fromList(utf8.encode('jpeg')),
          Uint8List.fromList([1, 2]),
        );
        expect(utf8.decode((await store.readBlob('b-i1'))!), 'jpeg');
        expect(await store.readThumbnail('b-i1'), [1, 2]);
        expect(await store.readBlob('unknown'), isNull);
      },
    );
  });

  group('the engine scenarios on Drift', () {
    for (final MapEntry(:key, :value) in engineScenarios.entries) {
      test(key, () => value(Sim(newStore: newDevice)));
    }
  });
}

extension on DecodeResult {
  SyncRecord get let => (this as DecodedRecord).record;
}
