import 'dart:convert';

import 'package:matcher/expect.dart';

import '../record.dart';
import '../record_codec.dart';
import '../stores.dart';
import 'sim.dart';

typedef Scenario = Future<void> Function(Sim sim);

/// The engine's multi-device tests (m3-design §12), shared so they run
/// against [MemoryLocalStore] here and against the Drift store in T6:
///
/// ```dart
/// for (final MapEntry(:key, :value) in engineScenarios.entries) {
///   test(key, () => value(Sim(newStore: ...)));
/// }
/// ```
final Map<String, Scenario> engineScenarios = {
  // -------------------------------------------------------- the basics
  'a project made on A appears on B': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    await a.sync();
    final report = await b.sync();
    expect(report.pulled, 1);
    expect((await b.get(p.key))!.name, 'Harbour');
    await sim.expectConverged([a, b]);
  },

  'an edit on B reaches A, which had not changed it': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    await a.sync();
    await b.sync();
    await b.edit(p.key, {'name': 'Harbour at dusk'});
    await b.sync();
    await a.sync();
    expect((await a.get(p.key))!.name, 'Harbour at dusk');
    expect(await a.conflicts(), isEmpty);
    await sim.expectConverged([a, b]);
  },

  'a second pass with nothing new does nothing': (sim) async {
    final a = sim.device('A');
    await a.newProject();
    await a.sync();
    final before = sim.remote.requests.length;
    final report = await a.sync();
    expect(report.pulled + report.pushed + report.uploaded, 0);
    expect(
      sim.remote.requests.skip(before).where((r) => !r.startsWith('changes')),
      isEmpty,
      reason: 'no reads or writes',
    );
  },

  'offline edits to different records on both merge': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'One');
    final q = await a.newProject(name: 'Two');
    await a.sync();
    await b.sync();
    await a.edit(p.key, {'startNotes': 'warm ground'});
    await b.edit(q.key, {'name': 'Two, revised'});
    await a.sync();
    await b.sync();
    await a.sync();
    expect((await b.get(p.key))!.fields['startNotes'], 'warm ground');
    expect((await a.get(q.key))!.name, 'Two, revised');
    expect(await a.conflicts(), isEmpty);
    expect(await b.conflicts(), isEmpty);
    await sim.expectConverged([a, b]);
  },

  'new images on both devices are separate records': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    await a.sync();
    await b.sync();
    await a.newImage(p.id);
    await b.newImage(p.id);
    await a.sync();
    await b.sync();
    await a.sync();
    final images = [
      for (final r in await a.data.records())
        if (r.kind == RecordKind.image) r,
    ];
    expect(images, hasLength(2));
    expect(await a.conflicts(), isEmpty);
    await sim.expectConverged([a, b]);
  },

  // --------------------------------------------------------- conflicts
  'both edit a project offline: a conflict, the local one kept': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    await a.sync();
    await b.sync();
    await a.edit(p.key, {'name': 'From A'});
    await b.edit(p.key, {'name': 'From B'});
    await a.sync();
    final report = await b.sync();
    expect(report.conflicts, 1);
    expect((await b.get(p.key))!.name, 'From B', reason: 'local shown');
    final conflict = (await b.conflicts())[p.key]!;
    final remote = const RecordCodec().decode(conflict.remoteJson);
    expect((remote as DecodedRecord).record.name, 'From A');
    // Held: B doesn't push over A's version while undecided.
    await b.sync();
    await a.sync();
    expect((await a.get(p.key))!.name, 'From A');
  },

  'the same change on both is not a conflict': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    await a.sync();
    await b.sync();
    await a.edit(p.key, {'name': 'Harbour at dusk'});
    await b.edit(p.key, {'name': 'Harbour at dusk'});
    await a.sync();
    await b.sync();
    await a.sync();
    expect(await b.conflicts(), isEmpty);
    await sim.expectConverged([a, b]);
  },

  'deleted on one, edited on the other: a conflict': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    final img = await a.newImage(p.id);
    await a.sync();
    await b.sync();
    await a.delete(img.key);
    await b.edit(img.key, {
      'edits': {'v': 1, 'quarterTurns': 1},
    });
    await a.sync();
    expect((await b.sync()).conflicts, 1);
    expect((await b.get(img.key))!.isDeleted, isFalse);
  },

  'keeping this device\'s version pushes it over the other': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    await a.sync();
    await b.sync();
    await a.edit(p.key, {'name': 'From A'});
    await b.edit(p.key, {'name': 'From B'});
    await a.sync();
    await b.sync();
    await b.engine.resolveConflict(p.key, keepLocal: true);
    expect(await b.conflicts(), isEmpty);
    await b.sync();
    await a.sync();
    expect((await a.get(p.key))!.name, 'From B');
    await sim.expectConverged([a, b]);
  },

  'taking the other version replaces this one': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    await a.sync();
    await b.sync();
    await a.edit(p.key, {'name': 'From A'});
    await b.edit(p.key, {'name': 'From B'});
    await a.sync();
    await b.sync();
    await b.engine.resolveConflict(p.key, keepLocal: false);
    expect((await b.get(p.key))!.name, 'From A');
    await b.sync();
    await a.sync();
    await sim.expectConverged([a, b]);
  },

  'a newer remote change while undecided updates the conflict': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    await a.sync();
    await b.sync();
    await a.edit(p.key, {'name': 'From A'});
    await b.edit(p.key, {'name': 'From B'});
    await a.sync();
    await b.sync();
    await a.edit(p.key, {'name': 'From A, again'});
    await a.sync();
    expect((await b.sync()).conflicts, 0, reason: 'not a second conflict');
    final conflict = (await b.conflicts())[p.key]!;
    final remote = const RecordCodec().decode(conflict.remoteJson);
    expect((remote as DecodedRecord).record.name, 'From A, again');
  },

  'tombstones sync like edits': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    await a.sync();
    await b.sync();
    await b.delete(p.key);
    await b.sync();
    await a.sync();
    expect((await a.get(p.key))!.isDeleted, isTrue);
    await sim.expectConverged([a, b]);
  },

  // ------------------------------------------------------------- blobs
  'an original and thumbnail upload before their image': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    final img = await a.newImage(p.id);
    await a.sync();
    final uploads = [
      for (final (i, r) in sim.remote.requests.indexed)
        if (r.startsWith('upload') || r == 'create ${recordFileName(img.key)}')
          (i, r),
    ];
    expect(uploads.map((u) => u.$2), [
      'upload ${blobFileName(img.blobId!, 'image/jpeg')}',
      'upload ${thumbFileName(img.blobId!)}',
      'create ${recordFileName(img.key)}',
    ]);
    expect((await a.data.blobs())[img.blobId]!.state, BlobState.synced);

    await b.sync();
    expect(
      (await b.data.blobs())[img.blobId]!.state,
      BlobState.remoteOnly,
      reason: 'downloaded later (T9)',
    );
    await sim.expectConverged([a, b]);
  },

  'an interrupted upload is not uploaded twice': (sim) async {
    final a = sim.device('A');
    final p = await a.newProject();
    final img = await a.newImage(p.id);
    sim.remote.failNext(op: 'upload', afterApply: true);
    await a.syncFailing();
    await a.sync();
    expect(
      sim.remote.named(blobFileName(img.blobId!, 'image/jpeg')),
      hasLength(1),
    );
    expect((await a.data.blobs())[img.blobId]!.state, BlobState.synced);
  },

  'an image that arrives before its project waits for it': (sim) async {
    final b = sim.device('B');
    const codec = RecordCodec();
    final orphan = SyncRecord(
      kind: RecordKind.image,
      id: 'image-x',
      createdAt: 1,
      updatedAt: 2,
      updatedByDeviceId: 'device-X',
      fields: {
        'projectId': 'project-x',
        'blobId': 'blob-x',
        'mimeType': 'image/jpeg',
        'width': 10,
        'height': 10,
        'source': 'device',
        'capturedAt': null,
        'edits': {'v': 1},
        'derivedFrom': null,
      },
    );
    sim.remote.put(recordFileName(orphan.key), codec.encode(orphan));
    expect((await b.sync()).held, 1);
    expect(await b.get(orphan.key), isNull);

    final project = SyncRecord(
      kind: RecordKind.project,
      id: 'project-x',
      createdAt: 1,
      updatedAt: 1,
      updatedByDeviceId: 'device-X',
      fields: {
        'name': 'Late',
        'nameIsDefault': false,
        'size': {'kind': 'none'},
        'startNotes': '',
        'referenceImageId': null,
      },
    );
    sim.remote.put(recordFileName(project.key), codec.encode(project));
    await b.sync();
    expect(await b.get(orphan.key), isNotNull);
    expect((await b.data.syncStates())[orphan.key]!.heldJson, isNull);
  },

  // ------------------------------------------------ failed requests
  'a dropped request: the next pass finishes the job': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    await a.newProject(name: 'One');
    await a.newProject(name: 'Two');
    sim.remote.failNext(op: 'create');
    await a.syncFailing();
    await a.sync();
    await b.sync();
    await sim.expectConverged([a, b]);
  },

  'an interrupted create leaves no duplicate': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    sim.remote.failNext(op: 'create', afterApply: true);
    await a.syncFailing();
    await a.sync();
    expect(sim.remote.named(recordFileName(p.key)), hasLength(1));
    await b.sync();
    await sim.expectConverged([a, b]);
  },

  'an interrupted update, then another edit: no conflict with itself':
      (sim) async {
        final a = sim.device('A'), b = sim.device('B');
        final p = await a.newProject(name: 'One');
        await a.sync();
        await a.edit(p.key, {'name': 'Two'});
        sim.remote.failNext(op: 'update', afterApply: true);
        await a.syncFailing();
        await a.edit(p.key, {'name': 'Three'});
        await a.sync();
        expect(await a.conflicts(), isEmpty);
        await b.sync();
        expect((await b.get(p.key))!.name, 'Three');
        await sim.expectConverged([a, b]);
      },

  'a failed pull changes nothing': (sim) async {
    final a = sim.device('A');
    await a.newProject();
    sim.remote.failNext(op: 'changes');
    await a.syncFailing();
    expect(await a.data.syncStates(), isEmpty);
    expect(await a.data.pageToken(), isNull);
    await a.sync();
    expect(sim.remote.files, hasLength(1));
  },

  'a record file on Drive twice: the newest kept, the rest deleted':
      (sim) async {
        final a = sim.device('A'), b = sim.device('B');
        final p = await a.newProject(name: 'Harbour');
        await a.sync();
        await a.edit(p.key, {'name': 'Harbour, edited'});
        await a.sync(); // version 2
        // Another client created the same file again, as a lost retry would.
        sim.remote.put(
          recordFileName(p.key),
          const RecordCodec().encode((await a.get(p.key))!),
        );
        await b.sync();
        expect(sim.remote.named(recordFileName(p.key)), hasLength(1));
        expect(sim.remote.named(recordFileName(p.key)).single.version, 2);
        await a.sync();
        await sim.expectConverged([a, b]);
      },

  // ------------------------------------------------------ the rules
  'duplicate default names are renumbered, the same on both': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final first = await a.newProject(name: '2026-11-12', nameIsDefault: true);
    final second = await b.newProject(name: '2026-11-12', nameIsDefault: true);
    await a.sync();
    await b.sync(); // B sees both and renumbers.
    await a.sync();
    await b.sync();
    expect((await a.get(first.key))!.name, '2026-11-12');
    expect((await a.get(second.key))!.name, '2026-11-12 (2)');
    expect(await a.conflicts(), isEmpty);
    expect(await b.conflicts(), isEmpty);
    await sim.expectConverged([a, b]);
  },

  'a chosen name is never renumbered': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'Harbour');
    final q = await b.newProject(name: 'Harbour');
    await a.sync();
    await b.sync();
    await a.sync();
    expect((await a.get(p.key))!.name, 'Harbour');
    expect((await a.get(q.key))!.name, 'Harbour');
  },

  'view prefs edited on both: the newer wins, no prompt': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    final prefs = await a.newViewPrefs(p.id);
    await a.sync();
    await b.sync();
    await a.edit(prefs.key, {
      'prefs': {'v': 1, 'bands': 3},
    });
    await b.edit(prefs.key, {
      'prefs': {'v': 1, 'bands': 7},
    }); // newer
    await b.sync();
    await a.sync();
    await b.sync();
    expect(await a.conflicts(), isEmpty);
    expect((await a.get(prefs.key))!.fields['prefs'], {'v': 1, 'bands': 7});
    await sim.expectConverged([a, b]);
  },

  'two view prefs records for one project: the newer stays': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    await a.sync();
    await b.sync();
    final older = await a.newViewPrefs(p.id, bands: 3);
    final newer = await b.newViewPrefs(p.id, bands: 7);
    await a.sync();
    await b.sync();
    await a.sync();
    expect((await a.get(older.key))!.isDeleted, isTrue);
    expect((await a.get(newer.key))!.isDeleted, isFalse);
    expect((await b.get(older.key))!.isDeleted, isTrue);
    await sim.expectConverged([a, b]);
  },

  'a record from a newer Filbert is held, then applied after updating':
      (sim) async {
        final a = sim.device('A');
        final p = await a.newProject(name: 'Harbour');
        await a.sync();
        final json =
            (jsonDecode(const RecordCodec().encode(p)) as Map<String, Object?>)
              ..['schemaVersion'] = 2
              ..['name'] = 'From the future'
              ..['updatedAt'] = p.updatedAt + 1
              ..['updatedByDeviceId'] = 'device-Z';
        final fileId = sim.remote.named(recordFileName(p.key)).single.id;
        await sim.remote.update(fileId, jsonEncode(json));
        final report = await a.sync();
        expect(report.held, 1);
        expect((await a.get(p.key))!.name, 'Harbour', reason: 'not applied');
        // Held: not overwritten from here either.
        await a.edit(p.key, {'startNotes': 'local edit'});
        await a.sync();
        expect(jsonDecode(sim.remote.textOf(fileId)!)['schemaVersion'], 2);

        // After an update to a Filbert that knows schema 2, the held version
        // is applied; this device's edit since makes it a conflict.
        final updated = a.withCodec(
          RecordCodec(schemaVersion: 2, migrations: {1: (m) => m}),
        );
        expect((await updated.sync()).conflicts, 1);
        expect((await updated.data.syncStates())[p.key]!.heldJson, isNull);
      },

  'the first sync merges what both devices already had': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject(name: 'On A');
    final q = await b.newProject(name: 'On B');
    await a.newImage(p.id);
    await b.newImage(q.id);
    await a.sync();
    await b.sync();
    await a.sync();
    expect((await a.get(q.key))!.name, 'On B');
    expect((await b.get(p.key))!.name, 'On A');
    await sim.expectConverged([a, b]);
  },

  'three devices converge': (sim) async {
    final a = sim.device('A'), b = sim.device('B'), c = sim.device('C');
    final p = await a.newProject(name: 'Shared');
    await a.sync();
    await b.sync();
    await c.sync();
    await b.newImage(p.id);
    await c.edit(p.key, {'startNotes': 'from C'});
    await a.newViewPrefs(p.id);
    for (var round = 0; round < 2; round++) {
      for (final d in [a, b, c]) {
        await d.sync();
      }
    }
    await sim.expectConverged([a, b, c]);
  },

  'a referenceImageId for an image not here yet is kept': (sim) async {
    final a = sim.device('A'), b = sim.device('B');
    final p = await a.newProject();
    final img = await a.newImage(p.id);
    await a.edit(p.key, {'referenceImageId': img.id});
    await a.sync();
    await b.sync();
    expect((await b.get(p.key))!.fields['referenceImageId'], img.id);
    expect(await b.get(img.key), isNotNull);
  },
};
