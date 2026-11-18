import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photo_viewer/photo_screen.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/data/view_aids_providers.dart';
import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:filbert/features/view_aids/ui/aid_toolbar.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_view_aids.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakeViewPrefsRepository prefs;
  late FakePaletteService palettes;
  late String projectId;
  late ProjectImage a, b;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    prefs = FakeViewPrefsRepository();
    palettes = FakePaletteService();
    projectId = projects.seed('Still life').id;
    a = images.seed(projectId);
    b = images.seed(projectId);
  });

  for (final narrow in [false, true]) {
    group(narrow ? 'narrow phone (400 dp)' : 'normal screen', () {
      Future<ProviderContainer> open(WidgetTester tester, String id) {
        if (narrow) {
          tester.view.physicalSize = const Size(400, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
        }
        return pumpFilbertApp(
          tester,
          projects: projects,
          images: images,
          viewPrefs: prefs,
          palettes: palettes,
          initialLocation: Routes.photo(projectId, id),
        );
      }

      ViewAids aids(ProviderContainer c) =>
          c.read(viewAidsStateProvider(projectId));

      Finder aidButton(String label) => find.byKey(
        ValueKey(
          'aid-${label == 'Values' ? 'valueBands' : label.toLowerCase()}',
        ),
      );

      Future<void> tapAid(WidgetTester tester, String label) async {
        await tester.tap(aidButton(label));
        await tester.pumpAndSettle();
      }

      IconButton iconButton(WidgetTester tester, String tooltip) =>
          tester.widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          );

      Future<void> tapPhoto(WidgetTester tester) async {
        await tester.tapAt(tester.getCenter(find.byType(PageView)) / 2);
        await tester.pump(kDoubleTapTimeout);
        await tester.pumpAndSettle();
      }

      double opacity(WidgetTester tester, String label) => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: aidButton(label),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;

      testWidgets('shows the five aids with the chrome', (tester) async {
        await open(tester, a.id);
        for (final label in ['Grid', 'Gray', 'Values', 'Colors', 'Compare']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(opacity(tester, 'Grid'), 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Compare is hidden when there is no other photo', (
        tester,
      ) async {
        final lonely = projects.seed('Sketch').id;
        final only = images.seed(lonely);
        if (narrow) {
          tester.view.physicalSize = const Size(400, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
        }
        await pumpFilbertApp(
          tester,
          projects: projects,
          images: images,
          viewPrefs: prefs,
          palettes: palettes,
          initialLocation: Routes.photo(lonely, only.id),
        );
        expect(find.text('Grid'), findsOneWidget);
        expect(find.text('Compare'), findsNothing);
      });

      testWidgets('Gray, Values and Colors exclude each other', (tester) async {
        final c = await open(tester, a.id);
        await tapAid(tester, 'Grid');
        await tapAid(tester, 'Gray');
        expect(aids(c).tone, ToneAid.gray);
        await tapAid(tester, 'Values');
        expect(aids(c).tone, ToneAid.valueBands);
        await tapAid(tester, 'Colors');
        expect(aids(c).tone, ToneAid.colors);
        expect(aids(c).grid, isTrue, reason: 'Grid combines with them');
        expect(tester.takeException(), isNull);
      });

      testWidgets('panels open, switch and close', (tester) async {
        final c = await open(tester, a.id);
        await tapAid(tester, 'Values');
        expect(find.text('Bands'), findsOneWidget);
        await tapAid(tester, 'Colors');
        expect(find.text('Bands'), findsNothing);
        expect(find.byKey(const ValueKey('palette-swatches')), findsOneWidget);
        // Tapping Colors again turns it off and closes its panel.
        await tapAid(tester, 'Colors');
        expect(aids(c), ViewAids.off);
        expect(find.byKey(const ValueKey('palette-swatches')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the chrome stays while a panel is open', (tester) async {
        final c = await open(tester, a.id);
        await tapAid(tester, 'Values');
        await tester.pump(PhotoScreen.chromeTimeout * 2);
        await tester.pumpAndSettle();
        expect(opacity(tester, 'Values'), 1);

        // Tapping the photo closes the panel and hides the chrome; the aid
        // stays on.
        await tapPhoto(tester);
        expect(aids(c).panel, isNull);
        expect(aids(c).tone, ToneAid.valueBands);
        expect(opacity(tester, 'Values'), 0);
      });

      testWidgets('toolbar taps restart the hide timer', (tester) async {
        await open(tester, a.id);
        await tester.pump(PhotoScreen.chromeTimeout * 0.8);
        // Just a frame: settling would also run the clock (the ripple).
        await tester.tap(aidButton('Gray')); // No panel.
        await tester.pump();
        await tester.pump(PhotoScreen.chromeTimeout * 0.8);
        expect(opacity(tester, 'Gray'), 1, reason: 'restarted by the tap');
        await tester.pump(PhotoScreen.chromeTimeout);
        await tester.pumpAndSettle();
        expect(opacity(tester, 'Gray'), 0);
      });

      testWidgets('Back closes an open panel before leaving', (tester) async {
        final c = await open(tester, a.id);
        await tapAid(tester, 'Colors');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(PhotoScreen), findsOneWidget);
        expect(aids(c).panel, isNull);
        expect(aids(c).tone, ToneAid.colors);
      });

      testWidgets('aids stay on while swiping, reset after leaving', (
        tester,
      ) async {
        final c = await open(tester, a.id);
        await tapAid(tester, 'Grid');
        await tapAid(tester, 'Gray');
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
        expect((aids(c).grid, aids(c).tone), (true, ToneAid.gray));

        c.read(routerProvider).go(Routes.project(projectId));
        await tester.pumpAndSettle();
        c.read(routerProvider).go(Routes.photo(projectId, b.id));
        await tester.pumpAndSettle();
        expect(aids(c), ViewAids.off);
      });

      testWidgets('the Values stepper writes the project\'s prefs, 2–9', (
        tester,
      ) async {
        await open(tester, a.id);
        await tapAid(tester, 'Values');
        await tester.tap(find.byTooltip('More bands'));
        await tester.pumpAndSettle();
        expect(prefs.of(projectId).values.bands, 6);
        expect(find.text('6'), findsOneWidget);

        for (var i = 0; i < 10; i++) {
          final more = find.byTooltip('More bands');
          if (iconButton(tester, 'More bands').onPressed == null) break;
          await tester.tap(more);
          await tester.pumpAndSettle();
        }
        expect(prefs.of(projectId).values.bands, ValuesPrefs.maxBands);
        expect(iconButton(tester, 'More bands').onPressed, isNull);
      });

      testWidgets('the Colors stepper writes prefs and asks for that palette', (
        tester,
      ) async {
        prefs.update(
          projectId,
          const ViewPrefs(colors: ColorsPrefs(count: ColorsPrefs.minCount)),
        );
        await open(tester, a.id);
        await tapAid(tester, 'Colors');
        expect(iconButton(tester, 'Fewer colors').onPressed, isNull);
        await tester.tap(find.byTooltip('More colors'));
        await tester.pumpAndSettle();
        expect(prefs.of(projectId).colors.count, 3);
        expect(palettes.requests, ['${a.id} 2', '${a.id} 3']);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the stepper stays put as the swatches wrap', (tester) async {
        await open(tester, a.id);
        await tapAid(tester, 'Colors');
        final more = find.byTooltip('More colors');
        final start = tester.getCenter(more);
        while (iconButton(tester, 'More colors').onPressed != null) {
          await tester.tap(more);
          await tester.pumpAndSettle();
          expect(tester.getCenter(more), start);
        }
        expect(prefs.of(projectId).colors.count, ColorsPrefs.maxCount);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a palette still computing shows a spinner', (tester) async {
        palettes = FakePaletteService(hang: true);
        await open(tester, a.id);
        await tester.tap(aidButton('Colors'));
        await tester.pump();
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(AidPanel),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
      });
    });
  }
}
