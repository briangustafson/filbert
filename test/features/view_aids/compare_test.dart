// Compare on the photo screen (m2-design §3.4): which photo is overlaid,
// the panel, and the blend handed to the shader (whose math is tested in
// tone_shader_test.dart).

import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/data/view_aids_providers.dart';
import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:filbert/features/view_aids/ui/shaded_image.dart';
import 'package:filbert/features/view_aids/ui/tone_shader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_view_aids.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

const _note = "This is the photo you're comparing with.";

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakeViewPrefsRepository prefs;
  late FakePaletteService palettes;
  late String projectId;
  // Swipe order: reference, newer, older.
  late ProjectImage reference, older, newer;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    prefs = FakeViewPrefsRepository();
    palettes = FakePaletteService();
    projectId = projects.seed('Still life').id;
    reference = images.seed(projectId, asReference: true);
    older = images.seed(projectId);
    newer = images.seed(projectId);
  });

  ComparePrefs compare() => prefs.of(projectId).compare;

  ShadedImage? shaded(WidgetTester tester) {
    final found = find.byType(ShadedImage);
    return found.evaluate().isEmpty ? null : tester.widget(found.first);
  }

  Finder thumb(ProjectImage p) => find.byKey(ValueKey('compare-thumb-${p.id}'));

  Future<void> swipe(WidgetTester tester, {bool toNext = true}) async {
    await tester.fling(
      find.byType(PageView),
      Offset(toNext ? -400 : 400, 0),
      1000,
    );
    await tester.pumpAndSettle();
  }

  for (final narrow in [false, true]) {
    group(narrow ? 'narrow phone (400 dp)' : 'normal screen', () {
      Future<ProviderContainer> open(
        WidgetTester tester,
        ProjectImage photo, {
        bool compareOn = true,
      }) async {
        if (narrow) {
          tester.view.physicalSize = const Size(400, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
        }
        final c = await pumpFilbertApp(
          tester,
          projects: projects,
          images: images,
          renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
          viewPrefs: prefs,
          palettes: palettes,
          initialLocation: Routes.photo(projectId, photo.id),
        );
        if (compareOn) {
          await tester.tap(find.byKey(const ValueKey('aid-compare')));
          await tester.pumpAndSettle();
        }
        return c;
      }

      ProjectImage? overlay(ProviderContainer c, ProjectImage shown) =>
          c.read(compareTargetProvider(shown))?.overlay;

      testWidgets('the default is the reference, at 50 %', (tester) async {
        final c = await open(tester, older);
        expect(overlay(c, older), reference);
        final s = shaded(tester)!;
        expect(s.params.tone, const ToneParams.plain());
        expect(s.params.compare!.opacity, 0.5);
        expect(s.other, isNotNull);
        expect(
          tester.getSemantics(thumb(reference)),
          isSemantics(isSelected: true),
        );
        expect(
          tester.getSemantics(thumb(newer)),
          isSemantics(isSelected: false),
        );
        expect(thumb(older), findsNothing, reason: 'the shown photo');
        expect(find.text('50 %'), findsOneWidget);
        expect(find.text(_note), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('on the reference: the most recent other photo', (
        tester,
      ) async {
        final c = await open(tester, reference);
        expect(overlay(c, reference), newer);
        expect(shaded(tester)!.other, isNotNull);
      });

      testWidgets('a chosen photo is saved and kept while swiping', (
        tester,
      ) async {
        final c = await open(tester, reference);
        await tester.tap(thumb(older));
        await tester.pumpAndSettle();
        expect(compare().imageId, older.id);
        expect(overlay(c, reference), older);

        await swipe(tester); // newer
        expect(overlay(c, newer), older);
        expect(shaded(tester)!.other, isNotNull);

        // The compare photo itself: no overlay, and the panel says so.
        await swipe(tester); // older
        expect(shaded(tester), isNull);
        expect(find.text(_note), findsOneWidget);
        expect(c.read(compareTargetProvider(older))!.isShown, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a deleted compare photo falls back to the default', (
        tester,
      ) async {
        prefs.update(
          projectId,
          ViewPrefs(compare: ComparePrefs(imageId: newer.id)),
        );
        final c = await open(tester, older);
        expect(overlay(c, older), newer);
        await images.delete(newer.id);
        await tester.pumpAndSettle();
        expect(overlay(c, older), reference);
        expect(compare().imageId, newer.id, reason: 'restore brings it back');
      });

      testWidgets('the opacity slider sets the blend', (tester) async {
        await open(tester, older);
        await tester.drag(
          find.byKey(const ValueKey('compare-opacity')),
          const Offset(-1000, 0),
        );
        await tester.pumpAndSettle();
        expect(compare().opacity, 0);
        expect(shaded(tester)!.params.compare!.opacity, 0);
        expect(find.text('0 %'), findsOneWidget);

        await tester.drag(
          find.byKey(const ValueKey('compare-opacity')),
          const Offset(1000, 0),
        );
        await tester.pumpAndSettle();
        expect(compare().opacity, 1);
      });

      testWidgets('with Colors, each photo uses its own palette', (
        tester,
      ) async {
        await open(tester, older);
        await tester.tap(find.byKey(const ValueKey('aid-colors')));
        await tester.pumpAndSettle();
        expect(
          palettes.requests,
          containsAll(['${older.id} 8', '${reference.id} 8']),
        );
        final s = shaded(tester)!;
        expect(s.params.tone.mode, ToneAid.colors);
        expect(s.params.compare!.palette, isNotNull);
      });

      testWidgets('off again: the plain photo', (tester) async {
        await open(tester, older);
        await tester.tap(find.byKey(const ValueKey('aid-compare')));
        await tester.pumpAndSettle();
        expect(shaded(tester), isNull);
      });
    });
  }

  testWidgets('no Compare button with one photo', (tester) async {
    await images.delete(older.id);
    await images.delete(newer.id);
    await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
      viewPrefs: prefs,
      initialLocation: Routes.photo(projectId, reference.id),
    );
    expect(find.byKey(const ValueKey('aid-compare')), findsNothing);
    expect(find.byKey(const ValueKey('aid-grid')), findsOneWidget);
  });
}
