import 'dart:typed_data';

import 'package:sync_engine/sync_engine.dart';
import 'package:sync_engine/src/testing/fake_remote_store.dart';
import 'package:test/test.dart';

void main() {
  test(
    'download returns uploaded bytes; a missing file is not found',
    () async {
      final remote = FakeRemoteStore();
      final file = await remote.upload(
        'blob-b1.jpg',
        Uint8List.fromList([1, 2, 3]),
        'image/jpeg',
      );
      expect(await remote.download(file.id), [1, 2, 3]);
      await remote.delete(file.id);
      expect(remote.download(file.id), throwsA(isA<RemoteNotFound>()));
    },
  );
}
