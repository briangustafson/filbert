import 'dart:convert';

import 'package:filbert/core/imaging/edits.dart';
import 'package:flutter_test/flutter_test.dart';

CropEdit _crop(List<List<double>> corners, {OutputAspect? output}) => CropEdit(
  quad: [for (final c in corners) NormPoint(c[0], c[1])],
  output: output,
);

final _square = [
  [0.1, 0.1],
  [0.9, 0.1],
  [0.9, 0.9],
  [0.1, 0.9],
];

void main() {
  group('round-trip', () {
    test('example from m1-design §4.2', () {
      const source = '''
{
  "v": 1,
  "crop": {
    "quad": [[0.06, 0.04], [0.95, 0.07], [0.93, 0.96], [0.04, 0.94]],
    "output": { "aspectW": 4, "aspectH": 5 }
  },
  "quarterTurns": 0
}''';
      final edits = Edits.fromJsonString(source);
      expect(edits.crop!.quad.first, const NormPoint(0.06, 0.04));
      expect(edits.crop!.output, const OutputAspect(4, 5));
      expect(edits.quarterTurns, 0);
      expect(jsonDecode(edits.toJsonString()), jsonDecode(source));
    });

    test('no crop', () {
      const edits = Edits(quarterTurns: 3);
      final json = edits.toJson();
      expect(json, {'v': 1, 'quarterTurns': 3});
      expect(Edits.fromJson(json), edits);
    });

    test('Edits.none', () {
      expect(Edits.none.isNone, isTrue);
      expect(Edits.fromJsonString(Edits.none.toJsonString()), Edits.none);
    });

    test('crop without output, rotated rectangle', () {
      final edits = Edits(
        crop: _crop([
          [0.5, 0.1],
          [0.9, 0.5],
          [0.5, 0.9],
          [0.1, 0.5],
        ]),
        quarterTurns: 1,
      );
      final parsed = Edits.fromJsonString(edits.toJsonString());
      expect(parsed, edits);
      expect(parsed.hashCode, edits.hashCode);
      expect(edits.toJson()['crop'], isNot(contains('output')));
    });

    test('integer coordinates are read as doubles', () {
      final edits = Edits.fromJson({
        'v': 1,
        'crop': {
          'quad': [
            [0, 0],
            [1, 0],
            [1, 1],
            [0, 1],
          ],
        },
      });
      expect(edits.crop!.quad[2], const NormPoint(1.0, 1.0));
      expect(edits.quarterTurns, 0);
    });

    test('unknown fields are ignored', () {
      expect(
        Edits.fromJson({'v': 1, 'quarterTurns': 2, 'future': true}),
        const Edits(quarterTurns: 2),
      );
    });
  });

  group('version handling', () {
    test('unknown version is rejected, not misread', () {
      expect(
        () => Edits.fromJson({'v': 2, 'quarterTurns': 0}),
        throwsA(
          isA<UnsupportedEditsVersionException>().having(
            (e) => e.version,
            'version',
            2,
          ),
        ),
      );
    });

    test('missing or non-integer version is a format error', () {
      expect(() => Edits.fromJson({'quarterTurns': 0}), throwsFormatException);
      expect(() => Edits.fromJson({'v': '1'}), throwsFormatException);
    });
  });

  group('validation', () {
    void expectInvalid(Object? json) =>
        expect(() => Edits.fromJson(json), throwsFormatException);

    Map<String, Object?> withQuad(List<Object?> quad) => {
      'v': 1,
      'crop': {'quad': quad},
    };

    test('malformed JSON', () {
      expect(() => Edits.fromJsonString('{'), throwsFormatException);
      expectInvalid([1, 2]);
      expectInvalid(null);
    });

    test('quarterTurns must be 0–3', () {
      expectInvalid({'v': 1, 'quarterTurns': 4});
      expectInvalid({'v': 1, 'quarterTurns': -1});
      expectInvalid({'v': 1, 'quarterTurns': 1.5});
      expect(() => const Edits(quarterTurns: 4).toJson(), throwsArgumentError);
    });

    test('quad needs exactly four [x, y] corners', () {
      expectInvalid(withQuad(_square.sublist(0, 3)));
      expectInvalid(
        withQuad([
          ..._square,
          [0.5, 0.5],
        ]),
      );
      expectInvalid(
        withQuad([
          [0.1, 0.1, 0.1],
          ..._square.sublist(1),
        ]),
      );
      expectInvalid(
        withQuad([
          ['a', 0.1],
          ..._square.sublist(1),
        ]),
      );
      expectInvalid({
        'v': 1,
        'crop': {'quad': 'nope'},
      });
    });

    test('corners must be within 0–1', () {
      expectInvalid(
        withQuad([
          [-0.01, 0.1],
          ..._square.sublist(1),
        ]),
      );
      expectInvalid(
        withQuad([
          ..._square.sublist(0, 2),
          [1.01, 0.9],
          _square[3],
        ]),
      );
    });

    test('corners must be ordered TL, TR, BR, BL', () {
      // Counter-clockwise on screen.
      expectInvalid(withQuad(_square.reversed.toList()));
    });

    test('self-intersecting and concave quads are rejected', () {
      // Bow-tie: BR and BL swapped.
      expectInvalid(withQuad([_square[0], _square[1], _square[3], _square[2]]));
      // Concave: BR pulled inside.
      expectInvalid(
        withQuad([
          [0.1, 0.1],
          [0.9, 0.1],
          [0.3, 0.3],
          [0.1, 0.9],
        ]),
      );
    });

    test('degenerate quads are rejected', () {
      expectInvalid(
        withQuad([
          [0.1, 0.1],
          [0.5, 0.1],
          [0.9, 0.1],
          [0.1, 0.9],
        ]),
      );
      expectInvalid(
        withQuad([
          [0.5, 0.5],
          [0.5, 0.5],
          [0.5, 0.5],
          [0.5, 0.5],
        ]),
      );
    });

    test('output aspect must be positive', () {
      Map<String, Object?> withOutput(Object? w, Object? h) => {
        'v': 1,
        'crop': {
          'quad': _square,
          'output': {'aspectW': w, 'aspectH': h},
        },
      };
      expectInvalid(withOutput(0, 5));
      expectInvalid(withOutput(4, -5));
      expectInvalid(withOutput('4', 5));
      expect(
        Edits.fromJson(withOutput(4, 5)).crop!.output,
        const OutputAspect(4, 5),
      );
    });

    test('quad list is unmodifiable', () {
      final crop = _crop(_square);
      expect(
        () => crop.quad.add(const NormPoint(0, 0)),
        throwsUnsupportedError,
      );
    });
  });
}
