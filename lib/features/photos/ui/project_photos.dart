import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/imaging/render_geometry.dart';
import '../../projects/domain/project.dart';
import '../data/image_providers.dart';
import '../data/image_repository.dart';
import '../data/photo_imports.dart';
import '../domain/project_image.dart';
import 'add_photos.dart';
import 'image_thumbnail.dart';

/// The project's reference slot and photo grid (m1-design §3.3), as slivers
/// for the project screen.
List<Widget> projectPhotoSlivers(
  BuildContext context,
  WidgetRef ref,
  Project project,
) {
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
                onAdd: () =>
                    addPhotos(context, ref, project.id, asReference: true),
              )
            : _ReferenceTile(project: project, image: reference),
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
            'No photos yet. Tap Add photo to add progress shots.',
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
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: grid.length,
          itemBuilder: (context, i) =>
              _PhotoTile(key: ValueKey(grid[i].id), image: grid[i]),
        ),
      ),
  ];
}

class _EmptyReference extends StatelessWidget {
  const _EmptyReference({required this.onAdd});

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
  const _PhotoTile({super.key, required this.image});

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
