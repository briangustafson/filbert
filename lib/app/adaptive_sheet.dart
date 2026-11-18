import 'package:material_ui/material_ui.dart';

import 'layout.dart';

/// Width of [showAdaptiveSheet]'s dialog.
const adaptiveDialogWidth = 480.0;

/// A modal bottom sheet on phones; on wider windows (medium and up) a
/// centred dialog of the same content (m3-design §3.2). The content pops
/// with its result as usual, and a `PopScope` in it guards both forms.
///
/// [enableDrag] is the sheet's drag-to-close (dialogs have none).
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool enableDrag = true,
}) {
  if (WindowWidth.of(context).isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: enableDrag,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: adaptiveDialogWidth),
        child: Padding(
          // The sheet's drag handle gives this space on phones.
          padding: const EdgeInsets.only(top: 20),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}
