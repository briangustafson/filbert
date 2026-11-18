// End-to-end flows on an Android emulator (m1-design §8, m2-design §7):
// M1's photo editing, and M2's viewing aids and export.
//
//   flutter test integration_test -d emulator-5554
//
// `flutter test` uninstalls the app afterwards, deleting its data on the
// device: run it on an emulator only.
//
// Everything is real (database, files, rendering, OpenCV detection) except
// the system photo picker, which a test can't drive: a fake hands over a
// generated photo of a canvas. The database is in memory and files go to a
// temp folder, so the test itself never reads or writes the app's own data.
// Both flows are in one file so CI builds the app once.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:filbert/app/app.dart';
import 'package:filbert/app/router.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/device/device_info.dart';
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:filbert/core/settings/app_settings.dart';
import 'package:filbert/features/autocrop/autocrop_review_screen.dart';
import 'package:filbert/features/photo_viewer/photo_screen.dart';
import 'package:filbert/features/photos/data/image_repository.dart';
import 'package:filbert/features/photos/data/photo_source.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/projects/data/project_repository.dart';
import 'package:filbert/features/photo_viewer/photo_page.dart';
import 'package:filbert/features/view_aids/ui/shaded_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/support/synthetic_canvas.dart';

/// The app with a real, empty in-memory database and files in a temp
/// folder; only the photo picker is faked.
Future<({ProviderContainer container, AppDatabase db, FileStore files})>
_pumpApp(WidgetTester tester, {bool autoCrop = true}) async {
  final root = await Directory.systemTemp.createTemp('app_flow');
  addTearDown(() => root.delete(recursive: true));
  const clock = SystemClock();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (!autoCrop) await DriftSettingsStore(db).setAutoCropOnAdd(false);
  final files = LocalFileStore(
    supportDir: Directory('${root.path}/support'),
    cacheDir: Directory('${root.path}/cache'),
  );
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceInfoProvider.overrideWithValue(
        await StoredDeviceInfo.loadOrCreate(db, UuidV7IdGenerator(clock)),
      ),
      fileStoreProvider.overrideWithValue(files),
      photoSourceProvider.overrideWithValue(_SyntheticPhotoSource(root)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FilbertApp()),
  );
  return (container: container, db: db, files: files);
}

/// New project: created with a default name, opens its screen. Returns its
/// id.
Future<String> _newProject(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _tap(tester, find.text('New project'));
  await _pumpUntil(tester, find.text('Add photo'));
  return container
      .read(routerProvider)
      .routeInformationProvider
      .value
      .uri
      .pathSegments
      .last;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M1: new project → add photo → auto-crop review → apply → '
      'undo → redo → revert', (tester) async {
    final (:container, db: _, files: _) = await _pumpApp(tester);

    _phase('new project');
    final projectId = await _newProject(tester, container);

    _phase('add photo');
    // Add a photo: the auto-crop review opens ("Auto-crop photos when
    // added" is on by default) and detection fills in the corners.
    await _tap(tester, find.text('Add photo'));
    await _tap(tester, find.text('Choose from device'));
    await _pumpUntil(tester, find.byType(AutocropReviewScreen));
    _phase('waiting for detection');
    await _pumpUntil(tester, _enabledButton('Reset'));
    expect(
      find.textContaining("Couldn't find the canvas edges"),
      findsNothing,
      reason: 'detection should be confident on the synthetic canvas',
    );

    _phase('apply');
    // Apply: back on the project, the photo has the detected crop.
    await _tap(tester, find.text('Apply'));
    await _pumpUntil(tester, find.text('Add photo'));
    final images = container.read(imageRepositoryProvider);
    Future<ProjectImage> image() async =>
        (await images.watchForProject(projectId).first).single;
    final applied = (await image()).edits.crop;
    expect(applied, isNotNull);
    _expectNear(applied!.quad, SyntheticCanvas.normalizedCorners);

    // Undo, redo, revert from the photo screen's menu.
    _phase('photo screen');
    final imageId = (await image()).id;
    await _tap(tester, find.byKey(ValueKey(imageId)));
    await _pumpUntil(tester, find.byType(PhotoScreen));

    _phase('undo, redo, revert');
    await _menu(tester, 'Undo');
    expect((await image()).edits.crop, isNull, reason: 'undo');
    await _menu(tester, 'Redo');
    expect((await image()).edits.crop, isNotNull, reason: 'redo');
    await _menu(tester, 'Revert to original');
    await _pumpUntil(tester, find.text('Reverted to the original.'));
    expect((await image()).edits.crop, isNull, reason: 'revert');
    _phase('done');
  });

  testWidgets('M2: reference + photo → Values and Compare → save as new '
      'image', (tester) async {
    // Auto-crop is the M1 flow's; here photos go straight in.
    final (:container, :db, :files) = await _pumpApp(tester, autoCrop: false);

    _phase('M2 new project');
    final projectId = await _newProject(tester, container);

    _phase('M2 add reference and photo');
    await _tap(tester, find.text('Add reference'));
    await _tap(tester, find.text('Choose from device'));
    await _pumpUntil(tester, find.text('Add photo'));
    await _tap(tester, find.text('Add photo'));
    await _tap(tester, find.text('Choose from device'));
    final images = container.read(imageRepositoryProvider);
    Future<List<ProjectImage>> photos() =>
        images.watchForProject(projectId).first;
    await _waitFor(() async => (await photos()).length == 2);
    final project = await container
        .read(projectRepositoryProvider)
        .watch(projectId)
        .first;
    final referenceId = project!.referenceImageId!;
    final progress = (await photos()).firstWhere((p) => p.id != referenceId);

    _phase('M2 photo screen');
    await _tap(tester, find.byKey(ValueKey(progress.id)));
    await _pumpUntil(tester, find.byType(PhotoScreen));

    _phase('M2 Values and Compare');
    await _tapAid(tester, 'valueBands');
    await _tapAid(tester, 'compare');
    // The real shader, with the reference's preview blended in.
    await _pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is ShadedImage &&
            w.params.tone.bands == 5 &&
            w.params.compare?.opacity == 0.5 &&
            w.other != null,
      ),
    );

    _phase('M2 export as new image');
    await _tap(tester, find.byTooltip('Photo options'));
    await _tap(tester, find.text('Export…'));
    await _pumpUntil(tester, find.text('Values (5 bands)'));
    expect(find.text('Compare overlay'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('export-new-photo')));
    await _pumpUntil(
      tester,
      find.text('Saved as a new photo.'),
      timeout: const Duration(seconds: 60),
    );

    _phase('M2 check the new photo');
    final all = await photos();
    expect(all, hasLength(3));
    final derived = all.firstWhere((p) => p.origin == ImageOrigin.derived);
    final row = await (db.select(
      db.images,
    )..where((t) => t.id.equals(derived.id))).getSingle();
    final from = jsonDecode(row.derivedFromJson!) as Map<String, Object?>;
    expect(from['imageId'], progress.id);
    expect(from['aids'], {
      'tone': 'values',
      'bands': 5,
      'compareImageId': referenceId,
      'opacity': 0.5,
    });
    expect((derived.width, derived.height), (progress.width, progress.height));
    // Values on both photos mixed at 50 %: every pixel is a gray.
    final bytes = await files.blobFile(derived.blobId, 'jpg').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final rgba = (await image.toByteData())!.buffer.asUint8List();
    var worst = 0;
    for (var i = 0; i < rgba.length; i += 4) {
      final (r, g, b) = (rgba[i], rgba[i + 1], rgba[i + 2]);
      worst = math.max(worst, math.max((r - g).abs(), (g - b).abs()));
    }
    expect(worst, lessThanOrEqualTo(8), reason: 'JPEG noise only');

    _phase('M2 open it');
    await _tap(tester, find.text('Open'));
    await _pumpUntil(
      tester,
      find
          .byWidgetPredicate((w) => w is PhotoPage && w.image.id == derived.id)
          .hitTestable(),
    );
    _phase('M2 done');
  });
}

