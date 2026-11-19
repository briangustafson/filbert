// The export sheet (m2-design §3.5): the Include checklist, Save to
// gallery, Save as new image, progress, errors; the RenderService and the
// gallery are fakes. Save to file… (m3-design §3.5) uses the real
// FileExportDestination with a fake save dialog and a temp folder.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:filbert/app/routes.dart';
import 'package:filbert/core/settings/app_settings.dart';
import 'package:filbert/features/export/data/export_destination.dart';
import 'package:filbert/features/export/data/gallery_saver.dart';
import 'package:filbert/features/export/domain/gallery_file_name.dart';
import 'package:filbert/features/photo_viewer/photo_page.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_export.dart';
import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings.dart';
import '../../support/fake_view_aids.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakeViewPrefsRepository prefs;
  late FakeRenderService exports;
  late FakeGallerySaver gallery;
  late FakeSystemSettings settings;
  late FakeSettingsStore store;
  ExportDestination? destination;
  late String projectId;
  late ProjectImage reference, photo;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    prefs = FakeViewPrefsRepository();
    exports = FakeRenderService();
    gallery = FakeGallerySaver();
    settings = FakeSystemSettings();
    store = FakeSettingsStore(const AppSettings(autoCropOnAdd: false));
    destination = null;
    projectId = projects.seed('Harbour: dusk?').id;
    reference = images.seed(projectId, asReference: true);
    photo = images.seed(projectId);
  });

  for (final narrow in [false, true]) {
    group(narrow ? 'narrow phone (400 dp)' : 'normal screen', () {
      Future<void> open(
        WidgetTester tester, {
        List<Aid> aids = const [],
      }) async {
        if (narrow) {
          tester.view.physicalSize = const Size(400, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
        }
        await pumpFilbertApp(
          tester,
          projects: projects,
          images: images,
          renderer: FakeImageRenderer(file: fixtureImage('plain.png')),
          viewPrefs: prefs,
          exports: exports,
          gallery: gallery,
          settings: store,
          exportDestination: destination,
          systemSettings: settings,
          initialLocation: Routes.photo(projectId, photo.id),
        );
        for (final aid in aids) {
          await tester.tap(find.byKey(ValueKey('aid-${aid.name}')));
          await tester.pumpAndSettle();
        }
        // The chrome may have hidden; show it, then the menu.
        if (find.byTooltip('Photo options').hitTestable().evaluate().isEmpty) {
          await tester.tapAt(const Offset(200, 300));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Photo options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export…'));
        await tester.pumpAndSettle();
      }

      Finder include(String item) =>
          find.byKey(ValueKey('export-include-$item'));

      Future<void> tap(WidgetTester tester, Finder f) async {
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      testWidgets('no aids: no checklist; exports the plain photo', (
        tester,
      ) async {
        await open(tester);
        expect(find.text('Include'), findsNothing);
        await tap(tester, find.byKey(const ValueKey('export-gallery')));
        final (image, options) = exports.requests.single;
        expect(image, photo);
        expect(options.hasAids, isFalse);
        expect(find.text('Saved to the gallery.'), findsOneWidget);
        expect(find.text('Export'), findsNothing, reason: 'sheet closed');
        expect(tester.takeException(), isNull);
      });

      testWidgets('the aids that are on are listed, checked', (tester) async {
        prefs.update(projectId, const ViewPrefs(values: ValuesPrefs(bands: 6)));
        await open(tester, aids: [Aid.grid, Aid.valueBands, Aid.compare]);
        expect(find.text('Grid'), findsWidgets);
        expect(find.text('Values (6 bands)'), findsOneWidget);
        expect(find.text('Compare overlay'), findsOneWidget);
        for (final item in ['grid', 'tone', 'compare']) {
          expect(tester.widget<CheckboxListTile>(include(item)).value, isTrue);
        }
        await tap(tester, find.byKey(const ValueKey('export-gallery')));
        final options = exports.requests.single.$2;
        expect(options.grid, isNotNull);
        expect((options.tone, options.bands), (ToneAid.valueBands, 6));
        expect(options.compareWith, reference);
        expect(tester.takeException(), isNull);
      });

      testWidgets('unchecked items are left out', (tester) async {
        await open(tester, aids: [Aid.grid, Aid.gray]);
        expect(include('compare'), findsNothing);
        await tap(tester, include('grid'));
        await tap(tester, find.byKey(const ValueKey('export-gallery')));
        final options = exports.requests.single.$2;
        expect(options.grid, isNull);
        expect(options.tone, ToneAid.gray);
      });

      group('Save to file… (the Mac)', () {
        late Directory folder;
        late List<({String name, String? initial})> dialogs;
        late List<String> revealed;
        String? Function(String name)? answer;

        /// Taps Save to file…; the copy is real file I/O, which needs real
        /// time to finish.
        Future<void> saveToFile(WidgetTester tester) async {
          final button = find.byKey(const ValueKey('export-file'));
          await tester.ensureVisible(button);
          await tester.tap(button);
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
            if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
          }
          await tester.pumpAndSettle();
        }

        setUp(() {
          folder = Directory.systemTemp.createTempSync('export');
          addTearDown(() => folder.deleteSync(recursive: true));
          dialogs = [];
          revealed = [];
          answer = (name) => '${folder.path}/$name';
          gallery.available = false;
          destination = FileExportDestination(
            store,
            picturesFolder: '/Users/me/Pictures',
            dialog: ({required suggestedName, initialDirectory}) async {
              dialogs.add((name: suggestedName, initial: initialDirectory));
              return answer?.call(suggestedName);
            },
          );
        });

        testWidgets('saves where the dialog says, then shows it in Finder', (
          tester,
        ) async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(const MethodChannel('filbert/finder'), (
                call,
              ) async {
                if (call.method == 'reveal') {
                  revealed.add(call.arguments as String);
                }
                return null;
              });
          addTearDown(
            () => TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('filbert/finder'),
                  null,
                ),
          );
          await open(tester);
          expect(find.byKey(const ValueKey('export-gallery')), findsNothing);
          await saveToFile(tester);

          final dialog = dialogs.single;
          expect(dialog.name, startsWith('Harbour dusk-'));
          expect(dialog.name, endsWith('.jpg'));
          expect(dialog.initial, '/Users/me/Pictures', reason: 'first time');
          final saved = File('${folder.path}/${dialog.name}');
          expect(saved.readAsBytesSync(), exports.file.readAsBytesSync());
          expect(store.folder, folder.path, reason: 'remembered');

          expect(find.text('Saved.'), findsOneWidget);
          await tester.tap(find.text('Show in Finder'));
          await tester.pumpAndSettle();
          expect(revealed, [saved.path]);
        });

        testWidgets('the dialog opens where the last export went', (
          tester,
        ) async {
          store.folder = '/Users/me/Exports';
          await open(tester);
          await saveToFile(tester);
          expect(dialogs.single.initial, '/Users/me/Exports');
        });

        testWidgets('a cancelled dialog renders nothing; the sheet stays', (
          tester,
        ) async {
          answer = null;
          await open(tester);
          await saveToFile(tester);
          expect(dialogs, hasLength(1));
          expect(exports.requests, isEmpty);
          expect(find.text('Full size, as a JPEG.'), findsOneWidget);
          expect(store.folder, isNull);
        });

        testWidgets('a write error shows in the sheet', (tester) async {
          answer = (name) => '${folder.path}/missing/$name';
          await open(tester);
          await saveToFile(tester);
          expect(find.text("Couldn't save the file."), findsOneWidget);
          expect(store.folder, isNull);
        });

        testWidgets('Save as new image is still there', (tester) async {
          await open(tester);
          await tap(tester, find.byKey(const ValueKey('export-new-photo')));
          expect(find.text('Saved as a new photo.'), findsOneWidget);
        });
      });

      testWidgets('saves to the Filbert album with the file name rule', (
        tester,
      ) async {
        await open(tester);
        await tap(tester, find.byKey(const ValueKey('export-gallery')));
        final saved = gallery.saved.single;
        expect(saved.album, 'Filbert');
        expect(saved.fileName, startsWith('Harbour dusk-'));
        expect(saved.fileName, endsWith('.jpg'));
      });

      testWidgets('save as new image, then Open shows it', (tester) async {
        await open(tester, aids: [Aid.gray]);
        await tap(tester, find.byKey(const ValueKey('export-new-photo')));
        expect(images.calls, contains('importDerived $projectId'));
        final newId = images.derivedFrom.keys.single;
        final json = jsonDecode(images.derivedFrom[newId]!) as Map;
        expect(json['imageId'], photo.id);
        expect(json['aids'], {'tone': 'gray'});
        expect(find.text('Saved as a new photo.'), findsOneWidget);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final shown = tester
            .widget<PhotoPage>(find.byType(PhotoPage).hitTestable())
            .image
            .id;
        expect(shown, newId);
      });

      testWidgets('busy: progress, and the sheet stays open', (tester) async {
        exports.gate = Completer<void>();
        await open(tester);
        await tester.tap(find.byKey(const ValueKey('export-gallery')));
        await tester.pump();
        expect(find.text('Exporting at full size…'), findsOneWidget);
        expect(find.byKey(const ValueKey('export-gallery')), findsNothing);

        // Tapping outside and Back don't close it.
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Exporting at full size…'), findsOneWidget);

        exports.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Saved to the gallery.'), findsOneWidget);
      });

      testWidgets('a render error shows in the sheet; trying again works', (
        tester,
      ) async {
        exports.failNext = Exception('out of memory');
        await open(tester);
        await tap(tester, find.byKey(const ValueKey('export-gallery')));
        expect(find.text("Couldn't export this photo."), findsOneWidget);
        expect(find.text('Export'), findsOneWidget, reason: 'still open');
        await tap(tester, find.byKey(const ValueKey('export-gallery')));
        expect(gallery.saved, hasLength(1));
      });

      testWidgets('permission refused: a Settings button', (tester) async {
        gallery.failNext = GallerySaveFailure.permissionDenied;
        await open(tester);
        await tap(tester, find.byKey(const ValueKey('export-gallery')));
        expect(
          find.text('Filbert needs permission to save to the gallery.'),
          findsOneWidget,
        );
        await tap(tester, find.text('Settings'));
        expect(settings.opened, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('saving the new photo fails: the sheet says so', (
        tester,
      ) async {
        images.failDerived = Exception('disk full');
        await open(tester);
        await tap(tester, find.byKey(const ValueKey('export-new-photo')));
        expect(find.text("Couldn't save the new photo."), findsOneWidget);
      });
    });
  }

  group('galleryFileName', () {
    final t = DateTime(2026, 11, 18, 9, 5, 7);

    test('name and local time', () {
      expect(
        galleryFileName('Still life', t),
        'Still life-20261118-090507.jpg',
      );
    });

    test('drops characters not allowed in file names', () {
      expect(
        galleryFileName(r'a/b\c:d*e?f"g<h>i|j', t),
        'abcdefghij-20261118-090507.jpg',
      );
      expect(galleryFileName('..hidden', t), 'hidden-20261118-090507.jpg');
      expect(
        galleryFileName('  two   spaces ', t),
        'two spaces-20261118-090507.jpg',
      );
    });

    test('an empty name becomes Filbert; long names are shortened', () {
      expect(galleryFileName(' ?* ', t), 'Filbert-20261118-090507.jpg');
      final long = galleryFileName('x' * 300, t);
      expect(long, '${'x' * 100}-20261118-090507.jpg');
    });
  });
}
