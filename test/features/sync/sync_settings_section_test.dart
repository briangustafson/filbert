import 'package:filbert/app/routes.dart';
import 'package:filbert/core/auth/auth_service.dart';
import 'package:filbert/features/sync/data/sync_settings.dart';
import 'package:filbert/features/sync/ui/sync_settings_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_sync.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeAuthService auth;
  late FakeSyncSettingsStore store;

  setUp(() {
    auth = FakeAuthService();
    store = FakeSyncSettingsStore();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFilbertApp(
      tester,
      auth: auth,
      syncSettings: store,
      initialLocation: Routes.settings,
    );
  }

  Future<void> tapTurnOn(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Turn on'));
    await tester.pumpAndSettle();
  }

  testWidgets('off: explains sync and offers Turn on', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Sync with Google Drive'), findsOneWidget);
    expect(find.text(SyncSettingsSection.explanation), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('Turn on signs in, asks for Drive, and shows the account', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tapTurnOn(tester);

    expect(auth.calls, ['signIn', 'drive']);
    expect(store.settings.enabled, isTrue);
    expect(store.settings.account, 'painter@example.com');
    expect(find.text('painter@example.com'), findsOneWidget);
    expect(find.text('Pixel 11'), findsOneWidget, reason: 'device name');
    expect(find.text('Turn off sync'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Turn on when already signed in only asks for Drive', (
    tester,
  ) async {
    auth.signedIn = const AuthAccount('painter@example.com');
    await pumpSettings(tester);
    await tapTurnOn(tester);
    expect(auth.calls, ['drive']);
    expect(store.settings.enabled, isTrue);
  });

  testWidgets('cancelling the account picker leaves sync off quietly', (
    tester,
  ) async {
    auth.picks = null;
    await pumpSettings(tester);
    await tapTurnOn(tester);
    expect(auth.calls, ['signIn']);
    expect(store.settings.enabled, isFalse);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Turn on'), findsOneWidget);
  });

  testWidgets('declining Drive access leaves sync off and says why', (
    tester,
  ) async {
    auth.grantsDrive = false;
    await pumpSettings(tester);
    await tapTurnOn(tester);
    expect(store.settings.enabled, isFalse);
    expect(find.text(SyncSettingsSection.driveDeclinedMessage), findsOneWidget);
  });

  testWidgets('a failed sign-in says so', (tester) async {
    auth.failure = const AuthFailed('offline');
    await pumpSettings(tester);
    await tapTurnOn(tester);
    expect(store.settings.enabled, isFalse);
    expect(find.text(SyncSettingsSection.failedMessage), findsOneWidget);
  });

  testWidgets('Turn off sync keeps the sign-in', (tester) async {
    auth.signedIn = const AuthAccount('painter@example.com');
    store = FakeSyncSettingsStore(
      const SyncSettings(
        enabled: true,
        account: 'painter@example.com',
        deviceName: 'Pixel 11',
      ),
    );
    await pumpSettings(tester);
    await tester.tap(find.text('Turn off sync'));
    await tester.pumpAndSettle();

    expect(store.settings.enabled, isFalse);
    expect(auth.calls, isEmpty);
    expect(find.widgetWithText(FilledButton, 'Turn on'), findsOneWidget);
  });

  testWidgets('Sign out turns sync off and forgets the account', (
    tester,
  ) async {
    auth.signedIn = const AuthAccount('painter@example.com');
    store = FakeSyncSettingsStore(
      const SyncSettings(enabled: true, account: 'painter@example.com'),
    );
    await pumpSettings(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(store.settings.enabled, isFalse);
    expect(auth.calls, ['signOut']);
    expect(auth.signedIn, isNull);
  });

  testWidgets('signing in with another account starts afresh', (tester) async {
    store = FakeSyncSettingsStore(
      const SyncSettings(account: 'old@example.com'),
    );
    await pumpSettings(tester);
    await tapTurnOn(tester);
    expect(store.settings.account, 'painter@example.com');
    expect(store.forgotRemote, 1);
  });

  testWidgets('the device name is edited in a dialog', (tester) async {
    store = FakeSyncSettingsStore(
      const SyncSettings(
        enabled: true,
        account: 'painter@example.com',
        deviceName: 'Pixel 11',
      ),
    );
    await pumpSettings(tester);
    await tester.tap(find.text('Device name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Studio phone  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.settings.deviceName, 'Studio phone');
    expect(find.text('Studio phone'), findsOneWidget);

    // A blank name is ignored; Cancel changes nothing.
    await tester.tap(find.text('Device name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.settings.deviceName, 'Studio phone');
  });
}
