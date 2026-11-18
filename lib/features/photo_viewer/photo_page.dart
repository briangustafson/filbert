import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/imaging/palette.dart';
import '../../core/imaging/render_geometry.dart';
import '../photos/data/image_renderer.dart';
import '../photos/domain/project_image.dart';
import '../photos/ui/image_thumbnail.dart';
import '../projects/data/project_providers.dart';
import '../projects/domain/project.dart';
import '../view_aids/data/view_aids_providers.dart';
import '../view_aids/domain/grid_layout.dart';
import '../view_aids/domain/view_prefs.dart';
import '../view_aids/domain/view_aids.dart';
import '../view_aids/ui/grid_painter.dart';
import '../view_aids/ui/shaded_image.dart';
import '../view_aids/ui/tone_shader.dart';
import 'photo_files.dart';

/// One photo on the photo screen (m1-design §3.5): the edited view fitted to
/// the screen, with pinch and double-tap zoom, and the original while held.
/// With a tone aid (Gray, Values, Colors) or Compare on, it's drawn through
/// the viewing-aid shader (m2-design §5.3); holding shows the plain
/// original.
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

  /// The last palette shown, kept while a new count's palette computes so
  /// the view doesn't drop back to the plain photo in between.
  Palette? _lastPalette;

  /// The same for the compare photo's palette, with that photo's id.
  (String, Palette)? _lastComparePalette;
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

  /// What the shader should draw, or null for the plain photo: no tone aid,
  /// or the palette isn't ready yet.
  ToneParams? _toneFor(ProjectImage image) {
    final aid = ref.watch(
      viewAidsStateProvider(image.projectId).select((a) => a.tone),
    );
    if (aid == ToneAid.none) return null;
    // Waits for the project's settings, so it never computes a palette for
    // the default count first.
    final prefs = ref.watch(viewPrefsProvider(image.projectId)).value;
    if (prefs == null) return null;
    switch (aid) {
      case ToneAid.none:
        return null;
      case ToneAid.gray:
        return const ToneParams.gray();
      case ToneAid.valueBands:
        return ToneParams.values(prefs.values.bands);
      case ToneAid.colors:
        final palette = ref
            .watch(photoPaletteProvider(image, prefs.colors.count))
            .value;
        if (palette != null) _lastPalette = palette;
        final shown = palette ?? _lastPalette;
        return shown == null ? null : ToneParams.colors(shown);
    }
  }

  /// The compare photo to blend over this one and how, or null with
  /// Compare off, no other photo, or this being the compare photo
  /// (m2-design §3.4).
  ({ProjectImage photo, CompareParams params})? _compareFor(
    ProjectImage image,
    ToneParams? tone,
  ) {
    final on = ref.watch(
      viewAidsStateProvider(image.projectId).select((a) => a.compare),
    );
    if (!on) return null;
    final prefs = ref.watch(viewPrefsProvider(image.projectId)).value;
    final other = ref.watch(compareTargetProvider(image))?.overlay;
    if (prefs == null || other == null) return null;
    Palette? palette;
    if (tone?.mode == ToneAid.colors) {
      // Each photo with its own palette; the last one while a new count
      // computes, but never another photo's.
      palette = ref
          .watch(photoPaletteProvider(other, prefs.colors.count))
          .value;
      if (palette != null) _lastComparePalette = (other.id, palette);
      palette ??= switch (_lastComparePalette) {
        (final id, final last) when id == other.id => last,
        _ => null,
      };
      if (palette == null) return null;
    }
    return (
      photo: other,
      params: CompareParams(opacity: prefs.compare.opacity, palette: palette),
    );
  }

  /// The grid to draw over the photo, or null with Grid off (m2-design
  /// §3.3).
  ({GridLayout layout, Color color, double width})? _gridFor(
    ProjectImage image,
  ) {
    final on = ref.watch(
      viewAidsStateProvider(image.projectId).select((a) => a.grid),
    );
    if (!on) return null;
    final grid = ref.watch(viewPrefsProvider(image.projectId)).value?.grid;
    if (grid == null) return null;
    final size = ref.watch(projectProvider(image.projectId)).value?.size;
    final canvas = size is PhysicalSize ? size : null;
    final (w, h) = _naturalSize;
    return (
      layout: GridLayout.of(
        grid,
        photoWidth: w.toDouble(),
        photoHeight: h.toDouble(),
        canvasWidth: canvas?.width,
        canvasHeight: canvas?.height,
        defaultSpacing: canvas == null
            ? null
            : GridPrefs.defaultSpacing(canvas.unit),
      ),
      color: Color(gridColorArgb(grid.color)),
      width: gridLineDp(grid.width),
    );
  }

  /// Where the fitted photo is on screen, following zoom.
  Rect _photoOnScreen() => MatrixUtils.transformRect(
    _zoom.value,
    Rect.fromCenter(
      center: _box.center(Offset.zero),
      width: _fitted.width,
      height: _fitted.height,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final program = ref.watch(toneProgramProvider).value;
    final tone = program == null ? null : _toneFor(image);
    final compare = program == null ? null : _compareFor(image, tone);
    final aids = tone == null && compare == null
        ? null
        : AidParams(tone ?? const ToneParams.plain(), compare: compare?.params);
    final other = compare == null
        ? null
        : ref.watch(previewFileProvider(compare.photo)).value;
    final grid = _gridFor(image);
    final thumb = ref.watch(thumbnailFileProvider(image));
    final preview = ref.watch(previewFileProvider(image));
    final detail = _wantDetail ? ref.watch(detailFileProvider(image)) : null;
    // Holding shows the plain original: unedited, without aids.
    final showOriginal =
        _holding && (!image.edits.isNone || aids != null || grid != null);
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
                        program: program,
                        aids: aids,
                        other: other,
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
              // Outside the zoom transform, so lines keep their width.
              if (grid != null && (best != null))
                IgnorePointer(
                  child: CustomPaint(
                    painter: GridPainter(
                      layout: grid.layout,
                      photoRect: _photoOnScreen,
                      color: grid.color,
                      strokeWidth: grid.width,
                      repaint: _zoom,
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
    this.program,
    this.aids,
    this.other,
  });

  final File file;
  final String label;

  /// Decode at this width (screen pixels); null for full resolution.
  final int? decodeWidth;

  /// With both, drawn through the viewing-aid shader.
  final ui.FragmentProgram? program;
  final AidParams? aids;

  /// The compare photo's preview, blended over this one.
  final File? other;

  @override
  Widget build(BuildContext context) {
    final program = this.program, aids = this.aids, other = this.other;
    if (program != null && aids != null) {
      return ShadedImage(
        // The same cache key as Image.file with cacheWidth, so switching
        // aids on and off reuses the decode.
        image: ResizeImage.resizeIfNeeded(decodeWidth, null, FileImage(file)),
        // Decoded like this photo; stretched to its frame by the shader.
        other: other == null
            ? null
            : ResizeImage.resizeIfNeeded(decodeWidth, null, FileImage(other)),
        program: program,
        params: aids,
        label: label,
      );
    }
    return _plain();
  }

  Widget _plain() => Semantics(
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
