import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/photos/data/photo_imports.dart';
import '../features/photos/data/photo_source.dart';
import '../features/photos/ui/add_photos.dart';
import 'router.dart';
import 'routes.dart';
import 'theme.dart';

class FilbertApp extends ConsumerStatefulWidget {
  const FilbertApp({super.key});

  @override
  ConsumerState<FilbertApp> createState() => _FilbertAppState();
}

class _FilbertAppState extends ConsumerState<FilbertApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startupTasks());
  }

  /// Photos taken while Android killed the app are imported where they were
  /// meant to go; then the picker's leftovers are cleared (m1-design §3.6).
  Future<void> _startupTasks() async {
    try {
      final recovered = await ref
          .read(photoImportsProvider.notifier)
          .recoverLostPhotos();
      if (recovered != null) _announce(recovered);
    } on Exception catch (e) {
      debugPrint('Recovering lost photos failed: $e');
    }
    try {
      await ref.read(photoSourceProvider).clearLeftovers();
    } on Exception catch (e) {
      debugPrint('Clearing picker leftovers failed: $e');
    }
  }

  void _announce(ProjectPhotosResult recovered) {
    final added = recovered.result.added.length;
    _messenger.currentState?.showSnackBar(
      added == 0
          ? SnackBar(content: Text(failedMessage(recovered.result.failed)))
          : SnackBar(
              content: Text(
                added == 1
                    ? 'Added the photo you took.'
                    : 'Added the $added photos you took.',
              ),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => ref
                    .read(routerProvider)
                    .go(Routes.project(recovered.projectId)),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Filbert',
      theme: FilbertTheme.light,
      darkTheme: FilbertTheme.dark,
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: _messenger,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
