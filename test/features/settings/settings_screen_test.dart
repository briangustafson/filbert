import 'package:filbert/app/routes.dart';
import 'package:filbert/core/settings/app_settings.dart';
import 'package:filbert/core/units/unit_preference.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/fake_settings.dart';
import '../../support/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSettingsStore settings;

  setUp(() => settings = FakeSettingsStore());

  Future<void> pumpSettings(WidgetTester tester) => pumpFilbertApp(
    tester,
    settings: settings,
    initialLocation: Routes.settings,
  );

  testWidgets('opens from the project list menu', (tester) async {
    await pumpFilbertApp(tester, settings: settings);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Auto-crop photos when added'), findsOneWidget);
  });

  testWidgets('the auto-crop switch is saved', (tester) async {
    await pumpSettings(tester);
    Switch toggle() => tester.widget<Switch>(find.byType(Switch));
    expect(toggle().value, isTrue, reason: 'on by default');

    await tester.tap(find.text('Auto-crop photos when added'));
    await tester.pumpAndSettle();
    expect(settings.settings.autoCropOnAdd, isFalse);
    expect(toggle().value, isFalse);
  });

  testWidgets('Units: pick from a dialog', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Automatic'), findsOneWidget);

    await tester.tap(find.text('Units'));
    await tester.pumpAndSettle();
    expect(find.text('From your region'), findsOneWidget);
    await tester.tap(find.text('Centimeters'));
    await tester.pumpAndSettle();

    expect(settings.settings.units, UnitsSetting.centimeters);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Centimeters'), findsOneWidget, reason: 'subtitle');
  });

  testWidgets('About shows the version and licenses', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Filbert',
      packageName: 'com.example.filbert',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
    await pumpSettings(tester);
    await tester.tap(find.text('About Filbert'));
    await tester.pumpAndSettle();
    expect(find.text('1.2.3 (4)'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
  });

  group('the unit for new sizes', () {
    test('follows the setting once loaded', () async {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(
            FakeSettingsStore(
              const AppSettings(units: UnitsSetting.centimeters),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // A provider nobody listens to is paused in Riverpod 3.
      container.listen(preferredLengthUnitProvider, (_, _) {});
      await container.read(appSettingsProvider.future);
      expect(
        container.read(preferredLengthUnitProvider),
        LengthUnit.centimeters,
      );
    });

    test('Automatic uses the region', () async {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
        ],
      );
      addTearDown(container.dispose);
      // A provider nobody listens to is paused in Riverpod 3.
      container.listen(preferredLengthUnitProvider, (_, _) {});
      await container.read(appSettingsProvider.future);
      expect(
        container.read(preferredLengthUnitProvider),
        lengthUnitForRegion(
          TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .locale
              .countryCode,
        ),
      );
    });
  });
}
