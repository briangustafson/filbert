import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sync_engine/sync_engine.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_meta_keys.dart';
import '../../../core/files/file_store.dart';
import '../../../core/imaging/image_metadata.dart';
import '../../photos/data/edit_history_table.dart';

/// The 512 px thumbnail of a blob's unedited original, as JPEG bytes, or
/// null. Drive keeps it uncropped; a device shows it with the image's crop
/// until the original arrives (m3-design §6.5, decided in T6).
typedef OriginalThumbnail = Future<Uint8List?> Function(String blobId);

/// The sync engine's [LocalStore] on the app's database (m3-design §6.1):
/// projects, images and view prefs as [SyncRecord]s, and the local-only
/// sync tables (§4).
class DriftLocalStore implements LocalStore {
  DriftLocalStore({
    required this._db,
    required this._files,
    required this._thumbnail,
  }) : _history = EditHistoryTable(_db);

  final AppDatabase _db;
  final FileStore _files;
  final OriginalThumbnail _thumbnail;
  final EditHistoryTable _history;

  // ------------------------------------------------------------ records

  @override
  Future<List<SyncRecord>> records() async => [
    for (final p in await _db.select(_db.projects).get()) projectRecord(p),
    for (final i in await _db.select(_db.images).get()) imageRecord(i),
    for (final v in await _db.select(_db.viewPrefs).get()) viewPrefsRecord(v),
  ];

  @override
  Future<SyncRecord?> record(RecordKey key) async {
    switch (key.kind) {
      case RecordKind.project:
        final row = await (_db.select(
          _db.projects,
        )..where((t) => t.id.equals(key.id))).getSingleOrNull();
        return row == null ? null : projectRecord(row);
      case RecordKind.image:
        final row = await (_db.select(
          _db.images,
        )..where((t) => t.id.equals(key.id))).getSingleOrNull();
        return row == null ? null : imageRecord(row);
      case RecordKind.viewPrefs:
        final row = await (_db.select(
          _db.viewPrefs,
        )..where((t) => t.id.equals(key.id))).getSingleOrNull();
        return row == null ? null : viewPrefsRecord(row);
    }
  }

  static SyncRecord _record(
    RecordKind kind, {
    required String id,
    required int createdAt,
    required int updatedAt,
    required String updatedByDeviceId,
    required int? deletedAt,
    required Map<String, Object?> fields,
  }) => SyncRecord(
    kind: kind,
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    updatedByDeviceId: updatedByDeviceId,
    deletedAt: deletedAt,
    fields: fields,
  );

  /// A project row in the record format; `size` is nested (§5).
  static SyncRecord projectRecord(ProjectRecord p) => _record(
    RecordKind.project,
    id: p.id,
    createdAt: p.createdAt,
    updatedAt: p.updatedAt,
    updatedByDeviceId: p.updatedByDeviceId,
    deletedAt: p.deletedAt,
    fields: {
      'name': p.name,
      'nameIsDefault': p.nameIsDefault,
      'size': switch (p.sizeKind) {
        SizeKind.none => {'kind': 'none'},
        SizeKind.ratio => {'kind': 'ratio', 'w': p.ratioW, 'h': p.ratioH},
        SizeKind.physical => {
          'kind': 'physical',
          'width': p.width,
          'height': p.height,
          'unit': p.unit?.code,
        },
      },
      'startNotes': p.startNotes,
      'referenceImageId': p.referenceImageId,
    },
  );

  static SyncRecord imageRecord(ImageRecord i) => _record(
    RecordKind.image,
    id: i.id,
    createdAt: i.createdAt,
    updatedAt: i.updatedAt,
    updatedByDeviceId: i.updatedByDeviceId,
    deletedAt: i.deletedAt,
    fields: {
      'projectId': i.projectId,
      'blobId': i.blobId,
      'mimeType': i.mimeType,
      'width': i.width,
      'height': i.height,
      'source': i.source.name,
      'capturedAt': i.capturedAt,
      'edits': jsonDecode(i.editsJson),
      'derivedFrom': i.derivedFromJson == null
          ? null
          : jsonDecode(i.derivedFromJson!),
    },
  );

