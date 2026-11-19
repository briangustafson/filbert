import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/layout.dart';
import '../../../app/routes.dart';
import '../../../app/shortcuts.dart';
import '../../../core/units/unit_preference.dart';
import '../../photos/ui/add_photos.dart';
import '../../photos/ui/photo_drop.dart';
import '../../photos/ui/project_photos.dart';
import '../data/project_providers.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import '../domain/size_presets.dart';
import 'delete_project.dart';
import 'project_name_field.dart';
import 'proportion_shape.dart';
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

class _ProjectView extends ConsumerStatefulWidget {
  const _ProjectView({required this.project});

  final Project project;

  @override
  ConsumerState<_ProjectView> createState() => _ProjectViewState();
}

class _ProjectViewState extends ConsumerState<_ProjectView> {
  /// The empty reference slot: a drop there sets the reference.
  final _referenceSlot = GlobalKey();

  bool _overReferenceSlot(Offset globalPosition) {
    final box = _referenceSlot.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final repository = ref.watch(projectRepositoryProvider);
    return PhotoDropTarget(
      hint: (at) => _overReferenceSlot(at)
          ? 'Drop to set the reference'
          : 'Drop to add photos',
      onDrop: (photos, at) => addDroppedPhotos(
        context,
        ref,
        project.id,
        photos,
        asReference: _overReferenceSlot(at),
      ),
      child: KeyBindings(
        bindings: [
          KeyBinding(
            command(LogicalKeyboardKey.keyO),
            () => addPhotos(context, ref, project.id),
            whileTyping: true,
          ),
          KeyBinding(
            const SingleActivator(LogicalKeyboardKey.escape),
            () => context.go(Routes.projectList),
          ),
        ],
        child: Scaffold(
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
            tooltip: shortcutTooltip('Add photos', commandKey('O')),
            onPressed: () => addPhotos(context, ref, project.id),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add photo'),
          ),
          body: CustomScrollView(
            slivers: [
              // The header is capped and centred on wide windows (m3-design
              // §3.2); the photo grid below stays full width.
              SliverToBoxAdapter(
                child: MaxWidth(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProjectNameField(
                          key: ValueKey('name-${project.id}'),
                          name: project.name,
                          onSave: (name) =>
                              repository.update(project.id, name: name),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ActionChip(
                            avatar: switch (dimsOf(project.size)) {
                              (final w, final h) => ProportionShape(
                                width: w,
                                height: h,
                              ),
                              null => const Icon(Icons.aspect_ratio, size: 18),
                            },
                            label: Text(sizeLabel(project.size)),
                            tooltip: 'Canvas size',
                            onPressed: () => showSizePicker(
                              context,
                              initial: project.size,
                              defaultUnit: ref.read(
                                preferredLengthUnitProvider,
                              ),
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
                ),
              ),
              ...projectPhotoSlivers(
                context,
                ref,
                project,
                referenceSlot: _referenceSlot,
              ),
            ],
          ),
        ),
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
