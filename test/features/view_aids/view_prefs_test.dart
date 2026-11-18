import 'dart:convert';

import 'package:filbert/core/units/length_unit.dart';
import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:filbert/features/view_aids/domain/view_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const custom = ViewPrefs(
    grid: GridPrefs(
      mode: GridMode.spacing,
      rows: 3,
      cols: 6,
      spacing: 1.5,
      diagonals: true,
      color: GridColor.red,
      width: GridLineWidth.thick,
    ),
    values: ValuesPrefs(bands: 3),
    colors: ColorsPrefs(count: 12),
    compare: ComparePrefs(imageId: '0193-photo', opacity: 0.25),
    on: AidsOn(grid: true, tone: ToneAid.valueBands, compare: true),
  );

  ViewPrefs parse(Object? json) => ViewPrefs.fromJson(json);

  test('defaults (m2-design §3)', () {
    const d = ViewPrefs.defaults;
    expect(d.grid.mode, GridMode.divisions);
    expect((d.grid.rows, d.grid.cols), (4, 4));
    expect(d.grid.spacing, isNull);
    expect(d.grid.spacingIn(LengthUnit.inches), 2);
    expect(d.grid.spacingIn(LengthUnit.centimeters), 5);
    expect(d.grid.diagonals, isFalse);
    expect(d.grid.color, GridColor.white);
    expect(d.grid.width, GridLineWidth.thin);
    expect(d.values.bands, 5);
    expect(d.colors.count, 8);
    expect(d.compare.imageId, isNull);
    expect(d.compare.opacity, 0.5);
  });

  test('round-trips through JSON', () {
    expect(ViewPrefs.fromJsonString(custom.toJsonString()), custom);
    expect(
      ViewPrefs.fromJsonString(ViewPrefs.defaults.toJsonString()),
      ViewPrefs.defaults,
    );
  });

  test('writes the documented format (§4.2)', () {
    expect(custom.toJson(), {
      'v': 1,
      'grid': {
        'mode': 'spacing',
        'rows': 3,
        'cols': 6,
        'spacing': 1.5,
        'diagonals': true,
        'color': 'red',
        'width': 'thick',
      },
      'values': {'bands': 3},
      'colors': {'count': 12},
      'compare': {'imageId': '0193-photo', 'opacity': 0.25},
      'on': {'grid': true, 'tone': 'values', 'compare': true},
    });
    // Defaults that are "unset" are left out.
    final d = ViewPrefs.defaults.toJson();
    expect((d['grid']! as Map).containsKey('spacing'), isFalse);
    expect((d['compare']! as Map).containsKey('imageId'), isFalse);
  });

  test('missing fields take defaults', () {
    expect(parse({'v': 1}), ViewPrefs.defaults);
    expect(
      parse({
        'v': 1,
        'grid': {'rows': 6},
        'compare': {'opacity': 0.8},
      }),
      ViewPrefs(
        grid: const GridPrefs(rows: 6),
        compare: const ComparePrefs(opacity: 0.8),
      ),
    );
  });

  test('which aids are on: missing means all off; each tone by name', () {
    expect(parse({'v': 1}).on, AidsOn.off, reason: 'rows from before');
    for (final (name, tone) in [
      ('none', ToneAid.none),
      ('gray', ToneAid.gray),
      ('values', ToneAid.valueBands),
      ('colors', ToneAid.colors),
      ('sepia', ToneAid.none),
    ]) {
      expect(
        parse({
          'v': 1,
          'on': {'tone': name},
        }).on.tone,
        tone,
      );
    }
    expect(
      parse({
        'v': 1,
        'on': {'grid': 'yes', 'compare': true},
      }).on,
      const AidsOn(compare: true),
    );
  });

  test('unknown fields are ignored', () {
    final json = custom.toJson()
      ..['future'] = {'x': 1}
      ..['grid'] = {...(custom.toJson()['grid']! as Map), 'dashed': true};
    expect(parse(json), custom);
  });

  test('an unknown version or malformed JSON gives defaults', () {
    expect(parse({...custom.toJson(), 'v': 2}), ViewPrefs.defaults);
    expect(parse({...custom.toJson()}..remove('v')), ViewPrefs.defaults);
    expect(parse('not a map'), ViewPrefs.defaults);
    expect(parse(null), ViewPrefs.defaults);
    expect(ViewPrefs.fromJsonString('{"v": 1, '), ViewPrefs.defaults);
  });

  test('wrong types take defaults; out-of-range values are clamped', () {
    final p = parse({
      'v': 1,
      'grid': {
        'mode': 'hexagons',
        'rows': 0,
        'cols': 99,
        'spacing': -2,
        'diagonals': 'yes',
        'color': 7,
        'width': null,
      },
      'values': {'bands': 12},
      'colors': {'count': 1},
      'compare': {'imageId': 42, 'opacity': 3},
    });
    expect(
      p,
      const ViewPrefs(
        grid: GridPrefs(rows: 1, cols: 20),
        values: ValuesPrefs(bands: 9),
        colors: ColorsPrefs(count: 2),
        compare: ComparePrefs(opacity: 1),
      ),
    );
    expect(
      parse({
        'v': 1,
        'values': {'bands': 'five'},
        'grid': {'rows': 4.6, 'spacing': 0},
        'compare': {'imageId': '', 'opacity': -1},
      }),
      const ViewPrefs(
        grid: GridPrefs(rows: 5),
        compare: ComparePrefs(opacity: 0),
      ),
    );
  });

  test('copyWith can reset spacing and the compare photo to defaults', () {
    final grid = custom.grid.copyWith(spacing: () => null, rows: 8);
    expect(grid.spacing, isNull);
    expect(grid.rows, 8);
    expect(grid.color, GridColor.red);
    expect(custom.compare.copyWith(imageId: () => null).imageId, isNull);
    expect(custom.compare.copyWith(opacity: 0.9).imageId, '0193-photo');
  });

  test('JSON is plain (encodable as is)', () {
    expect(() => jsonEncode(custom.toJson()), returnsNormally);
  });
}
