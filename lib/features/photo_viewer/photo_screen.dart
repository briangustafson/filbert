import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout.dart';
import '../../app/routes.dart';
import '../export/ui/export_sheet.dart';
import '../photos/data/image_providers.dart';
import '../photos/data/image_repository.dart';
import '../photos/domain/project_image.dart';
import '../projects/data/project_providers.dart';
import '../projects/ui/delete_project.dart' show projectUndoDuration;
import '../view_aids/data/view_aids_providers.dart';
import '../view_aids/domain/view_aids.dart';
import '../view_aids/ui/aid_toolbar.dart';
import 'photo_order.dart';
import 'photo_page.dart';

/// Full-screen view of a project's photos (m1-design §3.5): swipe through
/// them (reference first), zoom, hold for the original. A tap toggles the
/// chrome (back and menu at the top, the viewing-aid toolbar at the bottom,
/// m2-design §3.1), which also hides itself after a few seconds unless an
/// aid's panel is open.
///
/// With a mouse (m3-design §3.2): moving the pointer shows the chrome, which
/// stays while the pointer is over it, and previous / next buttons appear
/// at the sides (a mouse can't swipe pages). On wide windows an open panel
/// docks at the right.
///
/// Swiping doesn't change the route: it stays on the photo that was opened,
/// and Back returns to the project.
class PhotoScreen extends ConsumerStatefulWidget {
  const PhotoScreen({
    super.key,
    required this.projectId,
    required this.imageId,
  });

  final String projectId;
  final String imageId;

  /// How long the chrome stays after it was shown.
  static const chromeTimeout = Duration(seconds: 3);

