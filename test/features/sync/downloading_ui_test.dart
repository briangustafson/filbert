// Photos from other devices before their originals arrive (m3-design §6.5,
// §7.1): the photo screen, Crop, Export, grid tiles and the project list.
import 'package:filbert/app/router.dart';
import 'package:filbert/app/routes.dart';
import 'package:filbert/features/export/ui/export_sheet.dart';
import 'package:filbert/features/photo_viewer/photo_page.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/sync/data/blob_availability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_photos.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_sync.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeProjectRepository projects;
  late FakeImageRepository images;
  late FakeBlobAvailability availability;
  late FakeBlobDownloader downloader;
  late String projectId;
  late ProjectImage photo;

  setUp(() {
    projects = FakeProjectRepository();
    images = FakeImageRepository(projects);
    availability = FakeBlobAvailability();
    downloader = FakeBlobDownloader();
    projectId = projects.seed('Harbour').id;
    photo = images.seed(projectId);
  });

  /// Opens [location] from the project list: a downloading photo's ring
  /// never settles, so the app settles first.
  Future<void> pump(WidgetTester tester, String location) async {
    final container = await pumpFilbertApp(
      tester,
      projects: projects,
      images: images,
      renderer: FakeImageRenderer(file: fixtureImage('no_exif.jpg')),
      blobAvailability: availability,
      downloader: downloader,
    );
    container.read(routerProvider).go(location);
    await settleSome(tester);
  }

  testWidgets('the photo screen shows the thumbnail and fetches the original '
      'next', (tester) async {
    availability.set(photo.blobId, BlobAvailability.thumbnail);
    await pump(tester, Routes.photo(projectId, photo.id));
    expect(find.byType(DownloadingRing), findsOneWidget);
    expect(downloader.prioritized, [photo.blobId]);

    availability.set(photo.blobId, BlobAvailability.original);
    await settleSome(tester);
    expect(find.byType(DownloadingRing), findsNothing);
  });

  testWidgets('a photo gone from Drive says so', (tester) async {
    availability.set(photo.blobId, BlobAvailability.missing);
    await pump(tester, Routes.photo(projectId, photo.id));
    expect(find.text(PhotoMissingNotice.text), findsOneWidget);
  });

  testWidgets('Crop waits for the original', (tester) async {
    availability.set(photo.blobId, BlobAvailability.thumbnail);
    await pump(tester, Routes.crop(projectId, photo.id));
    expect(find.text('Downloading the full photo…'), findsOneWidget);
    expect(downloader.prioritized, contains(photo.blobId));

    availability.set(photo.blobId, BlobAvailability.original);
    await settleSome(tester);
    expect(find.text('Downloading the full photo…'), findsNothing);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('Export waits for the original', (tester) async {
    availability.set(photo.blobId, BlobAvailability.thumbnail);
    await pump(tester, Routes.photo(projectId, photo.id));
    final context = tester.element(find.byType(PhotoPage));
    // Not awaited: the sheet stays open.
    showExportSheet(context, photo).ignore();
    await settleSome(tester);
    expect(find.text(downloadingOriginal), findsOneWidget);
    final save = find.byWidgetPredicate(
      (w) => w is ButtonStyleButton && w.onPressed == null,
    );
    expect(save, findsWidgets, reason: 'saving waits');

    availability.set(photo.blobId, BlobAvailability.original);
    await settleSome(tester);
    expect(find.text('Full size, as a JPEG.'), findsOneWidget);
  });

  testWidgets('the project list shows a bar while photos download', (
    tester,
  ) async {
    await pump(tester, Routes.projectList);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    downloader.setActive(true);
    await settleSome(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    downloader.setActive(false);
    await settleSome(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}

/// Pumps frames for a while, without waiting for spinners to stop.
Future<void> settleSome(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
