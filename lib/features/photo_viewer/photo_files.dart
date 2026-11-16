import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../photos/data/image_renderer.dart';
import '../photos/domain/project_image.dart';

part 'photo_files.g.dart';

/// The display render of [image] (m1-design §5.1). Keyed by the whole
/// image, so new edits give a new file; pass `image.withEdits(Edits.none)`
/// for the original.
@riverpod
Future<File> previewFile(Ref ref, ProjectImage image) =>
    ref.watch(imageRendererProvider).preview(image);

/// The sharper render used when zoomed in past the preview's resolution.
@riverpod
Future<File> detailFile(Ref ref, ProjectImage image) =>
    ref.watch(imageRendererProvider).detail(image);
