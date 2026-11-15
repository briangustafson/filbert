import 'dart:async';

import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:filbert/features/projects/domain/project.dart';

/// In-memory [ProjectRepository] for widget tests. Drift's stream queries
/// leave timers pending under the widget-test fake clock, so widget tests use
/// this instead; the real repository is covered by its own tests.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({DateTime? now})
    : now = now ?? DateTime.utc(2026, 11, 15, 12);

  /// Time stamped on the next change.
  DateTime now;

  final _projects = <String, Project>{};
  final _deleted = <String>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  /// Mutating calls made through the [ProjectRepository] interface.
  final calls = <String>[];

  /// Adds a live project directly, without recording a call.
  Project seed(String name, {DateTime? updatedAt}) {
    final id = 'p${_nextId++}';
    final at = updatedAt ?? now;
    final project = Project(
      id: id,
      name: name,
      nameIsDefault: false,
      size: const NoSize(),
      startNotes: '',
      referenceImageId: null,
      createdAt: at,
      updatedAt: at,
      updatedByDeviceId: 'test-device',
    );
    _projects[id] = project;
    _changes.add(null);
    return project;
  }

  List<Project> get live =>
      _projects.values.where((p) => !_deleted.contains(p.id)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  bool isDeleted(String id) => _deleted.contains(id);

  @override
  Stream<List<Project>> watchAll() async* {
    yield live;
    await for (final _ in _changes.stream) {
      yield live;
    }
  }

  @override
  Stream<Project?> watch(String id) async* {
    Project? current() => _deleted.contains(id) ? null : _projects[id];
    yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }

  @override
  Future<Project> create() async {
    calls.add('create');
    return seed('New project $_nextId');
  }

  @override
  Future<void> update(
    String id, {
    String? name,
    ProjectSize? size,
    String? startNotes,
  }) async {
    calls.add('update $id');
    final p = _get(id);
    _projects[id] = Project(
      id: id,
      name: name ?? p.name,
      nameIsDefault: name == null ? p.nameIsDefault : false,
      size: size ?? p.size,
      startNotes: startNotes ?? p.startNotes,
      referenceImageId: p.referenceImageId,
      createdAt: p.createdAt,
      updatedAt: now,
      updatedByDeviceId: p.updatedByDeviceId,
    );
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    _get(id);
    _deleted.add(id);
    _changes.add(null);
  }

  @override
  Future<void> restore(String id) async {
    calls.add('restore $id');
    _get(id);
    _deleted.remove(id);
    _changes.add(null);
  }

  Project _get(String id) =>
      _projects[id] ?? (throw ProjectNotFoundException(id));
}
