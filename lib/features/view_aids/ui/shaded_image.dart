import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'tone_shader.dart';

/// [image] drawn through the viewing-aid shader with [params], filling its
/// box (m2-design §5.3). Used by the photo page in place of a plain
/// `Image` while a tone aid is on, so zoom and the detail render work the
/// same.
///
/// Like `Image` with gapless playback, it keeps drawing the previous image
/// until a new [image] has decoded, and shows nothing before the first.
class ShadedImage extends StatefulWidget {
  const ShadedImage({
    super.key,
    required this.image,
    required this.program,
    required this.params,
    required this.label,
  });

  /// What to draw: decoded through Flutter's image cache, so the plain view
  /// and this one share decodes.
  final ImageProvider image;
  final ui.FragmentProgram program;
  final ToneParams params;
  final String label;

  @override
  State<ShadedImage> createState() => _ShadedImageState();
}

class _ShadedImageState extends State<ShadedImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    // The plain image path shows decode errors; here, keep what's shown.
    onError: (_, _) {},
  );
  late ui.FragmentShader _shader = widget.program.fragmentShader();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ShadedImage old) {
    super.didUpdateWidget(old);
    if (old.program != widget.program) {
      _shader.dispose();
      _shader = widget.program.fragmentShader();
    }
    if (old.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _info?.image;
    return Semantics(
      label: widget.label,
      image: true,
      child: image == null
          ? const SizedBox.expand()
          : CustomPaint(
              size: Size.infinite,
              painter: _ShaderPainter(
                shader: _shader,
                image: image,
                params: widget.params,
              ),
            ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter({
    required this.shader,
    required this.image,
    required this.params,
  });

  final ui.FragmentShader shader;
  final ui.Image image;
  final ToneParams params;

  @override
  void paint(Canvas canvas, Size size) {
    params.applyTo(shader, size);
    shader.setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.image != image || old.params != params || old.shader != shader;
}
