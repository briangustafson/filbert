import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../photo_viewer/photo_page.dart' show PhotoMissingNotice;
import '../sync/data/blob_availability.dart';
import '../sync/data/sync_providers.dart';
import '../../app/layout.dart';
import '../../app/routes.dart';
import '../../app/shortcuts.dart';
import '../../app/theme.dart';
import '../../core/imaging/crop_geometry.dart';
import '../../core/imaging/image_metadata.dart';
import '../autocrop/canvas_detection.dart';
import '../autocrop/review_geometry.dart';
import '../autocrop/review_queue.dart';
import '../photo_viewer/photo_files.dart';
import '../photos/data/image_providers.dart';
import '../photos/data/image_repository.dart';
import '../photos/domain/project_image.dart';
import '../projects/data/project_providers.dart';
import '../projects/domain/project.dart';
import '../projects/domain/size_presets.dart';
import 'corners_canvas.dart';
import 'crop_editor.dart';
import 'crop_modes.dart';
import 'crop_overlay.dart';

/// Crop (m1-design §3.7): the full original photo with a crop over it, in
/// one of two modes. **Rectangle**: an upright crop with an aspect lock,
/// straighten slider and Rotate 90°. **Corners**: four corners moved freely
/// (with a magnifier), and Apply corrects the perspective. **Find canvas**
/// detects the canvas and switches to Corners. Apply saves an undoable
/// edit; Return applies and Esc cancels (m3-design §3.3).
///
/// [afterAdd]: opened for a reference just added (m1-design §3.6); Skip
/// leaves it uncropped, and every way out returns to the project.
///
/// [queue]: photos just added, cropped in turn (§3.6): "2 of 3" and Skip;
/// Apply and Skip go on to the next photo (or the project after the last),
/// Cancel and back end the queue at the project.
///
/// [findCanvas]: runs Find canvas on opening (adding photos with auto-crop
/// on).
class CropScreen extends ConsumerWidget {
  const CropScreen({
    super.key,
    required this.projectId,
    required this.imageId,
    this.afterAdd = false,
    this.queue,
    this.findCanvas = false,
  });

  final String projectId;
  final String imageId;
  final bool afterAdd;
  final ReviewQueue? queue;
  final bool findCanvas;

  /// Shown in Corners mode when detection is unsure.
  static const lowConfidenceHint =
      "Couldn't find the canvas edges — drag the corners into place.";

  /// Part of the add-photo flow: every way out goes on in the flow.
  bool get _inFlow => afterAdd || queue != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final images = ref.watch(projectImagesProvider(projectId));
    final image = images.value?.where((i) => i.id == imageId).firstOrNull;

    final Widget page;
    if (!project.hasValue || !images.hasValue) {
      page = EditorScaffold(
        body: project.hasError || images.hasError
            ? _Missing(projectId: projectId)
            : const Center(child: CircularProgressIndicator()),
      );
    } else if (project.value == null || image == null) {
      page = EditorScaffold(body: _Missing(projectId: projectId));
    } else if (ref
            .watch(blobAvailabilityProvider(image.blobId, image.mimeType))
            .value
        case final availability?
        when availability != BlobAvailability.original) {
      // Crops are drawn on the full photo, not Drive's 512 px thumbnail
      // (m3-design §6.5): wait for it, and fetch it next.
      if (availability != BlobAvailability.missing) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(blobDownloaderProvider).prioritize(image.blobId),
        );
      }
      page = EditorScaffold(
        body: _WaitingForOriginal(
          projectId: projectId,
          missing: availability == BlobAvailability.missing,
        ),
      );
    } else {
      page = _CropView(
        key: ValueKey(image.id),
        project: project.value!,
        image: image,
        afterAdd: afterAdd,
        queue: queue,
        findCanvas: findCanvas,
      );
    }
    return PopScope(
      canPop: !_inFlow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.project(projectId));
      },
      child: Theme(data: FilbertTheme.dark, child: page),
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
    this.findCanvas = false,
  });

  final Project project;
  final ProjectImage image;
  final bool afterAdd;
  final ReviewQueue? queue;
  final bool findCanvas;

  @override
  ConsumerState<_CropView> createState() => _CropViewState();
}

