import 'package:filbert/app/app.dart';
import 'package:filbert/app/router.dart';
import 'package:filbert/core/units/unit_preference.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filbert/features/autocrop/canvas_detection.dart';
import 'package:filbert/features/photos/data/image_renderer.dart';
import 'package:filbert/features/photos/data/image_repository.dart';
import 'package:filbert/features/photos/data/pending_capture.dart';
import 'package:filbert/features/photos/data/photo_source.dart';

import 'fake_photos.dart';
import 'fake_project_repository.dart';

/// Pumps the whole app with in-memory fakes and returns its container.
Future<ProviderContainer> pumpFilbertApp(
  WidgetTester tester, {
  FakeProjectRepository? projects,
  FakeImageRepository? images,
  FakeImageRenderer? renderer,
  FakePhotoSource? photoSource,
  FakePendingCaptureStore? pendingCapture,
  FakeCanvasDetection? detection,
  LengthUnit preferredUnit = LengthUnit.inches,
  String? initialLocation,
}) async {
  projects ??= FakeProjectRepository();
  final container = ProviderContainer(
    overrides: [
      projectRepositoryProvider.overrideWithValue(projects),
      imageRepositoryProvider.overrideWithValue(
        images ?? FakeImageRepository(projects),
      ),
      imageRendererProvider.overrideWithValue(renderer ?? FakeImageRenderer()),
      photoSourceProvider.overrideWithValue(photoSource ?? FakePhotoSource()),
      pendingCaptureStoreProvider.overrideWithValue(
        pendingCapture ?? FakePendingCaptureStore(),
      ),
      canvasDetectionProvider.overrideWithValue(
        detection ?? FakeCanvasDetection(),
      ),
      preferredLengthUnitProvider.overrideWithValue(preferredUnit),
    ],
  );
  if (initialLocation != null) {
    container.read(routerProvider).go(initialLocation);
  }
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FilbertApp()),
  );
  await tester.pumpAndSettle();
  return container;
}
