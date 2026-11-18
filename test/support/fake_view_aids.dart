import 'dart:async';

import 'package:filbert/core/imaging/palette.dart';
import 'package:filbert/core/imaging/tone.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/data/palette_service.dart';
import 'package:filbert/features/view_aids/data/view_prefs_repository.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';

/// In-memory view prefs; writes are immediate (no debounce).
class FakeViewPrefsRepository implements ViewPrefsRepository {
  final _prefs = <String, ViewPrefs>{};
  final _changes = StreamController<String>.broadcast(sync: true);

  /// Every update, in order.
  final updates = <(String projectId, ViewPrefs prefs)>[];
  var flushes = 0;

  ViewPrefs of(String projectId) => _prefs[projectId] ?? ViewPrefs.defaults;

  @override
  Stream<ViewPrefs> watch(String projectId) async* {
    yield of(projectId);
    yield* _changes.stream
        .where((id) => id == projectId)
        .map((_) => of(projectId));
  }

  @override
  void update(String projectId, ViewPrefs prefs) {
    updates.add((projectId, prefs));
    _prefs[projectId] = prefs;
    _changes.add(projectId);
  }

  @override
  Future<void> flush() async => flushes++;
}

/// Palettes of evenly spaced grays, the requested count; with [hang],
/// requests never finish (the loading state).
class FakePaletteService implements PaletteService {
  FakePaletteService({this.hang = false});

  final bool hang;
  final requests = <String>[];

  @override
  Future<Palette> palette(ProjectImage image, int count) {
    requests.add('${image.id} $count');
    if (hang) return Completer<Palette>().future;
    return Future.value(
      Palette([
        for (var i = 0; i < count; i++) Lab(100.0 * i / (count - 1), 0, 0),
      ]),
    );
  }
}
