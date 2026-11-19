import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'record.dart';

/// A field's JSON type.
enum FieldType { string, integer, number, boolean, object }

typedef FieldSpec = ({String name, FieldType type, bool nullable});

/// What reading a record's JSON gave.
sealed class DecodeResult {
  const DecodeResult();
}

class DecodedRecord extends DecodeResult {
  const DecodedRecord(this.record);

  final SyncRecord record;
}

/// Written by a newer Filbert: kept as-is and not applied (m3-design §5).
class TooNewRecord extends DecodeResult {
  const TooNewRecord(this.schemaVersion, this.json);

  final int schemaVersion;
  final String json;
}

class InvalidRecord extends DecodeResult {
  const InvalidRecord(this.reason);

  final String reason;

  @override
  String toString() => 'InvalidRecord($reason)';
}

/// The one JSON form of a record (m3-design §5), for sync and, later,
/// project backups.
///
/// Field names are camelCase and fixed here, apart from any Dart or Drift
/// names. Readers ignore unknown fields. A record with a higher
/// `schemaVersion` than [schemaVersion] is [TooNewRecord]; a lower one is
/// migrated on read by [migrations].
class RecordCodec {
  const RecordCodec({this.schemaVersion = current, this.migrations = const {}});

  /// The schema version this app writes.
  static const current = 1;

  final int schemaVersion;

  /// Upgrades a record's JSON from the key's version to the next one.
  final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
  migrations;

  /// Each kind's own fields (§5). `size` is a project's canvas:
  /// `{"kind": "none"}`, `{"kind": "ratio", "w", "h"}` or
  /// `{"kind": "physical", "width", "height", "unit"}`. `edits`,
  /// `derivedFrom` and `prefs` embed the app's JSON for them (m1-design §4.2,
  /// m2-design §4.2–4.3).
  static const Map<RecordKind, List<FieldSpec>> fieldsOf = {
    RecordKind.project: [
      (name: 'name', type: FieldType.string, nullable: false),
      (name: 'nameIsDefault', type: FieldType.boolean, nullable: false),
      (name: 'size', type: FieldType.object, nullable: false),
      (name: 'startNotes', type: FieldType.string, nullable: false),
      (name: 'referenceImageId', type: FieldType.string, nullable: true),
    ],
    RecordKind.image: [
      (name: 'projectId', type: FieldType.string, nullable: false),
      (name: 'blobId', type: FieldType.string, nullable: false),
      (name: 'mimeType', type: FieldType.string, nullable: false),
      (name: 'width', type: FieldType.integer, nullable: false),
      (name: 'height', type: FieldType.integer, nullable: false),
      (name: 'source', type: FieldType.string, nullable: false),
      (name: 'capturedAt', type: FieldType.integer, nullable: true),
      (name: 'edits', type: FieldType.object, nullable: false),
      (name: 'derivedFrom', type: FieldType.object, nullable: true),
    ],
    RecordKind.viewPrefs: [
      (name: 'projectId', type: FieldType.string, nullable: false),
      (name: 'prefs', type: FieldType.object, nullable: false),
    ],
  };

  Map<String, Object?> toJson(SyncRecord record) => {
    'schemaVersion': schemaVersion,
    'kind': record.kind.wire,
    'id': record.id,
    'createdAt': record.createdAt,
    'updatedAt': record.updatedAt,
    'updatedByDeviceId': record.updatedByDeviceId,
    'deletedAt': record.deletedAt,
    for (final field in fieldsOf[record.kind]!)
      field.name: record.fields[field.name],
  };

  /// The record's canonical JSON: keys sorted at every level, no spaces.
  String encode(SyncRecord record) => canonicalJson(toJson(record));

  DecodeResult decode(String json) {
    final Object? parsed;
    try {
      parsed = jsonDecode(json);
    } on FormatException catch (e) {
      return InvalidRecord('not JSON: ${e.message}');
    }
    if (parsed is! Map<String, Object?>) {
      return const InvalidRecord('not an object');
    }
    var map = parsed;
    final version = map['schemaVersion'];
    if (version is! int || version < 1) {
      return InvalidRecord('bad schemaVersion $version');
    }
    if (version > schemaVersion) return TooNewRecord(version, json);
    for (var v = version; v < schemaVersion; v++) {
      final migrate = migrations[v];
      if (migrate == null) return InvalidRecord('no migration from $v');
      map = migrate(map);
    }
    final kind = RecordKind.fromWire(map['kind'] as String?);
    if (kind == null) return InvalidRecord('unknown kind ${map['kind']}');
    final id = map['id'];
    final createdAt = map['createdAt'];
    final updatedAt = map['updatedAt'];
    final device = map['updatedByDeviceId'];
    final deletedAt = map['deletedAt'];
    if (id is! String ||
        createdAt is! int ||
        updatedAt is! int ||
        device is! String ||
        (deletedAt != null && deletedAt is! int)) {
      return const InvalidRecord('bad common fields');
    }
    final fields = <String, Object?>{};
    for (final field in fieldsOf[kind]!) {
      final value = map[field.name];
      if (!_fits(value, field)) {
        return InvalidRecord('bad ${kind.wire}.${field.name}: $value');
      }
      fields[field.name] = value;
    }
    return DecodedRecord(
      SyncRecord(
        kind: kind,
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        updatedByDeviceId: device,
        deletedAt: deletedAt as int?,
        fields: fields,
      ),
    );
  }

  static bool _fits(Object? value, FieldSpec field) => switch (value) {
    null => field.nullable,
    String() => field.type == FieldType.string,
    int() => field.type == FieldType.integer || field.type == FieldType.number,
    double() => field.type == FieldType.number,
    bool() => field.type == FieldType.boolean,
    Map() => field.type == FieldType.object,
    _ => false,
  };

  /// SHA-256 of the canonical JSON: changes when anything in the record
  /// does (m3-design §6.3).
  String hash(SyncRecord record) => _sha(encode(record));

  /// As [hash], without who changed it when: two devices making the same
  /// change (say, renumbering the same default name) get the same content
  /// hash, so that isn't a conflict.
  String contentHash(SyncRecord record) {
    final json = toJson(record)
      ..remove('updatedAt')
      ..remove('updatedByDeviceId');
    return _sha(canonicalJson(json));
  }

  static String _sha(String text) =>
      sha256.convert(utf8.encode(text)).toString();
}

/// [value] as JSON with map keys sorted at every level, and whole-number
/// decimals written as integers: the app's database keeps a 16 × 20 canvas
/// as 16.0 and 20.0, so the same record reads back the same either way.
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) => switch (value) {
  double() when value.isFinite && value == value.truncateToDouble() =>
    value.toInt(),
  Map() => {
    for (final key in (value.keys.map((k) => k as String).toList()..sort()))
      key: _sorted(value[key]),
  },
  List() => [for (final item in value) _sorted(item)],
  _ => value,
};
