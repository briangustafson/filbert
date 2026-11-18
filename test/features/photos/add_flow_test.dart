import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/core/settings/app_settings.dart';
import 'package:filbert/features/autocrop/autocrop_review_screen.dart';
import 'package:filbert/features/autocrop/review_queue.dart';
import 'package:filbert/features/crop/crop_screen.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings.dart';
import '../../support/pump_app.dart';

/// What opens after adding photos (m1-design §3.6).
void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakePhotoSource source;
  late String projectId;
  late ProviderContainer container;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    source = FakePhotoSource();
    projectId = projects.seed('Still life').id;
  });

  Future<void> pumpProject(
    WidgetTester tester, {
    bool autoCropOnAdd = true,
  }) async {
    container = await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      photoSource: source,
      settings: FakeSettingsStore(AppSettings(autoCropOnAdd: autoCropOnAdd)),
      initialLocation: Routes.project(projectId),
    );
  }

  String location() => container
      .read(routerProvider)
      .routeInformationProvider
      .value
      .uri
      .toString();

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> addFromDevice(WidgetTester tester, String button) async {
    await tapText(tester, button);
    await tapText(tester, 'Choose from device');
  }

  List<String> gridIds() => [
    for (final image in images.imagesOf(projectId)) image.id,
  ];

  group('grid photos', () {
    testWidgets('are reviewed in turn: Skip and Apply move on', (tester) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg'), picked('c.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add photo');

      final ids = gridIds();
      expect(find.byType(AutocropReviewScreen), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(location(), contains('/images/${ids[0]}/autocrop'));

      await tapText(tester, 'Skip');
      expect(find.text('2 of 3'), findsOneWidget);
      expect(location(), contains('/images/${ids[1]}/autocrop'));

      images.calls.clear();
      await tapText(tester, 'Apply');
      expect(images.calls, ['setEdits ${ids[1]}']);
      expect(find.text('3 of 3'), findsOneWidget);

      await tapText(tester, 'Skip');
      expect(find.byType(AutocropReviewScreen), findsNothing);
      expect(location(), Routes.project(projectId));
    });

    testWidgets('Crop manually carries on with the queue', (tester) async {
      await projects.update(projectId, size: const RatioSize(4, 5));
      source.nextPicks = [picked('a.jpg'), picked('b.jpg'), picked('c.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add photo');
      final ids = gridIds();

      // Manual crop, then Apply: on to the next photo's review.
      await tapText(tester, 'Crop manually');
      expect(find.byType(CropScreen), findsOneWidget);
      expect(location(), contains('/images/${ids[0]}/crop'));
      expect(find.text('Skip'), findsOneWidget);
      images.calls.clear();
      await tapText(tester, 'Apply');
      expect(images.calls, ['setEdits ${ids[0]}']);
      expect(find.byType(AutocropReviewScreen), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);

      // Skip in manual crop also moves on; on the last photo, to the project.
      await tapText(tester, 'Crop manually');
      await tapText(tester, 'Skip');
      expect(find.text('3 of 3'), findsOneWidget);
      await tapText(tester, 'Crop manually');
      await tapText(tester, 'Apply');
      expect(location(), Routes.project(projectId));
    });

    testWidgets('Cancel in manual crop ends the queue', (tester) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add photo');
      await tapText(tester, 'Crop manually');
      images.calls.clear();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(location(), Routes.project(projectId));
      expect(images.calls, isEmpty);
    });

    testWidgets('Cancel ends the queue, leaving the rest uncropped', (
      tester,
    ) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add photo');
      images.calls.clear();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(location(), Routes.project(projectId));
      expect(images.calls, isEmpty);
    });

    testWidgets('back ends the queue too', (tester) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add photo');
      await tapText(tester, 'Skip');
      expect(find.text('2 of 2'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(location(), Routes.project(projectId));
    });

    testWidgets('one photo: Skip but no counter', (tester) async {
      source.nextPicks = [picked('a.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add photo');
      expect(find.byType(AutocropReviewScreen), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('1 of 1'), findsNothing);
    });

    testWidgets('nothing opens with "Auto-crop photos when added" off', (
      tester,
    ) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await pumpProject(tester, autoCropOnAdd: false);
      await addFromDevice(tester, 'Add photo');
      expect(find.byType(AutocropReviewScreen), findsNothing);
      expect(location(), Routes.project(projectId));
    });

    testWidgets('a photo taken for a new project is reviewed', (tester) async {
      source.nextPhoto = picked('new.jpg');
      container = await pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        photoSource: source,
        settings: FakeSettingsStore(),
      );
      await tester.tap(find.byTooltip('Take photo'));
      await tester.pumpAndSettle();
      expect(find.byType(AutocropReviewScreen), findsOneWidget);
      await tapText(tester, 'Skip');
      expect(location(), startsWith('/projects/'));
      expect(location(), isNot(contains('/images/')));
    });
  });

  group('without a camera (macOS)', () {
    setUp(() => source.canTakePhoto = false);

    testWidgets('no Take photo on the project list', (tester) async {
      container = await pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        photoSource: source,
        settings: FakeSettingsStore(),
      );
      expect(find.byTooltip('Take photo'), findsNothing);
      expect(find.text('New project'), findsOneWidget);
    });

    testWidgets('Add photos opens the picker directly', (tester) async {
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await pumpProject(tester, autoCropOnAdd: false);
      await tapText(tester, 'Add photo');
      expect(find.text('Take photo'), findsNothing);
      expect(source.calls.last, 'pickFromDevice multiple=true');
      expect(images.imagesOf(projectId), hasLength(2));
    });

    testWidgets('so does Add reference', (tester) async {
      source.nextPicks = [picked('ref.jpg')];
      await pumpProject(tester);
      await tapText(tester, 'Add reference');
      expect(source.calls.last, 'pickFromDevice multiple=false');
    });
  });

  group('a new reference', () {
    testWidgets('opens manual crop when the project has a size', (
      tester,
    ) async {
      await projects.update(projectId, size: const RatioSize(4, 5));
      source.nextPicks = [picked('ref.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add reference');

      expect(find.byType(CropScreen), findsOneWidget);
      expect(find.byType(AutocropReviewScreen), findsNothing);
      await tapText(tester, 'Skip');
      expect(location(), Routes.project(projectId));
    });

    testWidgets('opens nothing without a size', (tester) async {
      source.nextPicks = [picked('ref.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add reference');
      expect(find.byType(CropScreen), findsNothing);
      expect(location(), Routes.project(projectId));
    });
  });

  // The top bars once pushed Apply off a 320 dp screen (the CI emulator).
  // The test font (Ahem: every glyph a full square) is far wider than real
  // fonts, so 400 dp here is tighter than 320 dp on a phone; without the fix
  // these overflow.
  group('on a narrow phone, every button fits', () {
    void narrow(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('the review queue', (tester) async {
      narrow(tester);
      source.nextPicks = [picked('a.jpg'), picked('b.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add photo');
      expect(find.byType(AutocropReviewScreen), findsOneWidget);
      for (final label in ['Full image', 'Reset', 'Crop manually']) {
        expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull, reason: 'no overflow');
      await tapText(tester, 'Apply');
      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('manual crop after adding a reference', (tester) async {
      narrow(tester);
      await projects.update(projectId, size: const RatioSize(4, 5));
      source.nextPicks = [picked('ref.jpg')];
      await pumpProject(tester);
      await addFromDevice(tester, 'Add reference');
      expect(find.byType(CropScreen), findsOneWidget);
      await tapText(tester, 'Apply');
      expect(location(), Routes.project(projectId));
    });
  });

  test('the queue survives the route', () {
    const queue = ReviewQueue(remaining: ['b', 'c'], total: 3);
    expect(queue.position, 1);
    expect(ReviewQueue.fromQuery(queue.toQuery()), queue);
    expect(queue.advanced, const ReviewQueue(remaining: ['c'], total: 3));
    expect(queue.advanced.advanced.isLast, isTrue);
    expect(ReviewQueue.fromQuery(const {}), isNull);
    expect(ReviewQueue.fromQuery(const {'queue': 'a,b', 'of': '2'}), isNull);
    expect(Uri.parse(Routes.autocrop('p', 'a', queue: queue)).queryParameters, {
      'queue': 'b,c',
      'of': '3',
    });
    expect(Uri.parse(Routes.crop('p', 'a', queue: queue)).queryParameters, {
      'queue': 'b,c',
      'of': '3',
    });
    expect(Routes.crop('p', 'a'), '/projects/p/images/a/crop');
  });
}
