import 'package:filbert/features/photos/data/image_renderer.dart';
import 'package:filbert/features/photos/data/image_repository.dart';
import 'package:filbert/features/photos/data/pending_capture.dart';
import 'package:filbert/features/photos/data/photo_imports.dart';
import 'package:filbert/features/photos/data/photo_source.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakeImageRenderer renderer;
  late FakePhotoSource source;
  late FakePendingCaptureStore pending;
  late ProviderContainer container;
  late PhotoImports imports;
  late String projectId;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    renderer = FakeImageRenderer();
    source = FakePhotoSource();
    pending = FakePendingCaptureStore();
    container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(projects),
        imageRepositoryProvider.overrideWithValue(images),
        imageRendererProvider.overrideWithValue(renderer),
        photoSourceProvider.overrideWithValue(source),
        pendingCaptureStoreProvider.overrideWithValue(pending),
      ],
    );
    addTearDown(container.dispose);
    imports = container.read(photoImportsProvider.notifier);
    projectId = projects.seed('Still life').id;
  });

  group('takePhoto', () {
    test('remembers the target while the camera is open', () async {
      PendingCapture? duringCamera;
      source
        ..nextPhoto = picked('a.jpg')
        ..whileCameraOpen = () => duringCamera = pending.value;

      final result = await imports.takePhoto(projectId, asReference: true);

      expect(duringCamera, CaptureForProject(projectId, asReference: true));
      expect(pending.value, isNull, reason: 'cleared afterwards');
      expect(result.added, hasLength(1));
      expect(images.calls, ['import $projectId 1 ref']);
      expect(
        projects.byId(projectId)!.referenceImageId,
        result.added.single.id,
      );
    });

    test('cancelling imports nothing and clears the target', () async {
      final result = await imports.takePhoto(projectId);
      expect(result.isCancelled, isTrue);
      expect(images.calls, isEmpty);
      expect(pending.value, isNull);
    });
  });

  group('pickFromDevice', () {
    test('several for the grid, one at a time, with progress', () async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg'), picked('c.jpg')];
      images.failingPaths.add('/picked/b.jpg');
      final progress = <ImportProgress?>[];
      container.listen(
        photoImportsProvider.select((s) => s[projectId]),
        (_, next) => progress.add(next),
      );

      final result = await imports.pickFromDevice(projectId);

      expect(source.calls, ['pickFromDevice multiple=true']);
      expect(images.calls, List.filled(3, 'import $projectId 1'));
      expect(result.added, hasLength(2));
      expect(result.failed, 1);
      expect(progress, [
        const ImportProgress(done: 0, total: 3),
        const ImportProgress(done: 1, total: 3),
        const ImportProgress(done: 2, total: 3),
        const ImportProgress(done: 3, total: 3),
        null,
      ]);
    });

    test('a reference is picked alone', () async {
      source.nextPicks = [picked('a.jpg')];
      await imports.pickFromDevice(projectId, asReference: true);
      expect(source.calls, ['pickFromDevice multiple=false']);
      expect(images.calls, ['import $projectId 1 ref']);
    });

    test('cancelling imports nothing', () async {
      final result = await imports.pickFromDevice(projectId);
      expect(result.isCancelled, isTrue);
      expect(images.calls, isEmpty);
      expect(container.read(photoImportsProvider), isEmpty);
    });

    test('renders thumbnails as photos land, previews after', () async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      final result = await imports.pickFromDevice(projectId);
      final [a, b] = result.added;
      expect(renderer.requests, [
        'thumbnail ${a.id} $standardThumbnailPx',
        'thumbnail ${b.id} $standardThumbnailPx',
        'preview ${a.id}',
        'preview ${b.id}',
      ]);
    });

    test('a project deleted meanwhile fails the rest', () async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await projects.delete(projectId);
      final result = await imports.pickFromDevice(projectId);
      expect(result.added, isEmpty);
      expect(result.failed, 2);
      expect(container.read(photoImportsProvider), isEmpty);
    });
  });

  group('takePhotoForNewProject', () {
    test('cancelling creates no project', () async {
      expect(await imports.takePhotoForNewProject(), isNull);
      expect(projects.calls, isEmpty);
    });

    test('creates a project with the photo in its grid', () async {
      PendingCapture? duringCamera;
      source
        ..nextPhoto = picked('a.jpg', origin: ImageOrigin.camera)
        ..whileCameraOpen = () => duringCamera = pending.value;

      final created = await imports.takePhotoForNewProject();

      expect(duringCamera, const CaptureForNewProject());
      expect(source.calls.first, 'takePhoto', reason: 'camera first');
      expect(projects.calls, ['create']);
      expect(created!.result.added, hasLength(1));
      expect(images.calls, ['import ${created.projectId} 1']);
      expect(projects.byId(created.projectId)!.referenceImageId, isNull);
    });

    test('a photo that fails to import leaves no project', () async {
      source.nextPhoto = picked('bad.jpg');
      images.failingPaths.add('/picked/bad.jpg');
      final created = await imports.takePhotoForNewProject();
      expect(created!.result.failed, 1);
      expect(projects.isDeleted(created.projectId), isTrue);
    });
  });

  group('recoverLostPhotos', () {
    test('nothing lost: nothing happens, stale target cleared', () async {
      pending.value = CaptureForProject(projectId);
      expect(await imports.recoverLostPhotos(), isNull);
      expect(pending.value, isNull);
      expect(images.calls, isEmpty);
    });

    test('goes to the project and slot it was taken for', () async {
      pending.value = CaptureForProject(projectId, asReference: true);
      source.lost = [picked('a.jpg', origin: ImageOrigin.camera)];

      final recovered = await imports.recoverLostPhotos();

      expect(recovered!.projectId, projectId);
      expect(images.calls, ['import $projectId 1 ref']);
      expect(pending.value, isNull);
    });

    test('a new project if that is what it was for, or it is gone', () async {
      pending.value = const CaptureForNewProject();
      source.lost = [picked('a.jpg')];
      final first = await imports.recoverLostPhotos();
      expect(first!.projectId, isNot(projectId));

      await projects.delete(projectId);
      pending.value = CaptureForProject(projectId);
      source.lost = [picked('b.jpg')];
      final second = await imports.recoverLostPhotos();
      expect(second!.projectId, isNot(projectId));
      expect(second.result.added, hasLength(1));
    });

    test('no saved target: a new project', () async {
      source.lost = [picked('a.jpg')];
      final recovered = await imports.recoverLostPhotos();
      expect(recovered!.projectId, isNot(projectId));
      expect(projects.calls, ['create']);
    });
  });
}
