import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../db/app_meta_keys.dart';
import '../ids/id_generator.dart';

part 'device_info.g.dart';

/// Identity of this installation, stamped on records as `updatedByDeviceId`.
abstract interface class DeviceInfo {
  /// UUIDv7 created on first launch and never changed afterwards.
  String get deviceId;

  /// Human-readable name for sync conflict UI (m3-design proposal 5); set on
  /// the first launch with sync (T6).
  String? get deviceName;
}

class StoredDeviceInfo implements DeviceInfo {
  const StoredDeviceInfo({required this.deviceId, this.deviceName});

  @override
  final String deviceId;

  @override
  final String? deviceName;

  /// Reads this device's identity from `app_meta`, creating the device id
  /// on first launch, and the name from [defaultName] if there's none yet.
  static Future<StoredDeviceInfo> loadOrCreate(
    AppDatabase db,
    IdGenerator ids, {
    Future<String> Function()? defaultName,
  }) async {
    // Insert-or-ignore keeps an existing id even if two loads race.
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(
            key: AppMetaKeys.deviceId,
            value: ids.newId(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final rows =
        await (db.select(db.appMeta)..where(
              (t) => t.key.isIn([AppMetaKeys.deviceId, AppMetaKeys.deviceName]),
            ))
            .get();
    final values = {for (final r in rows) r.key: r.value};
    if (values[AppMetaKeys.deviceName] == null && defaultName != null) {
      final name = await defaultName();
      await db
          .into(db.appMeta)
          .insert(
            AppMetaCompanion.insert(key: AppMetaKeys.deviceName, value: name),
            mode: InsertMode.insertOrIgnore,
          );
      values[AppMetaKeys.deviceName] = (await (db.select(
        db.appMeta,
      )..where((t) => t.key.equals(AppMetaKeys.deviceName))).getSingle()).value;
    }
    return StoredDeviceInfo(
      deviceId: values[AppMetaKeys.deviceId]!,
      deviceName: values[AppMetaKeys.deviceName],
    );
  }
}

/// Loaded before `runApp` and supplied as an override (see `main.dart`), so
/// repositories can read it synchronously.
@Riverpod(keepAlive: true)
DeviceInfo deviceInfo(Ref ref) => throw UnimplementedError(
  'deviceInfoProvider must be overridden with a loaded DeviceInfo',
);
