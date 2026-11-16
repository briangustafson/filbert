import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/imaging/render_geometry.dart';
import '../photos/data/image_renderer.dart';
import '../photos/domain/project_image.dart';
import '../photos/ui/image_thumbnail.dart';
import 'photo_files.dart';

/// One photo on the photo screen (m1-design §3.5): the edited view fitted to
/// the screen, with pinch and double-tap zoom, and the original while held.
///
/// Shows the thumbnail scaled up until the preview is ready, and switches to
/// a sharper "detail" render once zoomed past the preview's resolution.
class PhotoPage extends ConsumerStatefulWidget {
  const PhotoPage({
    super.key,
    required this.image,
    required this.onTap,
    required this.onZoomedChanged,
  });

  final ProjectImage image;
  final VoidCallback onTap;

  /// Whether the photo is zoomed in (the screen stops swiping while it is).
  final ValueChanged<bool> onZoomedChanged;

  @override
  ConsumerState<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends ConsumerState<PhotoPage>
    with SingleTickerProviderStateMixin {
  final _zoom = TransformationController();
  late final _zoomAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomTween;

  var _zoomed = false;
  var _wantDetail = false;
  var _holding = false;
  Offset _doubleTapAt = Offset.zero;

  // Layout facts from the last build, used by the zoom listener.
  var _fitted = Size.zero;
  var _box = Size.zero;
  var _devicePixelRatio = 1.0;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoom);
    _zoomAnimation.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _zoom.value = tween.value;
    });
  }

  @override
  void dispose() {
    _zoomAnimation.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// Output size in pixels at full resolution (before any preview cap).
  (int, int) get _naturalSize => RenderPlan.forEdits(
    sourceWidth: widget.image.width,
    sourceHeight: widget.image.height,
    edits: widget.image.edits,
    maxLongEdge: 1 << 20,
  ).outputSize;

  double get _scale => _zoom.value.getMaxScaleOnAxis();

  /// Zoom at which one pixel of the full-resolution edited view covers one
  /// screen pixel.
  double get _scaleFor100 {
    if (_fitted.width == 0) return 1;
    return _naturalSize.$1 / _devicePixelRatio / _fitted.width;
  }

  void _onZoom() {
    final zoomed = _scale > 1.01;
    if (zoomed != _zoomed) {
      // Rebuilds to switch between screen-sized and full-resolution decoding.
      setState(() => _zoomed = zoomed);
      widget.onZoomedChanged(zoomed);
    }
    if (!_wantDetail && _fitted.width > 0) {
      final (w, h) = _naturalSize;
      final previewWidth =
          w * math.min(1, OpenCvImageRenderer.previewLongEdge / math.max(w, h));
      final onScreen = _fitted.width * _scale * _devicePixelRatio;
      if (w > previewWidth && onScreen > previewWidth * 1.1) {
        setState(() => _wantDetail = true);
      }
    }
  }

  /// Double-tap: fit ↔ 100% (at least 2×), centred on the tapped point.
  void _toggleZoom() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      final s = math.max(_scaleFor100, 2.0).clamp(1.0, _maxScale);
      final p = _doubleTapAt;
      final dx = (-p.dx * (s - 1)).clamp(_box.width * (1 - s), 0.0);
      final dy = (-p.dy * (s - 1)).clamp(_box.height * (1 - s), 0.0);
      target = Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(dx, dy, 0);
    }
    _zoomTween = Matrix4Tween(begin: _zoom.value, end: target).animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeOutCubic),
    );
    _zoomAnimation.forward(from: 0);
  }

  double get _maxScale => math.max(_scaleFor100 * 2, 4.0);

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final thumb = ref.watch(thumbnailFileProvider(image));
    final preview = ref.watch(previewFileProvider(image));
    final detail = _wantDetail ? ref.watch(detailFileProvider(image)) : null;
    final showOriginal = _holding && !image.edits.isNone;
    final original = showOriginal
        ? ref.watch(previewFileProvider(image.withEdits(Edits.none)))
        : null;

    final best = detail?.value ?? preview.value ?? thumb.value;
    final failed = best == null && preview.hasError && thumb.hasError;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      onLongPressStart: (_) => setState(() => _holding = true),
      onLongPressEnd: (_) => setState(() => _holding = false),
      onLongPressCancel: () => setState(() => _holding = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _box = constraints.biggest;
          _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
          final (w, h) = _naturalSize;
          _fitted = applyBoxFit(
            BoxFit.contain,
            Size(w.toDouble(), h.toDouble()),
            _box,
          ).destination;

          return Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                transformationController: _zoom,
                minScale: 1,
                maxScale: _maxScale,
                child: Center(
                  child: SizedBox.fromSize(
                    size: _fitted,
                    child: switch ((best, failed)) {
                      (final File file, _) => _PhotoImage(
                        file: file,
                        label: 'Photo',
                        // Fitted, the screen shows fewer pixels than the
                        // preview has; decoding at screen size keeps
                        // swiping light on the GPU. Zoomed: full detail.
                        decodeWidth: _zoomed
                            ? null
                            : (_fitted.width * _devicePixelRatio).ceil(),
                      ),
                      (_, true) => const _Broken(),
                      _ => const _Loading(),
                    },
                  ),
                ),
              ),
              if (showOriginal)
                ColoredBox(
                  color: Colors.black,
                  child: switch (original?.value) {
                    final File file => _PhotoImage(
                      file: file,
                      label: 'Original photo',
                      decodeWidth: (_box.width * _devicePixelRatio).ceil(),
                    ),
                    _ => const _Loading(),
                  },
                ),
              if (showOriginal)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Center(child: _Badge('Original')),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({
    required this.file,
    required this.label,
    this.decodeWidth,
  });

  final File file;
  final String label;

  /// Decode at this width (screen pixels); null for full resolution.
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: Image.file(
      file,
      cacheWidth: decodeWidth,
      fit: BoxFit.contain,
      // Keeps showing the previous file (e.g. the thumbnail) until the new
      // one is decoded, so the swap doesn't flash.
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const _Broken(),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 28,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
    ),
  );
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.broken_image_outlined,
      color: Colors.white70,
      size: 40,
      semanticLabel: "Couldn't show this photo",
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    ),
  );
}
