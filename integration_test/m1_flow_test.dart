// M1 end-to-end flow on an Android emulator (m1-design §8):
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

import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:filbert/app/app.dart';
import 'package:filbert/app/router.dart';
import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/core/db/app_database.dart';
import 'package:filbert/core/device/device_info.dart';
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/core/ids/id_generator.dart';
import 'package:filbert/features/autocrop/autocrop_review_screen.dart';
import 'package:filbert/features/photo_viewer/photo_screen.dart';
import 'package:filbert/features/photos/data/image_repository.dart';
import 'package:filbert/features/photos/data/photo_source.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/support/synthetic_canvas.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new project → add photo → auto-crop review → apply → undo → '
      'redo → revert', (tester) async {
    final root = await Directory.systemTemp.createTemp('m1_flow');
    addTearDown(() => root.delete(recursive: true));
    const clock = SystemClock();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceInfoProvider.overrideWithValue(
          await StoredDeviceInfo.loadOrCreate(db, UuidV7IdGenerator(clock)),
        ),
        fileStoreProvider.overrideWithValue(
          LocalFileStore(
            supportDir: Directory('${root.path}/support'),
            cacheDir: Directory('${root.path}/cache'),
          ),
        ),
        photoSourceProvider.overrideWithValue(_SyntheticPhotoSource(root)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FilbertApp(),
      ),
    );

    // New project: created with a default name, opens its screen.
    await _tap(tester, find.text('New project'));
    await _pumpUntil(tester, find.text('Add photo'));
    final projectId = container
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .pathSegments
        .last;

    // Add a photo: the auto-crop review opens ("Auto-crop photos when
    // added" is on by default) and detection fills in the corners.
    await _tap(tester, find.text('Add photo'));
    await _tap(tester, find.text('Choose from device'));
    await _pumpUntil(tester, find.byType(AutocropReviewScreen));
    await _pumpUntil(tester, _enabledButton('Reset'));
    expect(
      find.textContaining("Couldn't find the canvas edges"),
      findsNothing,
      reason: 'detection should be confident on the synthetic canvas',
    );

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
    final imageId = (await image()).id;
    await _tap(tester, find.byKey(ValueKey(imageId)));
    await _pumpUntil(tester, find.byType(PhotoScreen));

    await _menu(tester, 'Undo');
    expect((await image()).edits.crop, isNull, reason: 'undo');
    await _menu(tester, 'Redo');
    expect((await image()).edits.crop, isNotNull, reason: 'redo');
    await _menu(tester, 'Revert to original');
    await _pumpUntil(tester, find.text('Reverted to the original.'));
    expect((await image()).edits.crop, isNull, reason: 'revert');
  });
}

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
