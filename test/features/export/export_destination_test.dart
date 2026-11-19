import 'package:filbert/core/settings/app_settings.dart';
import 'package:filbert/features/export/data/export_destination.dart';
import 'package:filbert/features/export/data/gallery_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_export.dart';
import '../../support/fake_settings.dart';
import '../../support/fixtures.dart';

void main() {
  ExportDestination destinationWith(FakeGallerySaver gallery) {
    final container = ProviderContainer(
      overrides: [
        gallerySaverProvider.overrideWithValue(gallery),
        settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
      ],
    );
    addTearDown(container.dispose);
    return container.read(exportDestinationProvider);
  }

  test('with a gallery (Android), exports go to its Filbert album', () async {
    final gallery = FakeGallerySaver();
    final destination = destinationWith(gallery);
    expect(destination.kind, ExportDestinationKind.gallery);
    expect(await destination.chooseLocation('a.jpg'), 'a.jpg');
    await destination.save(fixtureImage('no_exif.jpg'), 'a.jpg');
    expect(gallery.saved.single.album, 'Filbert');
    expect(gallery.saved.single.fileName, 'a.jpg');
  });

  test('without one (the Mac), they go to a file', () {
    final destination = destinationWith(FakeGallerySaver()..available = false);
    expect(destination, isA<FileExportDestination>());
    expect(destination.kind, ExportDestinationKind.file);
  });
}
