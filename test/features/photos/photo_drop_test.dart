// Drag and drop (m3-design §3.4): drops are simulated by calling the
// DropTarget's callbacks, as desktop_drop does from the native drag.

import 'package:desktop_drop/desktop_drop.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photos/ui/photo_drop.dart';
import 'package:filbert/features/projects/ui/project_list_screen.dart';
import 'package:filbert/features/projects/ui/project_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/pump_app.dart';

final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late String projectId;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    projectId = projects.seed('Still life').id;
  });

  Future<void> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      initialLocation: location,
    );
  }

  /// The drop target of the screen on top.
  DropTarget target(WidgetTester tester) =>
      tester.widget<DropTarget>(find.byType(DropTarget));

  Future<void> drop(
    WidgetTester tester,
    List<String> paths, {
    Offset at = const Offset(600, 700),
  }) async {
    target(tester).onDragDone!(
      DropDoneDetails(
        files: [for (final p in paths) DropItemFile(p)],
        localPosition: at,
        globalPosition: at,
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset referenceSlot(WidgetTester tester) =>
      tester.getCenter(find.text('Add reference'));

  test('images are JPEG, PNG and HEIC files', () {
    for (final ok in ['a.jpg', 'b.JPEG', '/x/c.png', 'd.heic', 'e.HEIF']) {
      expect(isDroppableImage(ok), isTrue, reason: ok);
    }
    for (final no in ['notes.txt', 'movie.mov', 'jpg', '/x.jpg/readme']) {
      expect(isDroppableImage(no), isFalse, reason: no);
    }
  });

  group('project screen', () {
    testWidgets('dropped images are added as photos, others ignored', (
      tester,
    ) async {
      await open(tester, Routes.project(projectId));
      await drop(tester, ['/in/one.jpg', '/in/notes.txt', '/in/two.HEIC']);
      expect(images.calls, [
        'import $projectId 1',
        'import $projectId 1',
      ], reason: 'one at a time, as Add photos');
      expect(
        [for (final p in images.imported) p.path],
        ['/in/one.jpg', '/in/two.HEIC'],
      );
      expect(
        images.imported.every((p) => !p.temporary),
        isTrue,
        reason: "the user's own files are never deleted",
      );
      expect(find.byType(ProjectScreen), findsOneWidget);
    }, variant: mac);

    testWidgets('dropping on the empty reference slot sets the reference', (
      tester,
    ) async {
      await open(tester, Routes.project(projectId));
      await drop(tester, [
        '/in/ref.png',
        '/in/other.jpg',
      ], at: referenceSlot(tester));
      expect(images.calls, ['import $projectId 1 ref']);
      expect(images.imported.single.path, '/in/ref.png');
      expect(projects.byId(projectId)!.referenceImageId, isNotNull);
    }, variant: mac);

    testWidgets('a drop with no images says so', (tester) async {
      await open(tester, Routes.project(projectId));
      await drop(tester, ['/in/notes.txt', '/in/clip.mov']);
      expect(images.calls, isEmpty);
      expect(find.text(PhotoDropTarget.notImages), findsOneWidget);
    }, variant: mac);

    testWidgets('dragging over shows what a drop will do', (tester) async {
      await open(tester, Routes.project(projectId));
      final highlight = find.byKey(const ValueKey('photo-drop-highlight'));
      expect(highlight, findsNothing);

      const below = Offset(600, 700);
      target(tester).onDragEntered!(
        DropEventDetails(localPosition: below, globalPosition: below),
      );
      await tester.pump();
      expect(highlight, findsOneWidget);
      expect(find.text('Drop to add photos'), findsOneWidget);

      final slot = referenceSlot(tester);
      target(tester).onDragUpdated!(
        DropEventDetails(localPosition: slot, globalPosition: slot),
      );
      await tester.pump();
      expect(find.text('Drop to set the reference'), findsOneWidget);

      target(tester).onDragExited!(
        DropEventDetails(localPosition: slot, globalPosition: slot),
      );
      await tester.pump();
      expect(highlight, findsNothing);
    }, variant: mac);

    testWidgets('only the screen on top takes drops', (tester) async {
      await open(tester, Routes.project(projectId));
      final all = tester.widgetList<DropTarget>(
        find.byType(DropTarget, skipOffstage: false),
      );
      expect([for (final t in all) t.enable], unorderedEquals([true, false]));
      expect(target(tester).enable, isTrue);
    }, variant: mac);

    testWidgets('phones take no drops', (tester) async {
      await open(tester, Routes.project(projectId));
      expect(target(tester).enable, isFalse);
    });
  });

  group('project list', () {
    testWidgets('a drop starts a project: a reference and photos', (
      tester,
    ) async {
      await open(tester, Routes.projectList);
      await drop(tester, ['/in/ref.jpg', '/in/a.jpg', '/in/b.png']);
      expect(projects.calls, contains('create'));
      final created = images.calls.first.split(' ')[1];
      expect(created, isNot(projectId));
      expect(images.calls, [
        'import $created 1 ref',
        'import $created 1',
        'import $created 1',
      ]);
      expect(projects.byId(created)!.referenceImageId, isNotNull);
      expect(find.byType(ProjectScreen), findsOneWidget);
      expect(find.byType(ProjectListScreen), findsNothing);
    }, variant: mac);

    testWidgets('if nothing can be added, no project is left', (tester) async {
      images.failingPaths.add('/in/bad.jpg');
      await open(tester, Routes.projectList);
      await drop(tester, ['/in/bad.jpg']);
      final created = images.calls.single.split(' ')[1];
      expect(projects.isDeleted(created), isTrue);
      expect(find.text("1 photo couldn't be added."), findsOneWidget);
      expect(find.byType(ProjectListScreen), findsOneWidget);
    }, variant: mac);
  });
}
