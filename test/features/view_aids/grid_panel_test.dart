import 'package:filbert/app/routes.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:filbert/features/view_aids/ui/grid_painter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late String projectId;
  late ProjectImage photo; // 40 × 30

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    prefs = FakeViewPrefsRepository();
    projectId = projects.seed('Still life').id;
    photo = images.seed(projectId);
  });

  GridPrefs grid() => prefs.of(projectId).grid;

  for (final narrow in [false, true]) {
    group(narrow ? 'narrow phone (400 dp)' : 'normal screen', () {
      Future<ProviderContainer> open(
        WidgetTester tester, {
        ProjectSize? size,
      }) async {
        if (size != null) await projects.update(projectId, size: size);
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
          initialLocation: Routes.photo(projectId, photo.id),
        );
        await tester.tap(find.byKey(const ValueKey('aid-grid')));
        await tester.pumpAndSettle();
        return c;
      }

      Future<void> tap(WidgetTester tester, Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      GridPainter? painter(WidgetTester tester) {
        final paints = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<GridPainter>();
        return paints.isEmpty ? null : paints.first;
      }

      testWidgets('Grid on draws the grid; off removes it', (tester) async {
        await open(tester);
        expect(painter(tester)!.layout.xs, hasLength(5), reason: '4 × 4');
        await tap(tester, find.byKey(const ValueKey('aid-grid')));
        expect(painter(tester), isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('without a physical size: divisions only', (tester) async {
        await open(tester, size: const RatioSize(4, 3));
        expect(find.text('Spacing'), findsNothing);
        expect(find.text('Rows'), findsOneWidget);
        expect(find.text('Columns'), findsOneWidget);

        await tap(tester, find.byTooltip('More rows'));
        await tap(tester, find.byTooltip('Fewer columns'));
        expect((grid().rows, grid().cols), (5, 3));
        expect(painter(tester)!.layout.ys, hasLength(6));
        expect(tester.takeException(), isNull);
      });

      testWidgets('options write the prefs', (tester) async {
        await open(tester);
        await tap(tester, find.text('Diagonals'));
        await tap(tester, find.byKey(const ValueKey('grid-color-red')));
        await tap(tester, find.byKey(const ValueKey('grid-width-thick')));
        expect(
          (grid().diagonals, grid().color, grid().width),
          (true, GridColor.red, GridLineWidth.thick),
        );
        final p = painter(tester)!;
        expect(p.layout.diagonals, isTrue);
        expect(p.color, const Color(0xFFE53935));
        expect(p.strokeWidth, 3);
      });

      testWidgets('spacing in the project\'s unit', (tester) async {
        await open(tester, size: const PhysicalSize(12, 9, LengthUnit.inches));
        await tap(tester, find.text('Spacing'));
        expect(grid().mode, GridMode.spacing);
        expect(find.text('2 in'), findsOneWidget, reason: 'the default');
        // 2 in on a 12 in wide canvas: 6 cells across.
        expect(painter(tester)!.layout.xs, hasLength(7));

        await tap(tester, find.byTooltip('Bigger squares'));
        expect(grid().spacing, 2.5);
        expect(find.text('2.5 in'), findsOneWidget);
        await tap(tester, find.byTooltip('Smaller squares'));
        await tap(tester, find.byTooltip('Smaller squares'));
        expect(grid().spacing, 1.5);
        // The photo matches the canvas: no note.
        expect(find.textContaining('exact grid'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('centimetres step by 1 cm, up to the shorter side', (
        tester,
      ) async {
        prefs.update(
          projectId,
          const ViewPrefs(grid: GridPrefs(mode: GridMode.spacing, spacing: 7)),
        );
        await open(
          tester,
          size: const PhysicalSize(10, 8, LengthUnit.centimeters),
        );
        expect(find.text('7 cm'), findsOneWidget);
        await tap(tester, find.byTooltip('Bigger squares'));
        expect(find.text('8 cm'), findsOneWidget);
        final bigger = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Bigger squares'),
            matching: find.byType(IconButton),
          ),
        );
        expect(bigger.onPressed, isNull, reason: '8 cm is the shorter side');
      });

      testWidgets('a photo not cropped to the canvas gets the note', (
        tester,
      ) async {
        prefs.update(
          projectId,
          const ViewPrefs(grid: GridPrefs(mode: GridMode.spacing)),
        );
        // A square canvas; the photo is 4:3.
        await open(tester, size: const PhysicalSize(10, 10, LengthUnit.inches));
        expect(
          find.text("Crop to the project's size for an exact grid."),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('a saved spacing grid shows as divisions without a size', (
        tester,
      ) async {
        prefs.update(
          projectId,
          const ViewPrefs(grid: GridPrefs(mode: GridMode.spacing, spacing: 2)),
        );
        await open(tester);
        expect(find.text('Rows'), findsOneWidget);
        expect(painter(tester)!.layout.xs, hasLength(5));
      });

      testWidgets('holding hides the grid behind the original', (tester) async {
        await open(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PageView)) / 2,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Original'), findsOneWidget);
        await gesture.up();
        await tester.pumpAndSettle();
      });
    });
  }
}
