// Migration harness (m1-design §4.1). `dart run drift_dev make-migrations`
// regenerates `generated/` and `lib/core/db/app_database.steps.dart`.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schemaVersion matches the newest committed schema dump', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, GeneratedHelper.versions.last);
  });

  for (final version in GeneratedHelper.versions) {
    test('database matches schema dump v$version', () async {
      final schema = await verifier.schemaAt(version);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, version);
      await db.close();
    });
  }

  test('v1 → v2 keeps the data; images get no derived_from_json', () async {
    const project = v1.ProjectsData(
      id: 'p1',
      createdAt: 1,
      updatedAt: 2,
      updatedByDeviceId: 'd',
      name: 'Still life',
      nameIsDefault: 0,
      sizeKind: 'physical',
      width: 30,
      height: 40,
      unit: 'cm',
      startNotes: 'notes',
      referenceImageId: 'i1',
    );
    const image = v1.ImagesData(
      id: 'i1',
      createdAt: 3,
      updatedAt: 4,
      updatedByDeviceId: 'd',
      projectId: 'p1',
      blobId: 'b1',
      mimeType: 'image/jpeg',
      width: 4000,
      height: 3000,
      source: 'camera',
      capturedAt: 5,
      editsJson: '{"v":1}',
    );
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, old) {
        batch.insert(old.projects, project);
        batch.insert(old.images, image);
      },
      validateItems: (db) async {
        expect(
          (await db.select(db.projects).get()).single.toJson(),
          project.toJson(),
        );
        final migrated = (await db.select(db.images).get()).single.toJson();
        expect(migrated.remove('derivedFromJson'), isNull);
        expect(migrated, image.toJson());
        expect(await db.select(db.viewPrefs).get(), isEmpty);
      },
    );
  });

  test('at most one live view_prefs row per project', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    ViewPrefsCompanion row(String id, {int? deletedAt}) =>
        ViewPrefsCompanion.insert(
          id: id,
          createdAt: 1,
          updatedAt: 1,
          updatedByDeviceId: 'd',
          deletedAt: Value(deletedAt),
          projectId: 'p1',
          prefsJson: '{}',
        );
    await db.into(db.viewPrefs).insert(row('a', deletedAt: 5));
    await db.into(db.viewPrefs).insert(row('b'));
    await expectLater(
      db.into(db.viewPrefs).insert(row('c')),
      throwsA(isA<SqliteException>()),
    );
  });
}