/// Taps the aid toolbar's [name] button, first showing the chrome if it
/// hid itself (after 3 s).
Future<void> _tapAid(WidgetTester tester, String name) async {
  final button = find.byKey(ValueKey('aid-$name'));
  await _pumpUntil(tester, button);
  if (button.hitTestable().evaluate().isEmpty) {
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Waits until [done] (checked every 100 ms), pumping frames.
Future<void> _waitFor(
  Future<bool> Function() done, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!await done()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Logs progress, so a CI run that hangs shows where.
void _phase(String name) => debugPrint('APP FLOW: $name');

/// Hands over the generated canvas photo, as the picker would: a temp file
/// that import copies and deletes.
class _SyntheticPhotoSource implements PhotoSource {
  _SyntheticPhotoSource(this._dir);

  final Directory _dir;
  var _count = 0;

  @override
  Future<List<PickedPhoto>> pickFromDevice({bool multiple = true}) async => [
    PickedPhoto(
      path: SyntheticCanvas.write('${_dir.path}/picked-${_count++}.jpg').path,
      origin: ImageOrigin.device,
    ),
  ];

  @override
  Future<PickedPhoto?> takePhoto() async => null;

  @override
  Future<List<PickedPhoto>> retrieveLost() async => const [];

  @override
  Future<void> clearLeftovers() async {}
}

/// Pumps frames until [finder] matches; work in isolates and drift streams
/// doesn't keep `pumpAndSettle` busy, so it can return too early.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _pumpUntil(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Opens the photo screen's menu and picks [item].
Future<void> _menu(WidgetTester tester, String item) async {
  await _tap(tester, find.byTooltip('Photo options'));
  await _tap(tester, find.text(item));
  // Let the edit reach the database.
  await tester.pump(const Duration(milliseconds: 300));
}

/// A button labelled [label] that can be pressed.
Finder _enabledButton(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (w) => w is ButtonStyleButton && w.onPressed != null,
  ),
);

void _expectNear(List<NormPoint> quad, List<(double, double)> truth) {
  for (var i = 0; i < 4; i++) {
    final (x, y) = truth[i];
    expect(
      math.max((quad[i].x - x).abs(), (quad[i].y - y).abs()),
      lessThan(0.01),
      reason: 'corner $i: ${quad[i]} vs ($x, $y)',
    );
  }
}
