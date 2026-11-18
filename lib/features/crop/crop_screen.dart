import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/imaging/crop_geometry.dart';
import '../autocrop/review_queue.dart';
import '../photo_viewer/photo_files.dart';
import '../photos/data/image_providers.dart';
import '../photos/data/image_repository.dart';
import '../photos/domain/project_image.dart';
import '../projects/data/project_providers.dart';
import '../projects/domain/project.dart';
import '../projects/domain/size_presets.dart';
import 'crop_editor.dart';
import 'crop_overlay.dart';

/// Manual crop (m1-design §3.7): crop rectangle with an aspect lock,
/// straighten slider and Rotate 90°, over the full original photo. Apply
/// saves the crop as an undoable edit.
///
/// [afterAdd]: opened for a reference just added (m1-design §3.6); Skip
/// leaves it uncropped, and every way out returns to the project.
///
/// [queue]: opened with Crop manually from the review of new photos
/// (§3.8); Skip leaves it as it is, Apply and Skip go on to the next
/// photo's review (or the project after the last), Cancel and back end the
/// queue at the project.
class CropScreen extends ConsumerWidget {
  const CropScreen({
    super.key,
    required this.projectId,
    required this.imageId,
    this.afterAdd = false,
    this.queue,
  });

  final String projectId;
  final String imageId;
  final bool afterAdd;
  final ReviewQueue? queue;

  /// Part of the add-photo flow: every way out goes on in the flow.
  bool get _inFlow => afterAdd || queue != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final images = ref.watch(projectImagesProvider(projectId));
    final image = images.value?.where((i) => i.id == imageId).firstOrNull;

    final Widget body;
    if (!project.hasValue || !images.hasValue) {
      body = project.hasError || images.hasError
          ? _Missing(projectId: projectId)
          : const Center(child: CircularProgressIndicator());
    } else if (project.value == null || image == null) {
      body = _Missing(projectId: projectId);
    } else {
      body = _CropView(
        key: ValueKey(image.id),
        project: project.value!,
        image: image,
        afterAdd: afterAdd,
        queue: queue,
      );
    }
    return PopScope(
      canPop: !_inFlow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.project(projectId));
      },
      child: Theme(
        data: FilbertTheme.dark,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: body),
        ),
      ),
    );
  }
}

class _CropView extends ConsumerStatefulWidget {
  const _CropView({
    super.key,
    required this.project,
    required this.image,
    this.afterAdd = false,
    this.queue,
  });

  final Project project;
  final ProjectImage image;
  final bool afterAdd;
  final ReviewQueue? queue;

  @override
  ConsumerState<_CropView> createState() => _CropViewState();
}

class _CropViewState extends ConsumerState<_CropView> {
  late final CropEditor _editor;

  /// The photo has a perspective crop manual crop can't show; Apply replaces
  /// it.
  late final bool _replacesPerspective;

