import 'dart:io';

import 'package:filbert/core/files/file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late LocalFileStore store;
  late File source;

  setUp(() {
    root = Directory.systemTemp.createTempSync('filbert_files');
    store = LocalFileStore(
      supportDir: Directory('${root.path}/support'),
      cacheDir: Directory('${root.path}/cache'),
    );
    source = File('${root.path}/picked.jpg')..writeAsBytesSync([1, 2, 3, 4]);
  });
  tearDown(() => root.deleteSync(recursive: true));

  List<String> blobDirListing() =>
      Directory('${root.path}/support/blobs')
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .toList();

  test('putBlob copies bytes into blobs/<id>.<ext>', () async {
    final file = await store.putBlob('b1', 'jpg', source);
    expect(file.path, '${root.path}/support/blobs/b1.jpg');
    expect(file.readAsBytesSync(), [1, 2, 3, 4]);
    expect(store.blobFile('b1', 'jpg').path, file.path);
    expect(source.existsSync(), isTrue, reason: 'source is not moved');
    expect(blobDirListing(), ['b1.jpg'], reason: 'no temp files left');
  });

  test('a failed copy leaves nothing behind', () async {
    await expectLater(
      store.putBlob('b2', 'jpg', File('${root.path}/missing.jpg')),
      throwsA(isA<FileSystemException>()),
    );
    expect(store.blobFile('b2', 'jpg').existsSync(), isFalse);
    expect(blobDirListing(), isEmpty);
  });

  test('deleteBlob removes the file and ignores missing ones', () async {
    await store.putBlob('b1', 'jpg', source);
    await store.deleteBlob('b1', 'jpg');
    expect(store.blobFile('b1', 'jpg').existsSync(), isFalse);
    await store.deleteBlob('b1', 'jpg');
  });

  test('deleteCachesFor removes only that image\'s renders', () async {
    await store.thumbsDir.create(recursive: true);
    await store.previewsDir.create(recursive: true);
    File('${store.thumbsDir.path}/img1-abc-256.jpg').writeAsStringSync('t');
    File('${store.previewsDir.path}/img1-abc.jpg').writeAsStringSync('p');
    File('${store.thumbsDir.path}/img10-abc-256.jpg').writeAsStringSync('t');
    File('${store.previewsDir.path}/img2-abc.jpg').writeAsStringSync('p');

    await store.deleteCachesFor('img1');

    expect(store.thumbsDir.listSync().map((e) => e.uri.pathSegments.last), [
      'img10-abc-256.jpg',
    ]);
    expect(store.previewsDir.listSync().map((e) => e.uri.pathSegments.last), [
      'img2-abc.jpg',
    ]);
  });

  test('deleteCachesFor tolerates missing cache directories', () async {
    await store.deleteCachesFor('img1');
  });
}