  static SyncRecord viewPrefsRecord(ViewPrefsRecord v) => _record(
    RecordKind.viewPrefs,
    id: v.id,
    createdAt: v.createdAt,
    updatedAt: v.updatedAt,
    updatedByDeviceId: v.updatedByDeviceId,
    deletedAt: v.deletedAt,
    fields: {'projectId': v.projectId, 'prefs': jsonDecode(v.prefsJson)},
  );

  static double? _real(Object? value) => (value as num?)?.toDouble();

  static ProjectsCompanion _projectRow(SyncRecord r) {
    final size = r.fields['size']! as Map;
    final kind = switch (size['kind']) {
      'ratio' => SizeKind.ratio,
      'physical' => SizeKind.physical,
      _ => SizeKind.none,
    };
    final unit = size['unit'] as String?;
    return ProjectsCompanion.insert(
      id: r.id,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      updatedByDeviceId: r.updatedByDeviceId,
      deletedAt: Value(r.deletedAt),
      name: r.name!,
      nameIsDefault: r.nameIsDefault,
      sizeKind: Value(kind),
      ratioW: Value(kind == SizeKind.ratio ? _real(size['w']) : null),
      ratioH: Value(kind == SizeKind.ratio ? _real(size['h']) : null),
      width: Value(kind == SizeKind.physical ? _real(size['width']) : null),
      height: Value(kind == SizeKind.physical ? _real(size['height']) : null),
      unit: Value(
        kind == SizeKind.physical && unit != null
            ? LengthUnit.fromCode(unit)
            : null,
      ),
      startNotes: Value(r.fields['startNotes']! as String),
      referenceImageId: Value(r.fields['referenceImageId'] as String?),
    );
  }

  static ImagesCompanion _imageRow(SyncRecord r) {
    final derivedFrom = r.fields['derivedFrom'];
    return ImagesCompanion.insert(
      id: r.id,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      updatedByDeviceId: r.updatedByDeviceId,
      deletedAt: Value(r.deletedAt),
      projectId: r.projectId!,
      blobId: r.blobId!,
      mimeType: r.mimeType!,
      width: r.fields['width']! as int,
      height: r.fields['height']! as int,
      // A source this version doesn't know (from a newer Filbert) reads as a
      // device photo.
      source:
          ImageOrigin.values.asNameMap()[r.fields['source']] ??
          ImageOrigin.device,
      capturedAt: Value(r.fields['capturedAt'] as int?),
      editsJson: canonicalJson(r.fields['edits']),
      derivedFromJson: Value(
        derivedFrom == null ? null : canonicalJson(derivedFrom),
      ),
    );
  }

  static ViewPrefsCompanion _viewPrefsRow(SyncRecord r) =>
      ViewPrefsCompanion.insert(
        id: r.id,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        updatedByDeviceId: r.updatedByDeviceId,
        deletedAt: Value(r.deletedAt),
        projectId: r.projectId!,
        prefsJson: canonicalJson(r.fields['prefs']),
      );

  /// Writes [record] as it is: a pulled version, or one the engine stamped.
  /// A pulled crop goes into the image's undo history, so Undo returns to
  /// what this device had (decided in T6).
  Future<void> _write(SyncRecord record) async {
    switch (record.kind) {
      case RecordKind.project:
        await _db
            .into(_db.projects)
            .insertOnConflictUpdate(_projectRow(record));
      case RecordKind.image:
        final row = _imageRow(record);
        final before = await (_db.select(
          _db.images,
        )..where((t) => t.id.equals(record.id))).getSingleOrNull();
        if (before != null && before.editsJson != row.editsJson.value) {
          await _history.recordChange(
            record.id,
            before.editsJson,
            row.editsJson.value,
          );
        }
        await _db.into(_db.images).insertOnConflictUpdate(row);
      case RecordKind.viewPrefs:
        await _db
            .into(_db.viewPrefs)
            .insertOnConflictUpdate(_viewPrefsRow(record));
    }
  }

  // ------------------------------------------------------- sync tables

