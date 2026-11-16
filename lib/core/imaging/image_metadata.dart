import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_metadata.g.dart';

/// What import needs to know about a photo file (m1-design §5.2).
class ImageMetadata {
  const ImageMetadata({
    required this.mimeType,
    required this.width,
    required this.height,
    required this.orientation,
    this.capturedAt,
  });

  final String mimeType;

  /// Pixel size after applying the EXIF orientation.
  final int width;
  final int height;

  /// EXIF orientation, 1–8 (1 = as stored).
  final int orientation;

  /// When the photo was taken, from EXIF, in UTC.
  final DateTime? capturedAt;

  @override
  String toString() =>
      'ImageMetadata($mimeType, ${width}x$height, orientation $orientation, '
      'capturedAt $capturedAt)';
}

/// The file isn't an image format Filbert can import.
class UnsupportedImageException implements Exception {
  const UnsupportedImageException(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedImageException: $message';
}

abstract interface class ImageMetadataReader {
  /// Throws [UnsupportedImageException] for unknown or undecodable files.
  Future<ImageMetadata> read(File file);
}

/// File extension stored for each supported MIME type.
const extensionForMimeType = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/heic': 'heic',
  'image/heif': 'heif',
  'image/webp': 'webp',
};

/// Identifies the format from the file's first bytes; null if unsupported.
String? sniffMimeType(Uint8List bytes) {
  bool at(int offset, List<int> expected) {
    if (bytes.length < offset + expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (bytes[offset + i] != expected[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  if (at(4, 'ftyp'.codeUnits) && bytes.length >= 12) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (const {'heic', 'heix', 'hevc', 'hevx'}.contains(brand)) {
      return 'image/heic';
    }
    if (const {'mif1', 'msf1', 'heim', 'heis'}.contains(brand)) {
      return 'image/heif';
    }
  }
  return null;
}

/// Parses EXIF `DateTimeOriginal` ("YYYY:MM:DD HH:MM:SS") with an optional
/// `OffsetTimeOriginal` ("+01:00"). Without an offset the time is taken as
/// device-local. Returns UTC, or null if absent or malformed.
DateTime? parseExifDateTime(String? value, {String? offset}) {
  if (value == null) return null;
  final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})')
      .firstMatch(value.trim());
  if (m == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  if (parts[0] == 0 || parts[1] == 0 || parts[2] == 0) return null;

  final o = offset == null
      ? null
      : RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(offset.trim());
  if (o != null) {
    final sign = o.group(1) == '-' ? -1 : 1;
    final delta = Duration(
      hours: int.parse(o.group(2)!),
      minutes: int.parse(o.group(3)!),
    );
    final asUtc = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    return sign > 0 ? asUtc.subtract(delta) : asUtc.add(delta);
  }
  return DateTime(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  ).toUtc();
}

/// Reads the format from magic bytes, the displayed pixel size from the
/// platform image decoder's header parse (no full decode), and orientation and
/// capture time from EXIF.
class PlatformImageMetadataReader implements ImageMetadataReader {
  const PlatformImageMetadataReader();

  @override
  Future<ImageMetadata> read(File file) async {
    final bytes = await file.readAsBytes();
    final mimeType = sniffMimeType(bytes);
    if (mimeType == null) {
      throw const UnsupportedImageException('Not a JPEG, PNG, HEIC, or WebP');
    }

    final (width, height) = await _decodedSize(bytes);
    final exif = await _readExif(bytes);
    final orientation = switch (exif['Image Orientation']?.values
        .firstAsInt()) {
      final int o when o >= 1 && o <= 8 => o,
      _ => 1,
    };
    final capturedAt = parseExifDateTime(
      exif['EXIF DateTimeOriginal']?.printable,
      offset: exif['EXIF OffsetTimeOriginal']?.printable,
    );

    // Flutter's image decoder already applies the EXIF orientation, so its
    // size is the displayed size (verified on the test host and Android;
    // see the T6 notes in m1-design §5.2).
    return ImageMetadata(
      mimeType: mimeType,
      width: width,
      height: height,
      orientation: orientation,
      capturedAt: capturedAt,
    );
  }

  static Future<(int, int)> _decodedSize(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return (descriptor.width, descriptor.height);
      } finally {
        descriptor.dispose();
      }
    } catch (e) {
      throw UnsupportedImageException('Could not decode image: $e');
    } finally {
      buffer.dispose();
    }
  }

  static Future<Map<String, IfdTag>> _readExif(Uint8List bytes) async {
    try {
      return await readExifFromBytes(bytes);
    } catch (_) {
      return const {}; // Missing or malformed EXIF is not an import error.
    }
  }
}

@Riverpod(keepAlive: true)
ImageMetadataReader imageMetadataReader(Ref ref) =>
    const PlatformImageMetadataReader();
