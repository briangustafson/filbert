import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/db/app_meta_keys.dart';
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/features/photos/data/purge_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late FakeClock clock;
  late LocalFileStore files;
  late PurgeJob job;

  final now = DateTime.utc(2026, 11, 15, 12);
  int daysAgo(int days) =>
      now.subtract(Duration(days: days)).millisecondsSinceEpoch;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('filbert_purge');
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(now);
    files = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
    await files.thumbsDir.create(recursive: true);
    await files.previewsDir.create(recursive: true);
    job = PurgeJob(db: db, files: files, clock: clock);
  });

  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<void> addProject(String id, {int? deletedAt}) => db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: id,
          createdAt: 0,
          updatedAt: 0,
          updatedByDeviceId: 'd',
          name: id,
          nameIsDefault: false,
          deletedAt: Value(deletedAt),
        ),
      );

  /// Adds an image with a blob, a thumbnail, and a preview on disk.
  Future<void> addImage(String id, String projectId, {int? deletedAt}) async {
    await db
        .into(db.images)
        .insert(
          ImagesCompanion.insert(
            id: id,
            createdAt: 0,
            updatedAt: 0,
            updatedByDeviceId: 'd',
            deletedAt: Value(deletedAt),
            projectId: projectId,
            blobId: 'blob-$id',
            mimeType: 'image/jpeg',
            width: 1,
            height: 1,
            source: ImageOrigin.device,
            editsJson: '{"v":1,"quarterTurns":0}',
          ),
        );
    final src = File('${root.path}/src-$id')..writeAsStringSync(id);
    await files.putBlob('blob-$id', 'jpg', src);
    File('${files.thumbsDir.path}/$id-h-256.jpg').writeAsStringSync('t');
    File('${files.previewsDir.path}/$id-h.jpg').writeAsStringSync('p');
  }

  bool hasFiles(String id) =>
      files.blobFile('blob-$id', 'jpg').existsSync() ||
      File('${files.thumbsDir.path}/$id-h-256.jpg').existsSync() ||
      File('${files.previewsDir.path}/$id-h.jpg').existsSync();

  bool hasAllFiles(String id) =>
      files.blobFile('blob-$id', 'jpg').existsSync() &&
      File('${files.thumbsDir.path}/$id-h-256.jpg').existsSync() &&
      File('${files.previewsDir.path}/$id-h.jpg').existsSync();

  test('purges files of images deleted more than 30 days ago', () async {
    await addProject('p');
    await addImage('old', 'p', deletedAt: daysAgo(31));
    await addImage('recent', 'p', deletedAt: daysAgo(29));
    await addImage('live', 'p');

    expect(await job.run(), 1);

    expect(hasFiles('old'), isFalse);
    expect(hasAllFiles('recent'), isTrue);
    expect(hasAllFiles('live'), isTrue);
    expect(
      await db.select(db.images).get(),
      hasLength(3),
      reason: 'records kept',
    );
  });

  test('purges files of images in projects deleted over 30 days ago', () async {
    await addProject('gone', deletedAt: daysAgo(40));
    await addProject('recent', deletedAt: daysAgo(3));
    await addImage('a', 'gone');
    await addImage('b', 'recent');

    expect(await job.run(), 1);
    expect(hasFiles('a'), isFalse);
    expect(hasAllFiles('b'), isTrue);
    expect(await db.select(db.projects).get(), hasLength(2));
  });

  test('exactly 30 days is not yet purged', () async {
    await addProject('p');
    await addImage('edge', 'p', deletedAt: daysAgo(30));
    expect(await job.run(), 0);
    expect(hasAllFiles('edge'), isTrue);
  });

  test('never touches live data', () async {
    await addProject('p');
    await addImage('x', 'p');
    await addImage('orphan', 'no-such-project');
    expect(await job.run(), 0);
    expect(hasAllFiles('x'), isTrue);
    expect(hasAllFiles('orphan'), isTrue);
  });

  test('re-running is harmless', () async {
    await addProject('p');
    await addImage('old', 'p', deletedAt: daysAgo(31));
    await job.run();
    await job.run();
    expect(hasFiles('old'), isFalse);
  });

  test('runIfDue runs at most once a day', () async {
    await addProject('p');
    await addImage('a', 'p', deletedAt: daysAgo(31));
    expect(await job.runIfDue(), 1);

    final meta = await (db.select(
      db.appMeta,
    )..where((m) => m.key.equals(AppMetaKeys.lastPurgeAt))).getSingle();
    expect(meta.value, now.millisecondsSinceEpoch.toString());

    await addImage('b', 'p', deletedAt: daysAgo(31));
    clock.advance(const Duration(hours: 23));
    expect(await job.runIfDue(), 0);
    expect(hasAllFiles('b'), isTrue);

    clock.advance(const Duration(hours: 1));
    expect(await job.runIfDue(), greaterThan(0));
    expect(hasFiles('b'), isFalse);
  });
}
