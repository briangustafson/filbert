// The record format (m3-design §5).

import 'dart:convert';

import 'package:sync_engine/sync_engine.dart';
import 'package:test/test.dart';

const codec = RecordCodec();

SyncRecord record(RecordKind kind, Map<String, Object?> fields) => SyncRecord(
  kind: kind,
  id: '0193-${kind.wire}',
  createdAt: 1763450000000,
  updatedAt: 1763450005000,
  updatedByDeviceId: '0193-device',
  fields: fields,
);

final samples = {
  RecordKind.project: record(RecordKind.project, {
    'name': 'Harbour at dusk',
    'nameIsDefault': false,
    'size': {'kind': 'physical', 'width': 16.0, 'height': 20.0, 'unit': 'in'},
    'startNotes': 'Warm ground; block in the sky first.',
    'referenceImageId': '0193-image',
  }),
  RecordKind.image: record(RecordKind.image, {
    'projectId': '0193-project',
    'blobId': '0193-blob',
    'mimeType': 'image/heic',
    'width': 4032,
    'height': 3024,
    'source': 'camera',
    'capturedAt': 1763449000000,
    'edits': {
      'v': 1,
      'crop': [
        [0.1, 0.1],
        [0.9, 0.1],
        [0.9, 0.9],
        [0.1, 0.9],
      ],
      'quarterTurns': 0,
    },
    'derivedFrom': null,
  }),
  RecordKind.viewPrefs: record(RecordKind.viewPrefs, {
    'projectId': '0193-project',
    'prefs': {
      'v': 1,
      'values': {'bands': 5},
    },
  }),
};

void main() {
  for (final MapEntry(key: kind, value: sample) in samples.entries) {
    test('${kind.wire}: round trip', () {
      final decoded = codec.decode(codec.encode(sample));
      expect(decoded, isA<DecodedRecord>());
      final back = (decoded as DecodedRecord).record;
      expect(codec.encode(back), codec.encode(sample));
      expect(back.key, sample.key);
      expect(codec.hash(back), codec.hash(sample));
    });
  }

  test('the JSON has the §5 shape', () {
    final json = jsonDecode(codec.encode(samples[RecordKind.image]!)) as Map;
    expect(json['schemaVersion'], 1);
    expect(json['kind'], 'image');
    expect(json.keys, containsAll(['createdAt', 'updatedAt', 'deletedAt']));
    expect(json['edits'], isA<Map>(), reason: 'embedded, not a string');
  });

  test('canonical: keys sorted at every level, no spaces', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {'d': 2, 'c': 3},
      }),
      '{"a":{"c":3,"d":2},"b":1}',
    );
  });

  test('the hash is the same whatever order the fields came in', () {
    final p = samples[RecordKind.project]!;
    final reordered = SyncRecord(
      kind: p.kind,
      id: p.id,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      updatedByDeviceId: p.updatedByDeviceId,
      fields: Map.fromEntries(p.fields.entries.toList().reversed),
    );
    expect(codec.hash(reordered), codec.hash(p));
    expect(codec.hash(p), hasLength(64), reason: 'SHA-256 in hex');
  });

  test('any change changes the hash; stamps alone keep the content hash', () {
    final p = samples[RecordKind.project]!;
    final renamed = p.edited(
      now: p.updatedAt,
      deviceId: p.updatedByDeviceId,
      fields: {'name': 'X'},
    );
    expect(codec.hash(renamed), isNot(codec.hash(p)));
    final restamped = p.edited(now: p.updatedAt + 1, deviceId: 'other');
    expect(codec.hash(restamped), isNot(codec.hash(p)));
    expect(codec.contentHash(restamped), codec.contentHash(p));
    final deleted = p.edited(
      now: p.updatedAt + 1,
      deviceId: 'other',
      delete: true,
    );
    expect(codec.contentHash(deleted), isNot(codec.contentHash(p)));
  });

  test('unknown fields are ignored', () {
    final json = jsonDecode(
      codec.encode(samples[RecordKind.project]!),
    ) as Map<String, Object?>;
    json['colourTemperature'] = 'warm';
    final decoded = codec.decode(jsonEncode(json)) as DecodedRecord;
    expect(decoded.record.fields.containsKey('colourTemperature'), isFalse);
    expect(
      codec.encode(decoded.record),
      codec.encode(samples[RecordKind.project]!),
    );
  });

  test('a higher schemaVersion is kept as it is, not read', () {
    final json = jsonDecode(
      codec.encode(samples[RecordKind.image]!),
    ) as Map<String, Object?>..['schemaVersion'] = 2;
    final text = jsonEncode(json);
    final decoded = codec.decode(text);
    expect(decoded, isA<TooNewRecord>());
    expect((decoded as TooNewRecord).schemaVersion, 2);
    expect(decoded.json, text);
  });

  test('a lower schemaVersion is migrated on read', () {
    final v2 = RecordCodec(
      schemaVersion: 2,
      migrations: {
        1: (m) => {...m, 'startNotes': '${m['startNotes']} (migrated)'},
      },
    );
    final decoded =
        v2.decode(codec.encode(samples[RecordKind.project]!)) as DecodedRecord;
    expect(decoded.record.fields['startNotes'], endsWith('(migrated)'));
    expect(jsonDecode(v2.encode(decoded.record))['schemaVersion'], 2);
    expect(
      const RecordCodec(schemaVersion: 2)
          .decode(codec.encode(samples[RecordKind.project]!)),
      isA<InvalidRecord>(),
      reason: 'no migration',
    );
  });

  group('invalid records', () {
    Map<String, Object?> json() =>
        jsonDecode(codec.encode(samples[RecordKind.image]!))
            as Map<String, Object?>;

    for (final (what, text) in [
      ('not JSON', 'nope'),
      ('not an object', '[1]'),
      ('no schemaVersion', jsonEncode(json()..remove('schemaVersion'))),
      ('an unknown kind', jsonEncode(json()..['kind'] = 'palette')),
      ('a missing field', jsonEncode(json()..remove('blobId'))),
      ('a wrong type', jsonEncode(json()..['width'] = '4032')),
      ('a null that is not allowed', jsonEncode(json()..['edits'] = null)),
      ('a bad timestamp', jsonEncode(json()..['updatedAt'] = 'yesterday')),
    ]) {
      test(what, () => expect(codec.decode(text), isA<InvalidRecord>()));
    }

    test('a nullable field may be null', () {
      expect(
        codec.decode(jsonEncode(json()..['capturedAt'] = null)),
        isA<DecodedRecord>(),
      );
    });
  });

  test('Drive file names (§6.2)', () {
    final key = samples[RecordKind.viewPrefs]!.key;
    expect(recordFileName(key), 'viewprefs-0193-viewPrefs.json');
    expect(recordKeyOfFile(recordFileName(key)), key);
    expect(recordKeyOfFile('project-0193-a-b.json'), (
      kind: RecordKind.project,
      id: '0193-a-b',
    ));
    expect(recordKeyOfFile('blob-0193.jpg'), isNull);
    expect(recordKeyOfFile('manifest.json'), isNull);
    expect(blobFileName('b1', 'image/heic'), 'blob-b1.heic');
    expect(blobFileName('b1', 'image/jpeg'), 'blob-b1.jpg');
    expect(thumbFileName('b1'), 'thumb-b1.jpg');
  });
}
