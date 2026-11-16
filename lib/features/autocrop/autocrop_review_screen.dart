import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/imaging/image_metadata.dart';
import '../photo_viewer/photo_files.dart';
import '../photos/data/image_providers.dart';
import '../photos/data/image_repository.dart';
import '../photos/domain/project_image.dart';
import '../projects/data/project_providers.dart';
import '../projects/domain/project.dart';
import 'canvas_detection.dart';
import 'review_geometry.dart';

/// Auto-crop review (m1-design §3.8): the detected canvas corners over the
/// photo, draggable with a magnifier loupe; Apply saves a perspective
/// correction as an undoable edit.
class AutocropReviewScreen extends ConsumerWidget {
  const AutocropReviewScreen({
    super.key,
    required this.projectId,
    required this.imageId,
  });

  final String projectId;
  final String imageId;

  /// Hint shown when detection is unsure.
  static const lowConfidenceHint =
      "Couldn't find the canvas edges — drag the corners.";

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
      body = _ReviewView(
        key: ValueKey(image.id),
        project: project.value!,
        image: image,
      );
    }
    return Theme(
      data: FilbertTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: body),
      ),
    );
  }
}

class _ReviewView extends ConsumerStatefulWidget {
  const _ReviewView({super.key, required this.project, required this.image});

  final Project project;
  final ProjectImage image;

