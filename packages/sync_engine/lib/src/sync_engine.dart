import 'record.dart';
import 'record_codec.dart';
import 'stores.dart';

/// What one pass did.
class SyncReport {
  int pulled = 0;
  int pushed = 0;
  int uploaded = 0;
  int conflicts = 0;

  /// Pulled records waiting: from a newer Filbert, or for their project.
  int held = 0;

  /// Default names renumbered (m3-design §6.4).
  int renamed = 0;

  @override
  String toString() =>
      'SyncReport(pulled $pulled, pushed $pushed, uploaded $uploaded, '
      'conflicts $conflicts, held $held, renamed $renamed)';
}

/// One sync pass (m3-design §6.3) between a device's [local] store and
/// Drive ([remote]): pull and reconcile, then push.
///
/// A failed request ([RemoteUnavailable]) stops the pass. What was written
/// stays written: the pulled batch with its page token, and each record or
/// original pushed before it. The next pass carries on from there.
class SyncEngine {
  SyncEngine({
    required this.local,
    required this.remote,
    required this.deviceId,
    required this.now,
    this.codec = const RecordCodec(),
  });

  final LocalStore local;
  final RemoteStore remote;

  /// Stamps the engine's own edits (renumbered names, a losing duplicate
  /// view prefs record).
  final String deviceId;

  /// UTC epoch milliseconds.
  final int Function() now;
  final RecordCodec codec;

  Future<SyncReport> syncOnce() async {
    final report = SyncReport();
    await _pull(report);
    await _push(report);
    return report;
  }

  /// Settles a conflict (m3-design §7.2): keep this device's version (pushed
  /// next pass, over the remote one) or take the remote one.
  Future<void> resolveConflict(RecordKey key, {required bool keepLocal}) async {
    final conflict = (await local.conflicts())[key];
    if (conflict == null) return;
    final state = (await local.syncStates())[key];
    final batch = LocalBatch()..resolvedConflicts.add(key);
    if (keepLocal) {
      batch.states[key] = SyncState(
        fileId: conflict.fileId,
        remoteVersion: conflict.remoteVersion,
        syncedHash: state?.syncedHash ?? '',
      );
    } else {
      final decoded = codec.decode(conflict.remoteJson);
      if (decoded is! DecodedRecord) {
        throw StateError('unreadable conflict ${key.kind.wire} ${key.id}');
      }
      batch.records.add(decoded.record);
      batch.states[key] = SyncState(
        fileId: conflict.fileId,
        remoteVersion: conflict.remoteVersion,
        syncedHash: codec.hash(decoded.record),
      );
    }
    await local.apply(batch);
  }

  // ---------------------------------------------------------------- pull

  Future<void> _pull(SyncReport report) async {
    final changes = await remote.changes(await local.pageToken());
    final ctx = await _Context.load(local);

    final changedByKey = <RecordKey, List<RemoteFile>>{};
    for (final file in changes.files) {
      final key = recordKeyOfFile(file.name);
      if (key != null) changedByKey.putIfAbsent(key, () => []).add(file);
    }

    final pulled = <_Pulled>[];
    for (final MapEntry(:key, value: files) in changedByKey.entries) {
      final state = ctx.states[key];
      final file =
          files.length == 1 &&
              (state == null || state.fileId == files.single.id)
          ? files.single
          : await _keepOne(await remote.findByName(recordFileName(key)));
      if (file == null) continue;
      // Our own push coming back: no need to read it.
      if (state != null &&
          state.fileId == file.id &&
          state.remoteVersion == file.version &&
          state.heldJson == null) {
        continue;
      }
      final read = await remote.read(file.id);
      pulled.add(_Pulled(key, file.id, read.version, read.content));
    }
    // Held records are retried: their project may be here now, or the app
    // updated.
    for (final MapEntry(:key, value: state) in ctx.states.entries) {
      final held = state.heldJson;
      if (held != null && !changedByKey.containsKey(key)) {
        pulled.add(_Pulled(key, state.fileId, state.remoteVersion, held));
      }
    }
    pulled.sort((a, b) => a.key.kind.index.compareTo(b.key.kind.index));

    final batch = LocalBatch();
    for (final p in pulled) {
      _reconcile(p, ctx, batch, report);
    }
    _renumberDefaultNames(ctx, batch, report);
    batch.pageToken = changes.nextPageToken;
    await local.apply(batch);
  }

