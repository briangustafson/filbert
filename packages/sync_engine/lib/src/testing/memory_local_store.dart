import 'dart:typed_data';

import '../record.dart';
import '../stores.dart';

/// A device's data for the engine's tests, with what the app would do to it
/// ([write], [writeBlob]). [DeviceData] lets the same scenarios run against
/// the Drift store (T6).
abstract interface class DeviceData implements LocalStore {
  /// The app saving [record] (created, edited or tombstoned).
  Future<void> write(SyncRecord record);

  /// The app importing an original and making its thumbnail.
  Future<void> writeBlob(String blobId, Uint8List original, Uint8List? thumb);
}

/// [DeviceData] in memory. Like the Drift schema, it allows one live view
/// prefs record per project, and [apply] throws if a batch breaks that.
class MemoryLocalStore implements DeviceData {
  final _records = <RecordKey, SyncRecord>{};
  final _states = <RecordKey, SyncState>{};
  final _blobs = <String, BlobSync>{};
  final _blobBytes = <String, Uint8List>{};
  final _thumbs = <String, Uint8List>{};
  final _conflicts = <RecordKey, SyncConflict>{};
  String? _pageToken;

  /// How many batches were applied.
  var batches = 0;

  @override
  Future<void> write(SyncRecord record) async {
    _put(record);
    _checkViewPrefs();
  }

  @override
  Future<void> writeBlob(
    String blobId,
    Uint8List original,
    Uint8List? thumb,
  ) async {
    _blobBytes[blobId] = original;
    if (thumb != null) _thumbs[blobId] = thumb;
  }

  void _put(SyncRecord record) => _records[record.key] = record;

  void _checkViewPrefs() {
    final live = <String>{};
    for (final r in _records.values) {
      if (r.kind != RecordKind.viewPrefs || r.isDeleted) continue;
      if (!live.add(r.projectId!)) {
        throw StateError('two live view prefs for project ${r.projectId}');
      }
    }
  }

  @override
  Future<List<SyncRecord>> records() async => _records.values.toList();

  @override
  Future<SyncRecord?> record(RecordKey key) async => _records[key];

  @override
  Future<Map<RecordKey, SyncState>> syncStates() async => Map.of(_states);

  @override
  Future<Map<String, BlobSync>> blobs() async => Map.of(_blobs);

  @override
  Future<Map<RecordKey, SyncConflict>> conflicts() async => Map.of(_conflicts);

  @override
  Future<String?> pageToken() async => _pageToken;

  @override
  Future<void> apply(LocalBatch batch) async {
    batches++;
    final sorted = [...batch.records]
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    sorted.forEach(_put);
    _checkViewPrefs();
    _states.addAll(batch.states);
    for (final blob in batch.blobs) {
      _blobs[blob.blobId] = blob;
    }
    for (final key in batch.resolvedConflicts) {
      _conflicts.remove(key);
    }
    for (final conflict in batch.conflicts) {
      _conflicts[conflict.key] = conflict;
    }
    if (batch.pageToken != null) _pageToken = batch.pageToken;
  }

  @override
  Future<Uint8List?> readBlob(String blobId) async => _blobBytes[blobId];

  @override
  Future<Uint8List?> readThumbnail(String blobId) async => _thumbs[blobId];
}
