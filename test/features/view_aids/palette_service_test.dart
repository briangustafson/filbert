import 'dart:convert';
import 'dart:io';

import 'package:dartcv4/dartcv.dart' as cv;
import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/core/imaging/edits_hash.dart';
import 'package:filbert/core/imaging/palette.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:filbert/features/view_aids/data/palette_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_photos.dart';

void main() {
  late Directory root;
  late LocalFileStore files;
  late File preview;
  late FakeImageRenderer renderer;
  late IsolatePaletteService service;

  // Four flat blocks (BGR), as a lossless PNG "preview" larger than the
  // 256 px sample, so it's downscaled.
  const blocks = [
    (30, 40, 60),
    (30, 40, 200),
    (220, 170, 120),
    (225, 240, 245),
  ];

  setUp(() {
    root = Directory.systemTemp.createTempSync('filbert_palette');
    files = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
    final image = cv.Mat.zeros(300, 800, cv.MatType.CV_8UC3);
    for (final (i, (b, g, r)) in blocks.indexed) {
      cv.rectangle(
        image,
        cv.Rect(i * 200, 0, 200, 300),
        cv.Scalar(b.toDouble(), g.toDouble(), r.toDouble()),
        thickness: -1,
      );
    }
    preview = File('${root.path}/preview.png');
    expect(cv.imwrite(preview.path, image), isTrue);
    image.dispose();
    renderer = FakeImageRenderer(file: preview);
    service = IsolatePaletteService(files: files, renderer: renderer);
  });
  tearDown(() => root.deleteSync(recursive: true));

  ProjectImage photo(String id, {Edits edits = Edits.none}) => ProjectImage(
    id: id,
    projectId: 'p1',
    blobId: 'b-$id',
    mimeType: 'image/jpeg',
    width: 800,
    height: 300,
    origin: ImageOrigin.camera,
    capturedAt: null,
    edits: edits,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    updatedByDeviceId: 'd',
  );

  File cacheFile(ProjectImage image, int count) => File(
    '${files.previewsDir.path}/'
    '${image.id}-${editsHash(image.edits)}-palette-$count.json',
  );

  test('computes the palette from the preview, dark to light', () async {
    final palette = await service.palette(photo('i1'), 4);
    // Area averaging at the block edges adds no colors that survive k = 4.
    expect(palette.srgb8, [
      (60, 40, 30),
      (200, 40, 30),
      (120, 170, 220),
      (245, 240, 225),
    ]);
    expect(renderer.requests, ['preview i1']);
  });

  test('caches in memory, then on disk', () async {
    final image = photo('i1');
    final first = await service.palette(image, 4);
    expect(cacheFile(image, 4).existsSync(), isTrue);
    expect(
      Palette.tryFromJson(jsonDecode(cacheFile(image, 4).readAsStringSync())),
      first,
    );

    expect(await service.palette(image, 4), first);
    expect(renderer.requests, hasLength(1), reason: 'served from memory');

    // A new service (an app restart) reads the disk cache.
    final restarted = IsolatePaletteService(files: files, renderer: renderer);
    expect(await restarted.palette(image, 4), first);
    expect(renderer.requests, hasLength(1), reason: 'served from disk');
  });

  test('keys by image, edits and count', () async {
    await service.palette(photo('i1'), 4);
    await service.palette(photo('i1'), 3);
    await service.palette(photo('i2'), 4);
    await service.palette(photo('i1', edits: const Edits(quarterTurns: 1)), 4);
    expect(renderer.requests, hasLength(4));
  });

  test('concurrent requests share one computation', () async {
    final image = photo('i1');
    final results = await Future.wait([
      service.palette(image, 4),
      service.palette(image, 4),
    ]);
    expect(results[0], results[1]);
    expect(renderer.requests, hasLength(1));
  });

  test('a damaged cache file is computed again', () async {
    final image = photo('i1');
    cacheFile(image, 4)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"v": 1, "colo');
    final palette = await service.palette(image, 4);
    expect(palette.colors, hasLength(4));
    expect(renderer.requests, hasLength(1));
  });

  test('deleting an image\'s caches removes its palettes', () async {
    final image = photo('i1');
    await service.palette(image, 4);
    await files.deleteCachesFor('i1');
    expect(cacheFile(image, 4).existsSync(), isFalse);
  });

  test('keeps at most memoryEntries palettes in memory', () async {
    final small = IsolatePaletteService(
      files: files,
      renderer: renderer,
      memoryEntries: 1,
    );
    await small.palette(photo('i1'), 4);
    await small.palette(photo('i1'), 3);
    // Evicted from memory; the disk cache answers, so no new render.
    await small.palette(photo('i1'), 4);
    expect(renderer.requests, hasLength(2));
  });
}
