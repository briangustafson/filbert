import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:filbert/features/photo_viewer/photo_screen.dart';

import '../support/fake_photos.dart';
import '../support/fake_project_repository.dart';
import '../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;

  setUp(() => projects = FakeProjectRepository());

  String location(ProviderContainer container) =>
      container.read(routerProvider).state.uri.toString();

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  void expectTitle(String title) {
    expect(find.widgetWithText(AppBar, title), findsOneWidget);
  }

  testWidgets('starts on the project list', (tester) async {
    final container = await pumpFilbertApp(tester, projects: projects);
    expectTitle('Projects');
    expect(location(container), Routes.projectList);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('navigates down to every M1 route and back', (tester) async {
    final project = projects.seed('Harbor');
    final images = FakeImageRepository(projects);
    final i = images.seed(project.id).id;
    final container = await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
    );
    final p = project.id;

    await tester.tap(find.text('Harbor'));
    await tester.pumpAndSettle();
    expect(location(container), Routes.project(p));
    expect(find.text('Harbor'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Photo',
      ),
    );
    await tester.pumpAndSettle();
    expect(location(container), Routes.photo(p, i));
    expect(find.byType(PhotoScreen), findsOneWidget);

    // Crop and auto-crop are reached by deep link until their menu items
    // arrive (T11, T12).
    container.read(routerProvider).go(Routes.crop(p, i));
    await tester.pumpAndSettle();
    expectTitle('Crop');
    await tapBack(tester);
    expect(find.byType(PhotoScreen), findsOneWidget);

    container.read(routerProvider).go(Routes.autocrop(p, i));
    await tester.pumpAndSettle();
    expectTitle('Auto-crop');
    await tapBack(tester);
    expect(location(container), Routes.photo(p, i));

    // Android's system back (the photo screen's own chrome may have hidden
    // itself by now; its Back button is tested in photo_screen_test).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(location(container), Routes.project(p));
    await tapBack(tester);
    expectTitle('Projects');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expectTitle('Settings');
    expect(location(container), Routes.settings);

    await tapBack(tester);
    expectTitle('Projects');
  });

  testWidgets('deep links open with route ids', (tester) async {
    final container = await pumpFilbertApp(tester, projects: projects);
    container.read(routerProvider).go(Routes.autocrop('p1', 'i1'));
    await tester.pumpAndSettle();

    expectTitle('Auto-crop');
    expect(find.text('Project: p1'), findsOneWidget);
    expect(find.text('Image: i1'), findsOneWidget);

    await tapBack(tester);
    expect(find.byType(PhotoScreen), findsOneWidget);
  });
}
