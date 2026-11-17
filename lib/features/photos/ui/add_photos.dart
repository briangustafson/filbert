import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/settings/app_settings.dart';
import '../../autocrop/review_queue.dart';
import '../../projects/data/project_providers.dart';
import '../../projects/domain/project.dart';
import '../data/photo_imports.dart';
import '../domain/project_image.dart';

enum PhotoSourceChoice { camera, device }

/// Bottom sheet: Take photo / Choose from device. Null if dismissed.
Future<PhotoSourceChoice?> showPhotoSourceSheet(
  BuildContext context, {
  required String title,
}) => showModalBottomSheet<PhotoSourceChoice>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Take photo'),
          onTap: () => Navigator.pop(context, PhotoSourceChoice.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Choose from device'),
          onTap: () => Navigator.pop(context, PhotoSourceChoice.device),
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

/// Asks where photos come from, then adds them to [projectId]'s grid (several
/// allowed) or as its reference (one), and opens what follows an add
/// ([afterAddRoute]). Reports failures in a snackbar.
Future<void> addPhotos(
  BuildContext context,
  WidgetRef ref,
  String projectId, {
  bool asReference = false,
}) async {
  final choice = await showPhotoSourceSheet(
    context,
    title: asReference ? 'Add reference' : 'Add photos',
  );
  if (choice == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final imports = ref.read(photoImportsProvider.notifier);
  try {
    final result = await switch (choice) {
      PhotoSourceChoice.camera => imports.takePhoto(
        projectId,
        asReference: asReference,
      ),
      PhotoSourceChoice.device => imports.pickFromDevice(
        projectId,
        asReference: asReference,
      ),
    };
    if (result.failed > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(failedMessage(result.failed))),
      );
    }
    final next = await afterAddRoute(
      ref,
      projectId,
      result.added,
      asReference: asReference,
    );
    if (next != null && context.mounted) context.go(next);
  } on Exception catch (e) {
    debugPrint('Adding photos failed: $e');
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          choice == PhotoSourceChoice.camera
              ? "Couldn't open the camera."
              : "Couldn't open your photos.",
        ),
      ),
    );
  }
}

String failedMessage(int failed) => failed == 1
    ? "1 photo couldn't be added."
    : "$failed photos couldn't be added.";

/// What opens after photos are added (m1-design §3.6), or null: the
/// auto-crop review queue for new grid photos if "Auto-crop photos when
/// added" is on, or manual crop at the project's ratio for a new reference
/// if the project has a size or ratio.
Future<String?> afterAddRoute(
  WidgetRef ref,
  String projectId,
  List<ProjectImage> added, {
  bool asReference = false,
}) async {
  if (added.isEmpty) return null;
  if (asReference) {
    final project = await ref.read(projectProvider(projectId).future);
    if (project == null || project.size is NoSize) return null;
    return Routes.crop(projectId, added.first.id, afterAdd: true);
  }
  // From the store: appSettingsProvider may have no listener here, and an
  // unlistened provider is paused (Riverpod 3), so its future never completes.
  final settings = await ref.read(settingsStoreProvider).watch().first;
  if (!settings.autoCropOnAdd) return null;
  return Routes.autocrop(
    projectId,
    added.first.id,
    queue: ReviewQueue.start([for (final image in added) image.id]),
  );
}
