import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/project_repository.dart';
import '../domain/project.dart';

/// How long the "Deleted" snackbar offers Undo.
const projectUndoDuration = Duration(seconds: 6);

/// Confirms, deletes (tombstones) [project], and shows a snackbar with Undo.
///
/// [beforeDelete] runs after confirmation and before the delete, e.g. to
/// leave the project's own screen. The snackbar uses the app-level
/// messenger, so it stays visible across that navigation.
Future<void> confirmAndDeleteProject(
  BuildContext context,
  WidgetRef ref,
  Project project, {
  VoidCallback? beforeDelete,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete “${project.name}”?'),
      content: const Text('The project and its photos will be removed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(projectRepositoryProvider);
  beforeDelete?.call();
  await repository.delete(project.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Deleted “${project.name}”'),
        duration: projectUndoDuration,
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repository.restore(project.id),
        ),
      ),
    );
}
