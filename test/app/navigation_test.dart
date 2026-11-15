import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_project_repository.dart';
import '../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;

  setUp(() => projects = FakeProjectRepository());

  String location(ProviderContainer container) =>
      container.read(routerProvider).state.uri.toString();

  Future<void> tapLink(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

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
    final container = await pumpFilbertApp(tester, projects: projects);
    final p = project.id;
    const i = 'sample-image';

    await tester.tap(find.text('Harbor'));
    await tester.pumpAndSettle();
    expectTitle('Project');
    expect(location(container), Routes.project(p));

    await tapLink(tester, 'Open photo');
    expectTitle('Photo');
    expect(location(container), Routes.photo(p, i));

    await tapLink(tester, 'Crop/rotate');
    expectTitle('Crop');
    expect(location(container), Routes.crop(p, i));

    await tapBack(tester);
    expectTitle('Photo');

    await tapLink(tester, 'Auto-crop');
    expectTitle('Auto-crop');
    expect(location(container), Routes.autocrop(p, i));

    await tapBack(tester);
    await tapBack(tester);
    expectTitle('Project');
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
    expectTitle('Photo');
  });
}