  @override
  Future<Map<RecordKey, SyncState>> syncStates() async => {
    for (final row in await _db.select(_db.syncStates).get())
      if (RecordKind.fromWire(row.kind) case final kind?)
        (kind: kind, id: row.recordId): SyncState(
          fileId: row.driveFileId,
          remoteVersion: row.remoteVersion,
          syncedHash: row.syncedHash,
          heldJson: row.heldJson,
        ),
  };

  @override
  Future<Map<String, BlobSync>> blobs() async => {
    for (final row in await _db.select(_db.blobSyncs).get())
      row.blobId: BlobSync(
        blobId: row.blobId,
        state: BlobState.values.asNameMap()[row.state] ?? BlobState.local,
        fileId: row.driveFileId,
        thumbFileId: row.thumbFileId,
      ),
  };

  @override
  Future<Map<RecordKey, SyncConflict>> conflicts() async => {
    for (final row in await _db.select(_db.syncConflicts).get())
      if (RecordKind.fromWire(row.kind) case final kind?)
        (kind: kind, id: row.recordId): SyncConflict(
          key: (kind: kind, id: row.recordId),
          fileId: row.driveFileId,
          remoteJson: row.remoteJson,
          remoteVersion: row.remoteVersion,
          detectedAt: row.detectedAt,
        ),
  };

  @override
  Future<String?> pageToken() async =>
      (await (_db.select(_db.appMeta)
                ..where((m) => m.key.equals(AppMetaKeys.changesPageToken)))
              .getSingleOrNull())
          ?.value;

  @override
  Future<void> apply(LocalBatch batch) => _db.transaction(() async {
    // Dependency order; within a kind, tombstones first, so a view prefs
    // record replacing another never makes two live ones for a project.
    final records = [...batch.records]
      ..sort((a, b) {
        final byKind = a.kind.index.compareTo(b.kind.index);
        if (byKind != 0) return byKind;
        return (a.isDeleted ? 0 : 1).compareTo(b.isDeleted ? 0 : 1);
      });
    for (final record in records) {
      await _write(record);
    }
    for (final MapEntry(:key, value: state) in batch.states.entries) {
      await _db
          .into(_db.syncStates)
          .insertOnConflictUpdate(
            SyncStatesCompanion.insert(
              kind: key.kind.wire,
              recordId: key.id,
              driveFileId: state.fileId,
              remoteVersion: state.remoteVersion,
              syncedHash: Value(state.syncedHash),
              heldJson: Value(state.heldJson),
            ),
          );
    }
    for (final blob in batch.blobs) {
      await _db
          .into(_db.blobSyncs)
          .insertOnConflictUpdate(
            BlobSyncsCompanion.insert(
              blobId: blob.blobId,
              state: blob.state.name,
              driveFileId: Value(blob.fileId),
              thumbFileId: Value(blob.thumbFileId),
            ),
          );
    }
    for (final key in batch.resolvedConflicts) {
      await (_db.delete(_db.syncConflicts)..where(
            (c) => c.kind.equals(key.kind.wire) & c.recordId.equals(key.id),
          ))
          .go();
    }
    for (final conflict in batch.conflicts) {
      await _db
          .into(_db.syncConflicts)
          .insertOnConflictUpdate(
            SyncConflictsCompanion.insert(
              kind: conflict.key.kind.wire,
              recordId: conflict.key.id,
              driveFileId: conflict.fileId,
              remoteJson: conflict.remoteJson,
              remoteVersion: conflict.remoteVersion,
              detectedAt: conflict.detectedAt,
            ),
          );
    }
    final token = batch.pageToken;
    if (token != null) {
      await _db
          .into(_db.appMeta)
          .insertOnConflictUpdate(
            AppMetaCompanion.insert(
              key: AppMetaKeys.changesPageToken,
              value: token,
            ),
          );
    }
  });

  // -------------------------------------------------------------- blobs

  @override
  Future<Uint8List?> readBlob(String blobId) async {
    final image =
        await (_db.select(_db.images)
              ..where((t) => t.blobId.equals(blobId))
              ..limit(1))
            .getSingleOrNull();
    final extension = extensionForMimeType[image?.mimeType];
    if (extension == null) return null;
    final file = _files.blobFile(blobId, extension);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<Uint8List?> readThumbnail(String blobId) => _thumbnail(blobId);
}
