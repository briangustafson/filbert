import 'dart:io';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/clock.dart';
import '../../../core/db/app_database.dart';
import '../../../core/device/device_info.dart';
import '../../../core/files/file_store.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/imaging/image_metadata.dart';
import '../../projects/data/project_repository.dart'
    show ProjectNotFoundException;
import '../domain/project_image.dart';
import 'photo_source.dart';

part 'image_repository.g.dart';

/// A project's images: import, live views, the reference pointer, and
/// tombstone delete/restore (m1-design §3.3, §5, §5.2). Undo/redo of edits
/// arrives in M1 T10.
abstract interface class ImageRepository {
  /// Live images of the project, most recently added first. Includes the
  /// current reference; the UI separates it out using
  /// `Project.referenceImageId`.
  Stream<List<ProjectImage>> watchForProject(String projectId);

  /// The cover image of every live project that has one, by project id
  /// (m1-design §3.2): its newest live photo other than the reference, else
  /// its live reference.
  Stream<Map<String, ProjectImage>> watchCovers();

  /// Copies each photo into the blob store and adds it to the project with
  /// no edits, then deletes the photo's temporary file. Photos are imported
  /// independently; results are in input order. With [asReference] (one
  /// photo only), the new image becomes the project's reference.
  ///
  /// Throws [ProjectNotFoundException] if the project is missing or deleted.
  Future<List<ImportResult>> import(
    String projectId,
    List<PickedPhoto> photos, {
    bool asReference = false,
  });

  /// Makes [imageId] the project's reference, or clears the reference when
  /// null. The previous reference stays in the project (it shows in the
  /// grid). The image must be live and belong to the project.
  Future<void> setAsReference(String projectId, String? imageId);

  /// Tombstones the image. If it is the reference, the pointer is kept so
  /// that restore brings it back as the reference; the UI treats a deleted
  /// reference as an empty slot.
  Future<void> delete(String imageId);

  /// Clears the tombstone.
  Future<void> restore(String imageId);
}

sealed class ImportResult {
  const ImportResult(this.photo);

  final PickedPhoto photo;
}

class ImportSuccess extends ImportResult {
  const ImportSuccess(super.photo, this.image);

  final ProjectImage image;
}

class ImportFailure extends ImportResult {
  const ImportFailure(super.photo, this.error);

  final Object error;
}

class ImageNotFoundException implements Exception {
  const ImageNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'ImageNotFoundException: no live image with id $id';
}

class DriftImageRepository implements ImageRepository {
  DriftImageRepository({
    required this._db,
    required this._files,
    required this._metadata,
    required this._clock,
    required this._ids,
    required this._device,
  });

  final AppDatabase _db;
  final FileStore _files;
  final ImageMetadataReader _metadata;
  final Clock _clock;
  final IdGenerator _ids;
  final DeviceInfo _device;

  static final _noEdits = Edits.none.toJsonString();

  @override
  Stream<List<ProjectImage>> watchForProject(String projectId) {
    final query = _db.select(_db.images)
      ..where((i) => i.projectId.equals(projectId) & i.deletedAt.isNull())
      ..orderBy([
        (i) => OrderingTerm.desc(i.createdAt),
        (i) => OrderingTerm.desc(i.id),
      ]);
    return query.watch().map((rows) => rows.map(toProjectImage).toList());
  }

