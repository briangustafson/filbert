import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/db/app_meta_keys.dart';
import 'package:filbert/core/device/device_info.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late File dbFile;
  final ids = UuidV7IdGenerator(const SystemClock());

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('filbert_device_test');
    dbFile = File('${dir.path}/filbert.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<StoredDeviceInfo> loadFresh() async {
    final db = AppDatabase(NativeDatabase(dbFile));
    try {
      return await StoredDeviceInfo.loadOrCreate(db, ids);
    } finally {
      await db.close();
    }
  }

  test('device id is created on first launch and persists', () async {
    final first = await loadFresh();
    final second = await loadFresh();

    expect(first.deviceId, isNotEmpty);
    expect(second.deviceId, first.deviceId);
    expect(first.deviceName, isNull);
  });

  test('loading twice in one session keeps a single id', () async {
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final results = await Future.wait([
      StoredDeviceInfo.loadOrCreate(db, ids),
      StoredDeviceInfo.loadOrCreate(db, ids),
    ]);
    expect(results[0].deviceId, results[1].deviceId);
    final rows = await db.select(db.appMeta).get();
    expect(rows.where((r) => r.key == AppMetaKeys.deviceId), hasLength(1));
  });

  test('provider must be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(deviceInfoProvider), throwsA(anything));
  });
}
