import 'package:filbert/features/projects/domain/project.dart';
import 'package:filbert/features/projects/ui/proportion_shape.dart';
import 'package:filbert/features/projects/ui/size_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late List<ProjectSize> saved;

  setUp(() => saved = []);

  Future<void> open(
    WidgetTester tester, {
    ProjectSize initial = const NoSize(),
    LengthUnit defaultUnit = LengthUnit.inches,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSizePicker(
                context,
                initial: initial,
                defaultUnit: defaultUnit,
                onChanged: saved.add,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(chip(label)).selected;
  bool sheetOpen() => find.byType(SizePickerSheet).evaluate().isNotEmpty;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('starts on None for a project without a size', (tester) async {
    await open(tester);
    expect(find.textContaining('No size set'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('presets say which number is the width', (tester) async {
    await open(tester);
    await tapText(tester, 'Size');
    expect(find.text('Width × height'), findsOneWidget);
    await tapText(tester, 'Aspect ratio');
    expect(find.text('Width : height'), findsOneWidget);
  });

  testWidgets('each preset shows its shape, turned with the orientation', (
    tester,
  ) async {
    ProportionShape shapeOf(String label) => tester.widget(
      find.descendant(of: chip(label), matching: find.byType(ProportionShape)),
    );
    await open(tester);
    await tapText(tester, 'Size');
    expect(
      (shapeOf('9 × 12').width, shapeOf('9 × 12').height),
      (9, 12),
      reason: 'portrait: taller than wide',
    );

    await tapText(tester, 'Landscape');
    expect((shapeOf('12 × 9').width, shapeOf('12 × 9').height), (12, 9));
  });

  testWidgets('tapping a size preset saves it and closes', (tester) async {
    await open(tester);
    await tapText(tester, 'Size');
    expect(chip('11 × 14'), findsOneWidget);

    await tester.tap(chip('11 × 14'));
    await tester.pumpAndSettle();

    expect(saved, [const PhysicalSize(11, 14, LengthUnit.inches)]);
    expect(sheetOpen(), isFalse);
  });

  testWidgets('presets follow the default unit and the unit toggle', (
    tester,
  ) async {
    await open(tester, defaultUnit: LengthUnit.centimeters);
    await tapText(tester, 'Size');
    expect(chip('50 × 70'), findsOneWidget);
    expect(chip('11 × 14'), findsNothing);

    await tapText(tester, 'in');
    expect(chip('11 × 14'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('landscape shows and saves presets turned', (tester) async {
    await open(tester);
    await tapText(tester, 'Aspect ratio');
    await tapText(tester, 'Landscape');
    expect(chip('5:4'), findsOneWidget);

    await tester.tap(chip('5:4'));
    await tester.pumpAndSettle();
    expect(saved, [const RatioSize(5, 4)]);
  });

  testWidgets('current preset is highlighted', (tester) async {
    await open(tester, initial: const PhysicalSize(14, 11, LengthUnit.inches));
    expect(isSelected(tester, '14 × 11'), isTrue);
    expect(isSelected(tester, '16 × 12'), isFalse);
    expect(
      tester
          .widget<SegmentedButton<Object>>(
            find.byWidgetPredicate(
              (w) =>
                  w is SegmentedButton &&
                  w.selected.contains(SizeMode.physical),
            ),
          )
          .selected,
      {SizeMode.physical},
    );
  });

  testWidgets('orientation toggle re-saves the current size right away', (
    tester,
  ) async {
    await open(tester, initial: const PhysicalSize(11, 14, LengthUnit.inches));
    await tapText(tester, 'Landscape');

    expect(saved, [const PhysicalSize(14, 11, LengthUnit.inches)]);
    expect(sheetOpen(), isTrue);
    expect(isSelected(tester, '14 × 11'), isTrue);
  });

  testWidgets('orientation toggle does not re-save a square', (tester) async {
    await open(tester, initial: const RatioSize(1, 1));
    await tapText(tester, 'Landscape');
    expect(saved, isEmpty);
  });

  testWidgets('custom size: validates, then saves on Save', (tester) async {
    await open(tester, defaultUnit: LengthUnit.centimeters);
    await tapText(tester, 'Size');
    await tester.tap(chip('Custom'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('custom-width')), '45');
    await tester.enterText(find.byKey(const ValueKey('custom-height')), '0');
    await tester.pump();
    expect(find.text('Enter 0.1–1000'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('custom-height')), '60.5');
    await tester.pump();
    expect(find.text('Enter 0.1–1000'), findsNothing);

    // At the test's 800 × 600 the picker is a dialog (m3-design §3.2) whose
    // Save sits below the fold.
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, [const PhysicalSize(45, 60.5, LengthUnit.centimeters)]);
    expect(sheetOpen(), isFalse);
  });

  testWidgets('custom ratio accepts decimals', (tester) async {
    await open(tester);
    await tapText(tester, 'Aspect ratio');
    await tester.tap(chip('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('custom-width')), '1');
    await tester.enterText(
      find.byKey(const ValueKey('custom-height')),
      '1.618',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(saved, [const RatioSize(1, 1.618)]);
  });

  testWidgets('a non-preset size opens Custom pre-filled', (tester) async {
    await open(tester, initial: const PhysicalSize(13, 17, LengthUnit.inches));
    expect(isSelected(tester, 'Custom'), isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('custom-width')))
          .controller!
          .text,
      '13',
    );
  });

  testWidgets('None clears the size and closes', (tester) async {
    await open(tester, initial: const RatioSize(4, 5));
    await tapText(tester, 'None');
    expect(saved, [const NoSize()]);
    expect(sheetOpen(), isFalse);
  });

  testWidgets('closing without choosing changes nothing', (tester) async {
    await open(tester, initial: const RatioSize(4, 5));
    await tapText(tester, 'Size');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(sheetOpen(), isFalse);
    expect(saved, isEmpty);
  });
}