  /// Decides what a pulled version means here (the table in m3-design
  /// §6.3) and adds it to [batch].
  void _reconcile(
    _Pulled p,
    _Context ctx,
    LocalBatch batch,
    SyncReport report,
  ) {
    final key = p.key;
    final state = ctx.states[key];
    void setState(SyncState s) => ctx.states[key] = batch.states[key] = s;

    final decoded = codec.decode(p.json);
    final SyncRecord remoteRecord;
    switch (decoded) {
      case TooNewRecord():
        setState(
          SyncState(
            fileId: p.fileId,
            remoteVersion: p.version,
            syncedHash: state?.syncedHash,
            heldJson: p.json,
          ),
        );
        report.held++;
        return;
      case InvalidRecord():
        return;
      case DecodedRecord(:final record):
        if (record.key != key) return;
        remoteRecord = record;
    }

    // Our own push coming back, or nothing new.
    if (state != null &&
        state.fileId == p.fileId &&
        state.remoteVersion == p.version &&
        state.heldJson == null) {
      return;
    }

    // An image or view prefs waits for its project.
    if (key.kind != RecordKind.project &&
        ctx.records[(kind: RecordKind.project, id: remoteRecord.projectId!)] ==
            null) {
      setState(
        SyncState(
          fileId: p.fileId,
          remoteVersion: p.version,
          syncedHash: state?.syncedHash,
          heldJson: p.json,
        ),
      );
      report.held++;
      return;
    }

    final pending = ctx.conflicts[key];
    if (pending != null) {
      // Still undecided: the user will compare with the newest remote one.
      final updated = SyncConflict(
        key: key,
        fileId: p.fileId,
        remoteJson: p.json,
        remoteVersion: p.version,
        detectedAt: pending.detectedAt,
      );
      ctx.conflicts[key] = updated;
      batch.conflicts.add(updated);
      if (state?.heldJson != null) {
        setState(state!.copyWith(heldJson: () => null));
      }
      return;
    }

    final localRecord = ctx.records[key];
    final localChanged =
        localRecord != null &&
        (state?.syncedHash == null ||
            codec.hash(localRecord) != state!.syncedHash);
    // A version this device wrote whose reply was lost isn't a remote edit.
    final ownWrite =
        localRecord != null &&
        remoteRecord.updatedByDeviceId == deviceId &&
        remoteRecord.updatedAt <= localRecord.updatedAt;

    if (localRecord == null || !localChanged) {
      _applyRemote(p, remoteRecord, ctx, batch, report);
    } else if (ownWrite) {
      setState(
        SyncState(
          fileId: p.fileId,
          remoteVersion: p.version,
          syncedHash: codec.hash(remoteRecord),
        ),
      );
    } else if (codec.contentHash(localRecord) ==
        codec.contentHash(remoteRecord)) {
      // The same change made on both.
      _applyRemote(p, remoteRecord, ctx, batch, report);
    } else if (key.kind == RecordKind.viewPrefs) {
      // Newer wins, no prompt (proposal 4).
      if (_newer(remoteRecord, localRecord)) {
        _applyRemote(p, remoteRecord, ctx, batch, report);
      } else {
        // Ours is pushed over it.
        setState(
          SyncState(
            fileId: p.fileId,
            remoteVersion: p.version,
            syncedHash: codec.hash(remoteRecord),
          ),
        );
      }
    } else {
      final conflict = SyncConflict(
        key: key,
        fileId: p.fileId,
        remoteJson: p.json,
        remoteVersion: p.version,
        detectedAt: now(),
      );
      ctx.conflicts[key] = conflict;
      batch.conflicts.add(conflict);
      // The remote version is in the conflict now.
      if (state?.heldJson != null) {
        setState(state!.copyWith(heldJson: () => null));
      }
      report.conflicts++;
    }
  }

