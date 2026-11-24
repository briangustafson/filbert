import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:filbert/core/auth/auth_service.dart';
import 'package:filbert/features/sync/data/drive_client.dart';
import 'package:filbert/features/sync/data/drive_remote_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_engine/sync_engine.dart';

/// Responses shaped like Drive v3's (developers.google.com/drive/api/
/// reference/rest/v3), hand-written: no recordings of a real Drive.
void main() {
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;
  late DriveRemoteStore store;

  http.Response json(Object body, {int status = 200}) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=UTF-8'},
  );

  http.Response error(int status, String message) => json({
    'error': {'code': status, 'message': message, 'errors': <Object>[]},
  }, status: status);

  Map<String, Object?> file(String id, String name, int version) => {
    'id': id,
    'name': name,
    'version': '$version',
  };

  setUp(() {
    requests = [];
    handler = (r) async => error(500, 'unexpected ${r.method} ${r.url}');
    final client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    store = DriveRemoteStore(client, createdBy: () async => '1.0.0 (1)');
  });

  /// The metadata part of a multipart upload.
  Map<String, Object?> metadataOf(http.Request request) {
    final body = request.body;
    final start = body.indexOf('{');
    final end = body.indexOf('}\r\n', start);
    return jsonDecode(body.substring(start, end + 1)) as Map<String, Object?>;
  }

  /// The media part of a multipart upload (sent base64-encoded).
  String mediaOf(http.Request request) {
    final parts = request.body.split(RegExp(r'\r\n--[^\r]+'));
    final media = parts[1].split('\r\n\r\n').last.trim();
    return utf8.decode(base64Decode(media));
  }

  group('changes', () {
    test('a first sync lists every file and writes the manifest', () async {
      handler = (r) async {
        final path = r.url.path;
        if (path.endsWith('/changes/startPageToken')) {
          return json({'startPageToken': '100'});
        }
        if (r.method == 'GET' && path.endsWith('/drive/v3/files')) {
          return r.url.queryParameters['pageToken'] == null
              ? json({
                  'nextPageToken': 'p2',
                  'files': [file('f1', 'project-p1.json', 3)],
                })
              : json({
                  'files': [file('f2', 'blob-b1.jpg', 1)],
                });
        }
        if (r.method == 'POST' && path.contains('/upload/')) {
          return json(file('m1', 'manifest.json', 1));
        }
        return error(500, 'unexpected');
      };

      final changes = await store.changes(null);

      expect(changes.nextPageToken, '100');
      expect([for (final f in changes.files) f.id], ['f1', 'f2']);
      expect(changes.files.first.version, 3);
      expect(changes.removedFileIds, isEmpty);

      expect(requests.first.url.path, endsWith('/changes/startPageToken'));
      final list = requests[1].url.queryParameters;
      expect(list['spaces'], 'appDataFolder');
      expect(list['fields'], contains('files(id,name,version)'));
      expect(requests[2].url.queryParameters['pageToken'], 'p2');

      final manifest = requests.last;
      expect(manifest.url.queryParameters['uploadType'], 'multipart');
      expect(metadataOf(manifest), {
        'name': 'manifest.json',
        'parents': ['appDataFolder'],
      });
      expect(mediaOf(manifest), '{"schemaVersion":1,"createdBy":"1.0.0 (1)"}');
    });

    test('a first sync keeps an existing manifest', () async {
      handler = (r) async => r.url.path.endsWith('startPageToken')
          ? json({'startPageToken': '7'})
          : json({
              'files': [file('m1', 'manifest.json', 1)],
            });
      await store.changes(null);
      expect(requests.map((r) => r.method), ['GET', 'GET']);
    });

    test(
      'later syncs follow the Changes pages to the new start token',
      () async {
        handler = (r) async {
          expect(r.url.path, endsWith('/drive/v3/changes'));
          return switch (r.url.queryParameters['pageToken']) {
            '100' => json({
              'nextPageToken': '101',
              'changes': [
                {
                  'fileId': 'f1',
                  'removed': false,
                  'file': file('f1', 'image-i1.json', 4),
                },
                {'fileId': 'f2', 'removed': true},
                {
                  'fileId': 'f3',
                  'removed': false,
                  'file': file('f3', 'project-p3.json', 2),
                },
              ],
            }),
            '101' => json({
              'newStartPageToken': '150',
              'changes': [
                {
                  'fileId': 'f3',
                  'removed': false,
                  'file': {
                    ...file('f3', 'project-p3.json', 2),
                    'trashed': true,
                  },
                },
                {
                  'fileId': 'f1',
                  'removed': false,
                  'file': file('f1', 'image-i1.json', 5),
                },
              ],
            }),
            _ => error(400, 'bad token'),
          };
        };

        final changes = await store.changes('100');

        expect(changes.nextPageToken, '150');
        expect(changes.files.single.id, 'f1');
        expect(changes.files.single.version, 5, reason: 'the latest change');
        expect(changes.removedFileIds, unorderedEquals(['f2', 'f3']));
        final query = requests.first.url.queryParameters;
        expect(query['spaces'], 'appDataFolder');
        expect(query['includeRemoved'], 'true');
        expect(query['fields'], contains('newStartPageToken'));
      },
    );
  });

  test('findByName queries by name, quotes escaped', () async {
    handler = (r) async => json({
      'files': [
        file('f1', 'project-p1.json', 2),
        file('f9', 'project-p1.json', 1),
      ],
    });
    final found = await store.findByName("project-p1.json");
    expect(found.map((f) => f.id), ['f1', 'f9']);
    expect(
      requests.single.url.queryParameters['q'],
      "name = 'project-p1.json'",
    );

    await store.findByName("it's");
    expect(requests.last.url.queryParameters['q'], r"name = 'it\'s'");
  });

  test('read gets the version, then the content', () async {
    handler = (r) async => r.url.queryParameters['alt'] == 'media'
        ? http.Response(
            '{"kind":"project"}',
            200,
            headers: {'content-type': 'application/json'},
          )
        : json({'version': '12'});
    final read = await store.read('f1');
    expect(read.version, 12);
    expect(read.content, '{"kind":"project"}');
    expect(requests.first.url.queryParameters['fields'], 'version');
    expect(requests.last.url.path, endsWith('/files/f1'));
  });

  test('create tags the record with its kind and id', () async {
    handler = (r) async => json(file('f7', 'image-i7.json', 1));
    final created = await store.create('image-i7.json', '{"a":1}');
    expect(created.id, 'f7');
    expect(created.version, 1);
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/upload/drive/v3/files');
    expect(metadataOf(request), {
      'appProperties': {'kind': 'image', 'id': 'i7'},
      'name': 'image-i7.json',
      'parents': ['appDataFolder'],
    });
    expect(mediaOf(request), '{"a":1}');
  });

  test('update replaces the content and returns the new version', () async {
    handler = (r) async => json(file('f7', 'image-i7.json', 2));
    final updated = await store.update('f7', '{"a":2}');
    expect(updated.version, 2);
    final request = requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.path, '/upload/drive/v3/files/f7');
    expect(mediaOf(request), '{"a":2}');
  });

  test('upload sends an original as a resumable upload', () async {
    final bytes = Uint8List.fromList(List.generate(1000, (i) => i % 256));
    handler = (r) async {
      if (r.url.queryParameters['uploadType'] == 'resumable') {
        return http.Response(
          '',
          200,
          headers: {'location': 'https://www.googleapis.com/upload/session/s1'},
        );
      }
      expect(r.url.path, '/upload/session/s1');
      expect(r.bodyBytes, bytes);
      return json(file('b9', 'blob-b9.jpg', 1));
    };

    final uploaded = await store.upload('blob-b9.jpg', bytes, 'image/jpeg');

    expect(uploaded.id, 'b9');
    final start = requests.first;
    expect(start.method, 'POST');
    expect(start.headers['x-upload-content-type'], 'image/jpeg');
    expect(jsonDecode(start.body), {
      'appProperties': {'kind': 'blob', 'id': 'b9'},
      'name': 'blob-b9.jpg',
      'parents': ['appDataFolder'],
    });
    expect(requests.last.method, 'PUT');
  });

  test('download returns the file\'s bytes', () async {
    handler = (r) async => http.Response.bytes(
      [9, 8, 7],
      200,
      headers: {'content-type': 'image/jpeg'},
    );
    expect(await store.download('b9'), [9, 8, 7]);
    expect(requests.single.url.queryParameters['alt'], 'media');
  });

  test('delete removes the file', () async {
    handler = (r) async => http.Response('', 204);
    await store.delete('f1');
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/drive/v3/files/f1');
  });

  group('failures', () {
    test('a missing file is RemoteNotFound', () async {
      handler = (r) async => error(404, 'File not found: f1.');
      expect(store.version('f1'), throwsA(isA<RemoteNotFound>()));
      expect(store.download('f1'), throwsA(isA<RemoteNotFound>()));
      expect(store.delete('f1'), throwsA(isA<RemoteNotFound>()));
    });

    test('server errors and rate limits are RemoteUnavailable', () async {
      for (final status in [500, 503, 429, 403]) {
        handler = (r) async => error(status, 'nope');
        await expectLater(
          store.findByName('x.json'),
          throwsA(isA<RemoteUnavailable>()),
          reason: '$status',
        );
      }
    });

    test('being offline is RemoteUnavailable', () async {
      handler = (r) async => throw const SocketException('offline');
      expect(store.changes('1'), throwsA(isA<RemoteUnavailable>()));
      handler = (r) async => throw http.ClientException('reset');
      expect(store.read('f1'), throwsA(isA<RemoteUnavailable>()));
    });
  });

  test('appPropertiesOf names what each file holds', () {
    expect(appPropertiesOf('project-p1.json'), {'kind': 'project', 'id': 'p1'});
    expect(appPropertiesOf('viewprefs-v1.json'), {
      'kind': 'viewPrefs',
      'id': 'v1',
    });
    expect(appPropertiesOf('blob-b1.heic'), {'kind': 'blob', 'id': 'b1'});
    expect(appPropertiesOf('thumb-b1.jpg'), {'kind': 'thumb', 'id': 'b1'});
    expect(appPropertiesOf('manifest.json'), isNull);
  });

  group('DriveAuthClient', () {
    late _TokenAuth auth;
    late List<String?> sentTokens;
    late int status;

    DriveAuthClient client() => DriveAuthClient(
      auth,
      inner: MockClient((r) async {
        sentTokens.add(r.headers['authorization']);
        expect(r.body, 'payload', reason: 'body sent again after a 401');
        return http.Response('', sentTokens.length == 1 ? status : 200);
      }),
    );

    setUp(() {
      auth = _TokenAuth();
      sentTokens = [];
      status = 200;
    });

    test('adds the access token', () async {
      await client().post(Uri.parse('https://example.com'), body: 'payload');
      expect(sentTokens, ['Bearer t1']);
    });

    test('after a 401, drops the token and retries once', () async {
      status = 401;
      final response = await client().post(
        Uri.parse('https://example.com'),
        body: 'payload',
      );
      expect(response.statusCode, 200);
      expect(sentTokens, ['Bearer t1', 'Bearer t2']);
      expect(auth.cleared, ['t1']);
    });

    test('without a token, nothing is sent', () async {
      auth.tokens.clear();
      await expectLater(
        client().post(Uri.parse('https://example.com'), body: 'payload'),
        throwsA(isA<DriveNotAuthorized>()),
      );
      expect(sentTokens, isEmpty);
    });
  });
}

/// Hands out t1, then t2 after t1 is cleared.
class _TokenAuth implements AuthService {
  final tokens = ['t1', 't2'];
  final cleared = <String>[];

  @override
  Future<String?> driveAccessToken() async => tokens.firstOrNull;

  @override
  Future<void> clearDriveToken(String accessToken) async {
    cleared.add(accessToken);
    tokens.remove(accessToken);
  }

  @override
  Future<AuthAccount?> restore() => throw UnimplementedError();

  @override
  Future<AuthAccount> signIn() => throw UnimplementedError();

  @override
  Future<bool> authorizeDrive() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}