  @override
  ConsumerState<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends ConsumerState<PhotoScreen> {
  late String _currentId = widget.imageId;
  PageController? _pages;
  List<String> _ids = const [];
  var _zoomed = false;
  var _chrome = true;
  Timer? _hideTimer;

  /// A mouse is in use: the last pointer hovered (touch never does) and
  /// no touch came since.
  var _mouse = false;

  /// The pointer is over the chrome or a panel, which then stays.
  var _overChrome = false;

  @override
  void initState() {
    super.initState();
    _showChrome();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pages?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  ViewAidsStateProvider get _aids => viewAidsStateProvider(widget.projectId);

  /// Shows the chrome and restarts its hide timer; with a panel open it
  /// stays until the panel closes.
  void _showChrome() {
    _hideTimer?.cancel();
    if (ref.read(_aids).panel == null && !_overChrome) {
      _hideTimer = Timer(PhotoScreen.chromeTimeout, _hideChrome);
    }
    _setChrome(true);
  }

  void _hideChrome() {
    _hideTimer?.cancel();
    _setChrome(false);
  }

  void _setChrome(bool visible) {
    if (mounted && visible != _chrome) setState(() => _chrome = visible);
    // The system bars come and go with the chrome.
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  /// A tap on the photo closes an open panel and hides the chrome;
  /// otherwise it toggles the chrome.
  void _onPhotoTap() {
    if (ref.read(_aids).panel != null) {
      ref.read(_aids.notifier).closePanel();
      _hideChrome();
    } else {
      _chrome ? _hideChrome() : _showChrome();
    }
  }

  void _onHover(PointerHoverEvent event) {
    if (!_mouse) setState(() => _mouse = true);
    _showChrome();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch && _mouse) {
      setState(() => _mouse = false);
    }
  }

  /// Keeps the chrome while the pointer is over [child].
  Widget _holdsChrome(Widget child) => MouseRegion(
    // Only over what's drawn, so it never takes taps meant for the photo.
    hitTestBehavior: HitTestBehavior.deferToChild,
    onEnter: (_) {
      _overChrome = true;
      _hideTimer?.cancel();
    },
    onExit: (_) {
      _overChrome = false;
      if (_chrome) _showChrome();
    },
    child: child,
  );

  void _turnPage(int delta) {
    _pages?.animateToPage(
      _ids.indexOf(_currentId) + delta,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    _showChrome();
  }

  void _onAidTap(Aid aid) {
    ref.read(_aids.notifier).tap(aid);
    _showChrome();
  }

  /// Keeps the pages on the current photo when the list changes (a delete,
  /// an undo, a new reference). A new controller would inherit the old
  /// scroll offset, so the one controller jumps to the photo's new index.
  PageController _pagesFor(List<String> ids) {
    final pages = _pages ??= PageController(
      initialPage: ids.indexOf(_currentId),
    );
    if (!listEquals(ids, _ids)) {
      _ids = ids;
      final target = ids.indexOf(_currentId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pages.hasClients && pages.page?.round() != target) {
          pages.jumpToPage(target);
        }
      });
    }
    return pages;
  }

  Future<void> _setAsReference(ProjectImage image) async {
    _showChrome();
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(imageRepositoryProvider)
        .setAsReference(widget.projectId, image.id);
    messenger.showSnackBar(
      const SnackBar(content: Text('Set as the reference.')),
    );
  }

  /// The export sheet (m2-design §3.5), then a snackbar for what it did.
  Future<void> _export(ProjectImage image) async {
    _hideTimer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await showExportSheet(context, image);
    if (!mounted) return;
    _showChrome();
    switch (outcome) {
      case null:
        return;
      case SavedToGallery():
        messenger.showSnackBar(
          const SnackBar(content: Text('Saved to the gallery.')),
        );
      case SavedAsNewPhoto(:final photo):
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Saved as a new photo.'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _showPhoto(photo.id),
            ),
          ),
        );
    }
  }

  /// Swipes to [imageId] if it's one of the photos.
  void _showPhoto(String imageId) {
    final index = _ids.indexOf(imageId);
    if (index < 0) return;
    setState(() {
      _currentId = imageId;
      _zoomed = false;
    });
    final pages = _pages;
    if (pages != null && pages.hasClients) pages.jumpToPage(index);
  }

  Future<void> _revert(ProjectImage image) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(imageRepositoryProvider);
    await repository.revert(image.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Reverted to the original.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repository.undo(image.id),
        ),
      ),
    );
  }

  /// Shows the next photo (else the previous one, else returns to the
  /// project), then deletes, with Undo.
  Future<void> _delete(ProjectImage image) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(imageRepositoryProvider);
    final next = neighbourAfterDelete(_ids, image.id);
    if (next == null) {
      context.go(Routes.project(widget.projectId));
    } else {
      setState(() {
        _currentId = next;
        _zoomed = false;
      });
    }
    await repository.delete(image.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Photo deleted.'),
        duration: projectUndoDuration,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repository.restore(image.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider(widget.projectId));
    final images = ref.watch(projectImagesProvider(widget.projectId));
    final aids = ref.watch(_aids);

    final Widget body;
    ProjectImage? current;
    var photoCount = 0;
    if (!project.hasValue || !images.hasValue) {
      body = project.hasError || images.hasError
          ? const _Missing()
          : const Center(child: CircularProgressIndicator());
    } else {
      final ordered = photoOrder(
        project.value?.referenceImageId,
        images.value!,
      );
      current = ordered.where((i) => i.id == _currentId).firstOrNull;
      photoCount = ordered.length;
      if (project.value == null || current == null) {
        body = const _Missing();
      } else {
        final ids = [for (final i in ordered) i.id];
        body = PageView.builder(
          controller: _pagesFor(ids),
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: ordered.length,
          onPageChanged: (i) => setState(() {
            _currentId = ids[i];
            _zoomed = false;
          }),
          itemBuilder: (context, i) => PhotoPage(
            key: ValueKey(ordered[i].id),
            image: ordered[i],
            onTap: _onPhotoTap,
            onZoomedChanged: (zoomed) {
              if (ordered[i].id == _currentId && zoomed != _zoomed) {
                setState(() => _zoomed = zoomed);
              }
            },
          ),
        );
      }
    }

    final index = current == null ? -1 : _ids.indexOf(current.id);
    final docked = WindowWidth.of(context).isExpanded;
    final panel = current == null || aids.panel == null
        ? null
        : AidPanel(
            projectId: widget.projectId,
            image: current,
            panel: aids.panel!,
          );
    final isReference =
        current != null && current.id == project.value?.referenceImageId;
    final history = current == null
        ? EditHistory.empty
        : ref.watch(editHistoryProvider(current.id)).value ?? EditHistory.empty;
    return PopScope(
      // Back closes an open panel first.
      canPop: aids.panel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(_aids.notifier).closePanel();
          _showChrome();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          onPointerDown: _onPointerDown,
          child: MouseRegion(
            onHover: _onHover,
            child: Stack(
              fit: StackFit.expand,
              children: [
                body,
                if (current != null && _mouse) ...[
                  if (index > 0)
                    _PageArrow(
                      hold: _holdsChrome,
                      visible: _chrome,
                      next: false,
                      onPressed: () => _turnPage(-1),
                    ),
                  if (index < photoCount - 1)
                    _PageArrow(
                      hold: _holdsChrome,
                      visible: _chrome,
                      next: true,
                      onPressed: () => _turnPage(1),
                    ),
                ],
                if (current != null)
                  _BottomChrome(
                    hold: _holdsChrome,
                    visible: _chrome,
                    toolbar: AidToolbar(
                      aids: aids,
                      showCompare: photoCount > 1,
                      onTap: _onAidTap,
                    ),
                    panel: panel == null || docked ? null : panel,
                  ),
                if (panel != null && docked)
                  _SidePanel(
                    hold: _holdsChrome,
                    visible: _chrome,
                    child: panel,
                  ),
                _Chrome(
                  hold: _holdsChrome,
                  visible: _chrome || current == null,
                  onBack: () => context.go(Routes.project(widget.projectId)),
                  menu: current == null
                      ? null
                      : _PhotoMenu(
                          onCrop: () => context.go(
                            Routes.crop(widget.projectId, current!.id),
                          ),
                          onAutoCrop: () => context.go(
                            Routes.autocrop(widget.projectId, current!.id),
                          ),
                          canUndo: history.canUndo,
                          canRedo: history.canRedo,
                          canRevert: !current.edits.isNone,
                          isReference: isReference,
                          onOpened: _hideTimer?.cancel,
                          onClosed: _showChrome,
                          onUndo: () => ref
                              .read(imageRepositoryProvider)
                              .undo(current!.id),
                          onRedo: () => ref
                              .read(imageRepositoryProvider)
                              .redo(current!.id),
                          onRevert: () => _revert(current!),
                          onExport: () => _export(current!),
                          onSetAsReference: () => _setAsReference(current!),
                          onDelete: () => _delete(current!),
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

Widget _noHold(Widget child) => child;

/// Previous / next photo at a side of the screen, for a mouse.
class _PageArrow extends StatelessWidget {
  const _PageArrow({
    this.hold = _noHold,
    required this.visible,
    required this.next,
    required this.onPressed,
  });

  final bool visible;
  final Widget Function(Widget) hold;
  final bool next;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: next ? Alignment.centerRight : Alignment.centerLeft,
    child: hold(
      IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton.filledTonal(
              key: ValueKey(next ? 'photo-next' : 'photo-previous'),
              tooltip: next ? 'Next photo' : 'Previous photo',
              icon: Icon(next ? Icons.chevron_right : Icons.chevron_left),
              iconSize: 32,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    ),
  );
}

/// An aid's panel docked at the right of a wide window, below the top bar
/// (m3-design §3.2).
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    this.hold = _noHold,
    required this.visible,
    required this.child,
  });

  static const width = 320.0;

  final bool visible;

  /// Keeps the chrome while the pointer is over it.
  final Widget Function(Widget) hold;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topRight,
    child: hold(
      IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SafeArea(
            child: Padding(
              // Below the top bar, above the toolbar.
              padding: const EdgeInsets.fromLTRB(0, 64, 12, 96),
              child: SizedBox(
                key: const ValueKey('aid-side-panel'),
                width: width,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The aid toolbar and the open panel, at the bottom on a dark gradient.
class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    this.hold = _noHold,
    required this.visible,
    required this.toolbar,
    this.panel,
  });

  final bool visible;

  /// Keeps the chrome while the pointer is over it.
  final Widget Function(Widget) hold;
  final Widget toolbar;
  final Widget? panel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: hold(
        IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.black54, Colors.transparent],
                  stops: [0, 0.7, 1],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [?panel, toolbar],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back button and menu over the photo, on a soft dark gradient.
class _Chrome extends StatelessWidget {
  const _Chrome({
    this.hold = _noHold,
    required this.visible,
    required this.onBack,
    this.menu,
  });

  final bool visible;

  /// Keeps the chrome while the pointer is over it.
  final Widget Function(Widget) hold;
  final VoidCallback onBack;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: hold(
        IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.white,
                          onPressed: onBack,
                        ),
                        const Spacer(),
                        ?menu,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Items appear only when they apply (m1-design §3.5).
class _PhotoMenu extends StatelessWidget {
  const _PhotoMenu({
    required this.onCrop,
    required this.onAutoCrop,
    required this.canUndo,
    required this.canRedo,
    required this.canRevert,
    required this.isReference,
    required this.onOpened,
    required this.onClosed,
    required this.onUndo,
    required this.onRedo,
    required this.onRevert,
    required this.onExport,
    required this.onSetAsReference,
    required this.onDelete,
  });

  final VoidCallback onCrop;
  final VoidCallback onAutoCrop;
  final bool canUndo;
  final bool canRedo;
  final bool canRevert;
  final bool isReference;
  final VoidCallback? onOpened;
  final VoidCallback onClosed;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onRevert;
  final VoidCallback onExport;
  final VoidCallback onSetAsReference;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PhotoAction>(
      tooltip: 'Photo options',
      iconColor: Colors.white,
      onOpened: onOpened,
      onCanceled: onClosed,
      onSelected: (action) {
        onClosed();
        switch (action) {
          case _PhotoAction.crop:
            onCrop();
          case _PhotoAction.autoCrop:
            onAutoCrop();
          case _PhotoAction.undo:
            onUndo();
          case _PhotoAction.redo:
            onRedo();
          case _PhotoAction.revert:
            onRevert();
          case _PhotoAction.export:
            onExport();
          case _PhotoAction.setAsReference:
            onSetAsReference();
          case _PhotoAction.delete:
            onDelete();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _PhotoAction.crop,
          child: Text('Crop/rotate'),
        ),
        const PopupMenuItem(
          value: _PhotoAction.autoCrop,
          child: Text('Auto-crop'),
        ),
        if (canUndo)
          const PopupMenuItem(value: _PhotoAction.undo, child: Text('Undo')),
        if (canRedo)
          const PopupMenuItem(value: _PhotoAction.redo, child: Text('Redo')),
        if (canRevert)
          const PopupMenuItem(
            value: _PhotoAction.revert,
            child: Text('Revert to original'),
          ),
        const PopupMenuItem(value: _PhotoAction.export, child: Text('Export…')),
        if (!isReference)
          const PopupMenuItem(
            value: _PhotoAction.setAsReference,
            child: Text('Set as reference'),
          ),
        const PopupMenuItem(value: _PhotoAction.delete, child: Text('Delete')),
      ],
    );
  }
}

enum _PhotoAction {
  crop,
  autoCrop,
  undo,
  redo,
  revert,
  export,
  setAsReference,
  delete,
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'This photo no longer exists.',
      style: TextStyle(color: Colors.white),
    ),
  );
}
