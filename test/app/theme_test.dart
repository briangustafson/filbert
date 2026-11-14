import 'package:filbert/app/app.dart';
import 'package:filbert/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('light and dark themes are Material 3 with matching brightness', () {
    expect(FilbertTheme.light.useMaterial3, isTrue);
    expect(FilbertTheme.light.colorScheme.brightness, Brightness.light);
    expect(FilbertTheme.dark.useMaterial3, isTrue);
    expect(FilbertTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  test('palette is neutral (no saturated accents)', () {
    for (final scheme in [
      FilbertTheme.light.colorScheme,
      FilbertTheme.dark.colorScheme,
    ]) {
      for (final color in [
        scheme.primary,
        scheme.secondary,
        scheme.tertiary,
        scheme.surface,
        scheme.primaryContainer,
      ]) {
        expect(
          HSLColor.fromColor(color).saturation,
          lessThan(0.1),
          reason: '$color should be near-gray',
        );
      }
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('app follows system brightness: $brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const ProviderScope(child: FilbertApp()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, brightness);
    });
  }
}
