import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photos/data/pending_capture.dart';
import 'package:filbert/features/photos/ui/image_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakePhotoSource source;
  late String projectId;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    source = FakePhotoSource();
    projectId = projects.seed('Still life').id;
  });

  Future<void> pumpProject(WidgetTester tester) async {
    await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      photoSource: source,
      initialLocation: Routes.project(projectId),
    );
    source.calls.clear(); // start-up's retrieveLost / clearLeftovers
  }

  Finder labelled(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );
  Finder referenceTile() => labelled('Reference photo');
  Finder gridTiles() => labelled('Photo');

  Future<void> chooseInSheet(WidgetTester tester, String option) async {
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  group('reference slot', () {
    testWidgets('empty: Add reference takes a photo as the reference', (
      tester,
    ) async {
      source.nextPhoto = picked('ref.jpg');
      await pumpProject(tester);
      expect(referenceTile(), findsNothing);

      await tester.tap(find.text('Add reference'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, 'Take photo');

      expect(images.calls, ['import $projectId 1 ref']);
      expect(referenceTile(), findsOneWidget);
      expect(
        gridTiles(),
        findsNothing,
        reason: 'the reference is not in the grid',
      );
    });

    testWidgets('choosing a reference from the device picks one photo', (
      tester,
    ) async {
      source.nextPicks = [picked('ref.jpg')];
      await pumpProject(tester);
      await tester.tap(find.text('Add reference'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, 'Choose from device');
      expect(source.calls, ['pickFromDevice multiple=false']);
      expect(referenceTile(), findsOneWidget);
    });

    testWidgets('Remove keeps the image, which moves to the grid', (
      tester,
    ) async {
      final ref = images.seed(projectId, asReference: true);
      await pumpProject(tester);
      expect(referenceTile(), findsOneWidget);

      await tester.tap(find.byTooltip('Reference options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(images.calls, ['setAsReference $projectId null']);
      expect(images.isDeleted(ref.id), isFalse);
      expect(referenceTile(), findsNothing);
      expect(find.text('Add reference'), findsOneWidget);
      expect(gridTiles(), findsOneWidget);
    });

    testWidgets('Replace adds a new reference; the old one joins the grid', (
      tester,
    ) async {
      images.seed(projectId, asReference: true);
      source.nextPhoto = picked('new.jpg');
      await pumpProject(tester);

      await tester.tap(find.byTooltip('Reference options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.text('Add reference'), findsOneWidget, reason: 'sheet title');
      await chooseInSheet(tester, 'Take photo');

      expect(images.calls, ['import $projectId 1 ref']);
      expect(referenceTile(), findsOneWidget);
      // The grid is below the reference; scroll so it's built.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(gridTiles(), findsOneWidget);
    });

    testWidgets('a deleted reference shows an empty slot', (tester) async {
      final ref = images.seed(projectId, asReference: true);
      await images.delete(ref.id);
      await pumpProject(tester);
      expect(referenceTile(), findsNothing);
      expect(find.text('Add reference'), findsOneWidget);
      expect(projects.byId(projectId)!.referenceImageId, ref.id);
    });

    testWidgets('tapping the reference opens the photo screen', (tester) async {
      final ref = images.seed(projectId, asReference: true);
      final container = await pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        initialLocation: Routes.project(projectId),
      );
      await tester.tap(referenceTile());
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.photo(projectId, ref.id),
      );
    });
  });

  group('photo grid', () {
    testWidgets('empty state, then Add photo picks several', (tester) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await pumpProject(tester);
      expect(find.textContaining('No photos yet'), findsOneWidget);

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      expect(find.text('Add photos'), findsOneWidget, reason: 'sheet title');
      await chooseInSheet(tester, 'Choose from device');

      expect(source.calls, ['pickFromDevice multiple=true']);
      expect(gridTiles(), findsNWidgets(2));
      expect(find.textContaining('No photos yet'), findsNothing);
      expect(find.byType(ImageThumbnail), findsNWidgets(2));
    });

    testWidgets('failures are reported', (tester) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg'), picked('c.jpg')];
      images.failingPaths.addAll(['/picked/a.jpg', '/picked/c.jpg']);
      await pumpProject(tester);
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, 'Choose from device');
      expect(find.text("2 photos couldn't be added."), findsOneWidget);
      expect(gridTiles(), findsOneWidget);
    });

    testWidgets('cancelling the camera changes nothing', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, 'Take photo');
      expect(source.calls, ['takePhoto']);
      expect(images.calls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('newest first; tapping a photo opens it', (tester) async {
      final older = images.seed(projectId);
      final newer = images.seed(projectId);
      final container = await pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        initialLocation: Routes.project(projectId),
      );
      final tiles = tester.widgetList<ImageThumbnail>(
        find.byType(ImageThumbnail),
      );
      expect([for (final t in tiles) t.image.id], [newer.id, older.id]);

      await tester.tap(gridTiles().last);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.photo(projectId, older.id),
      );
    });
  });

  group('project list', () {
    Future<dynamic> pumpList(WidgetTester tester) async {
      final container = await pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        photoSource: source,
      );
      source.calls.clear(); // start-up's retrieveLost / clearLeftovers
      return container;
    }

    testWidgets('Take photo: a new project with the photo, opened', (
      tester,
    ) async {
      source.nextPhoto = picked('a.jpg');
      final container = await pumpList(tester);
      await tester.tap(find.byTooltip('Take photo'));
      await tester.pumpAndSettle();

      expect(projects.calls, ['create']);
      final created = projects.live.firstWhere((p) => p.id != projectId);
      expect(images.calls, ['import ${created.id} 1']);
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.project(created.id),
      );
      expect(gridTiles(), findsOneWidget);
    });

    testWidgets('Take photo cancelled: no project', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byTooltip('Take photo'));
      await tester.pumpAndSettle();
      expect(projects.calls, isEmpty);
      expect(find.text('Projects'), findsOneWidget);
    });

    testWidgets('cards show the cover photo, or a placeholder', (tester) async {
      projects.seed('No photos');
      final cover = images.seed(projectId);
      await pumpList(tester);
      final thumbs = tester.widgetList<ImageThumbnail>(
        find.byType(ImageThumbnail),
      );
      expect([for (final t in thumbs) t.image.id], [cover.id]);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('empty state explains both actions', (tester) async {
      await pumpFilbertApp(tester);
      expect(find.text('Tap New project to start one.'), findsOneWidget);
      expect(
        find.text('Or take a photo to start a project with it.'),
        findsOneWidget,
      );
    });
  });

  group('start-up', () {
    testWidgets('recovers a lost photo, then clears picker leftovers', (
      tester,
    ) async {
      final pending = FakePendingCaptureStore()
        ..value = CaptureForProject(projectId);
      source.lost = [picked('lost.jpg')];
      final container = await pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        photoSource: source,
        pendingCapture: pending,
      );

      expect(source.calls, ['retrieveLost', 'clearLeftovers']);
      expect(images.calls, ['import $projectId 1']);
      expect(find.text('Added the photo you took.'), findsOneWidget);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.project(projectId),
      );
    });

    testWidgets('nothing lost: no message', (tester) async {
      await pumpFilbertApp(tester, photoSource: source);
      expect(source.calls, ['retrieveLost', 'clearLeftovers']);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
