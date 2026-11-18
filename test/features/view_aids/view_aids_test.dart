import 'package:filbert/features/view_aids/domain/view_aids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ViewAids tap(List<Aid> aids, [ViewAids from = ViewAids.off]) =>
      aids.fold(from, (state, aid) => state.tap(aid));

  test('everything starts off', () {
    expect(ViewAids.off.anyOn, isFalse);
    expect(ViewAids.off.panel, isNull);
  });

  test('turning an aid on opens its panel; tapping again turns it off', () {
    final on = tap([Aid.valueBands]);
    expect(on.tone, ToneAid.valueBands);
    expect(on.panel, Aid.valueBands);
    expect(on.tap(Aid.valueBands), ViewAids.off);
  });

  test('Gray, Values and Colors are one choice', () {
    final s = tap([Aid.gray, Aid.valueBands, Aid.colors]);
    expect(s.tone, ToneAid.colors);
    expect(s.isOn(Aid.gray), isFalse);
    expect(s.isOn(Aid.valueBands), isFalse);
    expect(s.panel, Aid.colors);
  });

  test('Grid and Compare combine with a tone aid', () {
    final s = tap([Aid.grid, Aid.compare, Aid.valueBands]);
    expect((s.grid, s.compare, s.tone), (true, true, ToneAid.valueBands));
    expect(s.panel, Aid.valueBands, reason: 'the last one tapped');
  });

  test('tapping an aid that is on, with its panel closed, opens the panel', () {
    final s = tap([Aid.grid, Aid.colors]);
    expect(s.panel, Aid.colors);
    final back = s.tap(Aid.grid);
    expect(back.grid, isTrue, reason: 'stays on');
    expect(back.panel, Aid.grid);
    expect(back.tone, ToneAid.colors);
  });

  test('Gray has no panel: it toggles', () {
    final on = tap([Aid.gray]);
    expect((on.tone, on.panel), (ToneAid.gray, null));
    expect(on.tap(Aid.gray), ViewAids.off);
  });

  test('Gray closes a tone panel but not the grid panel', () {
    expect(tap([Aid.valueBands, Aid.gray]).panel, isNull);
    final withGrid = tap([Aid.grid, Aid.gray]);
    expect(withGrid.panel, isNull, reason: 'turning an aid on closes panels');
    final gridOpen = tap([Aid.gray, Aid.grid]);
    expect(gridOpen.tap(Aid.gray).panel, Aid.grid, reason: 'Gray off keeps it');
  });

  test('closing the panel leaves the aids on', () {
    final s = tap([Aid.grid, Aid.valueBands]).closePanel();
    expect((s.grid, s.tone, s.panel), (true, ToneAid.valueBands, null));
  });
}
