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

/// Which aids are on for the photo screen of [projectId]. Lives while the
/// screen watches it, so leaving the screen turns every aid off
/// (m2-design §3.1).
@riverpod
class ViewAidsState extends _$ViewAidsState {
  @override
  ViewAids build(String projectId) => ViewAids.off;

  void tap(Aid aid) => state = state.tap(aid);

  void closePanel() => state = state.closePanel();
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
