import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../projects/data/project_repository.dart';
import '../domain/project_image.dart';
import 'image_renderer.dart';
import 'image_repository.dart';
import 'pending_capture.dart';
import 'photo_source.dart';

part 'photo_imports.g.dart';

/// Progress of an import into one project.
class ImportProgress {
  const ImportProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is ImportProgress && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'ImportProgress($done/$total)';
}

/// What adding photos did.
class AddPhotosResult {
  const AddPhotosResult({this.added = const [], this.failed = 0});

  /// Nothing was picked (the camera or picker was cancelled).
  static const cancelled = AddPhotosResult();

  final List<ProjectImage> added;
  final int failed;

  bool get isCancelled => added.isEmpty && failed == 0;
}

/// Photos added to [projectId] (possibly a project created for them).
typedef ProjectPhotosResult = ({String projectId, AddPhotosResult result});

/// Adding photos to projects (m1-design §3.2, §3.3, §3.6): camera and picker,
/// import with progress, and rendering each new photo's thumbnail and preview
/// in the background so they're ready when shown.
///
/// State: imports in progress, by project id.
@Riverpod(keepAlive: true)
class PhotoImports extends _$PhotoImports {
  @override
  Map<String, ImportProgress> build() => const {};

  PhotoSource get _source => ref.read(photoSourceProvider);
  PendingCaptureStore get _pending => ref.read(pendingCaptureStoreProvider);
  ImageRepository get _images => ref.read(imageRepositoryProvider);
  ProjectRepository get _projects => ref.read(projectRepositoryProvider);
  ImageRenderer get _renderer => ref.read(imageRendererProvider);

  /// Opens the camera and adds the photo to the project's grid, or as its
  /// reference.
  Future<AddPhotosResult> takePhoto(
    String projectId, {
    bool asReference = false,
  }) async {
    final photo = await _capture(
      CaptureForProject(projectId, asReference: asReference),
    );
    if (photo == null) return AddPhotosResult.cancelled;
    return _import(projectId, [photo], asReference: asReference);
  }

  /// Opens the photo picker: several photos for the grid, or one as the
  /// reference.
  Future<AddPhotosResult> pickFromDevice(
    String projectId, {
    bool asReference = false,
  }) async {
    final photos = await _source.pickFromDevice(multiple: !asReference);
    if (photos.isEmpty) return AddPhotosResult.cancelled;
    return _import(projectId, photos, asReference: asReference);
  }

  /// Adds dropped files (m3-design §3.4) to the project's grid, or the
  /// first as its reference.
  Future<AddPhotosResult> addDropped(
    String projectId,
    List<PickedPhoto> photos, {
    bool asReference = false,
  }) {
    if (photos.isEmpty) return Future.value(AddPhotosResult.cancelled);
    return _import(
      projectId,
      asReference ? [photos.first] : photos,
      asReference: asReference,
    );
  }

  /// Creates a project from dropped files: the first is its reference, the
  /// rest its photos (m3-design §3.4). [ProjectPhotosResult.result] has the
  /// grid photos, with the reference's failure counted. If nothing could be
  /// added, the project is deleted again.
  Future<ProjectPhotosResult> newProjectFromDropped(
    List<PickedPhoto> photos,
  ) async {
    final project = await _projects.create();
    final reference = await _import(project.id, [
      photos.first,
    ], asReference: true);
    final rest = photos.length == 1
        ? AddPhotosResult.cancelled
        : await _import(project.id, photos.sublist(1));
    if (reference.added.isEmpty && rest.added.isEmpty) {
      await _projects.delete(project.id);
    }
    return (
      projectId: project.id,
      result: AddPhotosResult(
        added: rest.added,
        failed: reference.failed + rest.failed,
      ),
    );
  }

  /// Opens the camera; on success creates a project with the photo in its
  /// grid. Null if cancelled. If the photo can't be added, the new project
  /// is deleted again and the result reports the failure.
  Future<ProjectPhotosResult?> takePhotoForNewProject() async {
    final photo = await _capture(const CaptureForNewProject());
    if (photo == null) return null;
    return _importIntoNewProject([photo]);
  }

  /// Imports photos from a camera session that finished after Android
  /// killed the app, into the project they were taken for (or a new project
  /// if that is gone). Null if there were none. Call once on start-up.
  Future<ProjectPhotosResult?> recoverLostPhotos() async {
    final photos = await _source.retrieveLost();
    final pending = await _pending.read();
    await _pending.clear();
    if (photos.isEmpty) return null;

    if (pending is CaptureForProject &&
        await _projects.watch(pending.projectId).first != null) {
      final result = await _import(
        pending.projectId,
        photos,
        asReference: pending.asReference && photos.length == 1,
      );
      return (projectId: pending.projectId, result: result);
    }
    return _importIntoNewProject(photos);
  }

  Future<PickedPhoto?> _capture(PendingCapture target) async {
    // Saved first: if Android kills the app while the camera is open, the
    // photo is recovered on the next launch and goes to the same place.
    await _pending.save(target);
    try {
      return await _source.takePhoto();
    } finally {
      await _pending.clear();
    }
  }

  Future<ProjectPhotosResult> _importIntoNewProject(
    List<PickedPhoto> photos,
  ) async {
    final project = await _projects.create();
    final result = await _import(project.id, photos);
    if (result.added.isEmpty) await _projects.delete(project.id);
    return (projectId: project.id, result: result);
  }

  Future<AddPhotosResult> _import(
    String projectId,
    List<PickedPhoto> photos, {
    bool asReference = false,
  }) async {
    final added = <ProjectImage>[];
    var failed = 0;
    _setProgress(projectId, ImportProgress(done: 0, total: photos.length));
    try {
      // One at a time, so progress and thumbnails appear as each one lands.
      for (final photo in photos) {
        try {
          final [result] = await _images.import(projectId, [
            photo,
          ], asReference: asReference);
          switch (result) {
            case ImportSuccess(:final image):
              added.add(image);
              _prerender(_renderer.thumbnail(image, standardThumbnailPx));
            case ImportFailure(:final error):
              failed++;
              debugPrint('Import failed: $error');
          }
        } on ProjectNotFoundException {
          // The project was deleted meanwhile; the rest can't be added.
          failed = photos.length - added.length;
          break;
        }
        _setProgress(
          projectId,
          ImportProgress(done: added.length + failed, total: photos.length),
        );
      }
    } finally {
      _setProgress(projectId, null);
    }
    // Previews after all thumbnails: the renderer runs a few at a time.
    for (final image in added) {
      _prerender(_renderer.preview(image));
    }
    return AddPhotosResult(added: added, failed: failed);
  }

  void _prerender(Future<Object?> render) {
    unawaited(
      render.then<void>(
        (_) {},
        onError: (Object e) => debugPrint('Background render failed: $e'),
      ),
    );
  }

  void _setProgress(String projectId, ImportProgress? progress) {
    state = {
      for (final MapEntry(:key, :value) in state.entries)
        if (key != projectId) key: value,
      projectId: ?progress,
    };
  }
}
