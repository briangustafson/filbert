import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/photos/data/photo_imports.dart';
import '../features/photos/data/photo_source.dart';
import '../features/photos/ui/add_photos.dart';
import '../features/view_aids/data/view_prefs_repository.dart';
import 'router.dart';
import 'routes.dart';
import 'shortcuts.dart';
import 'theme.dart';

/// The Mac app's menu bar (m3-design §3.3): Settings… calls `settings`.
const menuChannel = MethodChannel('filbert/menu');

class FilbertApp extends ConsumerStatefulWidget {
  const FilbertApp({super.key});

  @override
  ConsumerState<FilbertApp> createState() => _FilbertAppState();
}

class _FilbertAppState extends ConsumerState<FilbertApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startupTasks());
    // Android may kill the app once it's in the background; write debounced
    // changes before that (m2-design §4.2).
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(viewPrefsRepositoryProvider).flush(),
    );
    menuChannel.setMethodCallHandler((call) async {
      if (call.method == 'settings') _openSettings();
    });
  }

  @override
  void dispose() {
    menuChannel.setMethodCallHandler(null);
    _lifecycle.dispose();
    super.dispose();
  }

  void _openSettings() => ref.read(routerProvider).go(Routes.settings);

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
      // Shortcuts that work on every screen; ⌘W is the Mac menu's.
      builder: (context, child) => KeyBindings(
        scope: false,
        bindings: [
          KeyBinding(
            command(LogicalKeyboardKey.comma),
            _openSettings,
            whileTyping: true,
          ),
        ],
        child: child!,
      ),
    );
  }
}
