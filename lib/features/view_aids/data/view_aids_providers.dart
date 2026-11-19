import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/imaging/palette.dart';
import '../../photos/data/image_providers.dart';
import '../../photos/domain/project_image.dart';
import '../../projects/data/project_providers.dart';
import '../domain/compare_target.dart';
import '../domain/view_aids.dart';
import '../domain/view_prefs.dart';
import 'palette_service.dart';
import 'view_prefs_repository.dart';

part 'view_aids_providers.g.dart';

/// Which aids are on for the photo screen of [projectId], and its open
/// panel. Grid and the tone aid come from the project's view prefs, so they
/// are on again when the screen reopens. Compare and the panel live only
/// while the screen watches this, so each visit starts with Compare off and
/// panels closed (m2-design §3.1).
@riverpod
class ViewAidsState extends _$ViewAidsState {
  /// The open panel; kept across rebuilds from prefs while its aid is on.
  Aid? _panel;

  /// Compare is never saved: it's on only for this visit.
  var _compare = false;

  @override
  ViewAids build(String projectId) {
    final on = ref.watch(viewPrefsProvider(projectId)).value?.on ?? AidsOn.off;
    final aids = ViewAids(grid: on.grid, tone: on.tone, compare: _compare);
    final panel = _panel;
    return panel != null && aids.isOn(panel)
        ? ViewAids(
            grid: aids.grid,
            tone: aids.tone,
            compare: aids.compare,
            panel: panel,
          )
        : aids;
  }

  void tap(Aid aid) {
    // Ignored until the prefs have loaded, so a tap can't write defaults
    // over the project's settings.
    final prefs = ref.read(viewPrefsProvider(projectId)).value;
    if (prefs == null) return;
    final next = state.tap(aid);
    _panel = next.panel;
    _compare = next.compare;
    state = next;
    final saved = AidsOn(grid: next.grid, tone: next.tone);
    if (saved != prefs.on) {
      ref
          .read(viewPrefsRepositoryProvider)
          .update(projectId, prefs.copyWith(on: saved));
    }
  }

  void closePanel() {
    _panel = null;
    state = state.closePanel();
  }
}

/// The project's aid settings, live (m2-design §4.1).
@riverpod
Stream<ViewPrefs> viewPrefs(Ref ref, String projectId) =>
    ref.watch(viewPrefsRepositoryProvider).watch(projectId);

/// The photo's palette of [count] colors (m2-design §5.2).
@riverpod
Future<Palette> photoPalette(Ref ref, ProjectImage image, int count) =>
    ref.watch(paletteServiceProvider).palette(image, count);

/// The compare photo for [shown] (m2-design §3.4); null until the project,
/// its photos and its settings have loaded.
@riverpod
CompareTarget? compareTarget(Ref ref, ProjectImage shown) {
  final id = shown.projectId;
  final prefs = ref.watch(viewPrefsProvider(id)).value;
  final photos = ref.watch(projectImagesProvider(id)).value;
  final project = ref.watch(projectProvider(id)).value;
  if (prefs == null || photos == null || project == null) return null;
  return CompareTarget.resolve(
    savedId: prefs.compare.imageId,
    shown: shown,
    photos: photos,
    referenceId: project.referenceImageId,
  );
}
