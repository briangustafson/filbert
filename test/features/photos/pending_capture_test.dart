import 'package:drift/native.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/db/app_meta_keys.dart';
import 'package:filbert/features/photos/data/pending_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftPendingCaptureStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftPendingCaptureStore(db);
  });
  tearDown(() => db.close());

  test('empty until saved; save replaces; clear removes', () async {
    expect(await store.read(), isNull);

    await store.save(const CaptureForProject('p1'));
    expect(await store.read(), const CaptureForProject('p1'));

    await store.save(const CaptureForProject('p2', asReference: true));
    expect(
      await store.read(),
      const CaptureForProject('p2', asReference: true),
    );

    await store.save(const CaptureForNewProject());
    expect(await store.read(), const CaptureForNewProject());

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('malformed values read as nothing', () async {
    for (final bad in ['not json', '{"target":"grid"}', '{"target":"x"}']) {
      await db
          .into(db.appMeta)
          .insertOnConflictUpdate(
            AppMetaCompanion.insert(
              key: AppMetaKeys.pendingCapture,
              value: bad,
            ),
          );
      expect(await store.read(), isNull, reason: bad);
    }
  });
}