  @override
  void initState() {
    super.initState();
    final image = widget.image;
    final defaultAspect = switch (widget.project.size) {
      RatioSize(:final w, :final h) => CropAspect(w, h),
      PhysicalSize(:final width, :final height) => CropAspect(width, height),
      NoSize() => null,
    };
    final editor = CropEditor.forEdits(
      image.edits,
      sourceWidth: image.width,
      sourceHeight: image.height,
      defaultAspect: defaultAspect,
    );
    _replacesPerspective = editor == null;
    _editor =
        editor ??
        CropEditor.fresh(
          frame: CropFrame(
            sourceWidth: image.width,
            sourceHeight: image.height,
          ),
          defaultAspect: defaultAspect,
        );
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.afterAdd || widget.queue != null) {
      context.go(Routes.project(widget.project.id));
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.photo(widget.project.id, widget.image.id));
    }
  }

  Future<void> _apply() async {
    await ref
        .read(imageRepositoryProvider)
        .setEdits(widget.image.id, _editor.edits);
    if (mounted) _next();
  }

  /// After Apply or Skip: the next photo's review in the queue, else as
  /// [_close].
  void _next() {
    final queue = widget.queue;
    if (queue == null || queue.isLast) {
      _close();
    } else {
      context.go(
        Routes.autocrop(
          widget.project.id,
          queue.remaining.first,
          queue: queue.advanced,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = ref.watch(
      previewFileProvider(widget.image.withEdits(Edits.none)),
    );
    return ListenableBuilder(
      listenable: _editor,
      builder: (context, _) => Column(
        children: [
          _TopBar(
            onCancel: _close,
            onReset: _editor.reset,
            onSkip: widget.afterAdd || widget.queue != null ? _next : null,
            onApply: _apply,
          ),
          if (_replacesPerspective)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'This photo has a perspective correction. '
                'Applying a crop replaces it (Undo brings it back).',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: switch (original) {
              AsyncData(:final value) => CropCanvas(
                editor: _editor,
                photo: value,
              ),
              AsyncError() => const _Message("Couldn't show this photo."),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          _StraightenRow(editor: _editor),
          _AspectRow(
            editor: _editor,
            hasProjectRatio: _editor.defaultAspect != null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onCancel,
    required this.onReset,
    required this.onApply,
    this.onSkip,
  });

  final VoidCallback onCancel;
  final VoidCallback onReset;
  final VoidCallback onApply;

  /// Shown when set (after adding a reference).
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: onCancel,
        ),
        const SizedBox(width: 4),
        // The title gives way on narrow screens so the buttons fit.
        Expanded(
          child: Text(
            'Crop',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        TextButton(onPressed: onReset, child: const Text('Reset')),
        if (onSkip != null)
          TextButton(onPressed: onSkip, child: const Text('Skip')),
        const SizedBox(width: 8),
        FilledButton(onPressed: onApply, child: const Text('Apply')),
      ],
    ),
  );
}

/// The photo (straightened and turned) with the crop over it. Converts
/// screen drags into display-space pixels for the [CropEditor].
class CropCanvas extends StatefulWidget {
  const CropCanvas({super.key, required this.editor, required this.photo});

  final CropEditor editor;
  final File photo;

  /// Room around the photo so edge handles can be grabbed.
  static const margin = 24.0;

  /// Touch radius of handles.
  static const cornerReach = 32.0;
  static const edgeReach = 24.0;

  /// Smallest crop on screen.
  static const minScreenSize = 48.0;

  @override
  State<CropCanvas> createState() => _CropCanvasState();
}

class _CropCanvasState extends State<CropCanvas> {
  Offset _dragStart = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final frame = editor.frame;
    return LayoutBuilder(
      builder: (context, constraints) {
        const m = CropCanvas.margin;
        final k = math.min(
          (constraints.maxWidth - 2 * m) / frame.displayWidth,
          (constraints.maxHeight - 2 * m) / frame.displayHeight,
        );
        final frameRect = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero),
          width: frame.displayWidth * k,
          height: frame.displayHeight * k,
        );
        Offset toScreen(CropPoint p) =>
            frameRect.center + Offset(p.x * k, p.y * k);
        final r = editor.rect;
        final cropRect = Rect.fromPoints(
          toScreen((x: r.left, y: r.top)),
          toScreen((x: r.right, y: r.bottom)),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Hit-test and measure from where the finger went down, not from
          // where the drag was recognised, so the crop tracks the finger.
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) {
            final handle = _hit(cropRect, d.localPosition);
            if (handle == null) return;
            _dragStart = d.localPosition;
            editor.startDrag(handle);
          },
          onPanUpdate: (d) {
            final delta = d.localPosition - _dragStart;
            editor.updateDrag(
              delta.dx / k,
              delta.dy / k,
              minSize: CropCanvas.minScreenSize / k,
            );
          },
          onPanEnd: (_) => editor.endDrag(),
          onPanCancel: editor.endDrag,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: frameRect,
                child: ClipRect(
                  child: Transform.rotate(
                    angle: frame.angle,
                    child: RotatedBox(
                      quarterTurns: frame.quarterTurns,
                      child: Image.file(
                        widget.photo,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                painter: CropOverlayPainter(crop: cropRect, frame: frameRect),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Which handle a touch at [p] grabs: corners first, then edges, then the
  /// inside (move).
  static CropHandle? _hit(Rect crop, Offset p) {
    const cr = CropCanvas.cornerReach, er = CropCanvas.edgeReach;
    for (final (corner, handle) in [
      (crop.topLeft, CropHandle.topLeft),
      (crop.topRight, CropHandle.topRight),
      (crop.bottomRight, CropHandle.bottomRight),
      (crop.bottomLeft, CropHandle.bottomLeft),
    ]) {
      if ((p - corner).distance <= cr) return handle;
    }
    final withinX = p.dx >= crop.left && p.dx <= crop.right;
    final withinY = p.dy >= crop.top && p.dy <= crop.bottom;
    if (withinX && (p.dy - crop.top).abs() <= er) return CropHandle.top;
    if (withinX && (p.dy - crop.bottom).abs() <= er) return CropHandle.bottom;
    if (withinY && (p.dx - crop.left).abs() <= er) return CropHandle.left;
    if (withinY && (p.dx - crop.right).abs() <= er) return CropHandle.right;
    if (crop.contains(p)) return CropHandle.move;
    return null;
  }
}

class _StraightenRow extends StatelessWidget {
  const _StraightenRow({required this.editor});

  final CropEditor editor;

  @override
  Widget build(BuildContext context) {
    final degrees = editor.frame.angle * 180 / math.pi;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Icon(Icons.straighten),
          Expanded(
            child: Slider(
              value: degrees,
              min: -45,
              max: 45,
              semanticFormatterCallback: (v) =>
                  'Straighten ${v.toStringAsFixed(1)} degrees',
              onChangeStart: (_) => editor.startStraighten(),
              onChanged: (v) => editor.setAngle(v * math.pi / 180),
              onChangeEnd: (_) => editor.endStraighten(),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${degrees.toStringAsFixed(1)}°',
              textAlign: TextAlign.end,
            ),
          ),
          IconButton(
            tooltip: 'Rotate 90°',
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
            onPressed: editor.rotate90,
          ),
        ],
      ),
    );
  }
}

/// Aspect lock chips: the project's ratio, the photo's own, freeform, and
/// the ratio presets; plus a portrait/landscape switch.
class _AspectRow extends StatelessWidget {
  const _AspectRow({required this.editor, required this.hasProjectRatio});

  final CropEditor editor;
  final bool hasProjectRatio;

  /// The preset in the crop's current orientation.
  CropAspect _oriented(CropAspect portrait) {
    final landscape = editor.rect.width > editor.rect.height;
    return landscape && !portrait.isLandscape ? portrait.flipped : portrait;
  }

  static bool _sameRatio(CropAspect? a, CropAspect b) =>
      a != null &&
      ((a.ratio - b.ratio).abs() < 1e-9 ||
          (a.ratio - b.flipped.ratio).abs() < 1e-9);

  @override
  Widget build(BuildContext context) {
    final current = editor.aspect;
    final project = editor.defaultAspect;
    final original = editor.frame.originalAspect;
    final options = <(String, CropAspect?)>[
      if (project != null) ('Project', project),
      ('Original', original),
      ('Freeform', null),
      for (final (w, h) in ratioPresets) (ratioLabel(w, h), CropAspect(w, h)),
    ];
    // The first matching option is selected (the project's ratio wins).
    final selected = current == null
        ? 'Freeform'
        : options
              .where((o) => o.$2 != null && _sameRatio(current, o.$2!))
              .firstOrNull
              ?.$1;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (label, aspect) in options)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: label == selected,
                      onSelected: (_) => editor.setAspect(switch (label) {
                        'Project' || 'Original' => aspect,
                        'Freeform' => null,
                        _ => _oriented(aspect!),
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (current != null && !current.isSquare)
            IconButton(
              tooltip: current.isLandscape ? 'Make portrait' : 'Make landscape',
              icon: Icon(
                current.isLandscape
                    ? Icons.crop_portrait
                    : Icons.crop_landscape,
              ),
              onPressed: editor.flipAspect,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// "4:5", "1.5:2".
String ratioLabel(double w, double h) => '${_trim(w)}:${_trim(h)}';

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The photo (or its project) is gone: say so, with a way back.
class _Missing extends StatelessWidget {
  const _Missing({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('This photo no longer exists.'),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => context.go(Routes.project(projectId)),
          child: const Text('Back'),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(child: Text(text));
}
