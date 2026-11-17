import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:filbert/features/projects/ui/project_list_screen.dart';
import 'package:filbert/features/projects/ui/proportion_shape.dart';
import 'package:filbert/features/projects/ui/size_picker.dart';
import 'package:filbert/features/projects/ui/start_notes_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_project_repository.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late Project project;

  setUp(() {
    projects = FakeProjectRepository();
    project = projects.seed('Harbor');
  });

  Future<void> pumpProject(
    WidgetTester tester, {
    LengthUnit unit = LengthUnit.inches,
  }) => pumpFilbertApp(
    tester,
    projects: projects,
    preferredUnit: unit,
    initialLocation: Routes.project(project.id),
  );

  Project current() => projects.live.firstWhere((p) => p.id == project.id);

  group('name', () {
    testWidgets('tap to edit, Enter saves', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Harbor'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Harbor at dusk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(current().name, 'Harbor at dusk');
      expect(find.text('Harbor at dusk'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('leaving the field saves', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Harbor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pears');

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      expect(current().name, 'Pears');
    });

    testWidgets('tapping outside saves', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Harbor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pears');

      await tester.tapAt(const Offset(200, 500));
      await tester.pumpAndSettle();

      expect(current().name, 'Pears');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a blank name restores the previous one', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Harbor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(projects.calls, isEmpty);
      expect(find.text('Harbor'), findsOneWidget);
    });

    testWidgets('an unchanged name is not saved', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Harbor'));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(projects.calls, isEmpty);
    });
  });

  group('size', () {
    testWidgets('chip shows the size and opens the picker', (tester) async {
      await pumpProject(tester);
      expect(find.widgetWithText(ActionChip, 'No size'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'No size'));
      await tester.pumpAndSettle();
      expect(find.byType(SizePickerSheet), findsOneWidget);

      await tester.tap(find.text('Size').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '16 × 20'));
      await tester.pumpAndSettle();

      expect(current().size, const PhysicalSize(16, 20, LengthUnit.inches));
      expect(find.widgetWithText(ActionChip, '16 × 20 in'), findsOneWidget);
      final shape = tester.widget<ProportionShape>(
        find.descendant(
          of: find.byType(ActionChip),
          matching: find.byType(ProportionShape),
        ),
      );
      expect((shape.width, shape.height), (16, 20), reason: 'portrait shape');
    });

    testWidgets('picker uses the region unit for new sizes', (tester) async {
      await pumpProject(tester, unit: LengthUnit.centimeters);
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Size').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '40 × 50'), findsOneWidget);
    });
  });

  group('start notes', () {
    testWidgets('collapsed placeholder, expand, and auto-save after typing', (
      tester,
    ) async {
      await pumpProject(tester);
      expect(find.text('Add start notes'), findsOneWidget);

      await tester.tap(find.text('Add start notes'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Warm ground');
      await tester.pump(const Duration(milliseconds: 300));
      expect(current().startNotes, '');

      await tester.pump(StartNotesField.saveDelay);
      expect(current().startNotes, 'Warm ground');
      expect(projects.calls, hasLength(1));
    });

    testWidgets('saves immediately when focus leaves, then collapses', (
      tester,
    ) async {
      await pumpProject(tester);
      await tester.tap(find.text('Add start notes'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Limited palette');

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      expect(current().startNotes, 'Limited palette');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Limited palette'), findsOneWidget);
      expect(projects.calls, hasLength(1));
    });

    testWidgets('tapping outside saves and collapses', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Add start notes'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Thin layers');

      await tester.tapAt(const Offset(200, 500));
      await tester.pumpAndSettle();

      expect(current().startNotes, 'Thin layers');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('saves pending notes when leaving the screen', (tester) async {
      await pumpProject(tester);
      await tester.tap(find.text('Add start notes'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Unfinished thought');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectListScreen), findsOneWidget);
      expect(current().startNotes, 'Unfinished thought');
    });
  });

  testWidgets('Delete project → confirm → list with Undo', (tester) async {
    final container = await pumpFilbertApp(
      tester,
      projects: projects,
      initialLocation: Routes.project(project.id),
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete project'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Harbor”?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(projects.isDeleted(project.id), isTrue);
    expect(
      container.read(routerProvider).state.uri.toString(),
      Routes.projectList,
    );
    expect(find.text('Deleted “Harbor”'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(projects.isDeleted(project.id), isFalse);
    expect(find.text('Harbor'), findsOneWidget);
  });

  testWidgets('a missing project shows a way back', (tester) async {
    await pumpFilbertApp(
      tester,
      projects: projects,
      initialLocation: Routes.project('nope'),
    );
    expect(find.text('This project no longer exists.'), findsOneWidget);

    await tester.tap(find.text('Back to projects'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectListScreen), findsOneWidget);
  });
}