  @override
  ConsumerState<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<_ReviewView> {
  /// Where a low-confidence (or failed) detection starts the corners.
  static const unsureInset = 0.05;

  late List<ReviewCorner> _corners;

  /// What Reset returns to: the detected corners (or the inset guess).
  List<ReviewCorner>? _detected;
  var _lowConfidence = false;

  int get _turns => widget.image.edits.quarterTurns;

  ({double w, double h})? get _projectAspect => switch (widget.project.size) {
    RatioSize(:final w, :final h) => (w: w, h: h),
    PhysicalSize(:final width, :final height) => (w: width, h: height),
    NoSize() => null,
  };

  @override
  void initState() {
    super.initState();
    final crop = widget.image.edits.crop;
    // An existing crop is the starting point; detection fills in Reset.
    _corners = crop == null
        ? insetCorners(unsureInset)
        : quadToDisplayed(crop.quad, _turns);
    _detect(replaceCorners: crop == null);
  }

  Future<void> _detect({required bool replaceCorners}) async {
    List<ReviewCorner> start;
    bool low;
    try {
      final aspect = _projectAspect;
      final detection = await ref
          .read(canvasDetectionProvider)
          .detect(
            widget.image,
            aspectHint: aspect == null ? null : aspect.w / aspect.h,
          );
      low = detection.isLowConfidence;
      start = low
          ? insetCorners(unsureInset)
          : quadToDisplayed([
              for (final c in detection.quad.corners) NormPoint(c.x, c.y),
            ], _turns);
      if (!isValidReviewQuad(start)) {
        low = true;
        start = insetCorners(unsureInset);
      }
    } on Exception catch (e) {
      debugPrint('Canvas detection failed: $e');
      low = true;
      start = insetCorners(unsureInset);
    }
    if (!mounted) return;
    setState(() {
      _detected = start;
      _lowConfidence = low;
      if (replaceCorners) _corners = start;
    });
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.photo(widget.project.id, widget.image.id));
    }
  }

  Future<void> _apply() async {
    await ref
        .read(imageRepositoryProvider)
        .setEdits(
          widget.image.id,
          reviewEdits(_corners, quarterTurns: _turns, aspect: _projectAspect),
        );
    if (mounted) _close();
  }

  /// Debug builds: one `expected.json` entry for the evaluation set
  /// (m1-design §6.4), corners in the EXIF-oriented original.
  Future<void> _copyCorners() async {
    final quad = displayedToQuad(_corners, _turns);
    double round(double v) => (v * 10000).round() / 10000;
    final ext = extensionForMimeType[widget.image.mimeType] ?? 'jpg';
    final json = jsonEncode({
      'file': '${widget.image.id}.$ext',
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
      previewFileProvider(widget.image.withEdits(Edits.none)),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
              const SizedBox(width: 4),
              Text('Auto-crop', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (kDebugMode)
                IconButton(
                  tooltip: 'Copy corners as JSON',
                  icon: const Icon(Icons.data_object),
                  onPressed: _copyCorners,
                ),
              const SizedBox(width: 4),
              FilledButton(onPressed: _apply, child: const Text('Apply')),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: _detected == null
              ? const Text('Finding the canvas…')
              : (_lowConfidence
                    ? const Text(
                        AutocropReviewScreen.lowConfidenceHint,
                        textAlign: TextAlign.center,
                      )
                    : null),
        ),
        Expanded(
          child: switch (original) {
            AsyncData(:final value) => ReviewCanvas(
              photo: value,
              sourceWidth: widget.image.width,
              sourceHeight: widget.image.height,
              quarterTurns: _turns,
              corners: _corners,
              onChanged: (corners) => setState(() => _corners = corners),
            ),
            AsyncError() => const _Message("Couldn't show this photo."),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _corners = fullImageCorners),
                icon: const Icon(Icons.fullscreen),
                label: const Text('Full image'),
              ),
              TextButton.icon(
                onPressed: _detected == null
                    ? null
                    : () => setState(() => _corners = _detected!),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The photo (turned as displayed) with the four corners over it. Dragging
/// a corner shows a magnifier loupe above the finger; drags that would make
/// an invalid quad are refused.
class ReviewCanvas extends StatefulWidget {
  const ReviewCanvas({
    super.key,
    required this.photo,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.quarterTurns,
    required this.corners,
    required this.onChanged,
  });

  final File photo;
  final int sourceWidth;
  final int sourceHeight;
  final int quarterTurns;
  final List<ReviewCorner> corners;
  final ValueChanged<List<ReviewCorner>> onChanged;

  static const margin = 32.0;
  static const reach = 48.0;
  static const loupeSize = 120.0;
  static const loupeLift = 110.0;

  @override
  State<ReviewCanvas> createState() => _ReviewCanvasState();
}

class _ReviewCanvasState extends State<ReviewCanvas> {
  int? _active;
  ReviewCorner? _startCorner;
  Offset _startPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final turned = widget.quarterTurns.isOdd;
    final w = (turned ? widget.sourceHeight : widget.sourceWidth).toDouble();
    final h = (turned ? widget.sourceWidth : widget.sourceHeight).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        const m = ReviewCanvas.margin;
        final k = math.min(
          (constraints.maxWidth - 2 * m) / w,
          (constraints.maxHeight - 2 * m) / h,
        );
        final frame = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero),
          width: w * k,
          height: h * k,
        );
        Offset toScreen(ReviewCorner c) =>
            frame.topLeft + Offset(c.x * frame.width, c.y * frame.height);
        final points = [for (final c in widget.corners) toScreen(c)];

        final active = _active;
        Widget? loupe;
        if (active != null) {
          final p = points[active];
          const s = ReviewCanvas.loupeSize, lift = ReviewCanvas.loupeLift;
          // Above the finger, or below it near the top.
          final above = p.dy - lift - s / 2 >= 0;
          // Kept on screen sideways; it still magnifies the corner.
          final center = Offset(
            p.dx.clamp(s / 2, constraints.maxWidth - s / 2),
            p.dy + (above ? -lift : lift),
          );
          loupe = Positioned(
            left: center.dx - s / 2,
            top: center.dy - s / 2,
            child: RawMagnifier(
              size: const Size(s, s),
              magnificationScale: 2.5,
              focalPointOffset: p - center,
              decoration: const MagnifierDecoration(
                shape: CircleBorder(
                  side: BorderSide(color: Colors.white, width: 2),
                ),
              ),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) {
            final i = _nearest(points, d.localPosition);
            if (i == null) return;
            setState(() {
              _active = i;
              _startCorner = widget.corners[i];
              _startPosition = d.localPosition;
            });
          },
          onPanUpdate: (d) {
            final i = _active, start = _startCorner;
            if (i == null || start == null) return;
            final delta = d.localPosition - _startPosition;
            final moved = (
              x: (start.x + delta.dx / frame.width).clamp(0.0, 1.0),
              y: (start.y + delta.dy / frame.height).clamp(0.0, 1.0),
            );
            final next = [...widget.corners]..[i] = moved;
            if (isValidReviewQuad(next)) widget.onChanged(next);
          },
          onPanEnd: (_) => setState(() => _active = null),
          onPanCancel: () => setState(() => _active = null),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: frame,
                child: RotatedBox(
                  quarterTurns: widget.quarterTurns,
                  child: Image.file(
                    widget.photo,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              CustomPaint(
                painter: ReviewOverlayPainter(corners: points, active: _active),
              ),
              ?loupe,
            ],
          ),
        );
      },
    );
  }

  static int? _nearest(List<Offset> points, Offset p) {
    int? best;
    var bestDistance = ReviewCanvas.reach;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i] - p).distance;
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }
}

/// The quad outline with the outside dimmed, and round corner handles.
class ReviewOverlayPainter extends CustomPainter {
  const ReviewOverlayPainter({required this.corners, this.active});

  /// Corners in screen coordinates (exposed for tests).
  final List<Offset> corners;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final quad = Path()..addPolygon(corners, true);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        quad,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      quad,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < corners.length; i++) {
      final r = i == active ? 16.0 : 12.0;
      canvas
        ..drawCircle(
          corners[i],
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        )
        ..drawCircle(
          corners[i],
          r,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
    }
  }

  @override
  bool shouldRepaint(ReviewOverlayPainter old) =>
      !listEquals(old.corners, corners) || old.active != active;
}

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
