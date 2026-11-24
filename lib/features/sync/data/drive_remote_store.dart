import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sync_engine/sync_engine.dart';

import 'drive_client.dart';

/// [RemoteStore] on Drive v3 (m3-design §6.2): flat files in the hidden
/// `appDataFolder`, each tagged with `appProperties` `{kind, id}`.
///
/// Every failed request becomes [RemoteUnavailable] (the pass stops and the
/// next one retries), except a missing file: [RemoteNotFound].
class DriveRemoteStore implements RemoteStore {
  DriveRemoteStore(http.Client client, {required this.createdBy})
    : _api = drive.DriveApi(client);

  final drive.DriveApi _api;

  /// The app version written into `manifest.json`.
  final Future<String> Function() createdBy;

  static const _space = 'appDataFolder';
  static const manifestName = 'manifest.json';

  /// Fields of a file the engine needs.
  static const _fileFields = 'id,name,version';
  static const _pageSize = 1000;

  /// Originals are sent in pieces of this size; a failed piece is retried
  /// without starting over.
  static const _chunkSize = 4 * 1024 * 1024;

  @override
  Future<RemoteChanges> changes(String? pageToken) => _call(null, () async {
    if (pageToken == null) return _everything();
    final files = <String, RemoteFile>{};
    final removed = <String>{};
    String? next = pageToken;
    String? newStart;
    while (next != null) {
      final page = await _api.changes.list(
        next,
        spaces: _space,
        includeRemoved: true,
        pageSize: _pageSize,
        $fields:
            'nextPageToken,newStartPageToken,'
            'changes(fileId,removed,file($_fileFields,trashed))',
      );
      for (final change in page.changes ?? const <drive.Change>[]) {
        final id = change.fileId!;
        final file = change.file;
        if ((change.removed ?? false) ||
            file == null ||
            (file.trashed ?? false)) {
          files.remove(id);
          removed.add(id);
        } else {
          removed.remove(id);
          files[id] = _remoteFile(file);
        }
      }
      next = page.nextPageToken;
      newStart = page.newStartPageToken ?? newStart;
    }
    return RemoteChanges(
      files: files.values.toList(),
      removedFileIds: removed.toList(),
      nextPageToken: newStart!,
    );
  });

  /// A first sync: every file, and the token to start from next time. The
  /// token is taken first, so a change made while listing is seen again
  /// next pass rather than missed. Writes `manifest.json` if there's none.
  Future<RemoteChanges> _everything() async {
    final start = (await _api.changes.getStartPageToken(
      $fields: 'startPageToken',
    )).startPageToken!;
    final files = await _list(null);
    if (!files.any((f) => f.name == manifestName)) {
      await _create(
        manifestName,
        utf8.encode(
          jsonEncode({'schemaVersion': 1, 'createdBy': await createdBy()}),
        ),
        'application/json',
      );
    }
    return RemoteChanges(
      files: files,
      removedFileIds: const [],
      nextPageToken: start,
    );
  }

  /// Files in `appDataFolder`, all of them or matching [query].
  Future<List<RemoteFile>> _list(String? query) async {
    final files = <RemoteFile>[];
    String? pageToken;
    do {
      final page = await _api.files.list(
        spaces: _space,
        q: query,
        pageSize: _pageSize,
        pageToken: pageToken,
        $fields: 'nextPageToken,files($_fileFields)',
      );
      files.addAll((page.files ?? const <drive.File>[]).map(_remoteFile));
      pageToken = page.nextPageToken;
    } while (pageToken != null);
    return files;
  }

  @override
  Future<List<RemoteFile>> findByName(String name) => _call(
    null,
    () => _list(
      "name = '${name.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'",
    ),
  );

  /// The version is read before the content: if the file changes in
  /// between, the content is newer than the version, and the next pass
  /// reads it again.
  @override
  Future<({String content, int version})> read(String fileId) =>
      _call(fileId, () async {
        final version = await _version(fileId);
        final bytes = await _download(fileId);
        return (content: utf8.decode(bytes), version: version);
      });

  @override
  Future<int> version(String fileId) => _call(fileId, () => _version(fileId));

  Future<int> _version(String fileId) async {
    final file = await _api.files.get(fileId, $fields: 'version') as drive.File;
    return int.parse(file.version!);
  }

  @override
  Future<RemoteFile> create(String name, String content) => _call(
    null,
    () => _create(name, utf8.encode(content), 'application/json'),
  );

  @override
  Future<RemoteFile> update(String fileId, String content) =>
      _call(fileId, () async {
        final bytes = utf8.encode(content);
        return _remoteFile(
          await _api.files.update(
            drive.File(),
            fileId,
            uploadMedia: drive.Media(
              Stream.value(bytes),
              bytes.length,
              contentType: 'application/json',
            ),
            $fields: _fileFields,
          ),
        );
      });

  @override
  Future<RemoteFile> upload(String name, Uint8List bytes, String mimeType) =>
      _call(
        null,
        () => _create(
          name,
          bytes,
          mimeType,
          options: drive.ResumableUploadOptions(
            chunkSize: _chunkSize,
            numberOfAttempts: 3,
          ),
        ),
      );

  @override
  Future<Uint8List> download(String fileId) =>
      _call(fileId, () => _download(fileId));

  Future<Uint8List> _download(String fileId) async {
    final media = await _api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final builder = BytesBuilder(copy: false);
    await media.stream.forEach(builder.add);
    return builder.takeBytes();
  }

  @override
  Future<void> delete(String fileId) =>
      _call(fileId, () => _api.files.delete(fileId));

  Future<RemoteFile> _create(
    String name,
    List<int> bytes,
    String mimeType, {
    drive.UploadOptions options = drive.UploadOptions.defaultOptions,
  }) async => _remoteFile(
    await _api.files.create(
      drive.File(
        name: name,
        parents: const [_space],
        appProperties: appPropertiesOf(name),
      ),
      uploadMedia: drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: mimeType,
      ),
      uploadOptions: options,
      $fields: _fileFields,
    ),
  );

  static RemoteFile _remoteFile(drive.File file) => RemoteFile(
    id: file.id!,
    name: file.name!,
    version: int.parse(file.version!),
  );

  /// Turns failures into the engine's exceptions. [fileId] is the file the
  /// request is about, for [RemoteNotFound].
  static Future<T> _call<T>(
    String? fileId,
    Future<T> Function() request,
  ) async {
    try {
      return await request();
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404 && fileId != null) throw RemoteNotFound(fileId);
      throw RemoteUnavailable('Drive ${e.status}: ${e.message}');
    } on drive.ApiRequestError catch (e) {
      throw RemoteUnavailable('Drive: ${e.message}');
    } on DriveNotAuthorized catch (e) {
      throw RemoteUnavailable(e);
    } on SocketException catch (e) {
      throw RemoteUnavailable(e);
    } on http.ClientException catch (e) {
      throw RemoteUnavailable(e);
    } on TimeoutException catch (e) {
      throw RemoteUnavailable(e);
    } on HttpException catch (e) {
      throw RemoteUnavailable(e);
    }
  }
}

/// A file's `appProperties` (m3-design §6.2): what it holds, from its name.
Map<String, String>? appPropertiesOf(String name) {
  final record = recordKeyOfFile(name);
  if (record != null) return {'kind': record.kind.wire, 'id': record.id};
  final match = RegExp(r'^(blob|thumb)-([^.]+)\.').firstMatch(name);
  if (match != null) return {'kind': match[1]!, 'id': match[2]!};
  return null;
}
