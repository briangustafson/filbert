import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/image_renderer.dart';
import '../domain/project_image.dart';

part 'image_thumbnail.g.dart';

/// The cached thumbnail file of [image]'s edited view, rendering it if
/// needed. Keyed by the whole image, so new edits give a new thumbnail.
@riverpod
Future<File> thumbnailFile(Ref ref, ProjectImage image) =>
    ref.watch(imageRendererProvider).thumbnail(image, standardThumbnailPx);

/// [image]'s edited view, filling its box (cropped to cover). Shows a
/// placeholder while the thumbnail renders.
class ImageThumbnail extends ConsumerWidget {
  const ImageThumbnail({super.key, required this.image});

  final ProjectImage image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final file = ref.watch(thumbnailFileProvider(image));
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: switch (file) {
        AsyncData(:final value) => Image.file(
          value,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const _Broken(),
        ),
        AsyncError() => const _Broken(),
        _ => const Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      },
    );
  }
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.broken_image_outlined,
      semanticLabel: "Couldn't show this photo",
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
