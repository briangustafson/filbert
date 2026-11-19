import 'dart:async';

import 'package:filbert/core/settings/app_settings.dart';

/// In-memory [SettingsStore].
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;
  final _changes = StreamController<AppSettings>.broadcast();

  AppSettings get settings => _settings;

  @override
  Stream<AppSettings> watch() async* {
    yield _settings;
    yield* _changes.stream;
  }

  @override
  Future<void> setAutoCropOnAdd(bool value) async =>
      _set(_settings.copyWith(autoCropOnAdd: value));

  @override
  Future<void> setUnits(UnitsSetting value) async =>
      _set(_settings.copyWith(units: value));

  String? folder;

  @override
  Future<String?> exportFolder() async => folder;

  @override
  Future<void> setExportFolder(String path) async => folder = path;

  void _set(AppSettings settings) {
    _settings = settings;
    _changes.add(settings);
  }
}
