import 'package:drift/native.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/device/device_info.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DriftProjectRepository repo;

  // Noon UTC is the same calendar day in every time zone from -11 to +11.
  final start = DateTime.utc(2026, 11, 15, 12);
  const today = '2026-11-15';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    repo = DriftProjectRepository(
      db: db,
      clock: clock,
      ids: UuidV7IdGenerator(clock),
      device: const StoredDeviceInfo(deviceId: 'device-a'),
    );
  });
  tearDown(() => db.close());

  Future<List<Project>> all() => repo.watchAll().first;
  Future<Project?> one(String id) => repo.watch(id).first;
  Future<List<String>> names() async => [for (final p in await all()) p.name];

  void tick() => clock.advance(const Duration(minutes: 1));

  group('create', () {
    test('uses defaults', () async {
      final p = await repo.create();
      expect(p.name, today);
      expect(p.nameIsDefault, isTrue);
      expect(p.size, const NoSize());
      expect(p.startNotes, '');
      expect(p.referenceImageId, isNull);
      expect(p.createdAt, start);
      expect(p.updatedAt, start);
      expect(p.updatedByDeviceId, 'device-a');
      expect(await one(p.id), p);
    });

    test('numbers names that are already taken', () async {
      for (var i = 0; i < 4; i++) {
        await repo.create();
      }
      expect(
        await names(),
        unorderedEquals([today, '$today (2)', '$today (3)', '$today (4)']),
      );
    });

    test('reuses the lowest free number', () async {
      await repo.create();
      final second = await repo.create();
      await repo.create();
      await repo.delete(second.id);

      expect((await repo.create()).name, '$today (2)');
    });

    test('ignores deleted projects', () async {
      final first = await repo.create();
      await repo.delete(first.id);
      expect((await repo.create()).name, today);
    });

    test('counts renamed projects that use a default-looking name', () async {
      final p = await repo.create();
      await repo.update(p.id, name: 'Harbor at dusk');
      final other = await repo.create();
      expect(other.name, today);
      await repo.update(p.id, name: today);
      expect((await repo.create()).name, '$today (2)');
    });

    test('a new day starts again without a number', () async {
      await repo.create();
      clock.advance(const Duration(days: 1));
      expect((await repo.create()).name, '2026-11-16');
    });

    test('concurrent creates get distinct names', () async {
      final created = await Future.wait([
        for (var i = 0; i < 5; i++) repo.create(),
      ]);
      expect({for (final p in created) p.name}, hasLength(5));
    });

    test('default name uses the local calendar date', () {
      expect(
        DriftProjectRepository.defaultNameBase(DateTime(2026, 3, 5, 0, 30)),
        '2026-03-05',
      );
      expect(
        DriftProjectRepository.defaultNameBase(DateTime(2026, 12, 31, 23, 59)),
        '2026-12-31',
      );
    });
  });

  group('update', () {
    test('rename clears nameIsDefault and stamps the change', () async {
      final p = await repo.create();
      tick();
      await repo.update(p.id, name: 'Morning light');

      final updated = (await one(p.id))!;
      expect(updated.name, 'Morning light');
      expect(updated.nameIsDefault, isFalse);
      expect(updated.updatedAt, start.add(const Duration(minutes: 1)));
      expect(updated.createdAt, start);
    });

    test('size round-trips for each kind and clears other fields', () async {
      final p = await repo.create();
      for (final size in const [
        PhysicalSize(11, 14, LengthUnit.inches),
        RatioSize(4, 5),
        PhysicalSize(50, 70, LengthUnit.centimeters),
        NoSize(),
      ]) {
        await repo.update(p.id, size: size);
        expect((await one(p.id))!.size, size);
      }
      final row = await db.select(db.projects).getSingle();
      expect([
        row.ratioW,
        row.ratioH,
        row.width,
        row.height,
        row.unit,
      ], everyElement(isNull));
    });

    test('start notes', () async {
      final p = await repo.create();
      await repo.update(p.id, startNotes: 'Limited palette, warm ground.');
      final updated = (await one(p.id))!;
      expect(updated.startNotes, 'Limited palette, warm ground.');
      expect(updated.nameIsDefault, isTrue);
    });

    test('unchanged values write nothing', () async {
      final p = await repo.create();
      tick();
      await repo.update(
        p.id,
        name: p.name,
        size: const NoSize(),
        startNotes: '',
      );
      final same = (await one(p.id))!;
      expect(same, p);
      expect(same.nameIsDefault, isTrue);
    });

    test('rejects blank names and invalid sizes', () async {
      final p = await repo.create();
      await expectLater(repo.update(p.id, name: '  '), throwsArgumentError);
      await expectLater(
        repo.update(p.id, size: const RatioSize(0, 5)),
        throwsArgumentError,
      );
      await expectLater(
        repo.update(
          p.id,
          size: const PhysicalSize(12, double.nan, LengthUnit.inches),
        ),
        throwsArgumentError,
      );
      expect(await one(p.id), p);
    });

    test('stamps the device that made the change', () async {
      final p = await repo.create();
      final otherDevice = DriftProjectRepository(
        db: db,
        clock: clock,
        ids: UuidV7IdGenerator(clock),
        device: const StoredDeviceInfo(deviceId: 'device-b'),
      );
      await otherDevice.update(p.id, name: 'Renamed elsewhere');
      expect((await one(p.id))!.updatedByDeviceId, 'device-b');
    });
  });

  group('watchAll', () {
    test('is sorted by updatedAt, newest first', () async {
      final a = await repo.create();
      tick();
      final b = await repo.create();
      tick();
      final c = await repo.create();
      expect([for (final p in await all()) p.id], [c.id, b.id, a.id]);

      tick();
      await repo.update(a.id, startNotes: 'touched');
      expect([for (final p in await all()) p.id], [a.id, c.id, b.id]);
    });

    test('emits when projects change', () async {
      final p = await repo.create();
      final stream = repo.watchAll().map((ps) => [for (final x in ps) x.name]);
      final expectation = expectLater(
        stream,
        emitsInOrder([
          [today],
          ['Renamed'],
          <String>[],
        ]),
      );
      await pumpEventQueue();
      await repo.update(p.id, name: 'Renamed');
      await pumpEventQueue();
      await repo.delete(p.id);
      await expectation;
    });
  });

  group('delete and restore', () {
    test('delete tombstones: hidden from watches, row kept', () async {
      final p = await repo.create();
      tick();
      await repo.delete(p.id);

      expect(await all(), isEmpty);
      expect(await one(p.id), isNull);
      final row = await db.select(db.projects).getSingle();
      final deletedAtMs = start
          .add(const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      expect(row.deletedAt, deletedAtMs);
      expect(row.updatedAt, deletedAtMs);
    });

    test(
      'restore brings the project back unchanged except timestamps',
      () async {
        final p = await repo.create();
        await repo.update(
          p.id,
          name: 'Still life',
          size: const RatioSize(3, 4),
        );
        await repo.delete(p.id);
        tick();
        await repo.restore(p.id);

        final restored = (await one(p.id))!;
        expect(restored.name, 'Still life');
        expect(restored.size, const RatioSize(3, 4));
        expect(restored.updatedAt, start.add(const Duration(minutes: 1)));
        expect(await all(), [restored]);
      },
    );

    test('restore may duplicate a name; names are not unique', () async {
      final p = await repo.create();
      await repo.delete(p.id);
      await repo.create();
      await repo.restore(p.id);
      expect(await names(), [today, today]);
    });

    test('repeating delete or restore is a no-op', () async {
      final p = await repo.create();
      await repo.restore(p.id);
      expect(await one(p.id), p);

      await repo.delete(p.id);
      final deletedAt = (await db.select(db.projects).getSingle()).deletedAt;
      tick();
      await repo.delete(p.id);
      expect((await db.select(db.projects).getSingle()).deletedAt, deletedAt);
    });

    test('deleted projects can still be updated (e.g. by sync)', () async {
      final p = await repo.create();
      await repo.delete(p.id);
      await repo.update(p.id, name: 'Renamed while deleted');
      await repo.restore(p.id);
      expect((await one(p.id))!.name, 'Renamed while deleted');
    });
  });

  test('unknown ids throw ProjectNotFoundException', () async {
    final notFound = throwsA(isA<ProjectNotFoundException>());
    await expectLater(repo.update('missing', name: 'x'), notFound);
    await expectLater(repo.delete('missing'), notFound);
    await expectLater(repo.restore('missing'), notFound);
    expect(await one('missing'), isNull);
  });
}
