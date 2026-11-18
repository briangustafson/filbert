import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock.dart';
// The table class shares the domain model's name.
import '../../../core/db/app_database.dart' hide ViewPrefs;
import '../../../core/device/device_info.dart';
import '../../../core/ids/id_generator.dart';
import '../domain/view_prefs.dart';

part 'view_prefs_repository.g.dart';

/// Each project's viewing-aid settings (m2-design §4.1).
abstract interface class ViewPrefsRepository {
  /// The project's settings, live; [ViewPrefs.defaults] until it has any.
  /// Includes changes not yet written.
  Stream<ViewPrefs> watch(String projectId);

  /// Replaces the project's settings. [watch] shows them at once; the write
  /// waits until no change has come for [DriftViewPrefsRepository.debounce],
  /// so dragging a slider writes once. The first change creates the row;
  /// writes stamp only that row, never the project, so the project list
  /// order doesn't change.
  void update(String projectId, ViewPrefs prefs);

  /// Writes any pending changes now (when the app goes to the background).
  Future<void> flush();
}

class DriftViewPrefsRepository implements ViewPrefsRepository {
  DriftViewPrefsRepository({
    required this._db,
    required this._clock,
    required this._ids,
    required this._device,
    this.debounce = const Duration(milliseconds: 500),
  });

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;
  final DeviceInfo _device;
  final Duration debounce;

  /// Changes not yet written, by project id.
  final _pending = <String, ViewPrefs>{};
  final _timers = <String, Timer>{};

  /// Project ids whose pending value changed.
  final _changes = StreamController<String>.broadcast(sync: true);

  $ViewPrefsTable get _table => _db.viewPrefs;

  @override
  Stream<ViewPrefs> watch(String projectId) {
    late StreamController<ViewPrefs> out;
    StreamSubscription<ViewPrefs>? stored;
    StreamSubscription<String>? changes;
    ViewPrefs? last;
    var storedValue = ViewPrefs.defaults;

    void emit() {
      final value = _pending[projectId] ?? storedValue;
      if (value == last) return;
      last = value;
      out.add(value);
    }

    out = StreamController<ViewPrefs>(
      onListen: () {
        if (_pending.containsKey(projectId)) emit();
        changes = _changes.stream
            .where((id) => id == projectId)
            .listen((_) => emit());
        stored = _liveRow(projectId)
            .watchSingleOrNull()
            .map(_toPrefs)
            .listen((value) {
              storedValue = value;
              emit();
            }, onError: out.addError);
      },
      onCancel: () async {
        await changes?.cancel();
        await stored?.cancel();
      },
    );
    return out.stream;
  }

  @override
  void update(String projectId, ViewPrefs prefs) {
    _pending[projectId] = prefs;
    _changes.add(projectId);
    _timers[projectId]?.cancel();
    _timers[projectId] = Timer(debounce, () => _write(projectId));
  }

  @override
  Future<void> flush() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    await Future.wait([for (final id in _pending.keys.toList()) _write(id)]);
  }

  Future<void> _write(String projectId) async {
    _timers.remove(projectId)?.cancel();
    final prefs = _pending[projectId];
    if (prefs == null) return;
    try {
      await _store(projectId, prefs);
      // A newer change waits for its own write.
      if (identical(_pending[projectId], prefs)) _pending.remove(projectId);
    } on Exception catch (e) {
      // Kept pending, so the next change or flush tries again.
      debugPrint('Saving view prefs for $projectId failed: $e');
    }
  }

  Future<void> _store(String projectId, ViewPrefs prefs) {
    return _db.transaction(() async {
      final row = await _liveRow(projectId).getSingleOrNull();
      final now = _clock.now().millisecondsSinceEpoch;
      if (row == null) {
        if (prefs == ViewPrefs.defaults) return;
        await _db
            .into(_table)
            .insert(
              ViewPrefsCompanion.insert(
                id: _ids.newId(),
                createdAt: now,
                updatedAt: now,
                updatedByDeviceId: _device.deviceId,
                projectId: projectId,
                prefsJson: prefs.toJsonString(),
              ),
            );
        return;
      }
      if (_toPrefs(row) == prefs) return;
      await (_db.update(_table)..where((t) => t.id.equals(row.id))).write(
        ViewPrefsCompanion(
          prefsJson: Value(prefs.toJsonString()),
          updatedAt: Value(now),
          updatedByDeviceId: Value(_device.deviceId),
        ),
      );
    });
  }

  SimpleSelectStatement<$ViewPrefsTable, ViewPrefsRecord> _liveRow(
    String projectId,
  ) =>
      _db.select(_table)
        ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull());

  static ViewPrefs _toPrefs(ViewPrefsRecord? row) => row == null
      ? ViewPrefs.defaults
      : ViewPrefs.fromJsonString(row.prefsJson);

  /// Writes pending changes and stops.
  Future<void> dispose() async {
    await flush();
    await _changes.close();
  }
}

@Riverpod(keepAlive: true)
ViewPrefsRepository viewPrefsRepository(Ref ref) {
  final repo = DriftViewPrefsRepository(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    device: ref.watch(deviceInfoProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
}
