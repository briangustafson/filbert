import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/imaging/palette.dart';
import '../../photos/domain/project_image.dart';
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
