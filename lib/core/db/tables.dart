import 'package:drift/drift.dart';

import '../imaging/image_origin.dart';
import '../units/length_unit.dart';

export '../imaging/image_origin.dart';
export '../units/length_unit.dart';

// Schema v1 (m1-design §4.1). Any change here needs a schema version bump,
// a migration, and `dart run drift_dev make-migrations`.
//
// Timestamps are UTC epoch milliseconds. Relationships are declared with
// `references` for documentation but are not enforced (foreign_keys is off):
// sync may deliver an image before its project, and records are tombstoned,
// not deleted. Repositories keep references consistent.

enum SizeKind { none, ratio, physical }

class LengthUnitConverter extends TypeConverter<LengthUnit, String> {
  const LengthUnitConverter();

  @override
  LengthUnit fromSql(String fromDb) => LengthUnit.fromCode(fromDb);

  @override
  String toSql(LengthUnit value) => value.code;
}

/// Columns every synced record has (engineering guidelines, "Data").
mixin SyncedColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get updatedByDeviceId => text()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProjectRecord')
class Projects extends Table with SyncedColumns {
  TextColumn get name => text()();
  BoolColumn get nameIsDefault => boolean()();
  TextColumn get sizeKind =>
      textEnum<SizeKind>().withDefault(Constant(SizeKind.none.name))();
  RealColumn get ratioW => real().nullable()();
  RealColumn get ratioH => real().nullable()();
  RealColumn get width => real().nullable()();
  RealColumn get height => real().nullable()();
  TextColumn get unit => text().map(const LengthUnitConverter()).nullable()();
  TextColumn get startNotes => text().withDefault(const Constant(''))();
  TextColumn get referenceImageId =>
      text().nullable().references(Images, #id)();
}

@DataClassName('ImageRecord')
@TableIndex(name: 'images_project_id', columns: {#projectId})
class Images extends Table with SyncedColumns {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get blobId => text()();
  TextColumn get mimeType => text()();

  /// Pixel size after EXIF orientation.
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn get source => textEnum<ImageOrigin>()();
  IntColumn get capturedAt => integer().nullable()();

  /// Current edit state (m1-design §4.2).
  TextColumn get editsJson => text()();
}

/// Local-only undo history; never synced.
@DataClassName('ImageEditHistoryEntry')
class ImageEditHistory extends Table {
  TextColumn get imageId => text().references(Images, #id)();
  IntColumn get seq => integer()();
  TextColumn get editsJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {imageId, seq};
}

/// Local-only position in [ImageEditHistory], for redo.
@DataClassName('ImageEditCursorEntry')
class ImageEditCursor extends Table {
  TextColumn get imageId => text().references(Images, #id)();
  IntColumn get seq => integer()();

  @override
  Set<Column<Object>> get primaryKey => {imageId};
}

/// Local-only key/value settings and device identity.
@DataClassName('AppMetaEntry')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
