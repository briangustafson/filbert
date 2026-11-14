import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProjectsCompanion project(String id) => ProjectsCompanion.insert(
    id: id,
    createdAt: 1000,
    updatedAt: 2000,
    updatedByDeviceId: 'device-1',
    name: '2026-11-14',
    nameIsDefault: true,
  );

  ImagesCompanion image(String id, String projectId) => ImagesCompanion.insert(
    id: id,
    createdAt: 1000,
    updatedAt: 1000,
    updatedByDeviceId: 'device-1',
    projectId: projectId,
    blobId: 'blob-$id',
    mimeType: 'image/jpeg',
    width: 4000,
    height: 3000,
    source: ImageSource.camera,
    editsJson: '{"v":1,"quarterTurns":0}',
  );

  test('schema version is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('projects: defaults and round-trip', () async {
    await db.into(db.projects).insert(project('p1'));
    final row = await db.select(db.projects).getSingle();
    expect(row.name, '2026-11-14');
    expect(row.nameIsDefault, isTrue);
    expect(row.sizeKind, SizeKind.none);
    expect(row.startNotes, '');
    expect(row.unit, isNull);
    expect(row.referenceImageId, isNull);
    expect(row.deletedAt, isNull);
    expect(row.updatedAt, 2000);
  });

  test('projects: physical size stores unit codes in / cm', () async {
    await db
        .into(db.projects)
        .insert(
          project('p1').copyWith(
            sizeKind: const Value(SizeKind.physical),
            width: const Value(11),
            height: const Value(14),
            unit: const Value(LengthUnit.inches),
          ),
        );
    final raw = await db
        .customSelect('SELECT size_kind, unit FROM projects')
        .getSingle();
    expect(raw.read<String>('size_kind'), 'physical');
    expect(raw.read<String>('unit'), 'in');
    expect((await db.select(db.projects).getSingle()).unit, LengthUnit.inches);
    expect(LengthUnit.fromCode('cm'), LengthUnit.centimeters);
  });

  test('images: round-trip and enum storage', () async {
    await db.into(db.projects).insert(project('p1'));
    await db.into(db.images).insert(image('i1', 'p1'));
    final row = await db.select(db.images).getSingle();
    expect(row.projectId, 'p1');
    expect(row.source, ImageSource.camera);
    expect(row.capturedAt, isNull);
    final raw = await db.customSelect('SELECT source FROM images').getSingle();
    expect(raw.read<String>('source'), 'camera');
  });

  test('references are not enforced (sync may deliver out of order)', () async {
    await db.into(db.images).insert(image('i1', 'missing-project'));
    expect(await db.select(db.images).get(), hasLength(1));
  });

  test('edit history: keyed by image and seq, cursor per image', () async {
    for (var seq = 0; seq < 3; seq++) {
      await db
          .into(db.imageEditHistory)
          .insert(
            ImageEditHistoryCompanion.insert(
              imageId: 'i1',
              seq: seq,
              editsJson: '{"v":1,"quarterTurns":$seq}',
            ),
          );
    }
    await expectLater(
      db
          .into(db.imageEditHistory)
          .insert(
            ImageEditHistoryCompanion.insert(
              imageId: 'i1',
              seq: 1,
              editsJson: '{}',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );

    await db
        .into(db.imageEditCursor)
        .insertOnConflictUpdate(
          ImageEditCursorCompanion.insert(imageId: 'i1', seq: 2),
        );
    await db
        .into(db.imageEditCursor)
        .insertOnConflictUpdate(
          ImageEditCursorCompanion.insert(imageId: 'i1', seq: 1),
        );
    final cursor = await db.select(db.imageEditCursor).getSingle();
    expect(cursor.seq, 1);
    expect(await db.select(db.imageEditHistory).get(), hasLength(3));
  });

  test('app_meta: key/value', () async {
    await db
        .into(db.appMeta)
        .insert(AppMetaCompanion.insert(key: 'units', value: 'cm'));
    expect((await db.select(db.appMeta).getSingle()).value, 'cm');
  });
}
