import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../data/project_providers.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import 'delete_project.dart';

/// Home screen: the user's projects, newest first (m1-design §3.2).
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'More',
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => context.go(Routes.settings),
                child: const Text('Settings'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
      body: switch (projects) {
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => _ProjectGrid(
          projects: value,
          onOpen: (p) => context.go(Routes.project(p.id)),
          onDelete: (p) => confirmAndDeleteProject(context, ref, p),
        ),
        AsyncError() => const Center(child: Text("Couldn't load projects.")),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final project = await ref.read(projectRepositoryProvider).create();
    if (context.mounted) context.go(Routes.project(project.id));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No projects yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap New project to start one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({
    required this.projects,
    required this.onOpen,
    required this.onDelete,
  });

  final List<Project> projects;
  final ValueChanged<Project> onOpen;
  final ValueChanged<Project> onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Bottom padding keeps the last row clear of the FAB.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: projects.length,
      itemBuilder: (context, i) => ProjectCard(
        key: ValueKey(projects[i].id),
        project: projects[i],
        onOpen: () => onOpen(projects[i]),
        onDelete: () => onDelete(projects[i]),
      ),
    );
  }
}

class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onDelete,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  Offset? _pressPosition;

  Future<void> _showMenu() async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    final at =
        _pressPosition ?? box.localToGlobal(box.size.center(Offset.zero));
    final choice = await showMenu<_CardAction>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: _CardAction.delete, child: Text('Delete')),
      ],
    );
    if (choice == _CardAction.delete) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = widget.project;
    final updated = MaterialLocalizations.of(context)
        .formatShortDate(project.updatedAt.toLocal());
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onOpen,
        onTapDown: (d) => _pressPosition = d.globalPosition,
        onLongPress: _showMenu,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // Placeholder until real thumbnails arrive (M1 T8).
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    updated,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardAction { delete }
