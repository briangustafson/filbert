import 'dart:convert';

import 'package:canvas_detect/canvas_detect.dart';
import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filbert/features/crop/corners_canvas.dart';
import 'package:filbert/features/crop/crop_overlay.dart';
import 'package:filbert/features/crop/crop_screen.dart';
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

  /// Crop with Find canvas on opening, as adding photos opens it.
  Future<ProviderContainer> openReview(
    WidgetTester tester, {
    FakeCanvasDetection? detection,
    bool findCanvas = true,
  }) => pumpFilbertApp(
    tester,
    projects: projects,
    images: images,
    renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
    detection: detection,
    initialLocation: Routes.crop(projectId, photo.id, findCanvas: findCanvas),
  );

  /// The rectangle crop and the photo's frame on screen (Rectangle mode).
  (Rect, Rect) rectangle(WidgetTester tester) {
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is CropOverlayPainter,
                  ),
                )
                .painter!
            as CropOverlayPainter;
    final origin = tester.getTopLeft(find.byType(CropCanvas));
    return (painter.crop.shift(origin), painter.frame.shift(origin));
  }

  final trapezoid = Edits(
    crop: CropEdit(
      quad: const [
        NormPoint(0.2, 0.1),
        NormPoint(0.8, 0.15),
        NormPoint(0.75, 0.9),
        NormPoint(0.25, 0.85),
      ],
    ),
  );

  CornersOverlayPainter overlay(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is CornersOverlayPainter,
                ),
              )
              .painter!
          as CornersOverlayPainter;

  /// Corner positions on screen (the painter draws in canvas coordinates).
  List<Offset> corners(WidgetTester tester) {
    final origin = tester.getTopLeft(find.byType(CornersCanvas));
    return [for (final c in overlay(tester).corners) c + origin];
  }

  /// The photo's frame on screen.
  Rect frame(WidgetTester tester) {
    final image = find.descendant(
      of: find.byType(CornersCanvas),
      matching: find.byType(Image),
    );
    return tester.getRect(image);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Crop/rotate opens in Rectangle; Find canvas switches to '
      'Corners', (tester) async {
    await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
      detection: FakeCanvasDetection(result: confident),
      initialLocation: Routes.photo(projectId, photo.id),
    );
    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    expect(find.text('Auto-crop'), findsNothing, reason: 'one menu item');
    await tapText(tester, 'Crop/rotate');
    expect(find.byType(CropCanvas), findsOneWidget);
    expect(find.byType(CornersCanvas), findsNothing);

    await tapText(tester, 'Find canvas');
    expect(find.byType(CornersCanvas), findsOneWidget);
    final f = frame(tester);
    expect(corners(tester)[1].dx, closeTo(f.left + f.width * 0.8, 0.5));
  });

  group('detection', () {
    testWidgets('low confidence: inset corners and a hint', (tester) async {
      await openReview(tester);
      expect(find.text(CropScreen.lowConfidenceHint), findsOneWidget);
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
      expect(find.text(CropScreen.lowConfidenceHint), findsNothing);
      final f = frame(tester);
      expect(corners(tester)[1].dx, closeTo(f.left + f.width * 0.8, 0.5));
    });

    testWidgets('a failed detection is treated as unsure', (tester) async {
      await openReview(
        tester,
        detection: FakeCanvasDetection(error: Exception('boom')),
      );
      expect(find.text(CropScreen.lowConfidenceHint), findsOneWidget);
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
    await tapText(tester, 'Reset'); // corners at the frame's edges
    final gesture = await tester.startGesture(corners(tester)[3]);
    await gesture.moveBy(const Offset(-5, -5));
    await tester.pump();
    final loupe = tester.getRect(find.byType(RawMagnifier));
    final canvas = tester.getRect(find.byType(CornersCanvas));
    expect(loupe.left, greaterThanOrEqualTo(canvas.left));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  group('buttons', () {
    testWidgets('Reset puts the corners on the whole photo; Find canvas '
        'brings the detection back', (tester) async {
      await openReview(
        tester,
        detection: FakeCanvasDetection(result: confident),
      );
      final detected = corners(tester);
      final f = frame(tester);

      await tapText(tester, 'Reset');
      expect(corners(tester), [
        f.topLeft,
        f.topRight,
        f.bottomRight,
        f.bottomLeft,
      ]);

      await tapText(tester, 'Find canvas');
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
        container.read(routerProvider).state.uri.path,
        Routes.photo(projectId, photo.id),
      );
    });

    testWidgets('Reset then Apply removes the crop and the turn', (
      tester,
    ) async {
      await images.setEdits(
        photo.id,
        Edits(crop: trapezoid.crop, quarterTurns: 2),
      );
      images.calls.clear();
      await openReview(tester, findCanvas: false);
      expect(find.byType(CornersCanvas), findsOneWidget);
      await tapText(tester, 'Reset');
      await tapText(tester, 'Apply');
      expect(images.byId(photo.id).edits, Edits.none);
    });

    testWidgets('Cancel saves nothing', (tester) async {
      await openReview(tester);
      await tester.dragFrom(corners(tester)[0], const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(images.calls, isEmpty);
    });

    testWidgets('a perspective crop opens in Corners, on its corners', (
      tester,
    ) async {
      await images.setEdits(photo.id, trapezoid);
      await openReview(tester, findCanvas: false);
      final f = frame(tester);
      expect(corners(tester)[0].dx, closeTo(f.left + f.width * 0.2, 0.5));
      expect(corners(tester)[2].dy, closeTo(f.top + f.height * 0.9, 0.5));
      expect(find.text(CropScreen.lowConfidenceHint), findsNothing);
    });
  });

  group('switching modes', () {
    testWidgets('Rectangle → Corners: the corners start on the rectangle', (
      tester,
    ) async {
      await images.setEdits(
        photo.id,
        Edits(
          crop: CropEdit(
            quad: const [
              NormPoint(0.25, 0.2),
              NormPoint(0.75, 0.2),
              NormPoint(0.75, 0.8),
              NormPoint(0.25, 0.8),
            ],
          ),
        ),
      );
      await openReview(tester, findCanvas: false);
      expect(find.byType(CropCanvas), findsOneWidget, reason: 'a rectangle');
      final (rect, rectFrame) = rectangle(tester);

      await tapText(tester, 'Corners');
      expect(frame(tester), rectFrame, reason: 'the photo stays put');
      final c = corners(tester);
      expect(c[0].dx, closeTo(rect.left, 0.5));
      expect(c[0].dy, closeTo(rect.top, 0.5));
      expect(c[2].dx, closeTo(rect.right, 0.5));
      expect(c[2].dy, closeTo(rect.bottom, 0.5));
    });

    testWidgets('Corners → Rectangle: the rectangle around the corners', (
      tester,
    ) async {
      await images.setEdits(photo.id, trapezoid);
      await openReview(tester, findCanvas: false);
      await tapText(tester, 'Rectangle');
      final (rect, f) = rectangle(tester);
      expect(rect.left, closeTo(f.left + f.width * 0.2, 0.5));
      expect(rect.right, closeTo(f.left + f.width * 0.8, 0.5));
      expect(rect.top, closeTo(f.top + f.height * 0.1, 0.5));
      expect(rect.bottom, closeTo(f.top + f.height * 0.9, 0.5));

      await tapText(tester, 'Apply');
      final quad = images.byId(photo.id).edits.crop!.quad;
      expect(quad[0].x, closeTo(0.2, 1e-6));
      expect(quad[2].y, closeTo(0.9, 1e-6));
    });

    testWidgets("Corners → Rectangle applies the project's ratio", (
      tester,
    ) async {
      await projects.update(projectId, size: const RatioSize(1, 1));
      await images.setEdits(photo.id, trapezoid);
      await openReview(tester, findCanvas: false);
      await tapText(tester, 'Rectangle');
      final (rect, _) = rectangle(tester);
      expect(rect.width, closeTo(rect.height, 0.5));
    });

    testWidgets('Rotate 90° in Corners turns the photo and the corners', (
      tester,
    ) async {
      await openReview(
        tester,
        detection: FakeCanvasDetection(result: confident),
      );
      await tester.tap(find.byTooltip('Rotate 90°'));
      await tester.pumpAndSettle();
      final f = frame(tester);
      expect(f.width, lessThan(f.height), reason: '40×30 turned');
      // The detected top-left (0.2, 0.1) is now the top-right corner.
      expect(corners(tester)[1].dx, closeTo(f.left + f.width * 0.9, 0.5));

      await tapText(tester, 'Apply');
      final edits = images.byId(photo.id).edits;
      expect(edits.quarterTurns, 1);
      expect(edits.crop!.quad[0].x, closeTo(0.2, 1e-9));
      expect(edits.crop!.quad[0].y, closeTo(0.1, 1e-9));
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

  testWidgets("a snackbar doesn't cover the buttons below the photo", (
    tester,
  ) async {
    await openReview(tester);
    ScaffoldMessenger.of(tester.element(find.byType(CornersCanvas)))
        .showSnackBar(const SnackBar(content: Text('Hello')));
    await tester.pumpAndSettle();
    final snackBar = tester.getRect(find.byType(SnackBar));
    for (final label in ['Rectangle', 'Corners', 'Find canvas']) {
      expect(
        snackBar.bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.text(label)).dy),
        reason: label,
      );
    }
  });
}
