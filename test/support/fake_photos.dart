import 'dart:async';
import 'dart:io';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:filbert/features/autocrop/canvas_detection.dart';
import 'package:filbert/features/photos/data/image_renderer.dart';
import 'package:filbert/features/photos/data/image_repository.dart';
import 'package:filbert/features/photos/data/pending_capture.dart';
import 'package:filbert/features/photos/data/photo_source.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/data/project_repository.dart';

import 'fake_project_repository.dart';

/// In-memory [ImageRepository] for widget tests (see
/// [FakeProjectRepository] for why). Reference pointers live on [projects].
class FakeImageRepository implements ImageRepository {
  FakeImageRepository(this.projects);

  final FakeProjectRepository projects;

  final _images = <String, ProjectImage>{};

  /// Per image: edit states and the index of the current one.
  final _history = <String, ({List<Edits> states, int cursor})>{};
  final _deleted = <String>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;
  var _clock = 0;

  /// Mutating calls made through the [ImageRepository] interface.
  final calls = <String>[];

  /// Paths whose import fails.
  final failingPaths = <String>{};

  /// Adds a live image directly, without recording a call.
  ProjectImage seed(
    String projectId, {
    bool asReference = false,
    Edits edits = Edits.none,
  }) {
    final image = _newImage(projectId, ImageOrigin.device).withEdits(edits);
    _images[image.id] = image;
    if (asReference) projects.setReference(projectId, image.id);
    _changes.add(null);
    return image;
  }

  bool isDeleted(String id) => _deleted.contains(id);

  /// The image as currently stored.
  ProjectImage byId(String id) => _images[id]!;

  /// A project's live images in the order they were added.
  List<ProjectImage> imagesOf(String projectId) => [
    for (final i in _images.values)
      if (i.projectId == projectId && !_deleted.contains(i.id)) i,
  ];

