import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/layout.dart';
import '../../../app/routes.dart';
import '../../../app/shortcuts.dart';
import '../../../core/imaging/render_geometry.dart';
import '../../projects/domain/project.dart';
import '../data/image_providers.dart';
import '../data/image_repository.dart';
import '../data/photo_imports.dart';
import '../domain/project_image.dart';
import 'add_photos.dart';
import 'delete_photo.dart';
import 'image_thumbnail.dart';

/// The project's reference slot and photo grid (m1-design §3.3), as slivers
/// for the project screen.
///
/// [referenceSlot] marks the empty reference slot, where a drop sets the
/// reference (m3-design §3.4).
List<Widget> projectPhotoSlivers(
  BuildContext context,
  WidgetRef ref,
  Project project, {
  Key? referenceSlot,
}) {
  final images = ref.watch(projectImagesProvider(project.id));
  final progress = ref.watch(
    photoImportsProvider.select((imports) => imports[project.id]),
  );
  final all = images.value ?? const <ProjectImage>[];
  // A deleted reference keeps its pointer (so Undo restores it) but isn't
  // live, so it isn't found here and the slot shows as empty.
  final reference = all
      .where((i) => i.id == project.referenceImageId)
      .firstOrNull;
  final grid = [
    for (final i in all)
      if (i.id != reference?.id) i,
  ];
  final textTheme = Theme.of(context).textTheme;

  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text('Reference', style: textTheme.titleSmall),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: reference == null
            ? _EmptyReference(
                key: referenceSlot,
                onAdd: () =>
                    addPhotos(context, ref, project.id, asReference: true),
              )
            : _DeleteKey(
                image: reference,
                child: _ReferenceTile(project: project, image: reference),
              ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos', style: textTheme.titleSmall),
            if (progress != null) ...[
              const SizedBox(height: 8),
              _ImportProgressBar(progress: progress),
            ],
          ],
        ),
      ),
    ),
    if (images.hasValue && grid.isEmpty)
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Text(
            isDesktop
                ? 'No photos yet. Click Add photo, or drop photos here.'
                : 'No photos yet. Tap Add photo to add progress shots.',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      )
    else
      SliverPadding(
        // Bottom padding keeps the last row clear of the FAB.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        sliver: SliverGrid.builder(
          // Bigger thumbnails on wide windows (m3-design §3.2).
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: WindowWidth.of(context).isCompact ? 140 : 180,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: grid.length,
          itemBuilder: (context, i) => _DeleteKey(
            key: ValueKey(grid[i].id),
            image: grid[i],
            child: _PhotoTile(image: grid[i]),
          ),
        ),
      ),
  ];
}

/// Delete (or Backspace) deletes the photo while its tile has keyboard
/// focus, with Undo (m3-design §3.3).
class _DeleteKey extends ConsumerWidget {
  const _DeleteKey({super.key, required this.image, required this.child});

  final ProjectImage image;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void delete() => deletePhotoWithUndo(
      ScaffoldMessenger.of(context),
      ref.read(imageRepositoryProvider),
      image.id,
    );
    return KeyBindings(
      scope: false,
      bindings: [
        KeyBinding(const SingleActivator(LogicalKeyboardKey.delete), delete),
        KeyBinding(const SingleActivator(LogicalKeyboardKey.backspace), delete),
      ],
      child: child,
    );
  }
}

class _EmptyReference extends StatelessWidget {
  const _EmptyReference({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: SizedBox(
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              const Text('Add reference'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceTile extends ConsumerWidget {
  const _ReferenceTile({required this.project, required this.image});

  final Project project;
  final ProjectImage image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The tile has the edited view's proportions.
    final (w, h) = RenderPlan.forEdits(
      sourceWidth: image.width,
      sourceHeight: image.height,
      edits: image.edits,
      maxLongEdge: 1000,
    ).outputSize;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: AspectRatio(
          aspectRatio: w / h,
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(
                  onTap: () => context.go(Routes.photo(project.id, image.id)),
                  child: Semantics(
                    label: 'Reference photo',
                    image: true,
                    child: ImageThumbnail(image: image),
                  ),
                ),
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: PopupMenuButton<_ReferenceAction>(
                    tooltip: 'Reference options',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface
                          .withValues(alpha: 0.8),
                    ),
                    onSelected: (action) => switch (action) {
                      _ReferenceAction.replace => addPhotos(
                        context,
                        ref,
                        project.id,
                        asReference: true,
                      ),
                      _ReferenceAction.remove =>
                        ref
                            .read(imageRepositoryProvider)
                            .setAsReference(project.id, null),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ReferenceAction.replace,
                        child: Text('Replace'),
                      ),
                      PopupMenuItem(
                        value: _ReferenceAction.remove,
                        child: Text('Remove'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReferenceAction { replace, remove }

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.image});

  final ProjectImage image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo',
      image: true,
      button: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageThumbnail(image: image),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () =>
                    context.go(Routes.photo(image.projectId, image.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportProgressBar extends StatelessWidget {
  const _ImportProgressBar({required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final current = (progress.done + 1).clamp(1, progress.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progress.total == 1
              ? 'Adding photo…'
              : 'Adding $current of ${progress.total}…',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress.done / progress.total),
      ],
    );
  }
}
