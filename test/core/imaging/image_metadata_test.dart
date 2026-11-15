import 'dart:io';

import 'dart:typed_data';

import 'package:filbert/core/imaging/image_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  const reader = PlatformImageMetadataReader();

  group('read', () {
    test('JPEG without EXIF', () async {
      final m = await reader.read(fixtureImage('no_exif.jpg'));
      expect(m.mimeType, 'image/jpeg');
      expect((m.width, m.height), (40, 30));
      expect(m.orientation, 1);
      expect(m.capturedAt, isNull);
    });

    test('capture time with offset', () async {
      final m = await reader.read(fixtureImage('orientation_1_offset.jpg'));
      expect(m.orientation, 1);
      expect((m.width, m.height), (40, 30));
      expect(m.capturedAt, DateTime.utc(2026, 11, 14, 7, 30));
    });

    test('orientation 6 and 8 report the displayed (rotated) size', () async {
      for (final name in ['orientation_6.jpg', 'orientation_8.jpg']) {
        final m = await reader.read(fixtureImage(name));
        expect((m.width, m.height), (30, 40), reason: name);
      }
      expect(
        (await reader.read(fixtureImage('orientation_6.jpg'))).orientation,
        6,
      );
      expect(
        (await reader.read(fixtureImage('orientation_8.jpg'))).orientation,
        8,
      );
    });

    test('capture time without offset is device-local', () async {
      final m = await reader.read(fixtureImage('orientation_6.jpg'));
      expect(m.capturedAt, DateTime(2026, 3, 5, 14).toUtc());
    });

    test('PNG', () async {
      final m = await reader.read(fixtureImage('plain.png'));
      expect(m.mimeType, 'image/png');
      expect((m.width, m.height), (40, 30));
    });

    test('HEIC', () async {
      final m = await reader.read(fixtureImage('landscape.heic'));
      expect(m.mimeType, 'image/heic');
      expect((m.width, m.height), (40, 30));
    });

    test('non-images are rejected', () async {
      await expectLater(
        reader.read(fixtureImage('not_an_image.txt')),
        throwsA(isA<UnsupportedImageException>()),
      );
    });

    test('a truncated image is rejected', () async {
      final bytes = fixtureImage('no_exif.jpg').readAsBytesSync();
      final dir = await Directory.systemTemp.createTemp('filbert_meta');
      addTearDown(() => dir.delete(recursive: true));
      final broken = File('${dir.path}/broken.jpg')
        ..writeAsBytesSync(bytes.sublist(0, 20));
      await expectLater(
        reader.read(broken),
        throwsA(isA<UnsupportedImageException>()),
      );
    });
  });

  test('sniffMimeType', () {
    Uint8List b(List<int> bytes) => Uint8List.fromList(bytes);
    expect(sniffMimeType(b([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
    expect(
      sniffMimeType(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])),
      'image/png',
    );
    expect(
      sniffMimeType(b([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])),
      'image/webp',
    );
    Uint8List ftyp(String brand) =>
        b([0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits]);
    expect(sniffMimeType(ftyp('heic')), 'image/heic');
    expect(sniffMimeType(ftyp('mif1')), 'image/heif');
    expect(sniffMimeType(ftyp('avif')), isNull);
    expect(sniffMimeType(ftyp('isom')), isNull);
    expect(sniffMimeType(b([1, 2, 3])), isNull);
    expect(sniffMimeType(b([])), isNull);
  });

  test('parseExifDateTime', () {
    expect(
      parseExifDateTime('2026:11:14 09:30:00', offset: '+02:00'),
      DateTime.utc(2026, 11, 14, 7, 30),
    );
    expect(
      parseExifDateTime('2026:11:14 09:30:00', offset: '-05:30'),
      DateTime.utc(2026, 11, 14, 15),
    );
    expect(
      parseExifDateTime('2026:11:14 09:30:00'),
      DateTime(2026, 11, 14, 9, 30).toUtc(),
    );
    expect(
      parseExifDateTime('2026:11:14 09:30:00', offset: 'garbage'),
      DateTime(2026, 11, 14, 9, 30).toUtc(),
    );
    expect(parseExifDateTime(null), isNull);
    expect(parseExifDateTime('0000:00:00 00:00:00'), isNull);
    expect(parseExifDateTime('yesterday'), isNull);
  });
}
