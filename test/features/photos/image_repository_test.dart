import 'dart:io';

import 'package:drift/native.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/device/device_info.dart';
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:filbert/core/imaging/image_metadata.dart';
import 'package:filbert/features/photos/data/image_repository.dart';
import 'package:filbert/features/photos/data/photo_source.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Hands out queued ids first, then real UUIDv7s.
class _QueuedIds implements IdGenerator {
  _QueuedIds(this._fallback);

  final IdGenerator _fallback;
  final queue = <String>[];

  @override
  String newId() => queue.isEmpty ? _fallback.newId() : queue.removeAt(0);
}

void main() {
  late Directory root;
  late Directory picked;
  late AppDatabase db;
  late FakeClock clock;
  late _QueuedIds ids;
  late LocalFileStore files;
  late DriftProjectRepository projects;
  late DriftImageRepository images;
  late String projectId;

  final start = DateTime.utc(2026, 11, 15, 12);
  const device = StoredDeviceInfo(deviceId: 'device-a');

  setUp(() async {
    root = Directory.systemTemp.createTempSync('filbert_images');
    picked = Directory('${root.path}/picked')..createSync();
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    ids = _QueuedIds(UuidV7IdGenerator(clock));
    files = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
    projects = DriftProjectRepository(
      db: db,
      clock: clock,
      ids: ids,
      device: device,
    );
    images = DriftImageRepository(
      db: db,
      files: files,
      metadata: const PlatformImageMetadataReader(),
      clock: clock,
      ids: ids,
      device: device,
    );
    projectId = (await projects.create()).id;
  });

  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  PickedPhoto photo(
    String fixture, {
    String? as,
    ImageOrigin origin = ImageOrigin.device,
  }) =>
      PickedPhoto(path: copyFixture(fixture, picked, as).path, origin: origin);

  Future<List<ProjectImage>> live() => images.watchForProject(projectId).first;
  Future<String?> referenceId() async =>
      (await projects.watch(projectId).first)!.referenceImageId;
  List<String> blobFiles() {
    final dir = Directory('${root.path}/support/blobs');
    return dir.existsSync()
        ? dir.listSync().map((e) => e.uri.pathSegments.last).toList()
        : [];
  }

  void tick() => clock.advance(const Duration(minutes: 1));

  Future<ProjectImage> importOne(
    String fixture, {
    bool asReference = false,
  }) async {
    final result = await images.import(projectId, [
      photo(fixture),
    ], asReference: asReference);
    return (result.single as ImportSuccess).image;
  }

  group('import', () {
    test('stores the original and records metadata', () async {
      tick();
      final results = await images.import(projectId, [
        photo('orientation_6.jpg', origin: ImageOrigin.camera),
      ]);

      final image = (results.single as ImportSuccess).image;
      expect(image.projectId, projectId);
      expect(image.mimeType, 'image/jpeg');
      expect((image.width, image.height), (30, 40));
      expect(image.origin, ImageOrigin.camera);
      expect(image.capturedAt, DateTime(2026, 3, 5, 14).toUtc());
      expect(image.edits, Edits.none);
      expect(image.createdAt, start.add(const Duration(minutes: 1)));
      expect(image.updatedByDeviceId, 'device-a');

      final blob = files.blobFile(image.blobId, 'jpg');
      expect(
        blob.readAsBytesSync(),
        fixtureImage('orientation_6.jpg').readAsBytesSync(),
        reason: 'original stored byte-for-byte',
      );
      expect(await live(), [image]);
    });

    test('deletes the picked temp files', () async {
      final p = photo('no_exif.jpg');
      await images.import(projectId, [p]);
      expect(File(p.path).existsSync(), isFalse);
    });

    test('updates the project timestamp', () async {
      tick();
      await importOne('plain.png');
      final project = (await projects.watch(projectId).first)!;
      expect(project.updatedAt, start.add(const Duration(minutes: 1)));
      expect(project.referenceImageId, isNull);
    });

    test('keeps the format: stored with its extension', () async {
      final png = await importOne('plain.png');
      final jpg = await importOne('no_exif.jpg');
      expect(png.mimeType, 'image/png');
      expect(jpg.mimeType, 'image/jpeg');
      expect(
        blobFiles(),
        unorderedEquals(['${png.blobId}.png', '${jpg.blobId}.jpg']),
      );
    });

    test('HEIC is stored as-is', () async {
      final heic = await importOne('landscape.heic');
      expect(heic.mimeType, 'image/heic');
      expect(
        files.blobFile(heic.blobId, 'heic').readAsBytesSync(),
        fixtureImage('landscape.heic').readAsBytesSync(),
      );
    }, skip: heicSkip);

    test('a bad file fails alone; others still import', () async {
      final bad = photo('not_an_image.txt');
      final results = await images.import(projectId, [
        photo('no_exif.jpg'),
        bad,
        photo('plain.png'),
      ]);

      expect(results.map((r) => r.runtimeType), [
        ImportSuccess,
        ImportFailure,
        ImportSuccess,
      ]);
      expect(
        (results[1] as ImportFailure).error,
        isA<UnsupportedImageException>(),
      );
      expect(File(bad.path).existsSync(), isFalse, reason: 'temp cleaned up');
      expect(await live(), hasLength(2));
      expect(blobFiles(), hasLength(2));
    });

    test('a failed database insert removes the copied blob', () async {
      ids.queue.addAll(['blob-1', 'image-1', 'blob-2', 'image-1']);
      final results = await images.import(projectId, [
        photo('no_exif.jpg', as: 'a.jpg'),
        photo('no_exif.jpg', as: 'b.jpg'),
      ]);

      expect(results.first, isA<ImportSuccess>());
      expect(results.last, isA<ImportFailure>());
      expect(blobFiles(), ['blob-1.jpg']);
      expect(File('${picked.path}/b.jpg').existsSync(), isFalse);
    });

    test('into a deleted or missing project throws', () async {
      await projects.delete(projectId);
      await expectLater(
        images.import(projectId, [photo('no_exif.jpg')]),
        throwsA(isA<ProjectNotFoundException>()),
      );
      await expectLater(
        images.import('missing', [photo('no_exif.jpg', as: 'x.jpg')]),
        throwsA(isA<ProjectNotFoundException>()),
      );
      expect(blobFiles(), isEmpty);
    });

    test('as reference sets the pointer in the same step', () async {
      final image = await importOne('no_exif.jpg', asReference: true);
      expect(await referenceId(), image.id);
    });

    test('as reference requires exactly one photo', () async {
      await expectLater(
        images.import(projectId, [
          photo('no_exif.jpg'),
          photo('plain.png'),
        ], asReference: true),
        throwsArgumentError,
      );
    });
  });

  group('watchForProject', () {
    test('newest first, live only, this project only', () async {
      final a = await importOne('no_exif.jpg');
      tick();
      final b = await importOne('plain.png');
      tick();
      final c = await importOne('orientation_1_offset.jpg');
      await images.delete(b.id);

      final other = (await projects.create()).id;
      await images.import(other, [photo('orientation_8.jpg')]);

      expect([for (final i in await live()) i.id], [c.id, a.id]);
    });
  });

  group('reference rules', () {
    test('set, replace, and remove keep images in the project', () async {
      final first = await importOne('no_exif.jpg');
      final second = await importOne('plain.png');

      await images.setAsReference(projectId, first.id);
      expect(await referenceId(), first.id);

      // Replace: the old reference stays in the project.
      await images.setAsReference(projectId, second.id);
      expect(await referenceId(), second.id);

      // Remove: clears the pointer; the image stays.
      await images.setAsReference(projectId, null);
      expect(await referenceId(), isNull);
      expect(await live(), hasLength(2));
    });

    test('setting the reference stamps the project', () async {
      final image = await importOne('no_exif.jpg');
      tick();
      await images.setAsReference(projectId, image.id);
      final project = (await projects.watch(projectId).first)!;
      expect(project.updatedAt, start.add(const Duration(minutes: 1)));
    });

    test('rejects images from another project, deleted, or missing', () async {
      final other = (await projects.create()).id;
      final foreign =
          ((await images.import(other, [photo('plain.png')])).single
                  as ImportSuccess)
              .image;
      final deleted = await importOne('no_exif.jpg');
      await images.delete(deleted.id);

      await expectLater(
        images.setAsReference(projectId, foreign.id),
        throwsArgumentError,
      );
      await expectLater(
        images.setAsReference(projectId, deleted.id),
        throwsA(isA<ImageNotFoundException>()),
      );
      await expectLater(
        images.setAsReference(projectId, 'missing'),
        throwsA(isA<ImageNotFoundException>()),
      );
      expect(await referenceId(), isNull);
    });

    test(
      'deleting the reference keeps the pointer; restore brings it back',
      () async {
        final image = await importOne('no_exif.jpg', asReference: true);
        await images.delete(image.id);
        expect(await referenceId(), image.id);
        expect(await live(), isEmpty);

        await images.restore(image.id);
        expect(await referenceId(), image.id);
        expect(await live(), hasLength(1));
      },
    );

    test('a new reference while the old one is deleted wins', () async {
      final old = await importOne('no_exif.jpg', asReference: true);
      await images.delete(old.id);
      final replacement = await importOne('plain.png', asReference: true);
      await images.restore(old.id);

      expect(await referenceId(), replacement.id);
      expect(await live(), hasLength(2));
    });
  });

  group('delete and restore', () {
    test('tombstone keeps the record and the file', () async {
      final image = await importOne('no_exif.jpg');
      tick();
      await images.delete(image.id);

      final row = await db.select(db.images).getSingle();
      final at = start.add(const Duration(minutes: 1)).millisecondsSinceEpoch;
      expect(row.deletedAt, at);
      expect(row.updatedAt, at);
      expect(files.blobFile(image.blobId, 'jpg').existsSync(), isTrue);
    });

    test('repeats are no-ops; unknown ids throw', () async {
      final image = await importOne('no_exif.jpg');
      await images.restore(image.id);
      await images.delete(image.id);
      await images.delete(image.id);
      await expectLater(
        images.delete('missing'),
        throwsA(isA<ImageNotFoundException>()),
      );
      await expectLater(
        images.restore('missing'),
        throwsA(isA<ImageNotFoundException>()),
      );
    });
  });
}
