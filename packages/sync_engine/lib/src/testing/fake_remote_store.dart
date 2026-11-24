import 'dart:convert';
import 'dart:typed_data';

import '../stores.dart';

/// An in-memory `appDataFolder` (m3-design §6.1) shared by simulated
/// devices. Every change bumps the file's version and is logged, so
/// [changes] works like Drive's Changes API.
///
/// [failNext] makes requests fail: dropped (nothing happens) or, with
/// `afterApply`, interrupted (the change happens but the reply is lost, as
/// when a connection drops mid-response).
class FakeRemoteStore implements RemoteStore {
  final _files = <String, _File>{};
  final _log = <String>[];
  var _nextId = 1;
  final _failures = <({String? op, bool afterApply})>[];

  /// Every request made, as `op name-or-id`.
  final requests = <String>[];

  /// Makes the next request (of [op], if given) fail.
  void failNext({String? op, bool afterApply = false}) =>
      _failures.add((op: op, afterApply: afterApply));

  /// The live files, by id.
  Map<String, RemoteFile> get files => {
    for (final MapEntry(:key, :value) in _files.entries)
      key: RemoteFile(id: key, name: value.name, version: value.version),
  };

  List<RemoteFile> named(String name) => [
    for (final file in files.values)
      if (file.name == name) file,
  ];

  /// A text file's content.
  String? textOf(String fileId) {
    final bytes = _files[fileId]?.bytes;
    return bytes == null ? null : utf8.decode(bytes);
  }

  Uint8List? bytesOf(String fileId) => _files[fileId]?.bytes;

  /// Adds a file as another client would (for duplicates), without the
  /// failure queue.
  RemoteFile put(String name, String content) =>
      _create(name, utf8.encode(content));

  Future<T> _request<T>(String op, String what, T Function() run) async {
    requests.add('$op $what');
    final index = _failures.indexWhere((f) => f.op == null || f.op == op);
    if (index < 0) return run();
    final failure = _failures.removeAt(index);
    if (failure.afterApply) run();
    throw RemoteUnavailable(
      '$op $what (${failure.afterApply ? 'interrupted' : 'dropped'})',
    );
  }

  RemoteFile _create(String name, List<int> bytes) {
    final id = 'f${_nextId++}';
    _files[id] = _File(name, Uint8List.fromList(bytes), 1);
    _log.add(id);
    return RemoteFile(id: id, name: name, version: 1);
  }

  RemoteFile _fileOrThrow(String id) {
    final file = _files[id];
    if (file == null) throw RemoteNotFound(id);
    return RemoteFile(id: id, name: file.name, version: file.version);
  }

  @override
  Future<RemoteChanges> changes(String? pageToken) =>
      _request('changes', pageToken ?? 'all', () {
        final start = pageToken == null ? 0 : int.parse(pageToken);
        final changed = <String>{};
        final removed = <String>{};
        for (final id in _log.skip(start)) {
          (_files.containsKey(id) ? changed : removed).add(id);
        }
        if (pageToken == null) removed.clear();
        return RemoteChanges(
          files: [for (final id in changed) _fileOrThrow(id)],
          removedFileIds: removed.toList(),
          nextPageToken: '${_log.length}',
        );
      });

  @override
  Future<List<RemoteFile>> findByName(String name) =>
      _request('findByName', name, () => named(name));

  @override
  Future<({String content, int version})> read(String fileId) =>
      _request('read', fileId, () {
        final file = _fileOrThrow(fileId);
        return (content: textOf(fileId)!, version: file.version);
      });

  @override
  Future<int> version(String fileId) =>
      _request('version', fileId, () => _fileOrThrow(fileId).version);

  @override
  Future<RemoteFile> create(String name, String content) =>
      _request('create', name, () => _create(name, utf8.encode(content)));

  @override
  Future<RemoteFile> update(String fileId, String content) =>
      _request('update', fileId, () {
        final file = _files[fileId];
        if (file == null) throw RemoteNotFound(fileId);
        _files[fileId] = _File(
          file.name,
          Uint8List.fromList(utf8.encode(content)),
          file.version + 1,
        );
        _log.add(fileId);
        return _fileOrThrow(fileId);
      });

  @override
  Future<RemoteFile> upload(String name, Uint8List bytes, String mimeType) =>
      _request('upload', name, () => _create(name, bytes));

  @override
  Future<Uint8List> download(String fileId) => _request('download', fileId, () {
    _fileOrThrow(fileId);
    return _files[fileId]!.bytes;
  });

  @override
  Future<void> delete(String fileId) => _request('delete', fileId, () {
    if (_files.remove(fileId) != null) _log.add(fileId);
  });
}

class _File {
  _File(this.name, this.bytes, this.version);

  final String name;
  final Uint8List bytes;
  final int version;
}
