import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photo_viewer/photo_page.dart';
import 'package:filbert/features/photo_viewer/photo_screen.dart';
import 'package:filbert/features/photos/data/image_renderer.dart';
import 'package:filbert/features/view_aids/ui/aid_toolbar.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:flutter/gestures.dart'
    show kDoubleTapTimeout, kLongPressTimeout;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakeImageRenderer renderer;
  late String projectId;
  // Seeded oldest first, so the grid (newest first) is c, b, a.
  late ProjectImage a, b, c;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    renderer = FakeImageRenderer();
    projectId = projects.seed('Still life').id;
    a = images.seed(projectId);
    b = images.seed(projectId);
    c = images.seed(projectId);
  });

  Future<ProviderContainer> open(WidgetTester tester, String imageId) =>
      pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        renderer: renderer,
        initialLocation: Routes.photo(projectId, imageId),
      );

  String shown(WidgetTester tester) =>
      tester.widget<PhotoPage>(find.byType(PhotoPage).hitTestable()).image.id;

  Future<void> swipe(WidgetTester tester, {bool toNext = true}) async {
    await tester.fling(
      find.byType(PageView),
      Offset(toNext ? -400 : 400, 0),
      1000,
    );
    await tester.pumpAndSettle();
  }

  Future<List<String>> menuItems(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    final items = [
      for (final item in tester.widgetList<PopupMenuItem<Object?>>(
        find.byWidgetPredicate((w) => w is PopupMenuItem),
      ))
        ((item.child! as Text).data!),
    ];
    return items;
  }

  Future<void> choose(WidgetTester tester, String item) async {
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  group('swiping', () {
    testWidgets('reference first, then newest to oldest', (tester) async {
      await images.setAsReference(projectId, b.id);
      await open(tester, b.id);

      final seen = [shown(tester)];
      for (var i = 0; i < 3; i++) {
        await swipe(tester);
        seen.add(shown(tester));
      }
      expect(seen, [b.id, c.id, a.id, a.id], reason: 'stops at the end');

      await swipe(tester, toNext: false);
      expect(shown(tester), c.id);
    });

    testWidgets('opens on the tapped photo; the route stays put', (
      tester,
    ) async {
      final container = await open(tester, b.id);
      expect(shown(tester), b.id);
      await swipe(tester);
      expect(shown(tester), a.id);
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.photo(projectId, b.id),
      );
    });

    testWidgets('a missing photo says so, with a way back', (tester) async {
      final container = await open(tester, 'gone');
      expect(find.text('This photo no longer exists.'), findsOneWidget);
      expect(find.byTooltip('Photo options'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.project(projectId),
      );
    });
  });

  group('rendering', () {
    testWidgets('asks for the thumbnail and the preview', (tester) async {
      await open(tester, c.id);
      expect(
        renderer.requests,
        containsAll([
          'thumbnail ${c.id} $standardThumbnailPx',
          'preview ${c.id}',
        ]),
      );
      expect(renderer.requests.where((r) => r.startsWith('detail')), isEmpty);
    });

    testWidgets('holding an edited photo shows the original', (tester) async {
      final edited = images.seed(
        projectId,
        edits: const Edits(quarterTurns: 1),
      );
      await open(tester, edited.id);
      expect(find.text('Original'), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.text('Original'), findsOneWidget);
      expect(renderer.requests, contains('preview ${edited.id}'));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsNothing);
    });

    testWidgets('holding an unedited photo changes nothing', (tester) async {
      await open(tester, c.id);
      await tester.longPress(find.byType(PageView));
      expect(find.text('Original'), findsNothing);
    });
  });

  group('chrome', () {
    double opacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byTooltip('Back'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('hides by itself; a tap toggles it', (tester) async {
      await open(tester, c.id);
      expect(opacity(tester), 1);

      await tester.pump(PhotoScreen.chromeTimeout);
      await tester.pumpAndSettle();
      expect(opacity(tester), 0);

      // A single tap counts once the double-tap window has passed.
      await tester.tap(find.byType(PageView));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);

      await tester.tap(find.byType(PageView));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      expect(opacity(tester), 0);
    });
  });

  group('menu', () {
    testWidgets('grid photo: Set as reference and Delete', (tester) async {
      await open(tester, c.id);
      expect(await menuItems(tester), [
        'Crop/rotate',
        'Export…',
        'Set as reference',
        'Delete',
      ]);
    });

    testWidgets('the reference: Delete only', (tester) async {
      await images.setAsReference(projectId, a.id);
      await open(tester, a.id);
      expect(await menuItems(tester), ['Crop/rotate', 'Export…', 'Delete']);
    });

    testWidgets('Undo, Redo, Revert appear only when they apply', (
      tester,
    ) async {
      const turned = Edits(quarterTurns: 1);
      await images.setEdits(c.id, turned);
      await open(tester, c.id);
      expect(await menuItems(tester), [
        'Crop/rotate',
        'Undo',
        'Revert to original',
        'Export…',
        'Set as reference',
        'Delete',
      ]);

      await choose(tester, 'Undo');
      expect(images.calls.last, 'undo ${c.id}');
      expect(await menuItems(tester), [
        'Crop/rotate',
        'Redo',
        'Export…',
        'Set as reference',
        'Delete',
      ]);

      await choose(tester, 'Redo');
      expect(images.calls.last, 'redo ${c.id}');
      expect(await menuItems(tester), [
        'Crop/rotate',
        'Undo',
        'Revert to original',
        'Export…',
        'Set as reference',
        'Delete',
      ]);
    });

    testWidgets("Revert shows no snackbar; the menu's Undo brings it back", (
      tester,
    ) async {
      await images.setEdits(c.id, const Edits(quarterTurns: 1));
      await open(tester, c.id);
      await menuItems(tester);
      await choose(tester, 'Revert to original');

      expect(images.calls.last, 'revert ${c.id}');
      expect(find.byType(SnackBar), findsNothing);
      // Back at the original: Undo, but nothing to revert or redo.
      expect(await menuItems(tester), [
        'Crop/rotate',
        'Undo',
        'Export…',
        'Set as reference',
        'Delete',
      ]);
      await choose(tester, 'Undo');
      expect(images.calls.last, 'undo ${c.id}');
      expect(shown(tester), c.id);
    });

    testWidgets('Set as reference keeps showing the photo', (tester) async {
      await open(tester, b.id);
      await menuItems(tester);
      await choose(tester, 'Set as reference');

      expect(images.calls, ['setAsReference $projectId ${b.id}']);
      expect(shown(tester), b.id);
      expect(find.text('Set as the reference.'), findsOneWidget);
      // Now first in the order.
      await swipe(tester, toNext: false);
      expect(shown(tester), b.id);
    });

    testWidgets('Delete shows the next photo; Undo restores', (tester) async {
      await open(tester, b.id);
      await menuItems(tester);
      await choose(tester, 'Delete');

      expect(images.calls, ['delete ${b.id}']);
      expect(shown(tester), a.id);
      expect(find.text('Photo deleted.'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(images.calls.last, 'restore ${b.id}');
      expect(shown(tester), a.id, reason: 'stays where it was');
    });

    testWidgets('deleting the last photo in the order shows the previous', (
      tester,
    ) async {
      await open(tester, a.id);
      await menuItems(tester);
      await choose(tester, 'Delete');
      expect(shown(tester), b.id);
    });

    testWidgets('deleting the only photo returns to the project', (
      tester,
    ) async {
      final lone = projects.seed('Lone').id;
      final only = images.seed(lone);
      final container = await pumpFilbertApp(
        tester,
        projects: projects,
        images: images,
        initialLocation: Routes.photo(lone, only.id),
      );
      await menuItems(tester);
      await choose(tester, 'Delete');

      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.project(lone),
      );
      expect(find.text('Photo deleted.'), findsOneWidget);
    });
  });

  testWidgets("a snackbar doesn't cover the aid toolbar", (tester) async {
    await open(tester, c.id);
    await menuItems(tester);
    await choose(tester, 'Delete');
    final snackBar = tester.getRect(find.byType(SnackBar));
    expect(
      snackBar.bottom,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(AidToolbar)).dy),
    );
    // The photo still runs on behind the toolbar.
    expect(
      tester.getRect(find.byType(PageView)).bottom,
      tester.getSize(find.byType(MaterialApp)).height,
    );
  });
}