  void _applyRemote(
    _Pulled p,
    SyncRecord remoteRecord,
    _Context ctx,
    LocalBatch batch,
    SyncReport report,
  ) {
    var record = remoteRecord;
    // One live view prefs record per project (m2-design §4.1): newer wins,
    // the other is tombstoned and the tombstone synced.
    if (record.kind == RecordKind.viewPrefs && !record.isDeleted) {
      for (final other in ctx.records.values.toList()) {
        if (other.kind != RecordKind.viewPrefs ||
            other.isDeleted ||
            other.id == record.id ||
            other.projectId != record.projectId) {
          continue;
        }
        if (_newer(other, record)) {
          record = record.edited(now: now(), deviceId: deviceId, delete: true);
        } else {
          final loser = other.edited(
            now: now(),
            deviceId: deviceId,
            delete: true,
          );
          ctx.records[loser.key] = loser;
          batch.records.add(loser);
        }
      }
    }
    ctx.records[record.key] = record;
    batch.records.add(record);
    ctx.states[record.key] = batch.states[record.key] = SyncState(
      fileId: p.fileId,
      remoteVersion: p.version,
      syncedHash: codec.hash(remoteRecord),
    );
    report.pulled++;

    final blobId = record.blobId;
    if (record.kind == RecordKind.image &&
        blobId != null &&
        !ctx.blobs.containsKey(blobId)) {
      final blob = BlobSync(blobId: blobId, state: BlobState.remoteOnly);
      ctx.blobs[blobId] = blob;
      batch.blobs.add(blob);
    }
  }

  /// [a] is newer than [b]: later `updatedAt`, ties broken by id, so every
  /// device picks the same one.
  static bool _newer(SyncRecord a, SyncRecord b) => a.updatedAt != b.updatedAt
      ? a.updatedAt > b.updatedAt
      : a.id.compareTo(b.id) > 0;

  /// Live projects with the same default name: all but the first created
  /// get "(2)", "(3)"… (m3-design §6.4). Every device computes the same
  /// names (ties broken by id), so two devices doing it agree.
  void _renumberDefaultNames(
    _Context ctx,
    LocalBatch batch,
    SyncReport report,
  ) {
    final live = [
      for (final r in ctx.records.values)
        if (r.kind == RecordKind.project && !r.isDeleted) r,
    ];
    final taken = {for (final r in live) r.name};
    final byName = <String, List<SyncRecord>>{};
    for (final r in live) {
      if (r.nameIsDefault && !ctx.conflicts.containsKey(r.key)) {
        byName.putIfAbsent(r.name!, () => []).add(r);
      }
    }
    for (final MapEntry(key: name, value: group) in byName.entries) {
      if (group.length < 2) continue;
      group.sort(
        (a, b) => a.createdAt != b.createdAt
            ? a.createdAt.compareTo(b.createdAt)
            : a.id.compareTo(b.id),
      );
      var n = 2;
      for (final project in group.skip(1)) {
        while (taken.contains('$name ($n)')) {
          n++;
        }
        final renamed = project.edited(
          now: now(),
          deviceId: deviceId,
          fields: {'name': '$name ($n)'},
        );
        taken.add('$name ($n)');
        ctx.records[renamed.key] = renamed;
        batch.records.add(renamed);
        report.renamed++;
      }
    }
  }

  /// Keeps the highest version of a record file Drive holds twice (a
  /// retried create) and deletes the rest (m3-design §6.2).
  Future<RemoteFile?> _keepOne(List<RemoteFile> files) async {
    if (files.isEmpty) return null;
    final sorted = [...files]
      ..sort(
        (a, b) => a.version != b.version
            ? b.version.compareTo(a.version)
            : a.id.compareTo(b.id),
      );
    for (final extra in sorted.skip(1)) {
      try {
        await remote.delete(extra.id);
      } on RemoteNotFound {
        // Another device deleted it first.
      }
    }
    return sorted.first;
  }

  // ---------------------------------------------------------------- push

  Future<void> _push(SyncReport report) async {
    final ctx = await _Context.load(local);
    final waiting = [
      for (final r in ctx.records.values)
        if (_needsPush(r, ctx)) r,
    ]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    for (final record in waiting) {
      if (record.kind == RecordKind.image) await _upload(record, ctx, report);
      await _pushRecord(record.key, report);
    }
  }

