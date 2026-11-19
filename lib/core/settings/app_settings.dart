import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../db/app_meta_keys.dart';

part 'app_settings.g.dart';

/// The Units setting (m1-design §3.9).
enum UnitsSetting {
  /// From the device's region.
  automatic('auto'),
  inches('in'),
  centimeters('cm');

  const UnitsSetting(this.code);

  /// Stored value.
  final String code;

  /// Unknown or missing values read as [automatic].
  static UnitsSetting fromCode(String? code) =>
      values.firstWhere((u) => u.code == code, orElse: () => automatic);
}

/// App-wide settings (m1-design §3.9). Local to this device.
class AppSettings {
  const AppSettings({
    this.autoCropOnAdd = true,
    this.units = UnitsSetting.automatic,
  });

  /// Open the auto-crop review for photos added to a project's grid.
  final bool autoCropOnAdd;

  final UnitsSetting units;

  AppSettings copyWith({bool? autoCropOnAdd, UnitsSetting? units}) =>
      AppSettings(
        autoCropOnAdd: autoCropOnAdd ?? this.autoCropOnAdd,
        units: units ?? this.units,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.autoCropOnAdd == autoCropOnAdd &&
      other.units == units;

  @override
  int get hashCode => Object.hash(autoCropOnAdd, units);

  @override
  String toString() => 'AppSettings($autoCropOnAdd, $units)';
}

/// Reads and writes [AppSettings]. Local-only (`app_meta`).
abstract interface class SettingsStore {
  /// The settings now and after every change.
  Stream<AppSettings> watch();

  Future<void> setAutoCropOnAdd(bool value);

  Future<void> setUnits(UnitsSetting value);

  /// The folder the Mac's save dialog last saved an export to (m3-design
  /// §3.5); null before the first.
  Future<String?> exportFolder();

  Future<void> setExportFolder(String path);
}

class DriftSettingsStore implements SettingsStore {
  DriftSettingsStore(this._db);

  final AppDatabase _db;

  @override
  Stream<AppSettings> watch() =>
      (_db.select(_db.appMeta)..where(
            (m) => m.key.isIn([AppMetaKeys.autoCropOnAdd, AppMetaKeys.units]),
          ))
          .watch()
          .map((rows) {
            final values = {for (final r in rows) r.key: r.value};
            return AppSettings(
              autoCropOnAdd: values[AppMetaKeys.autoCropOnAdd] != 'false',
              units: UnitsSetting.fromCode(values[AppMetaKeys.units]),
            );
          });

  @override
  Future<void> setAutoCropOnAdd(bool value) =>
      _put(AppMetaKeys.autoCropOnAdd, value ? 'true' : 'false');

  @override
  Future<void> setUnits(UnitsSetting value) =>
      _put(AppMetaKeys.units, value.code);

  @override
  Future<String?> exportFolder() async =>
      (await (_db.select(_db.appMeta)
                ..where((m) => m.key.equals(AppMetaKeys.exportFolder)))
              .getSingleOrNull())
          ?.value;

  @override
  Future<void> setExportFolder(String path) =>
      _put(AppMetaKeys.exportFolder, path);

  Future<void> _put(String key, String value) => _db
      .into(_db.appMeta)
      .insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));
}

@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) =>
    DriftSettingsStore(ref.watch(databaseProvider));

/// The current settings; defaults until they've loaded.
@Riverpod(keepAlive: true)
Stream<AppSettings> appSettings(Ref ref) =>
    ref.watch(settingsStoreProvider).watch();
