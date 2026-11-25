import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../photos/data/image_renderer.dart';
import '../photos/domain/project_image.dart';
import '../sync/data/blob_availability.dart';

part 'photo_files.g.dart';

/// The display render of [image] (m1-design §5.1). Keyed by the whole
/// image, so new edits give a new file; pass `image.withEdits(Edits.none)`
/// for the original.
@riverpod
Future<File> previewFile(Ref ref, ProjectImage image) async {
  final renderer = ref.watch(imageRendererProvider);
  await whenRenderable(ref, image);
  return renderer.preview(image);
}

/// The sharper render used when zoomed in past the preview's resolution.
@riverpod
Future<File> detailFile(Ref ref, ProjectImage image) async {
  final renderer = ref.watch(imageRendererProvider);
  await whenRenderable(ref, image);
  return renderer.detail(image);
}
