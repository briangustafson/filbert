// Desktop layout (m3-design §3.2): width classes, the capped project header,
// the docked aid panel, the photo screen with a mouse, and sheets that
// become dialogs on wide windows.

import 'package:filbert/app/layout.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photo_viewer/photo_page.dart';
import 'package:filbert/features/photo_viewer/photo_screen.dart';
import 'package:filbert/features/view_aids/ui/aid_toolbar.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_photos.dart';
import '../support/fake_project_repository.dart';
import '../support/fake_view_aids.dart';
import '../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late String projectId;
  late String a, b;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    projectId = projects.seed('Still life').id;
    a = images.seed(projectId).id;
    b = images.seed(projectId).id;
  });

  void windowSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> open(WidgetTester tester, String location) => pumpFilbertApp(
    tester,
    projects: projects,
    images: images,
    viewPrefs: FakeViewPrefsRepository(),
    palettes: FakePaletteService(),
    initialLocation: location,
  );

  test('width classes: compact < 600 ≤ medium < 840 ≤ expanded', () {
    expect(WindowWidth.forWidth(400), WindowWidth.compact);
    expect(WindowWidth.forWidth(599.9), WindowWidth.compact);
    expect(WindowWidth.forWidth(600), WindowWidth.medium);
    expect(WindowWidth.forWidth(839.9), WindowWidth.medium);
    expect(WindowWidth.forWidth(840), WindowWidth.expanded);
    expect(WindowWidth.forWidth(1200), WindowWidth.expanded);
  });

  group('project screen', () {
    testWidgets('the header is capped and centred on a wide window', (
      tester,
    ) async {
      windowSize(tester, const Size(1200, 800));
      await open(tester, Routes.project(projectId));
      final name = tester.getRect(find.byKey(ValueKey('name-$projectId')));
      expect(name.width, lessThanOrEqualTo(formMaxWidth));
      expect(name.center.dx, closeTo(600, 1), reason: 'centred');
    });

    testWidgets('on a phone it spans the screen', (tester) async {
      windowSize(tester, const Size(400, 700));
      await open(tester, Routes.project(projectId));
      final name = tester.getRect(find.byKey(ValueKey('name-$projectId')));
      expect(name.width, 400 - 32);
    });

    testWidgets('the size picker is a dialog on a wide window', (tester) async {
      windowSize(tester, const Size(1200, 800));
      await open(tester, Routes.project(projectId));
      await tester.tap(find.byTooltip('Canvas size'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final card = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(tester.getSize(card).width, lessThanOrEqualTo(480 + 1));
    });

    testWidgets('and a bottom sheet on a phone', (tester) async {
      windowSize(tester, const Size(400, 700));
      await open(tester, Routes.project(projectId));
      await tester.tap(find.byTooltip('Canvas size'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('photo screen', () {
    final sidePanel = find.byKey(const ValueKey('aid-side-panel'));

    Future<void> tapGrid(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('aid-grid')));
      await tester.pumpAndSettle();
    }

    String shown(WidgetTester tester) =>
        tester.widget<PhotoPage>(find.byType(PhotoPage).hitTestable()).image.id;

    testWidgets('a wide window docks the open panel at the right', (
      tester,
    ) async {
      windowSize(tester, const Size(1200, 800));
      await open(tester, Routes.photo(projectId, a));
      await tapGrid(tester);
      expect(sidePanel, findsOneWidget);
      expect(find.byType(AidPanel), findsOneWidget);
      final panel = tester.getRect(sidePanel);
      expect(panel.right, closeTo(1200 - 12, 1));
      expect(panel.width, 320);

      // Back closes it, as when it sits above the toolbar.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sidePanel, findsNothing);
      expect(find.byType(PhotoScreen), findsOneWidget);
    });

    testWidgets('narrower windows keep it above the toolbar', (tester) async {
      windowSize(tester, const Size(800, 600));
      await open(tester, Routes.photo(projectId, a));
      await tapGrid(tester);
      expect(sidePanel, findsNothing);
      expect(find.byType(AidPanel), findsOneWidget);
    });

    group('with a mouse', () {
      Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: at);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(at + const Offset(1, 1));
        await tester.pump();
        return mouse;
      }

      Finder arrow(String which) =>
          find.byKey(ValueKey('photo-$which')).hitTestable();

      testWidgets('previous / next buttons move between photos', (
        tester,
      ) async {
        windowSize(tester, const Size(1200, 800));
        await open(tester, Routes.photo(projectId, a));
        await mouseAt(tester, const Offset(600, 400));
        final first = shown(tester);
        // Two photos: one arrow at either end.
        final forward = arrow('next').evaluate().isNotEmpty;
        expect(arrow(forward ? 'next' : 'previous'), findsOneWidget);
        expect(arrow(forward ? 'previous' : 'next'), findsNothing);

        // A click: a touch would switch the arrows off (below).
        await tester.tap(
          arrow(forward ? 'next' : 'previous'),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(shown(tester), isNot(first));
        expect({first, shown(tester)}, {a, b});
        expect(arrow(forward ? 'previous' : 'next'), findsOneWidget);
        expect(arrow(forward ? 'next' : 'previous'), findsNothing);
      });

      testWidgets('moving shows the chrome; it hides when still', (
        tester,
      ) async {
        windowSize(tester, const Size(1200, 800));
        await open(tester, Routes.photo(projectId, a));
        final back = find.byTooltip('Back').hitTestable();
        final mouse = await mouseAt(tester, const Offset(600, 400));
        await tester.pump(
          PhotoScreen.chromeTimeout + const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
        expect(back, findsNothing, reason: 'hidden after the timeout');

        await mouse.moveTo(const Offset(620, 420));
        await tester.pumpAndSettle();
        expect(back, findsOneWidget, reason: 'shown by moving');
      });

      testWidgets('the chrome stays while the pointer is over it', (
        tester,
      ) async {
        windowSize(tester, const Size(1200, 800));
        await open(tester, Routes.photo(projectId, a));
        final back = find.byTooltip('Back');
        await mouseAt(tester, tester.getCenter(back));
        await tester.pump(PhotoScreen.chromeTimeout * 2);
        await tester.pumpAndSettle();
        expect(back.hitTestable(), findsOneWidget);
      });

      testWidgets('a touch hides the arrows again', (tester) async {
        windowSize(tester, const Size(1200, 800));
        await open(tester, Routes.photo(projectId, a));
        await mouseAt(tester, const Offset(600, 400));
        expect(
          find.byTooltip('Next photo').evaluate().length +
              find.byTooltip('Previous photo').evaluate().length,
          1,
        );

        await tester.tapAt(const Offset(600, 400)); // a touch by default
        await tester.pumpAndSettle();
        expect(find.byTooltip('Next photo'), findsNothing);
        expect(find.byTooltip('Previous photo'), findsNothing);
      });
    });

    testWidgets('touch alone never shows the arrows', (tester) async {
      windowSize(tester, const Size(400, 700));
      await open(tester, Routes.photo(projectId, a));
      expect(find.byTooltip('Next photo'), findsNothing);
      expect(find.byTooltip('Previous photo'), findsNothing);
    });
  });
}
