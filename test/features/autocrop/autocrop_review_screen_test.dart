import 'dart:convert';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/autocrop/autocrop_review_screen.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:flutter/services.dart';
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

  final confident = Detection(
    quad: Quad(const [
      Corner(0.2, 0.1),
      Corner(0.8, 0.15),
      Corner(0.75, 0.9),
      Corner(0.25, 0.85),
    ]),
    confidence: 0.9,
  );

  Future<ProviderContainer> openReview(
    WidgetTester tester, {
    FakeCanvasDetection? detection,
  }) => pumpFilbertApp(
    tester,
    projects: projects,
    images: images,
    renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
    detection: detection,
    initialLocation: Routes.autocrop(projectId, photo.id),
  );

  ReviewOverlayPainter overlay(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is ReviewOverlayPainter,
                ),
              )
              .painter!
          as ReviewOverlayPainter;

  /// Corner positions on screen (the painter draws in canvas coordinates).
  List<Offset> corners(WidgetTester tester) {
    final origin = tester.getTopLeft(find.byType(ReviewCanvas));
    return [for (final c in overlay(tester).corners) c + origin];
  }

  /// The photo's frame on screen.
  Rect frame(WidgetTester tester) {
    final image = find.descendant(
      of: find.byType(ReviewCanvas),
      matching: find.byType(Image),
    );
    return tester.getRect(image);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('opens from the photo menu', (tester) async {
    await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
      initialLocation: Routes.photo(projectId, photo.id),
    );
    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Auto-crop');
    expect(find.byType(AutocropReviewScreen), findsOneWidget);
  });

  group('detection', () {
    testWidgets('low confidence: inset corners and a hint', (tester) async {
      await openReview(tester);
      expect(find.text(AutocropReviewScreen.lowConfidenceHint), findsOneWidget);
      final f = frame(tester);
      final c = corners(tester);
      expect(c[0].dx, closeTo(f.left + f.width * 0.05, 0.5));
      expect(c[2].dy, closeTo(f.top + f.height * 0.95, 0.5));
    });

    testWidgets('confident: the detected corners, no hint', (tester) async {
      await openReview(
        tester,
        detection: FakeCanvasDetection(result: confident),
      );
      expect(find.text(AutocropReviewScreen.lowConfidenceHint), findsNothing);
      final f = frame(tester);
      expect(corners(tester)[1].dx, closeTo(f.left + f.width * 0.8, 0.5));
    });

    testWidgets('a failed detection is treated as unsure', (tester) async {
      await openReview(
        tester,
        detection: FakeCanvasDetection(error: Exception('boom')),
      );
      expect(find.text(AutocropReviewScreen.lowConfidenceHint), findsOneWidget);
    });

    testWidgets("the project's ratio is passed as a hint", (tester) async {
      await projects.update(projectId, size: const RatioSize(4, 5));
      final detection = FakeCanvasDetection();
      await openReview(tester, detection: detection);
      expect(detection.requests, ['${photo.id} hint=0.8']);
    });
  });

  group('handles', () {
    testWidgets('dragging a corner moves it', (tester) async {
      await openReview(tester);
      final before = corners(tester);
      await tester.dragFrom(before[2], const Offset(-60, -40));
      await tester.pumpAndSettle();
      final after = corners(tester);
      expect(after[2], before[2] + const Offset(-60, -40));
      expect(after[0], before[0]);
    });

    testWidgets('a drag that would cross the corners is refused', (
      tester,
    ) async {
      await openReview(tester);
      final before = corners(tester);
      // Top-left dragged past the bottom-right.
      await tester.dragFrom(
        before[0],
        before[2] - before[0] + const Offset(40, 40),
      );
      await tester.pumpAndSettle();
      final after = corners(tester);
      expect(after[0].dx, lessThan(before[2].dx));
      expect(after[0].dy, lessThan(before[2].dy));
    });

    testWidgets('a magnifier shows while dragging', (tester) async {
      await openReview(tester);
      expect(find.byType(RawMagnifier), findsNothing);
      final gesture = await tester.startGesture(corners(tester)[0]);
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump();
      expect(find.byType(RawMagnifier), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(RawMagnifier), findsNothing);
    });
  });

  testWidgets('the magnifier stays on screen near an edge', (tester) async {
    await openReview(tester, detection: FakeCanvasDetection(result: confident));
    await tapText(tester, 'Full image'); // top-left corner at the frame edge
    final gesture = await tester.startGesture(corners(tester)[3]);
    await gesture.moveBy(const Offset(-5, -5));
    await tester.pump();
    final loupe = tester.getRect(find.byType(RawMagnifier));
    final canvas = tester.getRect(find.byType(ReviewCanvas));
    expect(loupe.left, greaterThanOrEqualTo(canvas.left));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  group('buttons', () {
    testWidgets('Full image and Reset', (tester) async {
      await openReview(
        tester,
        detection: FakeCanvasDetection(result: confident),
      );
      final detected = corners(tester);
      final f = frame(tester);

      await tapText(tester, 'Full image');
      expect(corners(tester), [
        f.topLeft,
        f.topRight,
        f.bottomRight,
        f.bottomLeft,
      ]);

      await tapText(tester, 'Reset');
      expect(corners(tester), detected);
    });

    testWidgets('Apply saves the adjusted quad and returns', (tester) async {
      final container = await openReview(
        tester,
        detection: FakeCanvasDetection(result: confident),
      );
      await tester.dragFrom(corners(tester)[0], const Offset(-30, 0));
      await tester.pumpAndSettle();
      await tapText(tester, 'Apply');

      expect(images.calls, ['setEdits ${photo.id}']);
      final quad = images.byId(photo.id).edits.crop!.quad;
      expect(quad[1], const NormPoint(0.8, 0.15));
      expect(quad[0].x, lessThan(0.2), reason: 'dragged left');
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.photo(projectId, photo.id),
      );
    });

    testWidgets('Apply on the full image removes the crop', (tester) async {
      await images.setEdits(photo.id, Edits(quarterTurns: 2));
      images.calls.clear();
      await openReview(tester);
      await tapText(tester, 'Full image');
      await tapText(tester, 'Apply');
      expect(images.byId(photo.id).edits, const Edits(quarterTurns: 2));
    });

    testWidgets('Cancel saves nothing', (tester) async {
      await openReview(tester);
      await tester.dragFrom(corners(tester)[0], const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(images.calls, isEmpty);
    });

    testWidgets('reopening starts from the saved crop', (tester) async {
      await images.setEdits(
        photo.id,
        Edits(
          crop: CropEdit(
            quad: const [
              NormPoint(0.3, 0.3),
              NormPoint(0.7, 0.3),
              NormPoint(0.7, 0.7),
              NormPoint(0.3, 0.7),
            ],
          ),
        ),
      );
      await openReview(tester);
      final f = frame(tester);
      expect(corners(tester)[0].dx, closeTo(f.left + f.width * 0.3, 0.5));
    });
  });

  testWidgets('debug: Copy corners as JSON', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await openReview(tester, detection: FakeCanvasDetection(result: confident));
    await tester.tap(find.byTooltip('Copy corners as JSON'));
    await tester.pumpAndSettle();

    final json = jsonDecode(copied!) as Map<String, Object?>;
    expect(json['file'], '${photo.id}.jpg');
    expect(json['corners'], [
      [0.2, 0.1],
      [0.8, 0.15],
      [0.75, 0.9],
      [0.25, 0.85],
    ]);
    expect(find.text('Corners copied as JSON.'), findsOneWidget);
  });
}
