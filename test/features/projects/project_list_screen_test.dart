import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/projects/ui/delete_project.dart';
import 'package:filbert/features/projects/ui/project_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_project_repository.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;

  setUp(() => projects = FakeProjectRepository());

  Finder card(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ProjectCard));

  Future<void> longPressAndDelete(WidgetTester tester, String name) async {
    await tester.longPress(card(name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, label),
  );

  testWidgets('empty state explains how to start', (tester) async {
    await pumpFilbertApp(tester, projects: projects);

    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('Tap New project to start one.'), findsOneWidget);
    expect(find.byType(ProjectCard), findsNothing);
    expect(
      find.widgetWithText(FloatingActionButton, 'New project'),
      findsOneWidget,
    );
  });

  testWidgets('shows projects newest first with name and date', (tester) async {
    projects
      ..seed('Old barn', updatedAt: DateTime.utc(2026, 3, 2, 12))
      ..seed('Harbor at dusk', updatedAt: DateTime.utc(2026, 11, 14, 12))
      ..seed('Pears', updatedAt: DateTime.utc(2026, 8, 20, 12));
    await pumpFilbertApp(tester, projects: projects);

    expect(find.text('No projects yet'), findsNothing);
    final names = tester
        .widgetList<ProjectCard>(find.byType(ProjectCard))
        .map((c) => c.project.name);
    expect(names, ['Harbor at dusk', 'Pears', 'Old barn']);
    expect(
      find.descendant(
        of: card('Harbor at dusk'),
        matching: find.text('Nov 14, 2026'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card('Old barn'), matching: find.text('Mar 2, 2026')),
      findsOneWidget,
    );
  });

  testWidgets('list updates when projects change', (tester) async {
    await pumpFilbertApp(tester, projects: projects);
    projects.seed('Arrived later');
    await tester.pumpAndSettle();
    expect(card('Arrived later'), findsOneWidget);
  });

  testWidgets('New project creates one and opens it', (tester) async {
    final container = await pumpFilbertApp(tester, projects: projects);

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();

    expect(projects.calls, ['create']);
    final created = projects.live.single;
    expect(
      container.read(routerProvider).state.uri.toString(),
      Routes.project(created.id),
    );
  });

  testWidgets('tapping a card opens the project', (tester) async {
    final p = projects.seed('Pears');
    final container = await pumpFilbertApp(tester, projects: projects);

    await tester.tap(card('Pears'));
    await tester.pumpAndSettle();

    expect(
      container.read(routerProvider).state.uri.toString(),
      Routes.project(p.id),
    );
  });

  testWidgets('long-press → Delete → confirm deletes, Undo restores', (
    tester,
  ) async {
    final p = projects.seed('Pears');
    projects.seed('Harbor');
    await pumpFilbertApp(tester, projects: projects);

    await longPressAndDelete(tester, 'Pears');
    expect(find.text('Delete “Pears”?'), findsOneWidget);

    await tester.tap(dialogButton('Delete'));
    await tester.pumpAndSettle();

    expect(projects.isDeleted(p.id), isTrue);
    expect(card('Pears'), findsNothing);
    expect(find.text('Deleted “Pears”'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();

    expect(projects.isDeleted(p.id), isFalse);
    expect(card('Pears'), findsOneWidget);
    expect(projects.calls, ['delete ${p.id}', 'restore ${p.id}']);
  });

  testWidgets('cancelling the confirm dialog keeps the project', (
    tester,
  ) async {
    projects.seed('Pears');
    await pumpFilbertApp(tester, projects: projects);

    await longPressAndDelete(tester, 'Pears');
    await tester.tap(dialogButton('Cancel'));
    await tester.pumpAndSettle();

    expect(projects.calls, isEmpty);
    expect(card('Pears'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('dismissing the menu does nothing', (tester) async {
    projects.seed('Pears');
    await pumpFilbertApp(tester, projects: projects);

    await tester.longPress(card('Pears'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(projects.calls, isEmpty);
  });

  testWidgets('undo snackbar goes away on its own', (tester) async {
    projects.seed('Pears');
    await pumpFilbertApp(tester, projects: projects);

    await longPressAndDelete(tester, 'Pears');
    await tester.tap(dialogButton('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pump(projectUndoDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
