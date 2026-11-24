import 'dart:typed_data';

import 'record.dart';

/// Where a record stands with Drive (`sync_state`, m3-design §4.1).
class SyncState {
  const SyncState({
    required this.fileId,
    required this.remoteVersion,
    this.syncedHash,
    this.heldJson,
  });

  /// The record's Drive file.
  final String fileId;

  /// The file's Drive `version` when last pushed or pulled.
  final int remoteVersion;

  /// The record's hash when last pushed or pulled; null if the remote
  /// version was never applied ([heldJson]).
  final String? syncedHash;

  /// A pulled version not applied yet, retried every pass: written by a
  /// newer Filbert, or an image or view prefs whose project hasn't
  /// arrived.
  final String? heldJson;

  SyncState copyWith({
    String? fileId,
    int? remoteVersion,
    String? syncedHash,
    String? Function()? heldJson,
  }) => SyncState(
    fileId: fileId ?? this.fileId,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    syncedHash: syncedHash ?? this.syncedHash,
    heldJson: heldJson == null ? this.heldJson : heldJson(),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncState &&
      other.fileId == fileId &&
      other.remoteVersion == remoteVersion &&
      other.syncedHash == syncedHash &&
      other.heldJson == heldJson;

  @override
  int get hashCode => Object.hash(fileId, remoteVersion, syncedHash, heldJson);

  @override
  String toString() =>
      'SyncState($fileId v$remoteVersion ${syncedHash?.substring(0, 8)}'
      '${heldJson == null ? '' : ', held'})';
}

/// `blob_sync.state` (m3-design §4.2).
enum BlobState {
  /// On this device only: upload before its image's record.
  local,
  synced,

  /// Known from a pulled image; not downloaded yet (T9).
  remoteOnly,

  /// Purged on Drive and not here.
  missing,
}

/// An original's sync state (`blob_sync`, m3-design §4.2).
class BlobSync {
  const BlobSync({
    required this.blobId,
    required this.state,
    this.fileId,
    this.thumbFileId,
  });

  final String blobId;
  final BlobState state;
  final String? fileId;
  final String? thumbFileId;

  @override
  bool operator ==(Object other) =>
      other is BlobSync &&
      other.blobId == blobId &&
      other.state == state &&
      other.fileId == fileId &&
      other.thumbFileId == thumbFileId;

  @override
  int get hashCode => Object.hash(blobId, state, fileId, thumbFileId);

  @override
  String toString() => 'BlobSync($blobId ${state.name} $fileId $thumbFileId)';
}

/// Both versions of a record changed on two devices (`sync_conflicts`,
/// m3-design §4.3). The local one stays what the app shows; pushing it
/// waits until the user chooses (T10).
class SyncConflict {
  const SyncConflict({
    required this.key,
    required this.fileId,
    required this.remoteJson,
    required this.remoteVersion,
    required this.detectedAt,
  });

  final RecordKey key;
  final String fileId;
  final String remoteJson;
  final int remoteVersion;
  final int detectedAt;

  @override
  String toString() =>
      'SyncConflict(${key.kind.wire} ${key.id} v$remoteVersion)';
}

/// What one pass writes locally, in one transaction.
class LocalBatch {
  /// Records to write as they are (pulled, or stamped by the engine).
  final records = <SyncRecord>[];
  final states = <RecordKey, SyncState>{};
  final blobs = <BlobSync>[];
  final conflicts = <SyncConflict>[];
  final resolvedConflicts = <RecordKey>[];

  /// The page token to save, once the batch is written.
  String? pageToken;

  bool get isEmpty =>
      records.isEmpty &&
      states.isEmpty &&
      blobs.isEmpty &&
      conflicts.isEmpty &&
      resolvedConflicts.isEmpty &&
      pageToken == null;
}

/// The device's side (m3-design §6.1): Drift in the app (T6), memory in
/// tests.
abstract interface class LocalStore {
  /// Every record, tombstones too.
  Future<List<SyncRecord>> records();

  Future<SyncRecord?> record(RecordKey key);

  Future<Map<RecordKey, SyncState>> syncStates();

  Future<Map<String, BlobSync>> blobs();

  Future<Map<RecordKey, SyncConflict>> conflicts();

  /// The Changes API token from the last pass; null before the first.
  Future<String?> pageToken();

  /// Writes [batch] in one transaction: records in dependency order
  /// (projects, images, view prefs), so the UI updates once.
  Future<void> apply(LocalBatch batch);

  /// An original's bytes; null if it isn't on this device.
  Future<Uint8List?> readBlob(String blobId);

  /// The original's 512 px thumbnail; null if there's none yet.
  Future<Uint8List?> readThumbnail(String blobId);
}

/// A file in Drive's `appDataFolder`.
class RemoteFile {
  const RemoteFile({
    required this.id,
    required this.name,
    required this.version,
  });

  final String id;
  final String name;

  /// Drive's file `version`: grows with every change.
  final int version;

  @override
  String toString() => 'RemoteFile($name $id v$version)';
}

/// What changed on Drive since a page token.
class RemoteChanges {
  const RemoteChanges({
    required this.files,
    required this.removedFileIds,
    required this.nextPageToken,
  });

  /// Files created or changed, at their current version.
  final List<RemoteFile> files;
  final List<String> removedFileIds;

  /// Where the next pass starts.
  final String nextPageToken;
}

/// Thrown by a [RemoteStore] when a request failed: offline, timed out, or
/// refused. The pass stops; the next one retries.
class RemoteUnavailable implements Exception {
  const RemoteUnavailable([this.detail]);

  final Object? detail;

  @override
  String toString() => 'RemoteUnavailable($detail)';
}

/// Thrown by a [RemoteStore] when a file isn't there (deleted, say, as a
/// duplicate by another device).
class RemoteNotFound implements Exception {
  const RemoteNotFound(this.fileId);

  final String fileId;

  @override
  String toString() => 'RemoteNotFound($fileId)';
}

/// Drive's side (m3-design §6.1, §6.2): the flat `appDataFolder`.
/// `DriveRemoteStore` in the app (T8); [FakeRemoteStore] in tests.
abstract interface class RemoteStore {
  /// Changes since [pageToken]; with null, every file (a first sync).
  Future<RemoteChanges> changes(String? pageToken);

  /// Every file named [name] (Drive allows several).
  Future<List<RemoteFile>> findByName(String name);

  /// A file's content and current version.
  Future<({String content, int version})> read(String fileId);

  Future<int> version(String fileId);

  Future<RemoteFile> create(String name, String content);

  Future<RemoteFile> update(String fileId, String content);

  /// Uploads an original or thumbnail (resumable on Drive, T8).
  Future<RemoteFile> upload(String name, Uint8List bytes, String mimeType);

  /// An uploaded original's or thumbnail's bytes (for T9's downloads).
  Future<Uint8List> download(String fileId);

  Future<void> delete(String fileId);
}