  bool _needsPush(SyncRecord record, _Context ctx) {
    if (ctx.conflicts.containsKey(record.key)) return false;
    final state = ctx.states[record.key];
    if (state == null) return true;
    // A held remote version isn't overwritten before it's applied.
    if (state.heldJson != null) return false;
    return codec.hash(record) != state.syncedHash;
  }

  /// Uploads an image's original and thumbnail before its record
  /// (m3-design §6.3, step 3). An upload whose reply was lost is found by
  /// name, not uploaded again.
  Future<void> _upload(
    SyncRecord image,
    _Context ctx,
    SyncReport report,
  ) async {
    final blobId = image.blobId!;
    final existing = ctx.blobs[blobId];
    if ((existing?.state ?? BlobState.local) != BlobState.local) return;
    final bytes = await local.readBlob(blobId);
    if (bytes == null) {
      await local.apply(
        LocalBatch()
          ..blobs.add(BlobSync(blobId: blobId, state: BlobState.missing)),
      );
      return;
    }
    final mime = image.mimeType ?? 'image/jpeg';
    final name = blobFileName(blobId, mime);
    final file =
        (await remote.findByName(name)).firstOrNull ??
        await remote.upload(name, bytes, mime);
    String? thumbId;
    final thumb = await local.readThumbnail(blobId);
    if (thumb != null) {
      final thumbName = thumbFileName(blobId);
      thumbId =
          ((await remote.findByName(thumbName)).firstOrNull ??
                  await remote.upload(thumbName, thumb, 'image/jpeg'))
              .id;
    }
    final synced = BlobSync(
      blobId: blobId,
      state: BlobState.synced,
      fileId: file.id,
      thumbFileId: thumbId,
    );
    ctx.blobs[blobId] = synced;
    await local.apply(LocalBatch()..blobs.add(synced));
    report.uploaded++;
  }

  /// Creates or updates the record's file. Just before, its Drive version is
  /// checked; if another device changed it, that version is reconciled
  /// first, and the record is pushed only if it still needs to be.
  Future<void> _pushRecord(RecordKey key, SyncReport report) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final ctx = await _Context.load(local);
      final record = ctx.records[key];
      if (record == null || !_needsPush(record, ctx)) return;
      final state = ctx.states[key];
      final name = recordFileName(key);
      final content = codec.encode(record);

      RemoteFile? found;
      if (state != null) {
        try {
          final version = await remote.version(state.fileId);
          if (version == state.remoteVersion) {
            final updated = await remote.update(state.fileId, content);
            await _saveState(key, updated, record);
            report.pushed++;
            return;
          }
          found = RemoteFile(id: state.fileId, name: name, version: version);
        } on RemoteNotFound {
          // Deleted as a duplicate: look it up by name below.
        }
      }
      found ??= await _keepOne(await remote.findByName(name));
      if (found == null) {
        final created = await remote.create(name, content);
        await _saveState(key, created, record);
        report.pushed++;
        return;
      }
      // Changed on Drive since this device last saw it.
      final read = await remote.read(found.id);
      final batch = LocalBatch();
      _reconcile(
        _Pulled(key, found.id, read.version, read.content),
        ctx,
        batch,
        report,
      );
      await local.apply(batch);
    }
  }

  Future<void> _saveState(RecordKey key, RemoteFile file, SyncRecord record) =>
      local.apply(
        LocalBatch()
          ..states[key] = SyncState(
            fileId: file.id,
            remoteVersion: file.version,
            syncedHash: codec.hash(record),
          ),
      );
}

class _Pulled {
  _Pulled(this.key, this.fileId, this.version, this.json);

  final RecordKey key;
  final String fileId;
  final int version;
  final String json;
}

/// The local state a pass works on, updated as it decides.
class _Context {
  _Context(this.records, this.states, this.conflicts, this.blobs);

  static Future<_Context> load(LocalStore local) async => _Context(
    {for (final r in await local.records()) r.key: r},
    await local.syncStates(),
    await local.conflicts(),
    await local.blobs(),
  );

  final Map<RecordKey, SyncRecord> records;
  final Map<RecordKey, SyncState> states;
  final Map<RecordKey, SyncConflict> conflicts;
  final Map<String, BlobSync> blobs;
}
