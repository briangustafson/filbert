import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock.dart';
import '../../../core/db/app_database.dart';
import '../../../core/device/device_info.dart';
import '../../../core/ids/id_generator.dart';
import '../domain/project.dart';

part 'project_repository.g.dart';

/// Projects: live views, creation with default names, edits, and
/// tombstone delete/restore (m1-design §4, §5).
abstract interface class ProjectRepository {
  /// Live projects, most recently updated first.
  Stream<List<Project>> watchAll();

  /// The project, or null if it doesn't exist or is deleted.
  Stream<Project?> watch(String id);

  /// Creates a project with defaults: a dated default name (§4.3), no size,
  /// empty start notes.
  Future<Project> create();

  /// Changes only the given fields. Changing the name clears
  /// `nameIsDefault`. Does nothing if no value actually changes.
  ///
  /// Throws [ProjectNotFoundException] for an unknown id, and
  /// [ArgumentError] for a blank name or an invalid size.
  Future<void> update(
    String id, {
    String? name,
    ProjectSize? size,
    String? startNotes,
  });

  /// Tombstones the project. Its images are left as they are; they are
  /// unreachable while the project is deleted. No-op if already deleted.
  Future<void> delete(String id);

  /// Clears the tombstone. No-op if the project is live.
  Future<void> restore(String id);
}

class ProjectNotFoundException implements Exception {
  const ProjectNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'ProjectNotFoundException: no project with id $id';
}

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository({
    required this._db,
    required this._clock,
    required this._ids,
    required this._device,
  });

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;
  final DeviceInfo _device;

  $ProjectsTable get _projects => _db.projects;

  @override
  Stream<List<Project>> watchAll() {
    final query = _db.select(_projects)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([
        (p) => OrderingTerm.desc(p.updatedAt),
        (p) => OrderingTerm.desc(p.id),
      ]);
    return query.watch().map((rows) => rows.map(_toProject).toList());
  }

  @override
  Stream<Project?> watch(String id) {
    final query = _db.select(_projects)
      ..where((p) => p.id.equals(id) & p.deletedAt.isNull());
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toProject(row),
    );
  }

  @override
  Future<Project> create() {
    return _db.transaction(() async {
      final now = _clock.now();
      final name = await _nextDefaultName(defaultNameBase(now));
      final row = await _db
          .into(_projects)
          .insertReturning(
            ProjectsCompanion.insert(
              id: _ids.newId(),
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
              updatedByDeviceId: _device.deviceId,
              name: name,
              nameIsDefault: true,
            ),
          );
      return _toProject(row);
    });
  }

  @override
  Future<void> update(
    String id, {
    String? name,
    ProjectSize? size,
    String? startNotes,
  }) async {
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be blank');
    }
    size?.validate();

    return _db.transaction(() async {
      final current = _toProject(await _get(id));
      final nameChanged = name != null && name != current.name;
      final sizeChanged = size != null && size != current.size;
      final notesChanged =
          startNotes != null && startNotes != current.startNotes;
      if (!nameChanged && !sizeChanged && !notesChanged) return;

      var changes = _touch();
      if (nameChanged) {
        changes = changes.copyWith(
          name: Value(name),
          nameIsDefault: const Value(false),
        );
      }
      if (sizeChanged) changes = _withSize(changes, size);
      if (notesChanged) {
        changes = changes.copyWith(startNotes: Value(startNotes));
      }
      await _updateRow(id, changes);
    });
  }

  @override
  Future<void> delete(String id) => _setDeleted(id, deleted: true);

  @override
  Future<void> restore(String id) => _setDeleted(id, deleted: false);

  Future<void> _setDeleted(String id, {required bool deleted}) {
    return _db.transaction(() async {
      final row = await _get(id);
      if ((row.deletedAt != null) == deleted) return;
      final changes = _touch().copyWith(
        deletedAt: Value(deleted ? _clock.now().millisecondsSinceEpoch : null),
      );
      await _updateRow(id, changes);
    });
  }

  /// `yyyy-MM-dd` in the device's local time zone (§4.3).
  static String defaultNameBase(DateTime now) {
    final local = now.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
        '${two(local.day)}';
  }

  /// [base] if no live project uses it, else `base (n)` with the lowest free
  /// n ≥ 2. Must run inside the creating transaction.
  Future<String> _nextDefaultName(String base) async {
    final query = _db.selectOnly(_projects)
      ..addColumns([_projects.name])
      ..where(
        _projects.deletedAt.isNull() &
            (_projects.name.equals(base) | _projects.name.like('$base (%)')),
      );
    final taken = {
      for (final row in await query.get()) row.read(_projects.name)!,
    };
    if (!taken.contains(base)) return base;
    for (var n = 2; ; n++) {
      final candidate = '$base ($n)';
      if (!taken.contains(candidate)) return candidate;
    }
  }

  Future<ProjectRecord> _get(String id) async {
    final row = await (_db.select(
      _projects,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (row == null) throw ProjectNotFoundException(id);
    return row;
  }

  Future<void> _updateRow(String id, ProjectsCompanion changes) =>
      (_db.update(_projects)..where((p) => p.id.equals(id))).write(changes);

  ProjectsCompanion _touch() => ProjectsCompanion(
    updatedAt: Value(_clock.now().millisecondsSinceEpoch),
    updatedByDeviceId: Value(_device.deviceId),
  );

  static ProjectsCompanion _withSize(ProjectsCompanion c, ProjectSize size) {
    const none = Value<double?>(null);
    return switch (size) {
      NoSize() => c.copyWith(
        sizeKind: const Value(SizeKind.none),
        ratioW: none,
        ratioH: none,
        width: none,
        height: none,
        unit: const Value(null),
      ),
      RatioSize(:final w, :final h) => c.copyWith(
        sizeKind: const Value(SizeKind.ratio),
        ratioW: Value(w),
        ratioH: Value(h),
        width: none,
        height: none,
        unit: const Value(null),
      ),
      PhysicalSize(:final width, :final height, :final unit) => c.copyWith(
        sizeKind: const Value(SizeKind.physical),
        ratioW: none,
        ratioH: none,
        width: Value(width),
        height: Value(height),
        unit: Value(unit),
      ),
    };
  }

  static Project _toProject(ProjectRecord r) => Project(
    id: r.id,
    name: r.name,
    nameIsDefault: r.nameIsDefault,
    size: switch (r.sizeKind) {
      SizeKind.none => const NoSize(),
      SizeKind.ratio => RatioSize(r.ratioW!, r.ratioH!),
      SizeKind.physical => PhysicalSize(r.width!, r.height!, r.unit!),
    },
    startNotes: r.startNotes,
    referenceImageId: r.referenceImageId,
    createdAt: _time(r.createdAt),
    updatedAt: _time(r.updatedAt),
    updatedByDeviceId: r.updatedByDeviceId,
  );

  static DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

@Riverpod(keepAlive: true)
ProjectRepository projectRepository(Ref ref) => DriftProjectRepository(
  db: ref.watch(databaseProvider),
  clock: ref.watch(clockProvider),
  ids: ref.watch(idGeneratorProvider),
  device: ref.watch(deviceInfoProvider),
);
