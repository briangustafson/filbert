// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ImagesTable extends Images with TableInfo<$ImagesTable, ImageRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedByDeviceIdMeta = const VerificationMeta(
    'updatedByDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedByDeviceId =
      GeneratedColumn<String>(
        'updated_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ImageOrigin, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ImageOrigin>($ImagesTable.$convertersource);
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _editsJsonMeta = const VerificationMeta(
    'editsJson',
  );
  @override
  late final GeneratedColumn<String> editsJson = GeneratedColumn<String>(
    'edits_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _derivedFromJsonMeta = const VerificationMeta(
    'derivedFromJson',
  );
  @override
  late final GeneratedColumn<String> derivedFromJson = GeneratedColumn<String>(
    'derived_from_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    updatedByDeviceId,
    deletedAt,
    projectId,
    blobId,
    mimeType,
    width,
    height,
    source,
    capturedAt,
    editsJson,
    derivedFromJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'images';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('updated_by_device_id')) {
      context.handle(
        _updatedByDeviceIdMeta,
        updatedByDeviceId.isAcceptableOrUnknown(
          data['updated_by_device_id']!,
          _updatedByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedByDeviceIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('edits_json')) {
      context.handle(
        _editsJsonMeta,
        editsJson.isAcceptableOrUnknown(data['edits_json']!, _editsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_editsJsonMeta);
    }
    if (data.containsKey('derived_from_json')) {
      context.handle(
        _derivedFromJsonMeta,
        derivedFromJson.isAcceptableOrUnknown(
          data['derived_from_json']!,
          _derivedFromJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImageRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      updatedByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by_device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      source: $ImagesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      ),
      editsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edits_json'],
      )!,
      derivedFromJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}derived_from_json'],
      ),
    );
  }

  @override
  $ImagesTable createAlias(String alias) {
    return $ImagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ImageOrigin, String, String> $convertersource =
      const EnumNameConverter<ImageOrigin>(ImageOrigin.values);
}

class ImageRecord extends DataClass implements Insertable<ImageRecord> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String updatedByDeviceId;
  final int? deletedAt;
  final String projectId;
  final String blobId;
  final String mimeType;

  /// Pixel size after EXIF orientation.
  final int width;
  final int height;
  final ImageOrigin source;
  final int? capturedAt;

  /// Current edit state (m1-design §4.2).
  final String editsJson;

  /// For `source = derived`: where the image was rendered from
  /// (m2-design §4.3). Null for other sources. Added in schema 2.
  final String? derivedFromJson;
  const ImageRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByDeviceId,
    this.deletedAt,
    required this.projectId,
    required this.blobId,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.source,
    this.capturedAt,
    required this.editsJson,
    this.derivedFromJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['updated_by_device_id'] = Variable<String>(updatedByDeviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['project_id'] = Variable<String>(projectId);
    map['blob_id'] = Variable<String>(blobId);
    map['mime_type'] = Variable<String>(mimeType);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    {
      map['source'] = Variable<String>(
        $ImagesTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<int>(capturedAt);
    }
    map['edits_json'] = Variable<String>(editsJson);
    if (!nullToAbsent || derivedFromJson != null) {
      map['derived_from_json'] = Variable<String>(derivedFromJson);
    }
    return map;
  }

  ImagesCompanion toCompanion(bool nullToAbsent) {
    return ImagesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      updatedByDeviceId: Value(updatedByDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      projectId: Value(projectId),
      blobId: Value(blobId),
      mimeType: Value(mimeType),
      width: Value(width),
      height: Value(height),
      source: Value(source),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      editsJson: Value(editsJson),
      derivedFromJson: derivedFromJson == null && nullToAbsent
          ? const Value.absent()
          : Value(derivedFromJson),
    );
  }

  factory ImageRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      updatedByDeviceId: serializer.fromJson<String>(json['updatedByDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      projectId: serializer.fromJson<String>(json['projectId']),
      blobId: serializer.fromJson<String>(json['blobId']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      source: $ImagesTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      capturedAt: serializer.fromJson<int?>(json['capturedAt']),
      editsJson: serializer.fromJson<String>(json['editsJson']),
      derivedFromJson: serializer.fromJson<String?>(json['derivedFromJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'updatedByDeviceId': serializer.toJson<String>(updatedByDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'projectId': serializer.toJson<String>(projectId),
      'blobId': serializer.toJson<String>(blobId),
      'mimeType': serializer.toJson<String>(mimeType),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'source': serializer.toJson<String>(
        $ImagesTable.$convertersource.toJson(source),
      ),
      'capturedAt': serializer.toJson<int?>(capturedAt),
      'editsJson': serializer.toJson<String>(editsJson),
      'derivedFromJson': serializer.toJson<String?>(derivedFromJson),
    };
  }

  ImageRecord copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? updatedByDeviceId,
    Value<int?> deletedAt = const Value.absent(),
    String? projectId,
    String? blobId,
    String? mimeType,
    int? width,
    int? height,
    ImageOrigin? source,
    Value<int?> capturedAt = const Value.absent(),
    String? editsJson,
    Value<String?> derivedFromJson = const Value.absent(),
  }) => ImageRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    projectId: projectId ?? this.projectId,
    blobId: blobId ?? this.blobId,
    mimeType: mimeType ?? this.mimeType,
    width: width ?? this.width,
    height: height ?? this.height,
    source: source ?? this.source,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    editsJson: editsJson ?? this.editsJson,
    derivedFromJson: derivedFromJson.present
        ? derivedFromJson.value
        : this.derivedFromJson,
  );
  ImageRecord copyWithCompanion(ImagesCompanion data) {
    return ImageRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedByDeviceId: data.updatedByDeviceId.present
          ? data.updatedByDeviceId.value
          : this.updatedByDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      source: data.source.present ? data.source.value : this.source,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      editsJson: data.editsJson.present ? data.editsJson.value : this.editsJson,
      derivedFromJson: data.derivedFromJson.present
          ? data.derivedFromJson.value
          : this.derivedFromJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedByDeviceId: $updatedByDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('projectId: $projectId, ')
          ..write('blobId: $blobId, ')
          ..write('mimeType: $mimeType, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('source: $source, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('editsJson: $editsJson, ')
          ..write('derivedFromJson: $derivedFromJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    updatedByDeviceId,
    deletedAt,
    projectId,
    blobId,
    mimeType,
    width,
    height,
    source,
    capturedAt,
    editsJson,
    derivedFromJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.updatedByDeviceId == this.updatedByDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.projectId == this.projectId &&
          other.blobId == this.blobId &&
          other.mimeType == this.mimeType &&
          other.width == this.width &&
          other.height == this.height &&
          other.source == this.source &&
          other.capturedAt == this.capturedAt &&
          other.editsJson == this.editsJson &&
          other.derivedFromJson == this.derivedFromJson);
}

class ImagesCompanion extends UpdateCompanion<ImageRecord> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> updatedByDeviceId;
  final Value<int?> deletedAt;
  final Value<String> projectId;
  final Value<String> blobId;
  final Value<String> mimeType;
  final Value<int> width;
  final Value<int> height;
  final Value<ImageOrigin> source;
  final Value<int?> capturedAt;
  final Value<String> editsJson;
  final Value<String?> derivedFromJson;
  final Value<int> rowid;
  const ImagesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedByDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.projectId = const Value.absent(),
    this.blobId = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.source = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.editsJson = const Value.absent(),
    this.derivedFromJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImagesCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    required String updatedByDeviceId,
    this.deletedAt = const Value.absent(),
    required String projectId,
    required String blobId,
    required String mimeType,
    required int width,
    required int height,
    required ImageOrigin source,
    this.capturedAt = const Value.absent(),
    required String editsJson,
    this.derivedFromJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       updatedByDeviceId = Value(updatedByDeviceId),
       projectId = Value(projectId),
       blobId = Value(blobId),
       mimeType = Value(mimeType),
       width = Value(width),
       height = Value(height),
       source = Value(source),
       editsJson = Value(editsJson);
  static Insertable<ImageRecord> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? updatedByDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? projectId,
    Expression<String>? blobId,
    Expression<String>? mimeType,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? source,
    Expression<int>? capturedAt,
    Expression<String>? editsJson,
    Expression<String>? derivedFromJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedByDeviceId != null) 'updated_by_device_id': updatedByDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (projectId != null) 'project_id': projectId,
      if (blobId != null) 'blob_id': blobId,
      if (mimeType != null) 'mime_type': mimeType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (source != null) 'source': source,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (editsJson != null) 'edits_json': editsJson,
      if (derivedFromJson != null) 'derived_from_json': derivedFromJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImagesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? updatedByDeviceId,
    Value<int?>? deletedAt,
    Value<String>? projectId,
    Value<String>? blobId,
    Value<String>? mimeType,
    Value<int>? width,
    Value<int>? height,
    Value<ImageOrigin>? source,
    Value<int?>? capturedAt,
    Value<String>? editsJson,
    Value<String?>? derivedFromJson,
    Value<int>? rowid,
  }) {
    return ImagesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      projectId: projectId ?? this.projectId,
      blobId: blobId ?? this.blobId,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      source: source ?? this.source,
      capturedAt: capturedAt ?? this.capturedAt,
      editsJson: editsJson ?? this.editsJson,
      derivedFromJson: derivedFromJson ?? this.derivedFromJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (updatedByDeviceId.present) {
      map['updated_by_device_id'] = Variable<String>(updatedByDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ImagesTable.$convertersource.toSql(source.value),
      );
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (editsJson.present) {
      map['edits_json'] = Variable<String>(editsJson.value);
    }
    if (derivedFromJson.present) {
      map['derived_from_json'] = Variable<String>(derivedFromJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImagesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedByDeviceId: $updatedByDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('projectId: $projectId, ')
          ..write('blobId: $blobId, ')
          ..write('mimeType: $mimeType, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('source: $source, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('editsJson: $editsJson, ')
          ..write('derivedFromJson: $derivedFromJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects
    with TableInfo<$ProjectsTable, ProjectRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedByDeviceIdMeta = const VerificationMeta(
    'updatedByDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedByDeviceId =
      GeneratedColumn<String>(
        'updated_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameIsDefaultMeta = const VerificationMeta(
    'nameIsDefault',
  );
  @override
  late final GeneratedColumn<bool> nameIsDefault = GeneratedColumn<bool>(
    'name_is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("name_is_default" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SizeKind, String> sizeKind =
      GeneratedColumn<String>(
        'size_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(SizeKind.none.name),
      ).withConverter<SizeKind>($ProjectsTable.$convertersizeKind);
  static const VerificationMeta _ratioWMeta = const VerificationMeta('ratioW');
  @override
  late final GeneratedColumn<double> ratioW = GeneratedColumn<double>(
    'ratio_w',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratioHMeta = const VerificationMeta('ratioH');
  @override
  late final GeneratedColumn<double> ratioH = GeneratedColumn<double>(
    'ratio_h',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LengthUnit?, String> unit =
      GeneratedColumn<String>(
        'unit',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<LengthUnit?>($ProjectsTable.$converterunitn);
  static const VerificationMeta _startNotesMeta = const VerificationMeta(
    'startNotes',
  );
  @override
  late final GeneratedColumn<String> startNotes = GeneratedColumn<String>(
    'start_notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _referenceImageIdMeta = const VerificationMeta(
    'referenceImageId',
  );
  @override
  late final GeneratedColumn<String> referenceImageId = GeneratedColumn<String>(
    'reference_image_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES images (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    updatedByDeviceId,
    deletedAt,
    name,
    nameIsDefault,
    sizeKind,
    ratioW,
    ratioH,
    width,
    height,
    unit,
    startNotes,
    referenceImageId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('updated_by_device_id')) {
      context.handle(
        _updatedByDeviceIdMeta,
        updatedByDeviceId.isAcceptableOrUnknown(
          data['updated_by_device_id']!,
          _updatedByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedByDeviceIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_is_default')) {
      context.handle(
        _nameIsDefaultMeta,
        nameIsDefault.isAcceptableOrUnknown(
          data['name_is_default']!,
          _nameIsDefaultMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameIsDefaultMeta);
    }
    if (data.containsKey('ratio_w')) {
      context.handle(
        _ratioWMeta,
        ratioW.isAcceptableOrUnknown(data['ratio_w']!, _ratioWMeta),
      );
    }
    if (data.containsKey('ratio_h')) {
      context.handle(
        _ratioHMeta,
        ratioH.isAcceptableOrUnknown(data['ratio_h']!, _ratioHMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('start_notes')) {
      context.handle(
        _startNotesMeta,
        startNotes.isAcceptableOrUnknown(data['start_notes']!, _startNotesMeta),
      );
    }
    if (data.containsKey('reference_image_id')) {
      context.handle(
        _referenceImageIdMeta,
        referenceImageId.isAcceptableOrUnknown(
          data['reference_image_id']!,
          _referenceImageIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      updatedByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by_device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameIsDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}name_is_default'],
      )!,
      sizeKind: $ProjectsTable.$convertersizeKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}size_kind'],
        )!,
      ),
      ratioW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ratio_w'],
      ),
      ratioH: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ratio_h'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      ),
      unit: $ProjectsTable.$converterunitn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit'],
        ),
      ),
      startNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_notes'],
      )!,
      referenceImageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_image_id'],
      ),
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SizeKind, String, String> $convertersizeKind =
      const EnumNameConverter<SizeKind>(SizeKind.values);
  static TypeConverter<LengthUnit, String> $converterunit =
      const LengthUnitConverter();
  static TypeConverter<LengthUnit?, String?> $converterunitn =
      NullAwareTypeConverter.wrap($converterunit);
}

class ProjectRecord extends DataClass implements Insertable<ProjectRecord> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String updatedByDeviceId;
  final int? deletedAt;
  final String name;
  final bool nameIsDefault;
  final SizeKind sizeKind;
  final double? ratioW;
  final double? ratioH;
  final double? width;
  final double? height;
  final LengthUnit? unit;
  final String startNotes;
  final String? referenceImageId;
  const ProjectRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByDeviceId,
    this.deletedAt,
    required this.name,
    required this.nameIsDefault,
    required this.sizeKind,
    this.ratioW,
    this.ratioH,
    this.width,
    this.height,
    this.unit,
    required this.startNotes,
    this.referenceImageId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['updated_by_device_id'] = Variable<String>(updatedByDeviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    map['name_is_default'] = Variable<bool>(nameIsDefault);
    {
      map['size_kind'] = Variable<String>(
        $ProjectsTable.$convertersizeKind.toSql(sizeKind),
      );
    }
    if (!nullToAbsent || ratioW != null) {
      map['ratio_w'] = Variable<double>(ratioW);
    }
    if (!nullToAbsent || ratioH != null) {
      map['ratio_h'] = Variable<double>(ratioH);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<double>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<double>(height);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(
        $ProjectsTable.$converterunitn.toSql(unit),
      );
    }
    map['start_notes'] = Variable<String>(startNotes);
    if (!nullToAbsent || referenceImageId != null) {
      map['reference_image_id'] = Variable<String>(referenceImageId);
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      updatedByDeviceId: Value(updatedByDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      name: Value(name),
      nameIsDefault: Value(nameIsDefault),
      sizeKind: Value(sizeKind),
      ratioW: ratioW == null && nullToAbsent
          ? const Value.absent()
          : Value(ratioW),
      ratioH: ratioH == null && nullToAbsent
          ? const Value.absent()
          : Value(ratioH),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      startNotes: Value(startNotes),
      referenceImageId: referenceImageId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImageId),
    );
  }

  factory ProjectRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      updatedByDeviceId: serializer.fromJson<String>(json['updatedByDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
      nameIsDefault: serializer.fromJson<bool>(json['nameIsDefault']),
      sizeKind: $ProjectsTable.$convertersizeKind.fromJson(
        serializer.fromJson<String>(json['sizeKind']),
      ),
      ratioW: serializer.fromJson<double?>(json['ratioW']),
      ratioH: serializer.fromJson<double?>(json['ratioH']),
      width: serializer.fromJson<double?>(json['width']),
      height: serializer.fromJson<double?>(json['height']),
      unit: serializer.fromJson<LengthUnit?>(json['unit']),
      startNotes: serializer.fromJson<String>(json['startNotes']),
      referenceImageId: serializer.fromJson<String?>(json['referenceImageId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'updatedByDeviceId': serializer.toJson<String>(updatedByDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'name': serializer.toJson<String>(name),
      'nameIsDefault': serializer.toJson<bool>(nameIsDefault),
      'sizeKind': serializer.toJson<String>(
        $ProjectsTable.$convertersizeKind.toJson(sizeKind),
      ),
      'ratioW': serializer.toJson<double?>(ratioW),
      'ratioH': serializer.toJson<double?>(ratioH),
      'width': serializer.toJson<double?>(width),
      'height': serializer.toJson<double?>(height),
      'unit': serializer.toJson<LengthUnit?>(unit),
      'startNotes': serializer.toJson<String>(startNotes),
      'referenceImageId': serializer.toJson<String?>(referenceImageId),
    };
  }

  ProjectRecord copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? updatedByDeviceId,
    Value<int?> deletedAt = const Value.absent(),
    String? name,
    bool? nameIsDefault,
    SizeKind? sizeKind,
    Value<double?> ratioW = const Value.absent(),
    Value<double?> ratioH = const Value.absent(),
    Value<double?> width = const Value.absent(),
    Value<double?> height = const Value.absent(),
    Value<LengthUnit?> unit = const Value.absent(),
    String? startNotes,
    Value<String?> referenceImageId = const Value.absent(),
  }) => ProjectRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
    nameIsDefault: nameIsDefault ?? this.nameIsDefault,
    sizeKind: sizeKind ?? this.sizeKind,
    ratioW: ratioW.present ? ratioW.value : this.ratioW,
    ratioH: ratioH.present ? ratioH.value : this.ratioH,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    unit: unit.present ? unit.value : this.unit,
    startNotes: startNotes ?? this.startNotes,
    referenceImageId: referenceImageId.present
        ? referenceImageId.value
        : this.referenceImageId,
  );
  ProjectRecord copyWithCompanion(ProjectsCompanion data) {
    return ProjectRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedByDeviceId: data.updatedByDeviceId.present
          ? data.updatedByDeviceId.value
          : this.updatedByDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
      nameIsDefault: data.nameIsDefault.present
          ? data.nameIsDefault.value
          : this.nameIsDefault,
      sizeKind: data.sizeKind.present ? data.sizeKind.value : this.sizeKind,
      ratioW: data.ratioW.present ? data.ratioW.value : this.ratioW,
      ratioH: data.ratioH.present ? data.ratioH.value : this.ratioH,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      unit: data.unit.present ? data.unit.value : this.unit,
      startNotes: data.startNotes.present
          ? data.startNotes.value
          : this.startNotes,
      referenceImageId: data.referenceImageId.present
          ? data.referenceImageId.value
          : this.referenceImageId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedByDeviceId: $updatedByDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('nameIsDefault: $nameIsDefault, ')
          ..write('sizeKind: $sizeKind, ')
          ..write('ratioW: $ratioW, ')
          ..write('ratioH: $ratioH, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('unit: $unit, ')
          ..write('startNotes: $startNotes, ')
          ..write('referenceImageId: $referenceImageId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    updatedByDeviceId,
    deletedAt,
    name,
    nameIsDefault,
    sizeKind,
    ratioW,
    ratioH,
    width,
    height,
    unit,
    startNotes,
    referenceImageId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.updatedByDeviceId == this.updatedByDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name &&
          other.nameIsDefault == this.nameIsDefault &&
          other.sizeKind == this.sizeKind &&
          other.ratioW == this.ratioW &&
          other.ratioH == this.ratioH &&
          other.width == this.width &&
          other.height == this.height &&
          other.unit == this.unit &&
          other.startNotes == this.startNotes &&
          other.referenceImageId == this.referenceImageId);
}

class ProjectsCompanion extends UpdateCompanion<ProjectRecord> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> updatedByDeviceId;
  final Value<int?> deletedAt;
  final Value<String> name;
  final Value<bool> nameIsDefault;
  final Value<SizeKind> sizeKind;
  final Value<double?> ratioW;
  final Value<double?> ratioH;
  final Value<double?> width;
  final Value<double?> height;
  final Value<LengthUnit?> unit;
  final Value<String> startNotes;
  final Value<String?> referenceImageId;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedByDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.nameIsDefault = const Value.absent(),
    this.sizeKind = const Value.absent(),
    this.ratioW = const Value.absent(),
    this.ratioH = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.unit = const Value.absent(),
    this.startNotes = const Value.absent(),
    this.referenceImageId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    required String updatedByDeviceId,
    this.deletedAt = const Value.absent(),
    required String name,
    required bool nameIsDefault,
    this.sizeKind = const Value.absent(),
    this.ratioW = const Value.absent(),
    this.ratioH = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.unit = const Value.absent(),
    this.startNotes = const Value.absent(),
    this.referenceImageId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       updatedByDeviceId = Value(updatedByDeviceId),
       name = Value(name),
       nameIsDefault = Value(nameIsDefault);
  static Insertable<ProjectRecord> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? updatedByDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? name,
    Expression<bool>? nameIsDefault,
    Expression<String>? sizeKind,
    Expression<double>? ratioW,
    Expression<double>? ratioH,
    Expression<double>? width,
    Expression<double>? height,
    Expression<String>? unit,
    Expression<String>? startNotes,
    Expression<String>? referenceImageId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedByDeviceId != null) 'updated_by_device_id': updatedByDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (nameIsDefault != null) 'name_is_default': nameIsDefault,
      if (sizeKind != null) 'size_kind': sizeKind,
      if (ratioW != null) 'ratio_w': ratioW,
      if (ratioH != null) 'ratio_h': ratioH,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (unit != null) 'unit': unit,
      if (startNotes != null) 'start_notes': startNotes,
      if (referenceImageId != null) 'reference_image_id': referenceImageId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? updatedByDeviceId,
    Value<int?>? deletedAt,
    Value<String>? name,
    Value<bool>? nameIsDefault,
    Value<SizeKind>? sizeKind,
    Value<double?>? ratioW,
    Value<double?>? ratioH,
    Value<double?>? width,
    Value<double?>? height,
    Value<LengthUnit?>? unit,
    Value<String>? startNotes,
    Value<String?>? referenceImageId,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      nameIsDefault: nameIsDefault ?? this.nameIsDefault,
      sizeKind: sizeKind ?? this.sizeKind,
      ratioW: ratioW ?? this.ratioW,
      ratioH: ratioH ?? this.ratioH,
      width: width ?? this.width,
      height: height ?? this.height,
      unit: unit ?? this.unit,
      startNotes: startNotes ?? this.startNotes,
      referenceImageId: referenceImageId ?? this.referenceImageId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (updatedByDeviceId.present) {
      map['updated_by_device_id'] = Variable<String>(updatedByDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameIsDefault.present) {
      map['name_is_default'] = Variable<bool>(nameIsDefault.value);
    }
    if (sizeKind.present) {
      map['size_kind'] = Variable<String>(
        $ProjectsTable.$convertersizeKind.toSql(sizeKind.value),
      );
    }
    if (ratioW.present) {
      map['ratio_w'] = Variable<double>(ratioW.value);
    }
    if (ratioH.present) {
      map['ratio_h'] = Variable<double>(ratioH.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(
        $ProjectsTable.$converterunitn.toSql(unit.value),
      );
    }
    if (startNotes.present) {
      map['start_notes'] = Variable<String>(startNotes.value);
    }
    if (referenceImageId.present) {
      map['reference_image_id'] = Variable<String>(referenceImageId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedByDeviceId: $updatedByDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('nameIsDefault: $nameIsDefault, ')
          ..write('sizeKind: $sizeKind, ')
          ..write('ratioW: $ratioW, ')
          ..write('ratioH: $ratioH, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('unit: $unit, ')
          ..write('startNotes: $startNotes, ')
          ..write('referenceImageId: $referenceImageId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImageEditHistoryTable extends ImageEditHistory
    with TableInfo<$ImageEditHistoryTable, ImageEditHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageEditHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _imageIdMeta = const VerificationMeta(
    'imageId',
  );
  @override
  late final GeneratedColumn<String> imageId = GeneratedColumn<String>(
    'image_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES images (id)',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editsJsonMeta = const VerificationMeta(
    'editsJson',
  );
  @override
  late final GeneratedColumn<String> editsJson = GeneratedColumn<String>(
    'edits_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [imageId, seq, editsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_edit_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageEditHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('image_id')) {
      context.handle(
        _imageIdMeta,
        imageId.isAcceptableOrUnknown(data['image_id']!, _imageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_imageIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('edits_json')) {
      context.handle(
        _editsJsonMeta,
        editsJson.isAcceptableOrUnknown(data['edits_json']!, _editsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_editsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {imageId, seq};
  @override
  ImageEditHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageEditHistoryEntry(
      imageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      editsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edits_json'],
      )!,
    );
  }

  @override
  $ImageEditHistoryTable createAlias(String alias) {
    return $ImageEditHistoryTable(attachedDatabase, alias);
  }
}

class ImageEditHistoryEntry extends DataClass
    implements Insertable<ImageEditHistoryEntry> {
  final String imageId;
  final int seq;
  final String editsJson;
  const ImageEditHistoryEntry({
    required this.imageId,
    required this.seq,
    required this.editsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['image_id'] = Variable<String>(imageId);
    map['seq'] = Variable<int>(seq);
    map['edits_json'] = Variable<String>(editsJson);
    return map;
  }

  ImageEditHistoryCompanion toCompanion(bool nullToAbsent) {
    return ImageEditHistoryCompanion(
      imageId: Value(imageId),
      seq: Value(seq),
      editsJson: Value(editsJson),
    );
  }

  factory ImageEditHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageEditHistoryEntry(
      imageId: serializer.fromJson<String>(json['imageId']),
      seq: serializer.fromJson<int>(json['seq']),
      editsJson: serializer.fromJson<String>(json['editsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'imageId': serializer.toJson<String>(imageId),
      'seq': serializer.toJson<int>(seq),
      'editsJson': serializer.toJson<String>(editsJson),
    };
  }

  ImageEditHistoryEntry copyWith({
    String? imageId,
    int? seq,
    String? editsJson,
  }) => ImageEditHistoryEntry(
    imageId: imageId ?? this.imageId,
    seq: seq ?? this.seq,
    editsJson: editsJson ?? this.editsJson,
  );
  ImageEditHistoryEntry copyWithCompanion(ImageEditHistoryCompanion data) {
    return ImageEditHistoryEntry(
      imageId: data.imageId.present ? data.imageId.value : this.imageId,
      seq: data.seq.present ? data.seq.value : this.seq,
      editsJson: data.editsJson.present ? data.editsJson.value : this.editsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageEditHistoryEntry(')
          ..write('imageId: $imageId, ')
          ..write('seq: $seq, ')
          ..write('editsJson: $editsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(imageId, seq, editsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageEditHistoryEntry &&
          other.imageId == this.imageId &&
          other.seq == this.seq &&
          other.editsJson == this.editsJson);
}

class ImageEditHistoryCompanion extends UpdateCompanion<ImageEditHistoryEntry> {
  final Value<String> imageId;
  final Value<int> seq;
  final Value<String> editsJson;
  final Value<int> rowid;
  const ImageEditHistoryCompanion({
    this.imageId = const Value.absent(),
    this.seq = const Value.absent(),
    this.editsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageEditHistoryCompanion.insert({
    required String imageId,
    required int seq,
    required String editsJson,
    this.rowid = const Value.absent(),
  }) : imageId = Value(imageId),
       seq = Value(seq),
       editsJson = Value(editsJson);
  static Insertable<ImageEditHistoryEntry> custom({
    Expression<String>? imageId,
    Expression<int>? seq,
    Expression<String>? editsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (imageId != null) 'image_id': imageId,
      if (seq != null) 'seq': seq,
      if (editsJson != null) 'edits_json': editsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageEditHistoryCompanion copyWith({
    Value<String>? imageId,
    Value<int>? seq,
    Value<String>? editsJson,
    Value<int>? rowid,
  }) {
    return ImageEditHistoryCompanion(
      imageId: imageId ?? this.imageId,
      seq: seq ?? this.seq,
      editsJson: editsJson ?? this.editsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (imageId.present) {
      map['image_id'] = Variable<String>(imageId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (editsJson.present) {
      map['edits_json'] = Variable<String>(editsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageEditHistoryCompanion(')
          ..write('imageId: $imageId, ')
          ..write('seq: $seq, ')
          ..write('editsJson: $editsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImageEditCursorTable extends ImageEditCursor
    with TableInfo<$ImageEditCursorTable, ImageEditCursorEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageEditCursorTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _imageIdMeta = const VerificationMeta(
    'imageId',
  );
  @override
  late final GeneratedColumn<String> imageId = GeneratedColumn<String>(
    'image_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES images (id)',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [imageId, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_edit_cursor';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageEditCursorEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('image_id')) {
      context.handle(
        _imageIdMeta,
        imageId.isAcceptableOrUnknown(data['image_id']!, _imageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_imageIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {imageId};
  @override
  ImageEditCursorEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageEditCursorEntry(
      imageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
    );
  }

  @override
  $ImageEditCursorTable createAlias(String alias) {
    return $ImageEditCursorTable(attachedDatabase, alias);
  }
}

class ImageEditCursorEntry extends DataClass
    implements Insertable<ImageEditCursorEntry> {
  final String imageId;
  final int seq;
  const ImageEditCursorEntry({required this.imageId, required this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['image_id'] = Variable<String>(imageId);
    map['seq'] = Variable<int>(seq);
    return map;
  }

  ImageEditCursorCompanion toCompanion(bool nullToAbsent) {
    return ImageEditCursorCompanion(imageId: Value(imageId), seq: Value(seq));
  }

  factory ImageEditCursorEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageEditCursorEntry(
      imageId: serializer.fromJson<String>(json['imageId']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'imageId': serializer.toJson<String>(imageId),
      'seq': serializer.toJson<int>(seq),
    };
  }

  ImageEditCursorEntry copyWith({String? imageId, int? seq}) =>
      ImageEditCursorEntry(
        imageId: imageId ?? this.imageId,
        seq: seq ?? this.seq,
      );
  ImageEditCursorEntry copyWithCompanion(ImageEditCursorCompanion data) {
    return ImageEditCursorEntry(
      imageId: data.imageId.present ? data.imageId.value : this.imageId,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageEditCursorEntry(')
          ..write('imageId: $imageId, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(imageId, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageEditCursorEntry &&
          other.imageId == this.imageId &&
          other.seq == this.seq);
}

class ImageEditCursorCompanion extends UpdateCompanion<ImageEditCursorEntry> {
  final Value<String> imageId;
  final Value<int> seq;
  final Value<int> rowid;
  const ImageEditCursorCompanion({
    this.imageId = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageEditCursorCompanion.insert({
    required String imageId,
    required int seq,
    this.rowid = const Value.absent(),
  }) : imageId = Value(imageId),
       seq = Value(seq);
  static Insertable<ImageEditCursorEntry> custom({
    Expression<String>? imageId,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (imageId != null) 'image_id': imageId,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageEditCursorCompanion copyWith({
    Value<String>? imageId,
    Value<int>? seq,
    Value<int>? rowid,
  }) {
    return ImageEditCursorCompanion(
      imageId: imageId ?? this.imageId,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (imageId.present) {
      map['image_id'] = Variable<String>(imageId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageEditCursorCompanion(')
          ..write('imageId: $imageId, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetaTable extends AppMeta
    with TableInfo<$AppMetaTable, AppMetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaEntry extends DataClass implements Insertable<AppMetaEntry> {
  final String key;
  final String value;
  const AppMetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetaEntry copyWith({String? key, String? value}) =>
      AppMetaEntry(key: key ?? this.key, value: value ?? this.value);
  AppMetaEntry copyWithCompanion(AppMetaCompanion data) {
    return AppMetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ViewPrefsTable extends ViewPrefs
    with TableInfo<$ViewPrefsTable, ViewPrefsRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ViewPrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedByDeviceIdMeta = const VerificationMeta(
    'updatedByDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedByDeviceId =
      GeneratedColumn<String>(
        'updated_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _prefsJsonMeta = const VerificationMeta(
    'prefsJson',
  );
  @override
  late final GeneratedColumn<String> prefsJson = GeneratedColumn<String>(
    'prefs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    updatedByDeviceId,
    deletedAt,
    projectId,
    prefsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'view_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ViewPrefsRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('updated_by_device_id')) {
      context.handle(
        _updatedByDeviceIdMeta,
        updatedByDeviceId.isAcceptableOrUnknown(
          data['updated_by_device_id']!,
          _updatedByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedByDeviceIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('prefs_json')) {
      context.handle(
        _prefsJsonMeta,
        prefsJson.isAcceptableOrUnknown(data['prefs_json']!, _prefsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_prefsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ViewPrefsRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ViewPrefsRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      updatedByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by_device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      prefsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prefs_json'],
      )!,
    );
  }

  @override
  $ViewPrefsTable createAlias(String alias) {
    return $ViewPrefsTable(attachedDatabase, alias);
  }
}

class ViewPrefsRecord extends DataClass implements Insertable<ViewPrefsRecord> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String updatedByDeviceId;
  final int? deletedAt;
  final String projectId;

  /// m2-design §4.2.
  final String prefsJson;
  const ViewPrefsRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByDeviceId,
    this.deletedAt,
    required this.projectId,
    required this.prefsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['updated_by_device_id'] = Variable<String>(updatedByDeviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['project_id'] = Variable<String>(projectId);
    map['prefs_json'] = Variable<String>(prefsJson);
    return map;
  }

  ViewPrefsCompanion toCompanion(bool nullToAbsent) {
    return ViewPrefsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      updatedByDeviceId: Value(updatedByDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      projectId: Value(projectId),
      prefsJson: Value(prefsJson),
    );
  }

  factory ViewPrefsRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ViewPrefsRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      updatedByDeviceId: serializer.fromJson<String>(json['updatedByDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      projectId: serializer.fromJson<String>(json['projectId']),
      prefsJson: serializer.fromJson<String>(json['prefsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'updatedByDeviceId': serializer.toJson<String>(updatedByDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'projectId': serializer.toJson<String>(projectId),
      'prefsJson': serializer.toJson<String>(prefsJson),
    };
  }

  ViewPrefsRecord copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? updatedByDeviceId,
    Value<int?> deletedAt = const Value.absent(),
    String? projectId,
    String? prefsJson,
  }) => ViewPrefsRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    projectId: projectId ?? this.projectId,
    prefsJson: prefsJson ?? this.prefsJson,
  );
  ViewPrefsRecord copyWithCompanion(ViewPrefsCompanion data) {
    return ViewPrefsRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedByDeviceId: data.updatedByDeviceId.present
          ? data.updatedByDeviceId.value
          : this.updatedByDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      prefsJson: data.prefsJson.present ? data.prefsJson.value : this.prefsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ViewPrefsRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedByDeviceId: $updatedByDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('projectId: $projectId, ')
          ..write('prefsJson: $prefsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    updatedByDeviceId,
    deletedAt,
    projectId,
    prefsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ViewPrefsRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.updatedByDeviceId == this.updatedByDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.projectId == this.projectId &&
          other.prefsJson == this.prefsJson);
}

class ViewPrefsCompanion extends UpdateCompanion<ViewPrefsRecord> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> updatedByDeviceId;
  final Value<int?> deletedAt;
  final Value<String> projectId;
  final Value<String> prefsJson;
  final Value<int> rowid;
  const ViewPrefsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedByDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.projectId = const Value.absent(),
    this.prefsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ViewPrefsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    required String updatedByDeviceId,
    this.deletedAt = const Value.absent(),
    required String projectId,
    required String prefsJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       updatedByDeviceId = Value(updatedByDeviceId),
       projectId = Value(projectId),
       prefsJson = Value(prefsJson);
  static Insertable<ViewPrefsRecord> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? updatedByDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? projectId,
    Expression<String>? prefsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedByDeviceId != null) 'updated_by_device_id': updatedByDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (projectId != null) 'project_id': projectId,
      if (prefsJson != null) 'prefs_json': prefsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ViewPrefsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? updatedByDeviceId,
    Value<int?>? deletedAt,
    Value<String>? projectId,
    Value<String>? prefsJson,
    Value<int>? rowid,
  }) {
    return ViewPrefsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      projectId: projectId ?? this.projectId,
      prefsJson: prefsJson ?? this.prefsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (updatedByDeviceId.present) {
      map['updated_by_device_id'] = Variable<String>(updatedByDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (prefsJson.present) {
      map['prefs_json'] = Variable<String>(prefsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ViewPrefsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedByDeviceId: $updatedByDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('projectId: $projectId, ')
          ..write('prefsJson: $prefsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driveFileIdMeta = const VerificationMeta(
    'driveFileId',
  );
  @override
  late final GeneratedColumn<String> driveFileId = GeneratedColumn<String>(
    'drive_file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<int> remoteVersion = GeneratedColumn<int>(
    'remote_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedHashMeta = const VerificationMeta(
    'syncedHash',
  );
  @override
  late final GeneratedColumn<String> syncedHash = GeneratedColumn<String>(
    'synced_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heldJsonMeta = const VerificationMeta(
    'heldJson',
  );
  @override
  late final GeneratedColumn<String> heldJson = GeneratedColumn<String>(
    'held_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    kind,
    recordId,
    driveFileId,
    remoteVersion,
    syncedHash,
    heldJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('drive_file_id')) {
      context.handle(
        _driveFileIdMeta,
        driveFileId.isAcceptableOrUnknown(
          data['drive_file_id']!,
          _driveFileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_driveFileIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteVersionMeta);
    }
    if (data.containsKey('synced_hash')) {
      context.handle(
        _syncedHashMeta,
        syncedHash.isAcceptableOrUnknown(data['synced_hash']!, _syncedHashMeta),
      );
    }
    if (data.containsKey('held_json')) {
      context.handle(
        _heldJsonMeta,
        heldJson.isAcceptableOrUnknown(data['held_json']!, _heldJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, recordId};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      driveFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drive_file_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_version'],
      )!,
      syncedHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_hash'],
      ),
      heldJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}held_json'],
      ),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  /// `project` · `image` · `viewPrefs` (the record format's `kind`).
  final String kind;
  final String recordId;
  final String driveFileId;
  final int remoteVersion;
  final String? syncedHash;

  /// A pulled version not applied yet (from a newer Filbert, or waiting for
  /// its project).
  final String? heldJson;
  const SyncStateRow({
    required this.kind,
    required this.recordId,
    required this.driveFileId,
    required this.remoteVersion,
    this.syncedHash,
    this.heldJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['record_id'] = Variable<String>(recordId);
    map['drive_file_id'] = Variable<String>(driveFileId);
    map['remote_version'] = Variable<int>(remoteVersion);
    if (!nullToAbsent || syncedHash != null) {
      map['synced_hash'] = Variable<String>(syncedHash);
    }
    if (!nullToAbsent || heldJson != null) {
      map['held_json'] = Variable<String>(heldJson);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      kind: Value(kind),
      recordId: Value(recordId),
      driveFileId: Value(driveFileId),
      remoteVersion: Value(remoteVersion),
      syncedHash: syncedHash == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedHash),
      heldJson: heldJson == null && nullToAbsent
          ? const Value.absent()
          : Value(heldJson),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      kind: serializer.fromJson<String>(json['kind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      driveFileId: serializer.fromJson<String>(json['driveFileId']),
      remoteVersion: serializer.fromJson<int>(json['remoteVersion']),
      syncedHash: serializer.fromJson<String?>(json['syncedHash']),
      heldJson: serializer.fromJson<String?>(json['heldJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'recordId': serializer.toJson<String>(recordId),
      'driveFileId': serializer.toJson<String>(driveFileId),
      'remoteVersion': serializer.toJson<int>(remoteVersion),
      'syncedHash': serializer.toJson<String?>(syncedHash),
      'heldJson': serializer.toJson<String?>(heldJson),
    };
  }

  SyncStateRow copyWith({
    String? kind,
    String? recordId,
    String? driveFileId,
    int? remoteVersion,
    Value<String?> syncedHash = const Value.absent(),
    Value<String?> heldJson = const Value.absent(),
  }) => SyncStateRow(
    kind: kind ?? this.kind,
    recordId: recordId ?? this.recordId,
    driveFileId: driveFileId ?? this.driveFileId,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    syncedHash: syncedHash.present ? syncedHash.value : this.syncedHash,
    heldJson: heldJson.present ? heldJson.value : this.heldJson,
  );
  SyncStateRow copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      driveFileId: data.driveFileId.present
          ? data.driveFileId.value
          : this.driveFileId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      syncedHash: data.syncedHash.present
          ? data.syncedHash.value
          : this.syncedHash,
      heldJson: data.heldJson.present ? data.heldJson.value : this.heldJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('syncedHash: $syncedHash, ')
          ..write('heldJson: $heldJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    kind,
    recordId,
    driveFileId,
    remoteVersion,
    syncedHash,
    heldJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.kind == this.kind &&
          other.recordId == this.recordId &&
          other.driveFileId == this.driveFileId &&
          other.remoteVersion == this.remoteVersion &&
          other.syncedHash == this.syncedHash &&
          other.heldJson == this.heldJson);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> kind;
  final Value<String> recordId;
  final Value<String> driveFileId;
  final Value<int> remoteVersion;
  final Value<String?> syncedHash;
  final Value<String?> heldJson;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.kind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.syncedHash = const Value.absent(),
    this.heldJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String kind,
    required String recordId,
    required String driveFileId,
    required int remoteVersion,
    this.syncedHash = const Value.absent(),
    this.heldJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       recordId = Value(recordId),
       driveFileId = Value(driveFileId),
       remoteVersion = Value(remoteVersion);
  static Insertable<SyncStateRow> custom({
    Expression<String>? kind,
    Expression<String>? recordId,
    Expression<String>? driveFileId,
    Expression<int>? remoteVersion,
    Expression<String>? syncedHash,
    Expression<String>? heldJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (recordId != null) 'record_id': recordId,
      if (driveFileId != null) 'drive_file_id': driveFileId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (syncedHash != null) 'synced_hash': syncedHash,
      if (heldJson != null) 'held_json': heldJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? kind,
    Value<String>? recordId,
    Value<String>? driveFileId,
    Value<int>? remoteVersion,
    Value<String?>? syncedHash,
    Value<String?>? heldJson,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      kind: kind ?? this.kind,
      recordId: recordId ?? this.recordId,
      driveFileId: driveFileId ?? this.driveFileId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      syncedHash: syncedHash ?? this.syncedHash,
      heldJson: heldJson ?? this.heldJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (driveFileId.present) {
      map['drive_file_id'] = Variable<String>(driveFileId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<int>(remoteVersion.value);
    }
    if (syncedHash.present) {
      map['synced_hash'] = Variable<String>(syncedHash.value);
    }
    if (heldJson.present) {
      map['held_json'] = Variable<String>(heldJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('syncedHash: $syncedHash, ')
          ..write('heldJson: $heldJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlobSyncsTable extends BlobSyncs
    with TableInfo<$BlobSyncsTable, BlobSyncRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlobSyncsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driveFileIdMeta = const VerificationMeta(
    'driveFileId',
  );
  @override
  late final GeneratedColumn<String> driveFileId = GeneratedColumn<String>(
    'drive_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbFileIdMeta = const VerificationMeta(
    'thumbFileId',
  );
  @override
  late final GeneratedColumn<String> thumbFileId = GeneratedColumn<String>(
    'thumb_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    blobId,
    driveFileId,
    thumbFileId,
    state,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blob_sync';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlobSyncRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('drive_file_id')) {
      context.handle(
        _driveFileIdMeta,
        driveFileId.isAcceptableOrUnknown(
          data['drive_file_id']!,
          _driveFileIdMeta,
        ),
      );
    }
    if (data.containsKey('thumb_file_id')) {
      context.handle(
        _thumbFileIdMeta,
        thumbFileId.isAcceptableOrUnknown(
          data['thumb_file_id']!,
          _thumbFileIdMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blobId};
  @override
  BlobSyncRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlobSyncRow(
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      driveFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drive_file_id'],
      ),
      thumbFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_file_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $BlobSyncsTable createAlias(String alias) {
    return $BlobSyncsTable(attachedDatabase, alias);
  }
}

class BlobSyncRow extends DataClass implements Insertable<BlobSyncRow> {
  final String blobId;
  final String? driveFileId;
  final String? thumbFileId;

  /// `local` · `synced` · `remoteOnly` · `missing`.
  final String state;
  const BlobSyncRow({
    required this.blobId,
    this.driveFileId,
    this.thumbFileId,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['blob_id'] = Variable<String>(blobId);
    if (!nullToAbsent || driveFileId != null) {
      map['drive_file_id'] = Variable<String>(driveFileId);
    }
    if (!nullToAbsent || thumbFileId != null) {
      map['thumb_file_id'] = Variable<String>(thumbFileId);
    }
    map['state'] = Variable<String>(state);
    return map;
  }

  BlobSyncsCompanion toCompanion(bool nullToAbsent) {
    return BlobSyncsCompanion(
      blobId: Value(blobId),
      driveFileId: driveFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(driveFileId),
      thumbFileId: thumbFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbFileId),
      state: Value(state),
    );
  }

  factory BlobSyncRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlobSyncRow(
      blobId: serializer.fromJson<String>(json['blobId']),
      driveFileId: serializer.fromJson<String?>(json['driveFileId']),
      thumbFileId: serializer.fromJson<String?>(json['thumbFileId']),
      state: serializer.fromJson<String>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blobId': serializer.toJson<String>(blobId),
      'driveFileId': serializer.toJson<String?>(driveFileId),
      'thumbFileId': serializer.toJson<String?>(thumbFileId),
      'state': serializer.toJson<String>(state),
    };
  }

  BlobSyncRow copyWith({
    String? blobId,
    Value<String?> driveFileId = const Value.absent(),
    Value<String?> thumbFileId = const Value.absent(),
    String? state,
  }) => BlobSyncRow(
    blobId: blobId ?? this.blobId,
    driveFileId: driveFileId.present ? driveFileId.value : this.driveFileId,
    thumbFileId: thumbFileId.present ? thumbFileId.value : this.thumbFileId,
    state: state ?? this.state,
  );
  BlobSyncRow copyWithCompanion(BlobSyncsCompanion data) {
    return BlobSyncRow(
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      driveFileId: data.driveFileId.present
          ? data.driveFileId.value
          : this.driveFileId,
      thumbFileId: data.thumbFileId.present
          ? data.thumbFileId.value
          : this.thumbFileId,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlobSyncRow(')
          ..write('blobId: $blobId, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('thumbFileId: $thumbFileId, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(blobId, driveFileId, thumbFileId, state);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlobSyncRow &&
          other.blobId == this.blobId &&
          other.driveFileId == this.driveFileId &&
          other.thumbFileId == this.thumbFileId &&
          other.state == this.state);
}

class BlobSyncsCompanion extends UpdateCompanion<BlobSyncRow> {
  final Value<String> blobId;
  final Value<String?> driveFileId;
  final Value<String?> thumbFileId;
  final Value<String> state;
  final Value<int> rowid;
  const BlobSyncsCompanion({
    this.blobId = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.thumbFileId = const Value.absent(),
    this.state = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlobSyncsCompanion.insert({
    required String blobId,
    this.driveFileId = const Value.absent(),
    this.thumbFileId = const Value.absent(),
    required String state,
    this.rowid = const Value.absent(),
  }) : blobId = Value(blobId),
       state = Value(state);
  static Insertable<BlobSyncRow> custom({
    Expression<String>? blobId,
    Expression<String>? driveFileId,
    Expression<String>? thumbFileId,
    Expression<String>? state,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blobId != null) 'blob_id': blobId,
      if (driveFileId != null) 'drive_file_id': driveFileId,
      if (thumbFileId != null) 'thumb_file_id': thumbFileId,
      if (state != null) 'state': state,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlobSyncsCompanion copyWith({
    Value<String>? blobId,
    Value<String?>? driveFileId,
    Value<String?>? thumbFileId,
    Value<String>? state,
    Value<int>? rowid,
  }) {
    return BlobSyncsCompanion(
      blobId: blobId ?? this.blobId,
      driveFileId: driveFileId ?? this.driveFileId,
      thumbFileId: thumbFileId ?? this.thumbFileId,
      state: state ?? this.state,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (driveFileId.present) {
      map['drive_file_id'] = Variable<String>(driveFileId.value);
    }
    if (thumbFileId.present) {
      map['thumb_file_id'] = Variable<String>(thumbFileId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlobSyncsCompanion(')
          ..write('blobId: $blobId, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('thumbFileId: $thumbFileId, ')
          ..write('state: $state, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driveFileIdMeta = const VerificationMeta(
    'driveFileId',
  );
  @override
  late final GeneratedColumn<String> driveFileId = GeneratedColumn<String>(
    'drive_file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteJsonMeta = const VerificationMeta(
    'remoteJson',
  );
  @override
  late final GeneratedColumn<String> remoteJson = GeneratedColumn<String>(
    'remote_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<int> remoteVersion = GeneratedColumn<int>(
    'remote_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<int> detectedAt = GeneratedColumn<int>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    kind,
    recordId,
    driveFileId,
    remoteJson,
    remoteVersion,
    detectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('drive_file_id')) {
      context.handle(
        _driveFileIdMeta,
        driveFileId.isAcceptableOrUnknown(
          data['drive_file_id']!,
          _driveFileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_driveFileIdMeta);
    }
    if (data.containsKey('remote_json')) {
      context.handle(
        _remoteJsonMeta,
        remoteJson.isAcceptableOrUnknown(data['remote_json']!, _remoteJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteJsonMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteVersionMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, recordId};
  @override
  SyncConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictRow(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      driveFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drive_file_id'],
      )!,
      remoteJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_json'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_version'],
      )!,
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_at'],
      )!,
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflictRow extends DataClass implements Insertable<SyncConflictRow> {
  final String kind;
  final String recordId;
  final String driveFileId;
  final String remoteJson;
  final int remoteVersion;
  final int detectedAt;
  const SyncConflictRow({
    required this.kind,
    required this.recordId,
    required this.driveFileId,
    required this.remoteJson,
    required this.remoteVersion,
    required this.detectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['record_id'] = Variable<String>(recordId);
    map['drive_file_id'] = Variable<String>(driveFileId);
    map['remote_json'] = Variable<String>(remoteJson);
    map['remote_version'] = Variable<int>(remoteVersion);
    map['detected_at'] = Variable<int>(detectedAt);
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      kind: Value(kind),
      recordId: Value(recordId),
      driveFileId: Value(driveFileId),
      remoteJson: Value(remoteJson),
      remoteVersion: Value(remoteVersion),
      detectedAt: Value(detectedAt),
    );
  }

  factory SyncConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictRow(
      kind: serializer.fromJson<String>(json['kind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      driveFileId: serializer.fromJson<String>(json['driveFileId']),
      remoteJson: serializer.fromJson<String>(json['remoteJson']),
      remoteVersion: serializer.fromJson<int>(json['remoteVersion']),
      detectedAt: serializer.fromJson<int>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'recordId': serializer.toJson<String>(recordId),
      'driveFileId': serializer.toJson<String>(driveFileId),
      'remoteJson': serializer.toJson<String>(remoteJson),
      'remoteVersion': serializer.toJson<int>(remoteVersion),
      'detectedAt': serializer.toJson<int>(detectedAt),
    };
  }

  SyncConflictRow copyWith({
    String? kind,
    String? recordId,
    String? driveFileId,
    String? remoteJson,
    int? remoteVersion,
    int? detectedAt,
  }) => SyncConflictRow(
    kind: kind ?? this.kind,
    recordId: recordId ?? this.recordId,
    driveFileId: driveFileId ?? this.driveFileId,
    remoteJson: remoteJson ?? this.remoteJson,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  SyncConflictRow copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflictRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      driveFileId: data.driveFileId.present
          ? data.driveFileId.value
          : this.driveFileId,
      remoteJson: data.remoteJson.present
          ? data.remoteJson.value
          : this.remoteJson,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictRow(')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('remoteJson: $remoteJson, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    kind,
    recordId,
    driveFileId,
    remoteJson,
    remoteVersion,
    detectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictRow &&
          other.kind == this.kind &&
          other.recordId == this.recordId &&
          other.driveFileId == this.driveFileId &&
          other.remoteJson == this.remoteJson &&
          other.remoteVersion == this.remoteVersion &&
          other.detectedAt == this.detectedAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflictRow> {
  final Value<String> kind;
  final Value<String> recordId;
  final Value<String> driveFileId;
  final Value<String> remoteJson;
  final Value<int> remoteVersion;
  final Value<int> detectedAt;
  final Value<int> rowid;
  const SyncConflictsCompanion({
    this.kind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.remoteJson = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    required String kind,
    required String recordId,
    required String driveFileId,
    required String remoteJson,
    required int remoteVersion,
    required int detectedAt,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       recordId = Value(recordId),
       driveFileId = Value(driveFileId),
       remoteJson = Value(remoteJson),
       remoteVersion = Value(remoteVersion),
       detectedAt = Value(detectedAt);
  static Insertable<SyncConflictRow> custom({
    Expression<String>? kind,
    Expression<String>? recordId,
    Expression<String>? driveFileId,
    Expression<String>? remoteJson,
    Expression<int>? remoteVersion,
    Expression<int>? detectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (recordId != null) 'record_id': recordId,
      if (driveFileId != null) 'drive_file_id': driveFileId,
      if (remoteJson != null) 'remote_json': remoteJson,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<String>? kind,
    Value<String>? recordId,
    Value<String>? driveFileId,
    Value<String>? remoteJson,
    Value<int>? remoteVersion,
    Value<int>? detectedAt,
    Value<int>? rowid,
  }) {
    return SyncConflictsCompanion(
      kind: kind ?? this.kind,
      recordId: recordId ?? this.recordId,
      driveFileId: driveFileId ?? this.driveFileId,
      remoteJson: remoteJson ?? this.remoteJson,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      detectedAt: detectedAt ?? this.detectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (driveFileId.present) {
      map['drive_file_id'] = Variable<String>(driveFileId.value);
    }
    if (remoteJson.present) {
      map['remote_json'] = Variable<String>(remoteJson.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<int>(remoteVersion.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<int>(detectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('kind: $kind, ')
          ..write('recordId: $recordId, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('remoteJson: $remoteJson, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ImagesTable images = $ImagesTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $ImageEditHistoryTable imageEditHistory = $ImageEditHistoryTable(
    this,
  );
  late final $ImageEditCursorTable imageEditCursor = $ImageEditCursorTable(
    this,
  );
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $ViewPrefsTable viewPrefs = $ViewPrefsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $BlobSyncsTable blobSyncs = $BlobSyncsTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final Index imagesProjectId = Index(
    'images_project_id',
    'CREATE INDEX images_project_id ON images (project_id)',
  );
  late final Index viewPrefsProjectId = Index(
    'view_prefs_project_id',
    'CREATE UNIQUE INDEX view_prefs_project_id ON view_prefs (project_id) WHERE deleted_at IS NULL',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    images,
    projects,
    imageEditHistory,
    imageEditCursor,
    appMeta,
    viewPrefs,
    syncStates,
    blobSyncs,
    syncConflicts,
    imagesProjectId,
    viewPrefsProjectId,
  ];
}

typedef $$ImagesTableCreateCompanionBuilder = ImagesCompanion Function({
  required String id,
  required int createdAt,
  required int updatedAt,
  required String updatedByDeviceId,
  Value<int?> deletedAt,
  required String projectId,
  required String blobId,
  required String mimeType,
  required int width,
  required int height,
  required ImageOrigin source,
  Value<int?> capturedAt,
  required String editsJson,
  Value<String?> derivedFromJson,
  Value<int> rowid,
});
typedef $$ImagesTableUpdateCompanionBuilder = ImagesCompanion Function({
  Value<String> id,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> updatedByDeviceId,
  Value<int?> deletedAt,
  Value<String> projectId,
  Value<String> blobId,
  Value<String> mimeType,
  Value<int> width,
  Value<int> height,
  Value<ImageOrigin> source,
  Value<int?> capturedAt,
  Value<String> editsJson,
  Value<String?> derivedFromJson,
  Value<int> rowid,
});

final class $$ImagesTableReferences
    extends BaseReferences<_$AppDatabase, $ImagesTable, ImageRecord> {
  $$ImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('images__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<ProjectRecord>>
  _projectsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: 'images__id__projects__reference_image_id',
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager($_db, $_db.projects).filter(
      (f) => f.referenceImageId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ImageEditHistoryTable,
    List<ImageEditHistoryEntry>
  >
  _imageEditHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.imageEditHistory,
    aliasName: 'images__id__image_edit_history__image_id',
  );

  $$ImageEditHistoryTableProcessedTableManager get imageEditHistoryRefs {
    final manager = $$ImageEditHistoryTableTableManager(
      $_db,
      $_db.imageEditHistory,
    ).filter((f) => f.imageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _imageEditHistoryRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ImageEditCursorTable, List<ImageEditCursorEntry>>
  _imageEditCursorRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.imageEditCursor,
    aliasName: 'images__id__image_edit_cursor__image_id',
  );

  $$ImageEditCursorTableProcessedTableManager get imageEditCursorRefs {
    final manager = $$ImageEditCursorTableTableManager(
      $_db,
      $_db.imageEditCursor,
    ).filter((f) => f.imageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _imageEditCursorRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImagesTableFilterComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ImageOrigin, ImageOrigin, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editsJson => $composableBuilder(
    column: $table.editsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get derivedFromJson => $composableBuilder(
    column: $table.derivedFromJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.referenceImageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> imageEditHistoryRefs(
    Expression<bool> Function($$ImageEditHistoryTableFilterComposer f) f,
  ) {
    final $$ImageEditHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.imageEditHistory,
      getReferencedColumn: (t) => t.imageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageEditHistoryTableFilterComposer(
            $db: $db,
            $table: $db.imageEditHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> imageEditCursorRefs(
    Expression<bool> Function($$ImageEditCursorTableFilterComposer f) f,
  ) {
    final $$ImageEditCursorTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.imageEditCursor,
      getReferencedColumn: (t) => t.imageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageEditCursorTableFilterComposer(
            $db: $db,
            $table: $db.imageEditCursor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editsJson => $composableBuilder(
    column: $table.editsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get derivedFromJson => $composableBuilder(
    column: $table.derivedFromJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ImageOrigin, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get editsJson =>
      $composableBuilder(column: $table.editsJson, builder: (column) => column);

  GeneratedColumn<String> get derivedFromJson => $composableBuilder(
    column: $table.derivedFromJson,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.referenceImageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> imageEditHistoryRefs<T extends Object>(
    Expression<T> Function($$ImageEditHistoryTableAnnotationComposer a) f,
  ) {
    final $$ImageEditHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.imageEditHistory,
      getReferencedColumn: (t) => t.imageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageEditHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.imageEditHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> imageEditCursorRefs<T extends Object>(
    Expression<T> Function($$ImageEditCursorTableAnnotationComposer a) f,
  ) {
    final $$ImageEditCursorTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.imageEditCursor,
      getReferencedColumn: (t) => t.imageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageEditCursorTableAnnotationComposer(
            $db: $db,
            $table: $db.imageEditCursor,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImagesTable,
          ImageRecord,
          $$ImagesTableFilterComposer,
          $$ImagesTableOrderingComposer,
          $$ImagesTableAnnotationComposer,
          $$ImagesTableCreateCompanionBuilder,
          $$ImagesTableUpdateCompanionBuilder,
          (ImageRecord, $$ImagesTableReferences),
          ImageRecord,
          PrefetchHooks Function({
            bool projectId,
            bool projectsRefs,
            bool imageEditHistoryRefs,
            bool imageEditCursorRefs,
          })
        > {
  $$ImagesTableTableManager(_$AppDatabase db, $ImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> updatedByDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> blobId = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<ImageOrigin> source = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                Value<String> editsJson = const Value.absent(),
                Value<String?> derivedFromJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImagesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedByDeviceId: updatedByDeviceId,
                deletedAt: deletedAt,
                projectId: projectId,
                blobId: blobId,
                mimeType: mimeType,
                width: width,
                height: height,
                source: source,
                capturedAt: capturedAt,
                editsJson: editsJson,
                derivedFromJson: derivedFromJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                required String updatedByDeviceId,
                Value<int?> deletedAt = const Value.absent(),
                required String projectId,
                required String blobId,
                required String mimeType,
                required int width,
                required int height,
                required ImageOrigin source,
                Value<int?> capturedAt = const Value.absent(),
                required String editsJson,
                Value<String?> derivedFromJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImagesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedByDeviceId: updatedByDeviceId,
                deletedAt: deletedAt,
                projectId: projectId,
                blobId: blobId,
                mimeType: mimeType,
                width: width,
                height: height,
                source: source,
                capturedAt: capturedAt,
                editsJson: editsJson,
                derivedFromJson: derivedFromJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImagesTable, ImageRecord>(table),
                  $$ImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                projectsRefs = false,
                imageEditHistoryRefs = false,
                imageEditCursorRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (projectsRefs) db.projects,
                    if (imageEditHistoryRefs) db.imageEditHistory,
                    if (imageEditCursorRefs) db.imageEditCursor,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$ImagesTableReferences
                                ._projectIdTable(db),
                            referencedColumn: $$ImagesTableReferences
                                ._projectIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (projectsRefs)
                        await $_getPrefetchedDataByColumns<
                          ImageRecord,
                          $ImagesTable,
                          ProjectRecord,
                          $ProjectsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImagesTableReferences
                              ._projectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImagesTableReferences(
                                db,
                                table,
                                p0,
                              ).projectsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'reference_image_id',
                          typedResults: items,
                        ),
                      if (imageEditHistoryRefs)
                        await $_getPrefetchedDataByColumns<
                          ImageRecord,
                          $ImagesTable,
                          ImageEditHistoryEntry,
                          $ImageEditHistoryTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImagesTableReferences
                              ._imageEditHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImagesTableReferences(
                                db,
                                table,
                                p0,
                              ).imageEditHistoryRefs,
                          currentColumn: 'id',
                          referencedColumn: 'image_id',
                          typedResults: items,
                        ),
                      if (imageEditCursorRefs)
                        await $_getPrefetchedDataByColumns<
                          ImageRecord,
                          $ImagesTable,
                          ImageEditCursorEntry,
                          $ImageEditCursorTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImagesTableReferences
                              ._imageEditCursorRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImagesTableReferences(
                                db,
                                table,
                                p0,
                              ).imageEditCursorRefs,
                          currentColumn: 'id',
                          referencedColumn: 'image_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImagesTable,
      ImageRecord,
      $$ImagesTableFilterComposer,
      $$ImagesTableOrderingComposer,
      $$ImagesTableAnnotationComposer,
      $$ImagesTableCreateCompanionBuilder,
      $$ImagesTableUpdateCompanionBuilder,
      (ImageRecord, $$ImagesTableReferences),
      ImageRecord,
      PrefetchHooks Function({
        bool projectId,
        bool projectsRefs,
        bool imageEditHistoryRefs,
        bool imageEditCursorRefs,
      })
    >;
typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required int createdAt,
  required int updatedAt,
  required String updatedByDeviceId,
  Value<int?> deletedAt,
  required String name,
  required bool nameIsDefault,
  Value<SizeKind> sizeKind,
  Value<double?> ratioW,
  Value<double?> ratioH,
  Value<double?> width,
  Value<double?> height,
  Value<LengthUnit?> unit,
  Value<String> startNotes,
  Value<String?> referenceImageId,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> updatedByDeviceId,
  Value<int?> deletedAt,
  Value<String> name,
  Value<bool> nameIsDefault,
  Value<SizeKind> sizeKind,
  Value<double?> ratioW,
  Value<double?> ratioH,
  Value<double?> width,
  Value<double?> height,
  Value<LengthUnit?> unit,
  Value<String> startNotes,
  Value<String?> referenceImageId,
  Value<int> rowid,
});

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, ProjectRecord> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImagesTable _referenceImageIdTable(_$AppDatabase db) =>
      db.images.createAlias('projects__reference_image_id__images__id');

  $$ImagesTableProcessedTableManager? get referenceImageId {
    final $_column = $_itemColumn<String>('reference_image_id');
    if ($_column == null) return null;
    final manager = $$ImagesTableTableManager(
      $_db,
      $_db.images,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_referenceImageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ImagesTable, List<ImageRecord>> _imagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.images,
    aliasName: 'projects__id__images__project_id',
  );

  $$ImagesTableProcessedTableManager get imagesRefs {
    final manager = $$ImagesTableTableManager(
      $_db,
      $_db.images,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_imagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ViewPrefsTable, List<ViewPrefsRecord>>
  _viewPrefsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.viewPrefs,
    aliasName: 'projects__id__view_prefs__project_id',
  );

  $$ViewPrefsTableProcessedTableManager get viewPrefsRefs {
    final manager = $$ViewPrefsTableTableManager(
      $_db,
      $_db.viewPrefs,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_viewPrefsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nameIsDefault => $composableBuilder(
    column: $table.nameIsDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SizeKind, SizeKind, String> get sizeKind =>
      $composableBuilder(
        column: $table.sizeKind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get ratioW => $composableBuilder(
    column: $table.ratioW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ratioH => $composableBuilder(
    column: $table.ratioH,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LengthUnit?, LengthUnit, String> get unit =>
      $composableBuilder(
        column: $table.unit,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get startNotes => $composableBuilder(
    column: $table.startNotes,
    builder: (column) => ColumnFilters(column),
  );

  $$ImagesTableFilterComposer get referenceImageId {
    final $$ImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.referenceImageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableFilterComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> imagesRefs(
    Expression<bool> Function($$ImagesTableFilterComposer f) f,
  ) {
    final $$ImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableFilterComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> viewPrefsRefs(
    Expression<bool> Function($$ViewPrefsTableFilterComposer f) f,
  ) {
    final $$ViewPrefsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewPrefs,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewPrefsTableFilterComposer(
            $db: $db,
            $table: $db.viewPrefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nameIsDefault => $composableBuilder(
    column: $table.nameIsDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sizeKind => $composableBuilder(
    column: $table.sizeKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ratioW => $composableBuilder(
    column: $table.ratioW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ratioH => $composableBuilder(
    column: $table.ratioH,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startNotes => $composableBuilder(
    column: $table.startNotes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImagesTableOrderingComposer get referenceImageId {
    final $$ImagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.referenceImageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableOrderingComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get nameIsDefault => $composableBuilder(
    column: $table.nameIsDefault,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SizeKind, String> get sizeKind =>
      $composableBuilder(column: $table.sizeKind, builder: (column) => column);

  GeneratedColumn<double> get ratioW =>
      $composableBuilder(column: $table.ratioW, builder: (column) => column);

  GeneratedColumn<double> get ratioH =>
      $composableBuilder(column: $table.ratioH, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LengthUnit?, String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get startNotes => $composableBuilder(
    column: $table.startNotes,
    builder: (column) => column,
  );

  $$ImagesTableAnnotationComposer get referenceImageId {
    final $$ImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.referenceImageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> imagesRefs<T extends Object>(
    Expression<T> Function($$ImagesTableAnnotationComposer a) f,
  ) {
    final $$ImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> viewPrefsRefs<T extends Object>(
    Expression<T> Function($$ViewPrefsTableAnnotationComposer a) f,
  ) {
    final $$ViewPrefsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewPrefs,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewPrefsTableAnnotationComposer(
            $db: $db,
            $table: $db.viewPrefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          ProjectRecord,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (ProjectRecord, $$ProjectsTableReferences),
          ProjectRecord,
          PrefetchHooks Function({
            bool referenceImageId,
            bool imagesRefs,
            bool viewPrefsRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> updatedByDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> nameIsDefault = const Value.absent(),
                Value<SizeKind> sizeKind = const Value.absent(),
                Value<double?> ratioW = const Value.absent(),
                Value<double?> ratioH = const Value.absent(),
                Value<double?> width = const Value.absent(),
                Value<double?> height = const Value.absent(),
                Value<LengthUnit?> unit = const Value.absent(),
                Value<String> startNotes = const Value.absent(),
                Value<String?> referenceImageId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedByDeviceId: updatedByDeviceId,
                deletedAt: deletedAt,
                name: name,
                nameIsDefault: nameIsDefault,
                sizeKind: sizeKind,
                ratioW: ratioW,
                ratioH: ratioH,
                width: width,
                height: height,
                unit: unit,
                startNotes: startNotes,
                referenceImageId: referenceImageId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                required String updatedByDeviceId,
                Value<int?> deletedAt = const Value.absent(),
                required String name,
                required bool nameIsDefault,
                Value<SizeKind> sizeKind = const Value.absent(),
                Value<double?> ratioW = const Value.absent(),
                Value<double?> ratioH = const Value.absent(),
                Value<double?> width = const Value.absent(),
                Value<double?> height = const Value.absent(),
                Value<LengthUnit?> unit = const Value.absent(),
                Value<String> startNotes = const Value.absent(),
                Value<String?> referenceImageId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedByDeviceId: updatedByDeviceId,
                deletedAt: deletedAt,
                name: name,
                nameIsDefault: nameIsDefault,
                sizeKind: sizeKind,
                ratioW: ratioW,
                ratioH: ratioH,
                width: width,
                height: height,
                unit: unit,
                startNotes: startNotes,
                referenceImageId: referenceImageId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectsTable, ProjectRecord>(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                referenceImageId = false,
                imagesRefs = false,
                viewPrefsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (imagesRefs) db.images,
                    if (viewPrefsRefs) db.viewPrefs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (referenceImageId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.referenceImageId,
                            referencedTable: $$ProjectsTableReferences
                                ._referenceImageIdTable(db),
                            referencedColumn: $$ProjectsTableReferences
                                ._referenceImageIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (imagesRefs)
                        await $_getPrefetchedDataByColumns<
                          ProjectRecord,
                          $ProjectsTable,
                          ImageRecord,
                          $ImagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._imagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).imagesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'project_id',
                          typedResults: items,
                        ),
                      if (viewPrefsRefs)
                        await $_getPrefetchedDataByColumns<
                          ProjectRecord,
                          $ProjectsTable,
                          ViewPrefsRecord,
                          $ViewPrefsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._viewPrefsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).viewPrefsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'project_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      ProjectRecord,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (ProjectRecord, $$ProjectsTableReferences),
      ProjectRecord,
      PrefetchHooks Function({
        bool referenceImageId,
        bool imagesRefs,
        bool viewPrefsRefs,
      })
    >;
typedef $$ImageEditHistoryTableCreateCompanionBuilder =
    ImageEditHistoryCompanion Function({
      required String imageId,
      required int seq,
      required String editsJson,
      Value<int> rowid,
    });
typedef $$ImageEditHistoryTableUpdateCompanionBuilder =
    ImageEditHistoryCompanion Function({
      Value<String> imageId,
      Value<int> seq,
      Value<String> editsJson,
      Value<int> rowid,
    });

final class $$ImageEditHistoryTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ImageEditHistoryTable,
          ImageEditHistoryEntry
        > {
  $$ImageEditHistoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ImagesTable _imageIdTable(_$AppDatabase db) =>
      db.images.createAlias('image_edit_history__image_id__images__id');

  $$ImagesTableProcessedTableManager get imageId {
    final $_column = $_itemColumn<String>('image_id')!;

    final manager = $$ImagesTableTableManager(
      $_db,
      $_db.images,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_imageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImageEditHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ImageEditHistoryTable> {
  $$ImageEditHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editsJson => $composableBuilder(
    column: $table.editsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ImagesTableFilterComposer get imageId {
    final $$ImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.imageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableFilterComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageEditHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageEditHistoryTable> {
  $$ImageEditHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editsJson => $composableBuilder(
    column: $table.editsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImagesTableOrderingComposer get imageId {
    final $$ImagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.imageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableOrderingComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageEditHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageEditHistoryTable> {
  $$ImageEditHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get editsJson =>
      $composableBuilder(column: $table.editsJson, builder: (column) => column);

  $$ImagesTableAnnotationComposer get imageId {
    final $$ImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.imageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageEditHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageEditHistoryTable,
          ImageEditHistoryEntry,
          $$ImageEditHistoryTableFilterComposer,
          $$ImageEditHistoryTableOrderingComposer,
          $$ImageEditHistoryTableAnnotationComposer,
          $$ImageEditHistoryTableCreateCompanionBuilder,
          $$ImageEditHistoryTableUpdateCompanionBuilder,
          (ImageEditHistoryEntry, $$ImageEditHistoryTableReferences),
          ImageEditHistoryEntry,
          PrefetchHooks Function({bool imageId})
        > {
  $$ImageEditHistoryTableTableManager(
    _$AppDatabase db,
    $ImageEditHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageEditHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageEditHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageEditHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> imageId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> editsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageEditHistoryCompanion(
                imageId: imageId,
                seq: seq,
                editsJson: editsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String imageId,
                required int seq,
                required String editsJson,
                Value<int> rowid = const Value.absent(),
              }) => ImageEditHistoryCompanion.insert(
                imageId: imageId,
                seq: seq,
                editsJson: editsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImageEditHistoryTable, ImageEditHistoryEntry>(
                    table,
                  ),
                  $$ImageEditHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({imageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (imageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.imageId,
                        referencedTable: $$ImageEditHistoryTableReferences
                            ._imageIdTable(db),
                        referencedColumn: $$ImageEditHistoryTableReferences
                            ._imageIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImageEditHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageEditHistoryTable,
      ImageEditHistoryEntry,
      $$ImageEditHistoryTableFilterComposer,
      $$ImageEditHistoryTableOrderingComposer,
      $$ImageEditHistoryTableAnnotationComposer,
      $$ImageEditHistoryTableCreateCompanionBuilder,
      $$ImageEditHistoryTableUpdateCompanionBuilder,
      (ImageEditHistoryEntry, $$ImageEditHistoryTableReferences),
      ImageEditHistoryEntry,
      PrefetchHooks Function({bool imageId})
    >;
typedef $$ImageEditCursorTableCreateCompanionBuilder =
    ImageEditCursorCompanion Function({
      required String imageId,
      required int seq,
      Value<int> rowid,
    });
typedef $$ImageEditCursorTableUpdateCompanionBuilder =
    ImageEditCursorCompanion Function({
      Value<String> imageId,
      Value<int> seq,
      Value<int> rowid,
    });

final class $$ImageEditCursorTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ImageEditCursorTable,
          ImageEditCursorEntry
        > {
  $$ImageEditCursorTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ImagesTable _imageIdTable(_$AppDatabase db) =>
      db.images.createAlias('image_edit_cursor__image_id__images__id');

  $$ImagesTableProcessedTableManager get imageId {
    final $_column = $_itemColumn<String>('image_id')!;

    final manager = $$ImagesTableTableManager(
      $_db,
      $_db.images,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_imageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImageEditCursorTableFilterComposer
    extends Composer<_$AppDatabase, $ImageEditCursorTable> {
  $$ImageEditCursorTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  $$ImagesTableFilterComposer get imageId {
    final $$ImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.imageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableFilterComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageEditCursorTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageEditCursorTable> {
  $$ImageEditCursorTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImagesTableOrderingComposer get imageId {
    final $$ImagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.imageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableOrderingComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageEditCursorTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageEditCursorTable> {
  $$ImageEditCursorTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  $$ImagesTableAnnotationComposer get imageId {
    final $$ImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.imageId,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImageEditCursorTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageEditCursorTable,
          ImageEditCursorEntry,
          $$ImageEditCursorTableFilterComposer,
          $$ImageEditCursorTableOrderingComposer,
          $$ImageEditCursorTableAnnotationComposer,
          $$ImageEditCursorTableCreateCompanionBuilder,
          $$ImageEditCursorTableUpdateCompanionBuilder,
          (ImageEditCursorEntry, $$ImageEditCursorTableReferences),
          ImageEditCursorEntry,
          PrefetchHooks Function({bool imageId})
        > {
  $$ImageEditCursorTableTableManager(
    _$AppDatabase db,
    $ImageEditCursorTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageEditCursorTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageEditCursorTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageEditCursorTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> imageId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageEditCursorCompanion(
                imageId: imageId,
                seq: seq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String imageId,
                required int seq,
                Value<int> rowid = const Value.absent(),
              }) => ImageEditCursorCompanion.insert(
                imageId: imageId,
                seq: seq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImageEditCursorTable, ImageEditCursorEntry>(
                    table,
                  ),
                  $$ImageEditCursorTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({imageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (imageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.imageId,
                        referencedTable: $$ImageEditCursorTableReferences
                            ._imageIdTable(db),
                        referencedColumn: $$ImageEditCursorTableReferences
                            ._imageIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImageEditCursorTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageEditCursorTable,
      ImageEditCursorEntry,
      $$ImageEditCursorTableFilterComposer,
      $$ImageEditCursorTableOrderingComposer,
      $$ImageEditCursorTableAnnotationComposer,
      $$ImageEditCursorTableCreateCompanionBuilder,
      $$ImageEditCursorTableUpdateCompanionBuilder,
      (ImageEditCursorEntry, $$ImageEditCursorTableReferences),
      ImageEditCursorEntry,
      PrefetchHooks Function({bool imageId})
    >;
typedef $$AppMetaTableCreateCompanionBuilder = AppMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetaTableUpdateCompanionBuilder = AppMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetaTable,
          AppMetaEntry,
          $$AppMetaTableFilterComposer,
          $$AppMetaTableOrderingComposer,
          $$AppMetaTableAnnotationComposer,
          $$AppMetaTableCreateCompanionBuilder,
          $$AppMetaTableUpdateCompanionBuilder,
          (
            AppMetaEntry,
            BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaEntry>,
          ),
          AppMetaEntry,
          PrefetchHooks Function()
        > {
  $$AppMetaTableTableManager(_$AppDatabase db, $AppMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppMetaTable, AppMetaEntry>(table),
                  BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetaTable,
      AppMetaEntry,
      $$AppMetaTableFilterComposer,
      $$AppMetaTableOrderingComposer,
      $$AppMetaTableAnnotationComposer,
      $$AppMetaTableCreateCompanionBuilder,
      $$AppMetaTableUpdateCompanionBuilder,
      (
        AppMetaEntry,
        BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaEntry>,
      ),
      AppMetaEntry,
      PrefetchHooks Function()
    >;
typedef $$ViewPrefsTableCreateCompanionBuilder = ViewPrefsCompanion Function({
  required String id,
  required int createdAt,
  required int updatedAt,
  required String updatedByDeviceId,
  Value<int?> deletedAt,
  required String projectId,
  required String prefsJson,
  Value<int> rowid,
});
typedef $$ViewPrefsTableUpdateCompanionBuilder = ViewPrefsCompanion Function({
  Value<String> id,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> updatedByDeviceId,
  Value<int?> deletedAt,
  Value<String> projectId,
  Value<String> prefsJson,
  Value<int> rowid,
});

final class $$ViewPrefsTableReferences
    extends BaseReferences<_$AppDatabase, $ViewPrefsTable, ViewPrefsRecord> {
  $$ViewPrefsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('view_prefs__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ViewPrefsTableFilterComposer
    extends Composer<_$AppDatabase, $ViewPrefsTable> {
  $$ViewPrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prefsJson => $composableBuilder(
    column: $table.prefsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewPrefsTableOrderingComposer
    extends Composer<_$AppDatabase, $ViewPrefsTable> {
  $$ViewPrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prefsJson => $composableBuilder(
    column: $table.prefsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewPrefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ViewPrefsTable> {
  $$ViewPrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedByDeviceId => $composableBuilder(
    column: $table.updatedByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get prefsJson =>
      $composableBuilder(column: $table.prefsJson, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewPrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ViewPrefsTable,
          ViewPrefsRecord,
          $$ViewPrefsTableFilterComposer,
          $$ViewPrefsTableOrderingComposer,
          $$ViewPrefsTableAnnotationComposer,
          $$ViewPrefsTableCreateCompanionBuilder,
          $$ViewPrefsTableUpdateCompanionBuilder,
          (ViewPrefsRecord, $$ViewPrefsTableReferences),
          ViewPrefsRecord,
          PrefetchHooks Function({bool projectId})
        > {
  $$ViewPrefsTableTableManager(_$AppDatabase db, $ViewPrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ViewPrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ViewPrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ViewPrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> updatedByDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> prefsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ViewPrefsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedByDeviceId: updatedByDeviceId,
                deletedAt: deletedAt,
                projectId: projectId,
                prefsJson: prefsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                required String updatedByDeviceId,
                Value<int?> deletedAt = const Value.absent(),
                required String projectId,
                required String prefsJson,
                Value<int> rowid = const Value.absent(),
              }) => ViewPrefsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedByDeviceId: updatedByDeviceId,
                deletedAt: deletedAt,
                projectId: projectId,
                prefsJson: prefsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ViewPrefsTable, ViewPrefsRecord>(table),
                  $$ViewPrefsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$ViewPrefsTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$ViewPrefsTableReferences
                            ._projectIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ViewPrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ViewPrefsTable,
      ViewPrefsRecord,
      $$ViewPrefsTableFilterComposer,
      $$ViewPrefsTableOrderingComposer,
      $$ViewPrefsTableAnnotationComposer,
      $$ViewPrefsTableCreateCompanionBuilder,
      $$ViewPrefsTableUpdateCompanionBuilder,
      (ViewPrefsRecord, $$ViewPrefsTableReferences),
      ViewPrefsRecord,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String kind,
  required String recordId,
  required String driveFileId,
  required int remoteVersion,
  Value<String?> syncedHash,
  Value<String?> heldJson,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> kind,
  Value<String> recordId,
  Value<String> driveFileId,
  Value<int> remoteVersion,
  Value<String?> syncedHash,
  Value<String?> heldJson,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get heldJson => $composableBuilder(
    column: $table.heldJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heldJson => $composableBuilder(
    column: $table.heldJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncedHash => $composableBuilder(
    column: $table.syncedHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get heldJson =>
      $composableBuilder(column: $table.heldJson, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncStateRow,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> driveFileId = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<String?> syncedHash = const Value.absent(),
                Value<String?> heldJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                kind: kind,
                recordId: recordId,
                driveFileId: driveFileId,
                remoteVersion: remoteVersion,
                syncedHash: syncedHash,
                heldJson: heldJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String recordId,
                required String driveFileId,
                required int remoteVersion,
                Value<String?> syncedHash = const Value.absent(),
                Value<String?> heldJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                kind: kind,
                recordId: recordId,
                driveFileId: driveFileId,
                remoteVersion: remoteVersion,
                syncedHash: syncedHash,
                heldJson: heldJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStatesTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncStateRow,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$BlobSyncsTableCreateCompanionBuilder = BlobSyncsCompanion Function({
  required String blobId,
  Value<String?> driveFileId,
  Value<String?> thumbFileId,
  required String state,
  Value<int> rowid,
});
typedef $$BlobSyncsTableUpdateCompanionBuilder = BlobSyncsCompanion Function({
  Value<String> blobId,
  Value<String?> driveFileId,
  Value<String?> thumbFileId,
  Value<String> state,
  Value<int> rowid,
});

class $$BlobSyncsTableFilterComposer
    extends Composer<_$AppDatabase, $BlobSyncsTable> {
  $$BlobSyncsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbFileId => $composableBuilder(
    column: $table.thumbFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlobSyncsTableOrderingComposer
    extends Composer<_$AppDatabase, $BlobSyncsTable> {
  $$BlobSyncsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbFileId => $composableBuilder(
    column: $table.thumbFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlobSyncsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlobSyncsTable> {
  $$BlobSyncsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbFileId => $composableBuilder(
    column: $table.thumbFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);
}

class $$BlobSyncsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlobSyncsTable,
          BlobSyncRow,
          $$BlobSyncsTableFilterComposer,
          $$BlobSyncsTableOrderingComposer,
          $$BlobSyncsTableAnnotationComposer,
          $$BlobSyncsTableCreateCompanionBuilder,
          $$BlobSyncsTableUpdateCompanionBuilder,
          (
            BlobSyncRow,
            BaseReferences<_$AppDatabase, $BlobSyncsTable, BlobSyncRow>,
          ),
          BlobSyncRow,
          PrefetchHooks Function()
        > {
  $$BlobSyncsTableTableManager(_$AppDatabase db, $BlobSyncsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlobSyncsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlobSyncsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlobSyncsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> blobId = const Value.absent(),
                Value<String?> driveFileId = const Value.absent(),
                Value<String?> thumbFileId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlobSyncsCompanion(
                blobId: blobId,
                driveFileId: driveFileId,
                thumbFileId: thumbFileId,
                state: state,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blobId,
                Value<String?> driveFileId = const Value.absent(),
                Value<String?> thumbFileId = const Value.absent(),
                required String state,
                Value<int> rowid = const Value.absent(),
              }) => BlobSyncsCompanion.insert(
                blobId: blobId,
                driveFileId: driveFileId,
                thumbFileId: thumbFileId,
                state: state,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BlobSyncsTable, BlobSyncRow>(table),
                  BaseReferences<_$AppDatabase, $BlobSyncsTable, BlobSyncRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlobSyncsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlobSyncsTable,
      BlobSyncRow,
      $$BlobSyncsTableFilterComposer,
      $$BlobSyncsTableOrderingComposer,
      $$BlobSyncsTableAnnotationComposer,
      $$BlobSyncsTableCreateCompanionBuilder,
      $$BlobSyncsTableUpdateCompanionBuilder,
      (
        BlobSyncRow,
        BaseReferences<_$AppDatabase, $BlobSyncsTable, BlobSyncRow>,
      ),
      BlobSyncRow,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      required String kind,
      required String recordId,
      required String driveFileId,
      required String remoteJson,
      required int remoteVersion,
      required int detectedAt,
      Value<int> rowid,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<String> kind,
      Value<String> recordId,
      Value<String> driveFileId,
      Value<String> remoteJson,
      Value<int> remoteVersion,
      Value<int> detectedAt,
      Value<int> rowid,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflictRow,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflictRow,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
          ),
          SyncConflictRow,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> driveFileId = const Value.absent(),
                Value<String> remoteJson = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<int> detectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion(
                kind: kind,
                recordId: recordId,
                driveFileId: driveFileId,
                remoteJson: remoteJson,
                remoteVersion: remoteVersion,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String recordId,
                required String driveFileId,
                required String remoteJson,
                required int remoteVersion,
                required int detectedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                kind: kind,
                recordId: recordId,
                driveFileId: driveFileId,
                remoteJson: remoteJson,
                remoteVersion: remoteVersion,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflictRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncConflictsTable,
                    SyncConflictRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflictRow,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflictRow,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
      ),
      SyncConflictRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ImagesTableTableManager get images =>
      $$ImagesTableTableManager(_db, _db.images);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$ImageEditHistoryTableTableManager get imageEditHistory =>
      $$ImageEditHistoryTableTableManager(_db, _db.imageEditHistory);
  $$ImageEditCursorTableTableManager get imageEditCursor =>
      $$ImageEditCursorTableTableManager(_db, _db.imageEditCursor);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$ViewPrefsTableTableManager get viewPrefs =>
      $$ViewPrefsTableTableManager(_db, _db.viewPrefs);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$BlobSyncsTableTableManager get blobSyncs =>
      $$BlobSyncsTableTableManager(_db, _db.blobSyncs);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(database)
final databaseProvider = DatabaseProvider._();

final class DatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$databaseHash() => r'1379a860768fcad4b90eb85e30508800f4d68e44';
