import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'tone_shader.dart';

/// [image] drawn through the viewing-aid shader with [params], filling its
/// box (m2-design §5.3), with [other] blended over it when
/// [AidParams.compare] is set (§3.4). Used by the photo page in place of a
/// plain `Image` while a tone aid or Compare is on, so zoom and the detail
/// render work the same.
///
/// Like `Image` with gapless playback, it keeps drawing the previous image
/// until a new one has decoded, and shows nothing before the first. Until
/// [other] has decoded, the photo is drawn without the blend.
class ShadedImage extends StatefulWidget {
  const ShadedImage({
    super.key,
    required this.image,
    this.other,
    required this.program,
    required this.params,
    required this.label,
  });

  /// What to draw: decoded through Flutter's image cache, so the plain view
  /// and this one share decodes.
  final ImageProvider image;

  /// The compare photo, stretched to [image]'s frame.
  final ImageProvider? other;
  final ui.FragmentProgram program;
  final AidParams params;
  final String label;

  @override
  State<ShadedImage> createState() => _ShadedImageState();
}

class _ShadedImageState extends State<ShadedImage> {
  late final _image = _Decoded(_changed);
  late final _other = _Decoded(_changed);
  late ui.FragmentShader _shader = widget.program.fragmentShader();

  void _changed() => setState(() {});

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
    _resolve();
  }

  void _resolve() {
    final config = createLocalImageConfiguration(context);
    _image.resolve(widget.image, config);
    _other.resolve(widget.other, config);
  }

  @override
  void dispose() {
    _image.dispose();
    _other.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image.image;
    final other = widget.other == null ? null : _other.image;
    final params = other == null && widget.params.compare != null
        ? AidParams(widget.params.tone)
        : widget.params;
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
                other: params.compare == null ? null : other,
                params: params,
              ),
            ),
    );
  }
}

/// One decoded image from an [ImageProvider], kept until the next one has
/// decoded.
class _Decoded {
  _Decoded(this._onChanged);

  final VoidCallback _onChanged;
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    // The plain image path shows decode errors; here, keep what's shown.
    onError: (_, _) {},
  );

  ui.Image? get image => _info?.image;

  void resolve(ImageProvider? provider, ImageConfiguration config) {
    if (provider == null) {
      _stream?.removeListener(_listener);
      _stream = null;
      return;
    }
    final stream = provider.resolve(config);
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    _info?.dispose();
    _info = info;
    _onChanged();
  }

  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter({
    required this.shader,
    required this.image,
    required this.other,
    required this.params,
  });

  final ui.FragmentShader shader;
  final ui.Image image;
  final ui.Image? other;
  final AidParams params;

  @override
  void paint(Canvas canvas, Size size) {
    params.applyTo(shader, size);
    shader.setImageSampler(0, image);
    // Every sampler needs an image; without compare it isn't read.
    shader.setImageSampler(1, other ?? image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.image != image ||
      old.other != other ||
      old.params != params ||
      old.shader != shader;
}
