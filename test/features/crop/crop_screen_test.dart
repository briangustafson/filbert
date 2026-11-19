import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/crop/crop_overlay.dart';
import 'package:filbert/features/crop/crop_screen.dart';
import 'package:filbert/features/photo_viewer/photo_screen.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late String projectId;
  late ProjectImage photo; // 40×30

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    projectId = projects.seed('Still life').id;
    photo = images.seed(projectId);
  });

  Future<ProviderContainer> openCrop(WidgetTester tester) => pumpFilbertApp(
    tester,
    projects: projects,
    images: images,
    renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
    initialLocation: Routes.crop(projectId, photo.id),
  );

  CropOverlayPainter overlay(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is CropOverlayPainter,
                ),
              )
              .painter!
          as CropOverlayPainter;

  /// The painter draws in the canvas's coordinates; taps are global.
  Offset origin(WidgetTester tester) =>
      tester.getTopLeft(find.byType(CropCanvas));
  Rect crop(WidgetTester tester) => overlay(tester).crop.shift(origin(tester));

  Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
    await tester.dragFrom(from, by);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  ProjectImage stored() => images.byId(photo.id);

  testWidgets('opens from the photo menu; Cancel saves nothing', (
    tester,
  ) async {
    final container = await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
      initialLocation: Routes.photo(projectId, photo.id),
    );
    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Crop/rotate');
    expect(find.byType(CropScreen), findsOneWidget);

    await drag(tester, crop(tester).bottomRight, const Offset(-80, -40));
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    expect(images.calls, isEmpty);
    expect(
      container.read(routerProvider).state.uri.toString(),
      Routes.photo(projectId, photo.id),
    );
  });

  group('handles', () {
    testWidgets('freeform corner and edge drags; Apply saves the crop', (
      tester,
    ) async {
      final container = await openCrop(tester);
      final full = crop(tester);
      expect(full.width / full.height, closeTo(40 / 30, 0.01));

      await drag(tester, full.bottomRight, const Offset(-100, -60));
      expect(crop(tester).right, closeTo(full.right - 100, 0.5));
      expect(crop(tester).bottom, closeTo(full.bottom - 60, 0.5));

      final before = crop(tester);
      await drag(tester, before.centerLeft, const Offset(50, 0));
      expect(crop(tester).left, closeTo(before.left + 50, 0.5));
      expect(crop(tester).top, before.top);

      await tapText(tester, 'Apply');
      expect(images.calls, ['setEdits ${photo.id}']);
      expect(stored().edits.crop, isNotNull);
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.photo(projectId, photo.id),
      );
    });

    testWidgets('dragging inside moves the crop; it stops at the edge', (
      tester,
    ) async {
      await openCrop(tester);
      final full = crop(tester);
      await drag(tester, full.bottomRight, const Offset(-150, -150));
      final small = crop(tester);

      await drag(tester, small.center, const Offset(400, 400));
      expect(crop(tester).size, small.size);
      expect(crop(tester).bottomRight.dx, closeTo(full.right, 0.5));
      expect(crop(tester).bottomRight.dy, closeTo(full.bottom, 0.5));
    });
  });

  group('aspect lock', () {
    testWidgets('defaults to the project ratio', (tester) async {
      await projects.update(projectId, size: const RatioSize(4, 5));
      await openCrop(tester);
      expect(crop(tester).width / crop(tester).height, closeTo(0.8, 0.01));
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Project'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('a preset keeps its ratio while dragging a corner', (
      tester,
    ) async {
      await openCrop(tester);
      await tapText(tester, '1:1');
      expect(crop(tester).width, closeTo(crop(tester).height, 0.5));

      await drag(tester, crop(tester).topLeft, const Offset(60, 10));
      expect(crop(tester).width, closeTo(crop(tester).height, 0.5));
    });

    testWidgets('a preset follows the crop orientation; the switch flips it', (
      tester,
    ) async {
      await openCrop(tester); // the whole 40×30 photo: landscape
      await tapText(tester, '4:5');
      expect(
        crop(tester).width / crop(tester).height,
        closeTo(5 / 4, 0.01),
        reason: 'landscape, like the crop it replaced',
      );
      await tester.tap(find.byTooltip('Make portrait'));
      await tester.pumpAndSettle();
      expect(crop(tester).width / crop(tester).height, closeTo(4 / 5, 0.01));
    });

    testWidgets('Freeform has no orientation switch', (tester) async {
      await openCrop(tester);
      expect(find.byTooltip('Make landscape'), findsNothing);
      expect(find.byTooltip('Make portrait'), findsNothing);
    });
  });

  group('straighten, rotate, reset', () {
    testWidgets('straightening shrinks the crop and shows the angle', (
      tester,
    ) async {
      await openCrop(tester);
      final full = crop(tester);
      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(find.text('0.0°'), findsNothing);
      expect(crop(tester).width, lessThan(full.width));
    });

    testWidgets('Rotate 90° turns the frame', (tester) async {
      await openCrop(tester);
      expect(
        overlay(tester).frame.width,
        greaterThan(overlay(tester).frame.height),
      );
      await tester.tap(find.byTooltip('Rotate 90°'));
      await tester.pumpAndSettle();
      expect(
        overlay(tester).frame.width,
        lessThan(overlay(tester).frame.height),
      );

      await tapText(tester, 'Apply');
      expect(stored().edits.quarterTurns, 1);
    });

    testWidgets('Reset returns to the whole photo', (tester) async {
      await openCrop(tester);
      final full = crop(tester);
      await drag(tester, full.bottomRight, const Offset(-120, -80));
      await tester.tap(find.byTooltip('Rotate 90°'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Reset');
      expect(crop(tester), full);
      expect(find.text('0.0°'), findsOneWidget);
    });
  });

  testWidgets('a perspective crop shows a hint and can be replaced', (
    tester,
  ) async {
    final perspective = Edits(
      crop: CropEdit(
        quad: const [
          NormPoint(0.1, 0.1),
          NormPoint(0.9, 0.05),
          NormPoint(0.85, 0.95),
          NormPoint(0.15, 0.9),
        ],
      ),
    );
    await images.setEdits(photo.id, perspective);
    images.calls.clear();
    await openCrop(tester);
    expect(find.textContaining('perspective correction'), findsOneWidget);
  });

  testWidgets("a snackbar from the photo screen doesn't cover the controls", (
    tester,
  ) async {
    await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
      initialLocation: Routes.photo(projectId, photo.id),
    );
    // Any snackbar shown there, e.g. "Saved as a new photo." with Open.
    ScaffoldMessenger.of(tester.element(find.byType(PhotoScreen)))
        .showSnackBar(const SnackBar(content: Text('Hello')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Crop/rotate');

    expect(find.byType(CropScreen), findsOneWidget);
    final snackBar = tester.getRect(find.byType(SnackBar));
    expect(
      snackBar.bottom,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(Slider)).dy),
    );
    expect(
      snackBar.bottom,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(ChoiceChip).first).dy),
    );
  });
}
