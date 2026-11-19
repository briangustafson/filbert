// Keyboard shortcuts (m3-design §3.3), mostly as on the Mac (⌘ is Meta),
// plus Ctrl on Android with a hardware keyboard.

import 'package:filbert/app/app.dart' show menuChannel;
import 'package:filbert/app/routes.dart';
import 'package:filbert/app/shortcuts.dart';
import 'package:filbert/features/crop/crop_screen.dart';
import 'package:filbert/features/photo_viewer/photo_page.dart';
import 'package:filbert/features/photo_viewer/photo_screen.dart';
import 'package:filbert/features/projects/ui/project_list_screen.dart';
import 'package:filbert/features/projects/ui/project_screen.dart';
import 'package:filbert/features/settings/settings_screen.dart';
import 'package:filbert/features/view_aids/data/view_aids_providers.dart';
import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_photos.dart';
import '../support/fake_project_repository.dart';
import '../support/fake_view_aids.dart';
import '../support/pump_app.dart';

final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakePhotoSource photoSource;
  late String projectId;
  late String a, b;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    photoSource = FakePhotoSource()..canTakePhoto = false;
    projectId = projects.seed('Still life').id;
    a = images.seed(projectId).id;
    b = images.seed(projectId).id;
  });

  Future<ProviderContainer> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      photoSource: photoSource,
      viewPrefs: FakeViewPrefsRepository(),
      palettes: FakePaletteService(),
      initialLocation: location,
    );
  }

  /// [key] with ⌘ on the Mac, Ctrl elsewhere (and Shift if [shift]).
  Future<void> command(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  /// Whether keyboard focus is inside what [finder] finds.
  bool focusIn(WidgetTester tester, Finder finder) {
    final target = tester.element(finder);
    final focused = primaryFocus?.context;
    if (focused == null) return false;
    if (focused == target) return true;
    var inside = false;
    focused.visitAncestorElements((e) {
      inside = e == target;
      return !inside;
    });
    return inside;
  }

  /// Tabs until focus is inside [finder].
  Future<void> tabTo(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20 && !focusIn(tester, finder); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusIn(tester, finder), isTrue, reason: 'reached by Tab');
  }

  group('everywhere', () {
    testWidgets('⌘, opens Settings, and Esc goes back', (tester) async {
      await open(tester, Routes.project(projectId));
      await command(tester, LogicalKeyboardKey.comma);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(ProjectListScreen), findsOneWidget);
    }, variant: mac);

    testWidgets('Settings… in the Mac menu opens Settings', (tester) async {
      await open(tester, Routes.projectList);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        menuChannel.name,
        menuChannel.codec.encodeMethodCall(const MethodCall('settings')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }, variant: mac);
  });

  group('project list', () {
    testWidgets('⌘N starts a project', (tester) async {
      await open(tester, Routes.projectList);
      await command(tester, LogicalKeyboardKey.keyN);
      expect(projects.calls, contains('create'));
      expect(find.byType(ProjectScreen), findsOneWidget);
    }, variant: mac);

    testWidgets('Return opens the focused project', (tester) async {
      await open(tester, Routes.projectList);
      await tabTo(tester, find.byType(ProjectCard));
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(ProjectScreen), findsOneWidget);
    }, variant: mac);

    testWidgets('the New project button names its keys', (tester) async {
      await open(tester, Routes.projectList);
      expect(find.byTooltip('New project (⌘N)'), findsOneWidget);
    }, variant: mac);
  });

  group('project screen', () {
    testWidgets('⌘O adds photos', (tester) async {
      await open(tester, Routes.project(projectId));
      await command(tester, LogicalKeyboardKey.keyO);
      expect(photoSource.calls, contains('pickFromDevice multiple=true'));
    }, variant: mac);

    testWidgets('Esc goes back to the projects', (tester) async {
      await open(tester, Routes.project(projectId));
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ProjectScreen), findsNothing);
      expect(find.byType(ProjectListScreen), findsOneWidget);
    }, variant: mac);

    testWidgets('Delete deletes the focused photo, with Undo', (tester) async {
      await open(tester, Routes.project(projectId));
      final tile = find.byKey(ValueKey(b));
      await tabTo(tester, tile);
      await press(tester, LogicalKeyboardKey.backspace);
      expect(images.calls, contains('delete $b'));
      expect(images.calls, isNot(contains('delete $a')));
      expect(find.text('Photo deleted.'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(images.calls, contains('restore $b'));
    }, variant: mac);

    testWidgets('typing in a field is left alone; Esc leaves the field', (
      tester,
    ) async {
      await open(tester, Routes.project(projectId));
      final name = find.byKey(ValueKey('name-$projectId'));
      await tester.tap(name);
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.backspace);
      expect(images.calls.where((c) => c.startsWith('delete')), isEmpty);

      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ProjectScreen), findsOneWidget, reason: 'stayed');
      expect(focusIn(tester, name), isFalse);
      // Esc again, with no field focused, goes back.
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ProjectListScreen), findsOneWidget);
    }, variant: mac);
  });

  group('photo screen', () {
    String shown(WidgetTester tester) =>
        tester.widget<PhotoPage>(find.byType(PhotoPage).hitTestable()).image.id;

    ViewAids aids(ProviderContainer c) =>
        c.read(viewAidsStateProvider(projectId));

    testWidgets('← and → move between photos', (tester) async {
      await open(tester, Routes.photo(projectId, a));
      final first = shown(tester);
      // Two photos: one of the arrows has nowhere to go.
      var forward = LogicalKeyboardKey.arrowRight;
      var back = LogicalKeyboardKey.arrowLeft;
      await press(tester, forward);
      if (shown(tester) == first) (forward, back) = (back, forward);
      if (shown(tester) == first) await press(tester, forward);
      expect({first, shown(tester)}, {a, b});
      await press(tester, forward);
      expect(shown(tester), isNot(first), reason: 'already at the end');
      await press(tester, back);
      expect(shown(tester), first);
    }, variant: mac);

    testWidgets('a letter turns each aid on and off', (tester) async {
      final c = await open(tester, Routes.photo(projectId, a));
      await press(tester, LogicalKeyboardKey.keyG);
      expect(aids(c).grid, isTrue);
      await press(tester, LogicalKeyboardKey.keyB);
      expect(aids(c).tone, ToneAid.gray);
      await press(tester, LogicalKeyboardKey.keyV);
      expect(aids(c).tone, ToneAid.valueBands);
      await press(tester, LogicalKeyboardKey.keyC);
      expect(aids(c).tone, ToneAid.colors);
      await press(tester, LogicalKeyboardKey.keyO);
      expect(aids(c).compare, isTrue);
      // As tapping: the first press opens Grid's panel, the next turns it
      // off.
      await press(tester, LogicalKeyboardKey.keyG);
      await press(tester, LogicalKeyboardKey.keyG);
      expect(aids(c).grid, isFalse);
    }, variant: mac);

    testWidgets('Esc closes a panel, then goes back', (tester) async {
      final c = await open(tester, Routes.photo(projectId, a));
      await press(tester, LogicalKeyboardKey.keyV); // Opens its panel.
      expect(aids(c).panel, isNotNull);
      await press(tester, LogicalKeyboardKey.escape);
      expect(aids(c).panel, isNull);
      expect(aids(c).tone, ToneAid.valueBands, reason: 'still on');
      expect(find.byType(PhotoScreen), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(PhotoScreen), findsNothing);
      expect(find.byType(ProjectScreen), findsOneWidget);
    }, variant: mac);

    testWidgets('⌘Z undoes and ⇧⌘Z redoes', (tester) async {
      await open(tester, Routes.photo(projectId, a));
      await command(tester, LogicalKeyboardKey.keyZ);
      await command(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(images.calls, containsAllInOrder(['undo $a', 'redo $a']));
    }, variant: mac);

    testWidgets('⌘E opens Export…', (tester) async {
      await open(tester, Routes.photo(projectId, a));
      await command(tester, LogicalKeyboardKey.keyE);
      expect(find.text('Full size, as a JPEG.'), findsOneWidget);
    }, variant: mac);

    testWidgets('holding Space shows the original', (tester) async {
      await open(tester, Routes.photo(projectId, a));
      await press(tester, LogicalKeyboardKey.keyG); // Something to hide.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('Original'), findsOneWidget);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('Original'), findsOneWidget);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('Original'), findsNothing);
    }, variant: mac);

    testWidgets('⌘= zooms in, ⌘− out, ⌘0 fits', (tester) async {
      await open(tester, Routes.photo(projectId, a));
      double scale() => tester
          .widget<InteractiveViewer>(
            find.byType(InteractiveViewer).hitTestable(),
          )
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      await command(tester, LogicalKeyboardKey.equal);
      expect(scale(), closeTo(PhotoZoomController.step, 1e-6));
      await command(tester, LogicalKeyboardKey.equal, shift: true); // ⌘+
      expect(
        scale(),
        closeTo(PhotoZoomController.step * PhotoZoomController.step, 1e-6),
      );
      await command(tester, LogicalKeyboardKey.minus);
      expect(scale(), closeTo(PhotoZoomController.step, 1e-6));
      await command(tester, LogicalKeyboardKey.digit0);
      expect(scale(), closeTo(1, 1e-6));
      await command(tester, LogicalKeyboardKey.minus);
      expect(scale(), closeTo(1, 1e-6), reason: 'never below fit');
    }, variant: mac);

    testWidgets('tooltips name the keys on the Mac', (tester) async {
      await open(tester, Routes.photo(projectId, a));
      expect(find.byTooltip('Back (Esc)'), findsOneWidget);
      expect(find.byTooltip('Grid (G)'), findsOneWidget);
      expect(find.byTooltip('Compare (O)'), findsOneWidget);
    }, variant: mac);

    testWidgets('on Android, Ctrl works and tooltips stay short', (
      tester,
    ) async {
      final c = await open(tester, Routes.photo(projectId, a));
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(images.calls, contains('undo $a'));
      await press(tester, LogicalKeyboardKey.keyG);
      expect(aids(c).grid, isTrue);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Grid (G)'), findsNothing);
    });
  });

  group('crop screen', () {
    testWidgets('Return applies', (tester) async {
      await open(tester, Routes.crop(projectId, a));
      expect(find.byType(CropScreen), findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter);
      expect(images.calls, contains('setEdits $a'));
      expect(find.byType(CropScreen), findsNothing);
    }, variant: mac);

    testWidgets('Esc cancels', (tester) async {
      await open(tester, Routes.crop(projectId, a));
      await press(tester, LogicalKeyboardKey.escape);
      expect(images.calls.where((c) => c.startsWith('setEdits')), isEmpty);
      expect(find.byType(CropScreen), findsNothing);
      expect(find.byType(PhotoScreen), findsOneWidget);
    }, variant: mac);
  });

  group('KeyBindings', () {
    testWidgets('letters type into a field instead', (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: KeyBindings(
            bindings: [
              KeyBinding(
                const SingleActivator(LogicalKeyboardKey.keyG),
                () => presses++,
              ),
              KeyBinding(
                const SingleActivator(LogicalKeyboardKey.keyN, control: true),
                () => presses += 10,
                whileTyping: true,
              ),
            ],
            child: const Scaffold(body: TextField()),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      expect(presses, 1, reason: 'no field focused');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      // Left unhandled, so it reaches the field as text.
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyG), isFalse);
      expect(presses, 1, reason: 'typing');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(presses, 11, reason: 'whileTyping still works');
    });
  });
}
