import 'dart:io';
import 'dart:ui' as ui;

import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/core/imaging/edits_hash.dart';
import 'package:filbert/features/export/data/render_service.dart';
import 'package:filbert/features/export/domain/export_options.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:filbert/features/projects/domain/project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_view_aids.dart';
import '../../support/fixtures.dart';

void main() {
  late Directory root;
  late LocalFileStore files;
  late FakePaletteService palettes;
  late OpenCvRenderService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('filbert_export');
    files = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
    palettes = FakePaletteService();
    service = OpenCvRenderService(files: files, palettes: palettes);
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// Stores [fixture] as a blob and returns an image record for it;
  /// [width] × [height] is its size after EXIF orientation.
  Future<ProjectImage> stored(
    String fixture, {
    int width = 40,
    int height = 30,
  }) async {
    final blobId = 'blob-$fixture';
    await files.putBlob(blobId, 'jpg', fixtureImage(fixture));
    return ProjectImage(
      id: 'image-$fixture',
      projectId: 'p',
      blobId: blobId,
      mimeType: 'image/jpeg',
      width: width,
      height: height,
      origin: ImageOrigin.device,
      capturedAt: null,
      edits: Edits.none,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      updatedByDeviceId: 'd',
    );
  }

  Future<(int, int)> sizeOf(File jpeg) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await jpeg.readAsBytes(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  test(
    'a JPEG in the exports cache, named by image, edits and options',
    () async {
      final image = await stored('no_exif.jpg');
      const options = ExportOptions(tone: ToneAid.gray);
      final file = await service.export(image, options);
      expect(
        file.path,
        '${files.exportsDir.path}/${image.id}-${editsHash(image.edits)}-'
        '${options.cacheKey}.jpg',
      );
      expect((await file.readAsBytes()).sublist(0, 2), [0xFF, 0xD8]);
      expect(await sizeOf(file), (40, 30));
      expect(
        files.exportsDir.listSync(),
        hasLength(1),
        reason: 'no temp files',
      );
    },
  );

  test('the same options reuse the file; others make a new one', () async {
    final image = await stored('no_exif.jpg');
    final results = await Future.wait([
      service.export(image, const ExportOptions(tone: ToneAid.gray)),
      service.export(image, const ExportOptions(tone: ToneAid.gray)),
    ]);
    expect(results[0].path, results[1].path);
    final stamp = results[0].lastModifiedSync();
    final again = await service.export(
      image,
      const ExportOptions(tone: ToneAid.gray),
    );
    expect(again.lastModifiedSync(), stamp);
    final values = await service.export(
      image,
      const ExportOptions(tone: ToneAid.valueBands, bands: 3),
    );
    expect(values.path, isNot(results[0].path));
  });

  test(
    'compare: the other photo, toned with its own palette, stretched',
    () async {
      final image = await stored('no_exif.jpg');
      // A portrait photo (30 × 40 after EXIF) over a landscape one.
      final other = await stored('orientation_6.jpg', width: 30, height: 40);
      final file = await service.export(
        image,
        ExportOptions(tone: ToneAid.colors, colors: 4, compareWith: other),
      );
      expect(await sizeOf(file), (40, 30));
      expect(
        palettes.requests,
        containsAll(['${image.id} 4', '${other.id} 4']),
      );
    },
  );

  test('grid and everything at once', () async {
    final image = await stored('no_exif.jpg');
    final other = await stored('plain.png');
    final file = await service.export(
      image,
      ExportOptions(
        tone: ToneAid.valueBands,
        grid: const GridPrefs(mode: GridMode.spacing, spacing: 2),
        canvas: const PhysicalSize(8, 6, LengthUnit.inches),
        compareWith: other,
        opacity: 0.3,
      ),
    );
    expect(await sizeOf(file), (40, 30));
  });

  test('clearExports removes them', () async {
    final image = await stored('no_exif.jpg');
    await service.export(image, const ExportOptions(tone: ToneAid.gray));
    await files.clearExports();
    expect(files.exportsDir.existsSync(), isFalse);
    // And exporting again works.
    final file = await service.export(image, const ExportOptions());
    expect(file.existsSync(), isTrue);
  });

  group('ExportOptions', () {
    test('fromAids takes only the aids that are on', () {
      const prefs = ViewPrefs(
        values: ValuesPrefs(bands: 7),
        grid: GridPrefs(rows: 3),
        compare: ComparePrefs(opacity: 0.25),
      );
      final o = ExportOptions.fromAids(
        const ViewAids(tone: ToneAid.valueBands, grid: true),
        prefs,
      );
      expect(
        (o.tone, o.bands, o.grid, o.compareWith),
        (ToneAid.valueBands, 7, const GridPrefs(rows: 3), null),
      );
      expect(o.hasAids, isTrue);
      expect(o.without(tone: true, grid: true).hasAids, isFalse);
    });

    test('the cache key ignores settings not in use', () {
      expect(
        const ExportOptions(tone: ToneAid.gray, bands: 3).cacheKey,
        const ExportOptions(tone: ToneAid.gray, bands: 7).cacheKey,
      );
      expect(
        const ExportOptions(tone: ToneAid.valueBands, bands: 3).cacheKey,
        isNot(const ExportOptions(tone: ToneAid.valueBands, bands: 7).cacheKey),
      );
    });
  });
}
