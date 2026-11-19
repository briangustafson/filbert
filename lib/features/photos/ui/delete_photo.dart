import 'package:material_ui/material_ui.dart';

import '../../projects/ui/delete_project.dart' show projectUndoDuration;
import '../data/image_repository.dart';

/// Deletes the photo and offers Undo in a snackbar (m1-design §3.5).
Future<void> deletePhotoWithUndo(
  ScaffoldMessengerState messenger,
  ImageRepository repository,
  String imageId,
) async {
  await repository.delete(imageId);
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Photo deleted.'),
      duration: projectUndoDuration,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => repository.restore(imageId),
      ),
    ),
  );
}