  List<ProjectImage> _live(String projectId) =>
      _images.values
          .where((i) => i.projectId == projectId && !_deleted.contains(i.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<ProjectImage>> watchForProject(String projectId) =>
      _watch(() => _live(projectId));

  @override
  Stream<Map<String, ProjectImage>> watchCovers() => _watch(() {
    final covers = <String, ProjectImage>{};
    for (final project in projects.live) {
      final images = _live(project.id);
      if (images.isNotEmpty) {
        covers[project.id] = coverOf(images, project.referenceImageId);
      }
    }
    return covers;
  });

  @override
  Future<List<ImportResult>> import(
    String projectId,
    List<PickedPhoto> photos, {
    bool asReference = false,
  }) async {
    calls.add('import $projectId ${photos.length}${asReference ? ' ref' : ''}');
    imported.addAll(photos);
    if (projects.byId(projectId) == null || projects.isDeleted(projectId)) {
      throw ProjectNotFoundException(projectId);
    }
    final results = <ImportResult>[];
    for (final photo in photos) {
      if (failingPaths.contains(photo.path)) {
        results.add(ImportFailure(photo, Exception('bad photo')));
        continue;
      }
      final image = _newImage(projectId, photo.origin);
      _images[image.id] = image;
      if (asReference) projects.setReference(projectId, image.id);
      results.add(ImportSuccess(photo, image));
    }
    _changes.add(null);
    return results;
  }

  /// Every photo given to [import], in order.
  final imported = <PickedPhoto>[];

  /// `derived_from_json` of each image saved by [importDerived], by id.
  final derivedFrom = <String, String>{};

  /// Makes the next [importDerived] fail.
  Object? failDerived;

  @override
  Future<ProjectImage> importDerived(
    String projectId,
    File file, {
    required String derivedFromJson,
  }) async {
    calls.add('importDerived $projectId');
    if (projects.byId(projectId) == null || projects.isDeleted(projectId)) {
      throw ProjectNotFoundException(projectId);
    }
    final failure = failDerived;
    if (failure != null) {
      failDerived = null;
      throw failure;
    }
    final image = _newImage(projectId, ImageOrigin.derived);
    _images[image.id] = image;
    derivedFrom[image.id] = derivedFromJson;
    _changes.add(null);
    return image;
  }

  @override
  Future<void> setEdits(String imageId, Edits edits) async {
    calls.add('setEdits $imageId');
    final image = _images[imageId]!;
    if (image.edits == edits) return;
    final h = _history[imageId];
    final kept = h == null ? [image.edits] : h.states.sublist(0, h.cursor + 1);
    _history[imageId] = (states: [...kept, edits], cursor: kept.length);
    _setImageEdits(imageId, edits);
  }

  @override
  Future<void> undo(String imageId) async {
    calls.add('undo $imageId');
    _step(imageId, -1);
  }

  @override
  Future<void> redo(String imageId) async {
    calls.add('redo $imageId');
    _step(imageId, 1);
  }

  @override
  Future<void> revert(String imageId) async {
    calls.add('revert $imageId');
    final before = calls.length;
    await setEdits(imageId, Edits.none);
    calls.removeRange(before, calls.length); // not a separate call
  }

  @override
  Stream<EditHistory> watchHistory(String imageId) => _watch(() {
    final h = _history[imageId];
    if (h == null) return EditHistory.empty;
    return EditHistory(
      canUndo: h.cursor > 0,
      canRedo: h.cursor < h.states.length - 1,
    );
  });

  void _step(String imageId, int direction) {
    final h = _history[imageId];
    if (h == null) return;
    final target = h.cursor + direction;
    if (target < 0 || target >= h.states.length) return;
    _history[imageId] = (states: h.states, cursor: target);
    _setImageEdits(imageId, h.states[target]);
  }

  void _setImageEdits(String imageId, Edits edits) {
    _images[imageId] = _images[imageId]!.withEdits(edits);
    _changes.add(null);
  }

  @override
  Future<void> setAsReference(String projectId, String? imageId) async {
    calls.add('setAsReference $projectId $imageId');
    projects.setReference(projectId, imageId);
    _changes.add(null);
  }

  @override
  Future<void> delete(String imageId) async {
    calls.add('delete $imageId');
    _deleted.add(imageId);
    _changes.add(null);
  }

  @override
  Future<void> restore(String imageId) async {
    calls.add('restore $imageId');
    _deleted.remove(imageId);
    _changes.add(null);
  }

  ProjectImage _newImage(String projectId, ImageOrigin origin) {
    final at = DateTime.utc(2026, 11, 15, 12).add(Duration(seconds: _clock++));
    return ProjectImage(
      id: 'img${_nextId++}',
      projectId: projectId,
      blobId: 'blob$_nextId',
      mimeType: 'image/jpeg',
      width: 40,
      height: 30,
      origin: origin,
      capturedAt: null,
      edits: Edits.none,
      createdAt: at,
      updatedAt: at,
      updatedByDeviceId: 'test-device',
    );
  }
}

/// Records requests and fails them at once, so tiles show their "broken"
/// state and nothing animates (which would keep `pumpAndSettle` waiting).
/// With [hang], requests never finish instead (the loading state); with
/// [file], they all return that file.
class FakeImageRenderer implements ImageRenderer {
  FakeImageRenderer({this.hang = false, this.file});

  final bool hang;
  final File? file;
  final requests = <String>[];

  @override
  Future<File> preview(ProjectImage image) =>
      _request('preview ${image.id}${image.edits.isNone ? '' : ' edited'}');

  @override
  Future<File> thumbnail(ProjectImage image, int px) =>
      _request('thumbnail ${image.id} $px');

  @override
  Future<File> detail(ProjectImage image) => _request('detail ${image.id}');

  Future<File> _request(String what) {
    requests.add(what);
    if (file != null) return Future.value(file);
    return hang
        ? Completer<File>().future
        : Future.error(UnsupportedError('FakeImageRenderer renders nothing'));
  }
}

/// Camera and picker that return queued results.
class FakePhotoSource implements PhotoSource {
  /// Next camera result; null means the user cancels.
  PickedPhoto? nextPhoto;

  /// Next picker result; empty means the user cancels.
  List<PickedPhoto> nextPicks = [];

  /// Returned once by [retrieveLost].
  List<PickedPhoto> lost = [];

  /// Called while the camera is "open", to observe what's saved meanwhile.
  FutureOr<void> Function()? whileCameraOpen;

  final calls = <String>[];

  /// False to act as macOS, which has no camera.
  @override
  bool canTakePhoto = true;

  @override
  Future<PickedPhoto?> takePhoto() async {
    calls.add('takePhoto');
    await whileCameraOpen?.call();
    return nextPhoto;
  }

  @override
  Future<List<PickedPhoto>> pickFromDevice({bool multiple = true}) async {
    calls.add('pickFromDevice multiple=$multiple');
    return nextPicks;
  }

  @override
  Future<List<PickedPhoto>> retrieveLost() async {
    calls.add('retrieveLost');
    final photos = lost;
    lost = [];
    return photos;
  }

  @override
  Future<void> clearLeftovers() async => calls.add('clearLeftovers');
}

class FakePendingCaptureStore implements PendingCaptureStore {
  PendingCapture? value;

  @override
  Future<void> save(PendingCapture capture) async => value = capture;

  @override
  Future<PendingCapture?> read() async => value;

  @override
  Future<void> clear() async => value = null;
}

PickedPhoto picked(String name, {ImageOrigin origin = ImageOrigin.device}) =>
    PickedPhoto(path: '/picked/$name', origin: origin);

/// Returns [result] (default: the stub detector's low-confidence guess), or
/// throws [error].
class FakeCanvasDetection implements CanvasDetection {
  FakeCanvasDetection({Detection? result, this.error})
    : result =
          result ??
          Detection(
            quad: Quad(const [
              Corner(0.05, 0.05),
              Corner(0.95, 0.05),
              Corner(0.95, 0.95),
              Corner(0.05, 0.95),
            ]),
            confidence: 0,
          );

  final Detection result;
  final Object? error;
  final requests = <String>[];

  @override
  Future<Detection> detect(ProjectImage image, {double? aspectHint}) async {
    requests.add('${image.id} hint=$aspectHint');
    if (error != null) throw error!;
    return result;
  }
}
