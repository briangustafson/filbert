import 'dart:convert';
import 'dart:typed_data';

import 'package:matcher/expect.dart';

import '../record.dart';
import '../record_codec.dart';
import '../stores.dart';
import '../sync_engine.dart';
import 'fake_remote_store.dart';
import 'memory_local_store.dart';

/// Several simulated devices sharing one [FakeRemoteStore] and one clock
/// (HLD §10). [newStore] gives each device its data: memory here, Drift in
/// the app's tests (T6).
class Sim {
  Sim({DeviceData Function()? newStore})
    : _newStore = newStore ?? MemoryLocalStore.new;

  final DeviceData Function() _newStore;
  final remote = FakeRemoteStore();
  var _time = 1763450000000;

  /// A clock every device shares; each reading is a second later.
  int now() => _time += 1000;

  SimDevice device(String name, {RecordCodec codec = const RecordCodec()}) =>
      SimDevice._(this, name, _newStore(), codec);

  /// Every device has the same records (tombstones too), and Drive holds
  /// each file once.
  Future<void> expectConverged(List<SimDevice> devices) async {
    final first = await devices.first.snapshot();
    for (final device in devices.skip(1)) {
      expect(
        await device.snapshot(),
        first,
        reason: '${device.name} differs from ${devices.first.name}',
      );
    }
    final names = [for (final f in remote.files.values) f.name];
    expect(names.toSet().length, names.length, reason: 'duplicate files');
  }
}

/// One device: its data, its engine, and what the app would do.
class SimDevice {
  SimDevice._(this.sim, this.name, this.data, this.codec)
    : engine = SyncEngine(
        local: data,
        remote: sim.remote,
        deviceId: 'device-$name',
        now: sim.now,
        codec: codec,
      );

  final Sim sim;
  final String name;
  final DeviceData data;
  final RecordCodec codec;
  final SyncEngine engine;
  var _nextId = 1;

  String get deviceId => 'device-$name';

  /// This device after an app update with [codec].
  SimDevice withCodec(RecordCodec codec) => SimDevice._(sim, name, data, codec);

  String _id(String prefix) => '$prefix-$name${_nextId++}';

  Future<SyncReport> sync() => engine.syncOnce();

  /// Syncs, expecting the pass to fail on a dropped or interrupted request.
  Future<void> syncFailing() async {
    Object? error;
    try {
      await engine.syncOnce();
    } on RemoteUnavailable catch (e) {
      error = e;
    }
    expect(error, isNotNull, reason: 'the pass should have failed');
  }

  Future<SyncRecord?> get(RecordKey key) => data.record(key);

  Future<SyncRecord> _create(
    RecordKind kind,
    String id,
    Map<String, Object?> fields,
  ) async {
    final t = sim.now();
    final record = SyncRecord(
      kind: kind,
      id: id,
      createdAt: t,
      updatedAt: t,
      updatedByDeviceId: deviceId,
      fields: fields,
    );
    await data.write(record);
    return record;
  }

  Future<SyncRecord> newProject({
    String? id,
    String name = 'Still life',
    bool nameIsDefault = false,
  }) => _create(RecordKind.project, id ?? _id('project'), {
    'name': name,
    'nameIsDefault': nameIsDefault,
    'size': {'kind': 'none'},
    'startNotes': '',
    'referenceImageId': null,
  });

  /// An image with its original and thumbnail on this device.
  Future<SyncRecord> newImage(String projectId, {String? id}) async {
    final imageId = id ?? _id('image');
    final blobId = 'blob-of-$imageId';
    await data.writeBlob(
      blobId,
      Uint8List.fromList(utf8.encode('original of $imageId')),
      Uint8List.fromList(utf8.encode('thumbnail of $imageId')),
    );
    return _create(RecordKind.image, imageId, {
      'projectId': projectId,
      'blobId': blobId,
      'mimeType': 'image/jpeg',
      'width': 4000,
      'height': 3000,
      'source': 'camera',
      'capturedAt': null,
      'edits': {'v': 1},
      'derivedFrom': null,
    });
  }

  Future<SyncRecord> newViewPrefs(
    String projectId, {
    String? id,
    int bands = 5,
  }) => _create(RecordKind.viewPrefs, id ?? _id('prefs'), {
    'projectId': projectId,
    'prefs': {'v': 1, 'bands': bands},
  });

  Future<SyncRecord> edit(RecordKey key, Map<String, Object?> fields) async {
    final record = (await data.record(key))!
        .edited(now: sim.now(), deviceId: deviceId, fields: fields);
    await data.write(record);
    return record;
  }

  Future<SyncRecord> delete(RecordKey key) async {
    final record = (await data.record(key))!
        .edited(now: sim.now(), deviceId: deviceId, delete: true);
    await data.write(record);
    return record;
  }

  Future<Map<RecordKey, SyncConflict>> conflicts() => data.conflicts();

  /// Every record as canonical JSON, by key.
  Future<Map<String, String>> snapshot() async => {
    for (final r in await data.records())
      '${r.kind.wire} ${r.id}': codec.encode(r),
  };
}
