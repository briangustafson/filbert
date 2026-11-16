import 'dart:io';
import 'dart:ui' as ui;

import 'package:filbert/core/files/file_store.dart';
import 'package:filbert/core/imaging/edits_hash.dart';
import 'package:filbert/core/imaging/image_metadata.dart';
import 'package:filbert/features/photos/data/image_renderer.dart';
import 'package:filbert/features/photos/domain/project_image.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory root;
  late LocalFileStore files;
  late OpenCvImageRenderer renderer;

  setUp(() {
    root = Directory.systemTemp.createTempSync('filbert_render');
    files = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
    renderer = OpenCvImageRenderer(files: files);
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// Stores [fixture] as a blob and returns an image record for it.
  Future<ProjectImage> stored(
    String fixture, {
    String mimeType = 'image/jpeg',
    Edits edits = Edits.none,
  }) async {
    final blobId = 'blob-$fixture';
    await files.putBlob(
      blobId,
      extensionForMimeType[mimeType]!,
      fixtureImage(fixture),
    );
    return ProjectImage(
      id: 'image-$fixture',
      projectId: 'p',
      blobId: blobId,
      mimeType: mimeType,
      width: 40,
      height: 30,
      origin: ImageOrigin.device,
      capturedAt: null,
      edits: edits,
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

  test('preview: a JPEG in the previews cache, named by edits hash', () async {
    final image = await stored('no_exif.jpg');
    final file = await renderer.preview(image);

    expect(
      file.path,
      '${files.previewsDir.path}/${image.id}-${editsHash(Edits.none)}.jpg',
    );
    expect((await file.readAsBytes()).sublist(0, 2), [0xFF, 0xD8]);
    expect(await sizeOf(file), (40, 30), reason: 'never upscaled');
    expect(files.previewsDir.listSync().map((e) => e.uri.pathSegments.last), [
      file.uri.pathSegments.last,
    ], reason: 'no temp files left behind');
  });

  test('EXIF orientation is applied before edits', () async {
    // Stored 40×30 with orientation 6: displays as 30×40.
    final image = await stored('orientation_6.jpg');
    expect(await sizeOf(await renderer.preview(image)), (30, 40));

    final turned = await stored(
      'orientation_8.jpg',
      edits: const Edits(quarterTurns: 1),
    );
    expect(await sizeOf(await renderer.preview(turned)), (40, 30));
  });

  test('crop and thumbnail size', () async {
    final image = await stored(
      'plain.png',
      mimeType: 'image/png',
      edits: Edits(
        crop: CropEdit(
          quad: const [
            NormPoint(0, 0),
            NormPoint(0.5, 0),
            NormPoint(0.5, 1),
            NormPoint(0, 1),
          ],
        ),
      ),
    );
    final thumb = await renderer.thumbnail(image, 16);
    expect(
      thumb.path,
      '${files.thumbsDir.path}/${image.id}-${editsHash(image.edits)}-16.jpg',
    );
    // The left half is 20×30; fitted to 16 px on the long edge.
    expect(await sizeOf(thumb), (11, 16));
  });

  test('reuses the cached file; new edits render a new one', () async {
    final image = await stored('no_exif.jpg');
    final first = await renderer.preview(image);
    final stamp = DateTime.utc(2000);
    await first.setLastModified(stamp);

    final again = await renderer.preview(image);
    expect(again.path, first.path);
    expect(
      (await again.lastModified()).isAtSameMomentAs(stamp),
      isTrue,
      reason: 'not re-rendered',
    );

    final edited = await renderer.preview(
      await stored('no_exif.jpg', edits: const Edits(quarterTurns: 2)),
    );
    expect(edited.path, isNot(first.path));
  });

  test('concurrent requests share one render', () async {
    final image = await stored('no_exif.jpg');
    final a = renderer.preview(image);
    final b = renderer.preview(image);
    expect(identical(a, b), isTrue);
    expect((await a).path, (await b).path);
  });

  test('HEIC renders via the platform decoder', () async {
    final image = await stored('landscape.heic', mimeType: 'image/heic');
    expect(await sizeOf(await renderer.preview(image)), (40, 30));
  }, skip: heicSkip);

  test('unreadable or unknown originals throw', () async {
    final bad = await stored('not_an_image.txt');
    await expectLater(
      renderer.preview(bad),
      throwsA(isA<UnsupportedImageException>()),
    );
    final unknownType = await stored('no_exif.jpg', mimeType: 'image/jpeg');
    await expectLater(
      renderer.preview(
        ProjectImage(
          id: unknownType.id,
          projectId: 'p',
          blobId: unknownType.blobId,
          mimeType: 'image/tiff',
          width: 40,
          height: 30,
          origin: ImageOrigin.device,
          capturedAt: null,
          edits: Edits.none,
          createdAt: unknownType.createdAt,
          updatedAt: unknownType.updatedAt,
          updatedByDeviceId: 'd',
        ),
      ),
      throwsA(isA<UnsupportedImageException>()),
    );
  });
}
