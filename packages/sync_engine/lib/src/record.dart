/// The kinds of synced record (m3-design §5), in dependency order: an image
/// needs its project, view prefs need theirs.
enum RecordKind {
  project('project', 'project'),
  image('image', 'image'),
  viewPrefs('viewPrefs', 'viewprefs');

  const RecordKind(this.wire, this.filePrefix);

  /// The `kind` field in the JSON.
  final String wire;

  /// The Drive file name's prefix (§6.2): `<prefix>-<id>.json`.
  final String filePrefix;

  static RecordKind? fromWire(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// A record's identity: its kind and id.
typedef RecordKey = ({RecordKind kind, String id});

/// One synced record (m3-design §5): the columns every record has, typed,
/// and the kind's own fields as JSON values ([fields]), whose names and
/// types [RecordCodec] pins down.
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByDeviceId,
    this.deletedAt,
    required this.fields,
  });

  final RecordKind kind;
  final String id;

  /// UTC epoch milliseconds.
  final int createdAt;
  final int updatedAt;
  final String updatedByDeviceId;

  /// Set on a tombstone.
  final int? deletedAt;

  /// The kind's fields, as JSON values (maps, lists, strings, numbers,
  /// booleans, null).
  final Map<String, Object?> fields;

  RecordKey get key => (kind: kind, id: id);
  bool get isDeleted => deletedAt != null;

  /// An image's or view prefs' project.
  String? get projectId => fields['projectId'] as String?;

  /// An image's original.
  String? get blobId => fields['blobId'] as String?;
  String? get mimeType => fields['mimeType'] as String?;

  /// A project's name.
  String? get name => fields['name'] as String?;
  bool get nameIsDefault => fields['nameIsDefault'] == true;

  /// This record changed by [deviceId] at [now]: [fields] merged in, or
  /// deleted.
  SyncRecord edited({
    required int now,
    required String deviceId,
    Map<String, Object?> fields = const {},
    bool delete = false,
  }) => SyncRecord(
    kind: kind,
    id: id,
    createdAt: createdAt,
    updatedAt: now,
    updatedByDeviceId: deviceId,
    deletedAt: delete ? (deletedAt ?? now) : deletedAt,
    fields: {...this.fields, ...fields},
  );

  @override
  String toString() =>
      'SyncRecord(${kind.wire} $id @$updatedAt by $updatedByDeviceId'
      '${isDeleted ? ', deleted' : ''}, $fields)';
}

/// The Drive file name of a record (§6.2).
String recordFileName(RecordKey key) => '${key.kind.filePrefix}-${key.id}.json';

/// The record a Drive file name stands for, or null for other files.
RecordKey? recordKeyOfFile(String name) {
  if (!name.endsWith('.json')) return null;
  final dash = name.indexOf('-');
  if (dash < 0) return null;
  final prefix = name.substring(0, dash);
  for (final kind in RecordKind.values) {
    if (kind.filePrefix == prefix) {
      return (kind: kind, id: name.substring(dash + 1, name.length - 5));
    }
  }
  return null;
}

/// The Drive file name of an original (§6.2): `blob-<blobId>.<ext>`.
String blobFileName(String blobId, String? mimeType) =>
    'blob-$blobId.${switch (mimeType) {
      'image/png' => 'png',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      'image/webp' => 'webp',
      _ => 'jpg',
    }}';

/// The Drive file name of an original's 512 px thumbnail (§6.2).
String thumbFileName(String blobId) => 'thumb-$blobId.jpg';
