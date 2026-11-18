import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart' hide ViewPrefs;
import 'package:filbert/core/device/device_info.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:filbert/features/view_aids/data/view_prefs_repository.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late UuidV7IdGenerator ids;
  late DriftViewPrefsRepository repo;
  late DriftProjectRepository projects;
  const device = StoredDeviceInfo(deviceId: 'device-a');

  final start = DateTime.utc(2026, 11, 18, 12);
  const bands3 = ViewPrefs(values: ValuesPrefs(bands: 3));
  const bands7 = ViewPrefs(values: ValuesPrefs(bands: 7));

  DriftViewPrefsRepository makeRepo(Duration debounce) =>
      DriftViewPrefsRepository(
        db: db,
        clock: clock,
        ids: ids,
        device: device,
        debounce: debounce,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    ids = UuidV7IdGenerator(clock);
    projects = DriftProjectRepository(
      db: db,
      clock: clock,
      ids: ids,
      device: device,
    );
    // Long enough that only flush() writes, unless a test says otherwise.
    repo = makeRepo(const Duration(hours: 1));
  });
  tearDown(() => db.close());

  Future<List<ViewPrefsRecord>> rows() => db.select(db.viewPrefs).get();

  test('defaults when the project has no row', () async {
    expect(await repo.watch('p1').first, ViewPrefs.defaults);
    await repo.flush();
    expect(await rows(), isEmpty);
  });

  test('watch shows a change at once, before it is written', () async {
    final seen = <ViewPrefs>[];
    final sub = repo.watch('p1').listen(seen.add);
    await pumpEventQueue();
    repo.update('p1', bands3);
    await pumpEventQueue();
    expect(seen, [ViewPrefs.defaults, bands3]);
    expect(await rows(), isEmpty);
    // A new watcher sees it too.
    expect(await repo.watch('p1').first, bands3);
    await sub.cancel();
  });

  test('the first change creates the row, stamped', () async {
    repo.update('p1', bands3);
    await repo.flush();
    final row = (await rows()).single;
    expect(row.projectId, 'p1');
    expect(ViewPrefs.fromJsonString(row.prefsJson), bands3);
    expect(row.createdAt, start.millisecondsSinceEpoch);
    expect(row.updatedAt, start.millisecondsSinceEpoch);
    expect(row.updatedByDeviceId, 'device-a');
    expect(row.deletedAt, isNull);
  });

  test('changes are debounced into one write', () async {
    final fast = makeRepo(const Duration(milliseconds: 200));
    final writes = <int>[];
    final sub = db
        .select(db.viewPrefs)
        .watch()
        .listen((r) => writes.add(r.length));
    await pumpEventQueue();
    for (var bands = 2; bands <= 9; bands++) {
      fast.update('p1', ViewPrefs(values: ValuesPrefs(bands: bands)));
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(await rows(), isEmpty, reason: 'still within the debounce');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(
      ViewPrefs.fromJsonString((await rows()).single.prefsJson),
      const ViewPrefs(values: ValuesPrefs(bands: 9)),
    );
    expect(writes, [0, 1], reason: 'one write after the initial empty read');
    await sub.cancel();
    await fast.dispose();
  });

  test('later changes update the same row and restamp it', () async {
    repo.update('p1', bands3);
    await repo.flush();
    final created = (await rows()).single;
    clock.advance(const Duration(minutes: 5));
    repo.update('p1', bands7);
    await repo.flush();
    final row = (await rows()).single;
    expect(row.id, created.id);
    expect(row.createdAt, created.createdAt);
    expect(row.updatedAt, clock.now().millisecondsSinceEpoch);
    expect(await repo.watch('p1').first, bands7);
  });

  test('an unchanged value is not rewritten', () async {
    repo.update('p1', bands3);
    await repo.flush();
    clock.advance(const Duration(minutes: 5));
    repo.update('p1', bands3);
    await repo.flush();
    expect((await rows()).single.updatedAt, start.millisecondsSinceEpoch);
  });

  test('setting defaults without a row writes nothing', () async {
    repo.update('p1', ViewPrefs.defaults);
    await repo.flush();
    expect(await rows(), isEmpty);
  });

  test('projects are independent', () async {
    repo.update('p1', bands3);
    repo.update('p2', bands7);
    await repo.flush();
    expect(await rows(), hasLength(2));
    expect(await repo.watch('p1').first, bands3);
    expect(await repo.watch('p2').first, bands7);
  });

  test('dispose writes pending changes', () async {
    repo.update('p1', bands3);
    await repo.dispose();
    expect(await rows(), hasLength(1));
  });

  test('reads a row written by another device or version', () async {
    await db
        .into(db.viewPrefs)
        .insert(
          ViewPrefsCompanion.insert(
            id: 'r1',
            createdAt: 1,
            updatedAt: 1,
            updatedByDeviceId: 'device-b',
            projectId: 'p1',
            prefsJson: '{"v":1,"colors":{"count":12},"newAid":{}}',
          ),
        );
    expect(
      await repo.watch('p1').first,
      const ViewPrefs(colors: ColorsPrefs(count: 12)),
    );
    await (db.update(db.viewPrefs)..where((t) => t.id.equals('r1'))).write(
      const ViewPrefsCompanion(prefsJson: Value('{"v":9}')),
    );
    expect(await repo.watch('p1').first, ViewPrefs.defaults);
  });

  test('a tombstoned row is ignored and a new one created', () async {
    await db
        .into(db.viewPrefs)
        .insert(
          ViewPrefsCompanion.insert(
            id: 'old',
            createdAt: 1,
            updatedAt: 1,
            updatedByDeviceId: 'device-b',
            deletedAt: const Value(2),
            projectId: 'p1',
            prefsJson: bands7.toJsonString(),
          ),
        );
    expect(await repo.watch('p1').first, ViewPrefs.defaults);
    repo.update('p1', bands3);
    await repo.flush();
    final live = (await rows()).where((r) => r.deletedAt == null).single;
    expect(live.id, isNot('old'));
    expect(ViewPrefs.fromJsonString(live.prefsJson), bands3);
  });

  test('changing prefs leaves the project and the list order alone', () async {
    final older = await projects.create();
    clock.advance(const Duration(minutes: 1));
    final newer = await projects.create();
    clock.advance(const Duration(minutes: 1));
    repo.update(older.id, bands3);
    await repo.flush();
    expect(await projects.watch(older.id).first, older);
    expect(
      [for (final p in await projects.watchAll().first) p.id],
      [newer.id, older.id],
    );
  });
}
