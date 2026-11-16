import 'dart:io';

import 'package:filbert/features/photos/data/photo_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory cache;

  setUp(() => cache = Directory.systemTemp.createTempSync('filbert_cache'));
  tearDown(() => cache.deleteSync(recursive: true));

  List<String> names() =>
      cache
          .listSync()
          .map((e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
          .toList()
        ..sort();

  test('deletes picker folders and camera files, nothing else', () async {
    const uuid = '093a433a-4253-425e-9482-f66424355174';
    Directory('${cache.path}/$uuid').createSync();
    File('${cache.path}/20389cbe-8bdb-4064-a2e2-95c5dcf0294d/image.jpg')
        .createSync(recursive: true);
    File('${cache.path}/d817cdf7-9fad-4f8d-ba26-ab78be8901dc123456.jpg')
        .createSync();
    // Ours and other things in the cache: kept.
    File('${cache.path}/thumbs/x.jpg').createSync(recursive: true);
    Directory('${cache.path}/previews').createSync();
    File('${cache.path}/$uuid.txt.bak').createSync();
    Directory('${cache.path}/not-a-uuid').createSync();

    expect(await deletePickerLeftovers(cache), 3);
    expect(names(), ['$uuid.txt.bak', 'not-a-uuid', 'previews', 'thumbs']);
    expect(File('${cache.path}/thumbs/x.jpg').existsSync(), isTrue);
  });

  test('a missing cache directory is fine', () async {
    expect(await deletePickerLeftovers(Directory('${cache.path}/nope')), 0);
  });
}