  @override
  Stream<Map<String, ProjectImage>> watchCovers() {
    final query =
        _db.select(_db.images).join([
            innerJoin(
              _db.projects,
              _db.projects.id.equalsExp(_db.images.projectId),
            ),
          ])
          ..where(
            _db.images.deletedAt.isNull() & _db.projects.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.desc(_db.images.createdAt),
            OrderingTerm.desc(_db.images.id),
          ]);
    return query.watch().map((rows) {
      final covers = <String, ProjectImage>{};
      final references = <String, ProjectImage>{};
      for (final row in rows) {
        final image = row.readTable(_db.images);
        final project = row.readTable(_db.projects);
        if (image.id == project.referenceImageId) {
          references[project.id] = toProjectImage(image);
        } else {
          covers.putIfAbsent(project.id, () => toProjectImage(image));
        }
      }
      for (final MapEntry(:key, :value) in references.entries) {
        covers.putIfAbsent(key, () => value);
      }
      return covers;
    });
  }

  @override
  Future<List<ImportResult>> import(
    String projectId,
    List<PickedPhoto> photos, {
    bool asReference = false,
  }) async {
    if (asReference && photos.length != 1) {
      throw ArgumentError.value(
        photos.length,
        'photos',
        'Exactly one photo can be imported as the reference',
      );
    }
    await _requireLiveProject(projectId);

    final results = <ImportResult>[];
    for (final photo in photos) {
      results.add(await _importOne(projectId, photo, asReference));
    }
    return results;
  }

  Future<ImportResult> _importOne(
    String projectId,
    PickedPhoto photo,
    bool asReference,
  ) async {
    final source = File(photo.path);
    String? blobId;
    String? extension;
    try {
      final meta = await _metadata.read(source);
      extension = extensionForMimeType[meta.mimeType]!;
      blobId = _ids.newId();
      await _files.putBlob(blobId, extension, source);

      final image = await _db.transaction(() async {
        await _requireLiveProject(projectId);
        final now = _clock.now().millisecondsSinceEpoch;
        final row = await _db
            .into(_db.images)
            .insertReturning(
              ImagesCompanion.insert(
                id: _ids.newId(),
                createdAt: now,
                updatedAt: now,
                updatedByDeviceId: _device.deviceId,
                projectId: projectId,
                blobId: blobId!,
                mimeType: meta.mimeType,
                width: meta.width,
                height: meta.height,
                source: photo.origin,
                capturedAt: Value(meta.capturedAt?.millisecondsSinceEpoch),
                editsJson: _noEdits,
              ),
            );
        await _touchProject(
          projectId,
          referenceImageId: asReference ? Value(row.id) : const Value.absent(),
        );
        return toProjectImage(row);
      });
      return ImportSuccess(photo, image);
    } catch (error) {
      if (blobId != null && extension != null) {
        await _files.deleteBlob(blobId, extension);
      }
      return ImportFailure(photo, error);
    } finally {
      if (await source.exists()) await source.delete();
    }
  }

  @override
  Future<void> setAsReference(String projectId, String? imageId) {
    return _db.transaction(() async {
      final project = await _requireLiveProject(projectId);
      if (imageId != null) {
        final image = await _liveImage(imageId);
        if (image.projectId != projectId) {
          throw ArgumentError.value(
            imageId,
            'imageId',
            'Image belongs to a different project',
          );
        }
      }
      if (project.referenceImageId == imageId) return;
      await _touchProject(projectId, referenceImageId: Value(imageId));
    });
  }

  @override
  Future<void> delete(String imageId) => _setDeleted(imageId, deleted: true);

  @override
  Future<void> restore(String imageId) => _setDeleted(imageId, deleted: false);

  Future<void> _setDeleted(String imageId, {required bool deleted}) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.images,
      )..where((i) => i.id.equals(imageId))).getSingleOrNull();
      if (row == null) throw ImageNotFoundException(imageId);
      if ((row.deletedAt != null) == deleted) return;
      final now = _clock.now().millisecondsSinceEpoch;
      await (_db.update(_db.images)..where((i) => i.id.equals(imageId))).write(
        ImagesCompanion(
          deletedAt: Value(deleted ? now : null),
          updatedAt: Value(now),
          updatedByDeviceId: Value(_device.deviceId),
        ),
      );
    });
  }

  Future<ProjectRecord> _requireLiveProject(String projectId) async {
    final row =
        await (_db.select(_db.projects)
              ..where((p) => p.id.equals(projectId) & p.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) throw ProjectNotFoundException(projectId);
    return row;
  }

  Future<ImageRecord> _liveImage(String imageId) async {
    final row =
        await (_db.select(_db.images)
              ..where((i) => i.id.equals(imageId) & i.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) throw ImageNotFoundException(imageId);
    return row;
  }

  Future<void> _touchProject(
    String projectId, {
    Value<String?> referenceImageId = const Value.absent(),
  }) {
    return (_db.update(
      _db.projects,
    )..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(
        updatedAt: Value(_clock.now().millisecondsSinceEpoch),
        updatedByDeviceId: Value(_device.deviceId),
        referenceImageId: referenceImageId,
      ),
    );
  }

  static ProjectImage toProjectImage(ImageRecord r) => ProjectImage(
    id: r.id,
    projectId: r.projectId,
    blobId: r.blobId,
    mimeType: r.mimeType,
    width: r.width,
    height: r.height,
    origin: r.source,
    capturedAt: r.capturedAt == null ? null : _time(r.capturedAt!),
    edits: Edits.fromJsonString(r.editsJson),
    createdAt: _time(r.createdAt),
    updatedAt: _time(r.updatedAt),
    updatedByDeviceId: r.updatedByDeviceId,
  );

  static DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

@Riverpod(keepAlive: true)
ImageRepository imageRepository(Ref ref) => DriftImageRepository(
  db: ref.watch(databaseProvider),
  files: ref.watch(fileStoreProvider),
  metadata: ref.watch(imageMetadataReaderProvider),
  clock: ref.watch(clockProvider),
  ids: ref.watch(idGeneratorProvider),
  device: ref.watch(deviceInfoProvider),
);
