// The photo page draws through the viewing-aid shader while a tone aid is on
// (m2-design §5.3); the shader's math is tested in tone_shader_test.dart.

import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:filbert/features/view_aids/ui/shaded_image.dart';
import 'package:filbert/features/view_aids/ui/tone_shader.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_view_aids.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakeViewPrefsRepository prefs;
  late FakePaletteService palettes;
  late String projectId;
  late ProjectImage photo;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    prefs = FakeViewPrefsRepository();
    palettes = FakePaletteService();
    projectId = projects.seed('Still life').id;
    photo = images.seed(projectId);
    images.seed(projectId);
  });

  Future<void> open(WidgetTester tester) => pumpFilbertApp(
    tester,
    projects: projects,
    images: images,
    // Every render is a real (tiny) image file.
    renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
    viewPrefs: prefs,
    palettes: palettes,
    initialLocation: Routes.photo(projectId, photo.id),
  );

  Future<void> tapAid(WidgetTester tester, Aid aid) async {
    await tester.tap(find.byKey(ValueKey('aid-${aid.name}')));
    await tester.pumpAndSettle();
  }

  ShadedImage? shaded(WidgetTester tester) {
    // Only the shown page is built (PageView builds no neighbours here).
    final found = find.byType(ShadedImage);
    return found.evaluate().isEmpty ? null : tester.widget(found.first);
  }

  testWidgets('no tone aid: the plain photo', (tester) async {
    await open(tester);
    expect(shaded(tester), isNull);
    await tapAid(tester, Aid.grid);
    expect(shaded(tester), isNull, reason: 'the grid is not a tone aid');
  });

  testWidgets('Gray, Values and Colors draw through the shader', (
    tester,
  ) async {
    prefs.update(
      projectId,
      const ViewPrefs(
        values: ValuesPrefs(bands: 6),
        colors: ColorsPrefs(count: 4),
      ),
    );
    await open(tester);

    await tapAid(tester, Aid.gray);
    expect(shaded(tester)!.params.tone, const ToneParams.gray());

    await tapAid(tester, Aid.valueBands);
    expect(shaded(tester)!.params.tone, const ToneParams.values(6));

    await tapAid(tester, Aid.colors);
    final params = shaded(tester)!.params.tone;
    expect(params.mode, ToneAid.colors);
    expect(params.palette!.colors, hasLength(4));
    expect(palettes.requests, contains('${photo.id} 4'));

    // Off again: the plain photo.
    await tapAid(tester, Aid.colors);
    expect(shaded(tester), isNull);
  });

  testWidgets('changing bands redraws at once', (tester) async {
    await open(tester);
    await tapAid(tester, Aid.valueBands);
    await tester.tap(find.byTooltip('More bands'));
    await tester.pump();
    expect(shaded(tester)!.params.tone, const ToneParams.values(6));
  });

  testWidgets('Colors shows the plain photo until the palette is ready', (
    tester,
  ) async {
    palettes = FakePaletteService(hang: true);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('aid-colors')));
    await tester.pump();
    await tester.pump();
    expect(shaded(tester), isNull);
  });

  testWidgets('holding shows the plain original, even unedited', (
    tester,
  ) async {
    await open(tester);
    await tapAid(tester, Aid.gray);
    expect(find.text('Original'), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)) / 2,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('Original'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsNothing);
    expect(shaded(tester), isNotNull);
  });
}