class _CropViewState extends ConsumerState<_CropView> {
  /// Where an unsure (or failed) detection starts the corners.
  static const unsureInset = 0.05;

  late CropMode _mode;

  /// Rectangle mode.
  late CropEditor _editor;

  /// Corners mode: normalized in the photo as displayed (turned by
  /// [_cornerTurns]).
  late List<ReviewCorner> _corners;
  late int _cornerTurns;

  /// Find canvas: running, its result (corners in the original, or null if
  /// unsure or failed) once it has run, and whether to show the hint.
  var _finding = false;
  var _found = false;
  List<NormPoint>? _detected;
  var _showHint = false;

  ProjectImage get _image => widget.image;

  /// The project's ratio as the painting is seen, if it has a size.
  CropAspect? get _projectAspect => switch (widget.project.size) {
    RatioSize(:final w, :final h) => CropAspect(w, h),
    PhysicalSize(:final width, :final height) => CropAspect(width, height),
    NoSize() => null,
  };

  CropEditor _editorFor(CropState state) => CropEditor(
    initial: state,
    defaultAspect: _projectAspect,
    resetFrame: CropFrame(
      sourceWidth: _image.width,
      sourceHeight: _image.height,
    ),
  );

  @override
  void initState() {
    super.initState();
    final edits = _image.edits;
    _cornerTurns = edits.quarterTurns;
    _corners = cornersFromEdits(edits);
    final editor = CropEditor.forEdits(
      edits,
      sourceWidth: _image.width,
      sourceHeight: _image.height,
      defaultAspect: _projectAspect,
    );
    if (widget.findCanvas) {
      _mode = CropMode.corners;
      _editor = editor ?? _rectangleAroundCorners(_projectAspect);
      _findCanvas();
    } else if (editor == null) {
      // A perspective crop: only Corners can show it.
      _mode = CropMode.corners;
      _editor = _rectangleAroundCorners(_projectAspect);
    } else {
      _mode = CropMode.rectangle;
      _editor = editor;
    }
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  CropEditor _rectangleAroundCorners(CropAspect? aspect) => _editorFor(
    rectangleAround(
      _corners,
      quarterTurns: _cornerTurns,
      sourceWidth: _image.width,
      sourceHeight: _image.height,
      aspect: aspect,
    ),
  );

  /// Switches modes, carrying the crop over: Rectangle → Corners on the
  /// rectangle's corners; Corners → Rectangle around the corners.
  void _setMode(CropMode mode) {
    if (mode == _mode) return;
    setState(() {
      if (mode == CropMode.corners) {
        final edits = _editor.edits;
        _corners = cornersFromEdits(edits);
        _cornerTurns = edits.quarterTurns;
      } else {
        final old = _editor;
        _editor = _rectangleAroundCorners(old.aspect);
        // Still listened to until this frame is built.
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      _showHint = false;
      _mode = mode;
    });
  }

  /// Detects the canvas (once per visit) and puts the corners on it, in
  /// Corners mode. Unsure: corners slightly inset, with the hint.
  Future<void> _findCanvas() async {
    if (_finding) return;
    _setMode(CropMode.corners);
    if (!_found) {
      setState(() => _finding = true);
      _detected = await _detect();
      _found = true;
      if (!mounted) return;
    }
    final quad = _detected;
    var corners = quad == null
        ? insetCorners(unsureInset)
        : quadToDisplayed(quad, _cornerTurns);
    if (!isValidReviewQuad(corners)) corners = insetCorners(unsureInset);
    setState(() {
      _finding = false;
      _mode = CropMode.corners;
      _corners = corners;
      _showHint = quad == null;
    });
  }

  /// The detected corners in the original, or null if unsure or failed.
  Future<List<NormPoint>?> _detect() async {
    try {
      final aspect = _projectAspect;
      final detection = await ref
          .read(canvasDetectionProvider)
          .detect(_image, aspectHint: aspect?.ratio);
      if (detection.isLowConfidence) return null;
      return [for (final c in detection.quad.corners) NormPoint(c.x, c.y)];
    } on Exception catch (e) {
      debugPrint('Canvas detection failed: $e');
      return null;
    }
  }

  void _rotate() {
    if (_mode == CropMode.rectangle) {
      _editor.rotate90();
    } else {
      setState(() {
        _corners = turnCornersClockwise(_corners);
        _cornerTurns = (_cornerTurns + 1) % 4;
      });
    }
  }

  /// Back to the whole, unturned photo (with the project's ratio proposed
  /// in Rectangle mode).
  void _reset() {
    if (_mode == CropMode.rectangle) {
      _editor.reset();
    } else {
      setState(() {
        _corners = fullImageCorners;
        _cornerTurns = 0;
        _showHint = false;
      });
    }
  }

  Edits get _edits => switch (_mode) {
    CropMode.rectangle => _editor.edits,
    CropMode.corners => reviewEdits(
      _corners,
      quarterTurns: _cornerTurns,
      aspect: switch (_projectAspect) {
        final a? => (w: a.w, h: a.h),
        null => null,
      },
    ),
  };

  void _close() {
    if (widget.afterAdd || widget.queue != null) {
      context.go(Routes.project(widget.project.id));
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.photo(widget.project.id, _image.id));
    }
  }

  Future<void> _apply() async {
    await ref.read(imageRepositoryProvider).setEdits(_image.id, _edits);
    if (mounted) _next();
  }

  /// After Apply or Skip: the next photo in the queue, else as [_close].
  void _next() {
    final queue = widget.queue;
    if (queue == null || queue.isLast) {
      _close();
    } else {
      context.go(
        Routes.crop(
          widget.project.id,
          queue.remaining.first,
          queue: queue.advanced,
          findCanvas: true,
        ),
      );
    }
  }

  /// Debug builds: one `expected.json` entry for the evaluation set
  /// (m1-design §6.4), corners in the EXIF-oriented original.
  Future<void> _copyCorners() async {
    final quad = displayedToQuad(_corners, _cornerTurns);
    double round(double v) => (v * 10000).round() / 10000;
    final ext = extensionForMimeType[_image.mimeType] ?? 'jpg';
    final json = jsonEncode({
      'file': '${_image.id}.$ext',
      'corners': [
        for (final p in quad) [round(p.x), round(p.y)],
      ],
      'notes': '',
    });
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Corners copied as JSON.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = ref.watch(
      previewFileProvider(_image.withEdits(Edits.none)),
    );
    final queue = widget.queue;
    final corners = _mode == CropMode.corners;
    final String? hint = _finding
        ? 'Finding the canvas…'
        : (corners && _showHint ? CropScreen.lowConfidenceHint : null);
    return KeyBindings(
      bindings: [
        KeyBinding(const SingleActivator(LogicalKeyboardKey.enter), _apply),
        KeyBinding(
          const SingleActivator(LogicalKeyboardKey.numpadEnter),
          _apply,
        ),
        KeyBinding(const SingleActivator(LogicalKeyboardKey.escape), _close),
      ],
      child: ListenableBuilder(
        listenable: _editor,
        builder: (context, _) => EditorScaffold(
          body: Column(
            children: [
              _TopBar(
                subtitle: queue != null && queue.total > 1
                    ? '${queue.position} of ${queue.total}'
                    : null,
                onCancel: _close,
                onReset: _reset,
                onSkip: widget.afterAdd || queue != null ? _next : null,
                onApply: _apply,
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(hint, textAlign: TextAlign.center),
                ),
              Expanded(
                child: switch (original) {
                  AsyncData(:final value) =>
                    corners
                        ? CornersCanvas(
                            photo: value,
                            sourceWidth: _image.width,
                            sourceHeight: _image.height,
                            quarterTurns: _cornerTurns,
                            corners: _corners,
                            onChanged: (c) => setState(() => _corners = c),
                          )
                        : CropCanvas(editor: _editor, photo: value),
                  AsyncError() => const _Message("Couldn't show this photo."),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
          controls: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeRow(
                mode: _mode,
                finding: _finding,
                onMode: _setMode,
                onFindCanvas: _findCanvas,
              ),
              if (corners)
                _CornersRow(
                  onRotate: _rotate,
                  onCopyCorners: kDebugMode ? _copyCorners : null,
                )
              else ...[
                _StraightenRow(editor: _editor),
                _AspectRow(
                  editor: _editor,
                  hasProjectRatio: _editor.defaultAspect != null,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onCancel,
    required this.onReset,
    required this.onApply,
    this.subtitle,
    this.onSkip,
  });

  final VoidCallback onCancel;
  final VoidCallback onReset;
  final VoidCallback onApply;

  /// "2 of 3" when cropping new photos in turn.
  final String? subtitle;

  /// Shown when set (adding photos).
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: withShortcut('Cancel', 'Esc'),
          icon: const Icon(Icons.close),
          onPressed: onCancel,
        ),
        const SizedBox(width: 4),
        // The title gives way on narrow screens so the buttons fit.
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crop',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
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

/// Rectangle | Corners, and Find canvas. Wraps onto two lines where they
/// don't fit (narrow phones, large text).
class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.finding,
    required this.onMode,
    required this.onFindCanvas,
  });

  final CropMode mode;
  final bool finding;
  final ValueChanged<CropMode> onMode;
  final VoidCallback onFindCanvas;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        SegmentedButton<CropMode>(
          segments: const [
            ButtonSegment(
              value: CropMode.rectangle,
              icon: Icon(Icons.crop),
              label: Text('Rectangle'),
            ),
            ButtonSegment(
              value: CropMode.corners,
              icon: Icon(Icons.format_shapes_outlined),
              label: Text('Corners'),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onMode(s.single),
        ),
        TextButton.icon(
          key: const ValueKey('find-canvas'),
          onPressed: finding ? null : onFindCanvas,
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('Find canvas'),
        ),
      ],
    ),
  );
}

/// Corners mode: what to do, and Rotate 90°. As tall as Rectangle mode's
/// straighten and ratio rows, so the photo stays put when switching modes.
class _CornersRow extends StatelessWidget {
  const _CornersRow({required this.onRotate, this.onCopyCorners});

  /// The straighten row (an icon button) and the ratio chips' row.
  static const height = kMinInteractiveDimension + _AspectRow.height;

  final VoidCallback onRotate;

  /// Debug builds only.
  final VoidCallback? onCopyCorners;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.topCenter,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Drag each corner onto the canvas's corner.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (onCopyCorners != null)
          IconButton(
            tooltip: 'Copy corners as JSON',
            icon: const Icon(Icons.data_object),
            onPressed: onCopyCorners,
          ),
        IconButton(
          tooltip: 'Rotate 90°',
          icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
          onPressed: onRotate,
        ),
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

  /// Room around the photo so edge handles can be grabbed; the same as
  /// [CornersCanvas.margin], so the photo stays put when switching modes.
  static const margin = CornersCanvas.margin;

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

  static const height = 56.0;

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
      height: height,
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

class _WaitingForOriginal extends StatelessWidget {
  const _WaitingForOriginal({required this.projectId, required this.missing});

  static const downloading = 'Downloading the full photo…';

  final String projectId;
  final bool missing;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (missing)
          const Text(PhotoMissingNotice.text)
        else ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(downloading),
        ],
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
