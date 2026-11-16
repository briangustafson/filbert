import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/units/unit_preference.dart';
import '../../photos/ui/add_photos.dart';
import '../../photos/ui/project_photos.dart';
import '../data/project_providers.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import '../domain/size_presets.dart';
import 'delete_project.dart';
import 'project_name_field.dart';
import 'size_picker.dart';
import 'start_notes_field.dart';

/// A project: header (name, size, start notes), reference slot, and photo
/// grid (m1-design §3.3).
class ProjectScreen extends ConsumerWidget {
  const ProjectScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    return switch (project) {
      AsyncData(value: final Project p) => _ProjectView(project: p),
      AsyncData() => const _MissingProject(),
      AsyncError() => const _MissingProject(),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _ProjectView extends ConsumerWidget {
  const _ProjectView({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(projectRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<void>(
            tooltip: 'More',
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => confirmAndDeleteProject(
                  context,
                  ref,
                  project,
                  beforeDelete: () => context.go(Routes.projectList),
                ),
                child: const Text('Delete project'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addPhotos(context, ref, project.id),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add photo'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(
              children: [
                ProjectNameField(
                  key: ValueKey('name-${project.id}'),
                  name: project.name,
                  onSave: (name) => repository.update(project.id, name: name),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ActionChip(
                    avatar: const Icon(Icons.aspect_ratio, size: 18),
                    label: Text(sizeLabel(project.size)),
                    tooltip: 'Canvas size',
                    onPressed: () => showSizePicker(
                      context,
                      initial: project.size,
                      defaultUnit: ref.read(preferredLengthUnitProvider),
                      onChanged: (size) =>
                          repository.update(project.id, size: size),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StartNotesField(
                  key: ValueKey('notes-${project.id}'),
                  notes: project.startNotes,
                  onSave: (notes) =>
                      repository.update(project.id, startNotes: notes),
                ),
              ],
            ),
          ),
          ...projectPhotoSlivers(context, ref, project),
        ],
      ),
    );
  }
}

class _MissingProject extends StatelessWidget {
  const _MissingProject();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This project no longer exists.'),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.go(Routes.projectList),
              child: const Text('Back to projects'),
            ),
          ],
        ),
      ),
    );
  }
}
