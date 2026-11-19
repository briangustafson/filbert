import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/layout.dart';
import '../../../core/imaging/image_origin.dart';
import '../data/photo_source.dart';

/// Files a drop adds (m3-design §3.4); others are ignored.
const droppableExtensions = {'.jpg', '.jpeg', '.png', '.heic', '.heif'};

bool isDroppableImage(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 &&
      droppableExtensions.contains(path.substring(dot).toLowerCase());
}

/// Takes image files dropped on [child] from the Finder or another app
/// (m3-design §3.4), on a desktop and only while its screen is on top.
///
/// While files are over it, the area is outlined with [hint] for where they
/// are. A drop with no image says so; otherwise [onDrop] gets the images in
/// order, with access to them held until it completes.
class PhotoDropTarget extends StatefulWidget {
  const PhotoDropTarget({
    super.key,
    required this.hint,
    required this.onDrop,
    required this.child,
  });

  /// What dropping at a global position would do ("Drop to add photos").
  final String Function(Offset globalPosition) hint;

  final Future<void> Function(List<PickedPhoto> photos, Offset globalPosition)
  onDrop;

  final Widget child;

  static const notImages = 'Filbert can only add photos.';

  @override
  State<PhotoDropTarget> createState() => _PhotoDropTargetState();
}

class _PhotoDropTargetState extends State<PhotoDropTarget> {
  /// Where the dragged files are, while they're over the target.
  Offset? _over;

  void _setOver(Offset? at) {
    if (mounted && at != _over) setState(() => _over = at);
  }

  Future<void> _onDone(DropDoneDetails details) async {
    _setOver(null);
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final items = [
      for (final item in details.files)
        if (item is! DropItemDirectory && isDroppableImage(item.path)) item,
    ];
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(PhotoDropTarget.notImages)));
      return;
    }
    // Finder files are outside the sandbox: reading them needs the
    // bookmarks that came with the drop.
    final drop = DesktopDrop.instance;
    final bookmarks = [
      for (final item in items)
        if (item.extraAppleBookmark case final b? when b.isNotEmpty) b,
    ];
    for (final bookmark in bookmarks) {
      await drop.startAccessingSecurityScopedResource(bookmark: bookmark);
    }
    try {
      await widget.onDrop([
        for (final item in items)
          PickedPhoto(
            path: item.path,
            origin: ImageOrigin.device,
            // A promised file is the app's own copy; a Finder file is the
            // user's, which import must never delete.
            temporary: item.fromPromise,
          ),
      ], details.globalPosition);
    } finally {
      for (final bookmark in bookmarks) {
        unawaited(drop.stopAccessingSecurityScopedResource(bookmark: bookmark));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final over = _over;
    final enabled = isDesktop && (ModalRoute.of(context)?.isCurrent ?? true);
    final colors = Theme.of(context).colorScheme;
    return DropTarget(
      enable: enabled,
      onDragEntered: (d) => _setOver(d.globalPosition),
      onDragUpdated: (d) => _setOver(d.globalPosition),
      onDragExited: (_) => _setOver(null),
      onDragDone: _onDone,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (over != null && enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('photo-drop-highlight'),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Text(
                          widget.hint(over),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
