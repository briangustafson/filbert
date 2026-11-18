/// The viewing aids on the photo-screen toolbar (m2-design §3.1).
enum Aid {
  grid,
  gray,

  /// "Values" in the UI (`values` is taken by Dart's enum list).
  valueBands,
  colors,
  compare;

  /// Gray, Values and Colors are alternative ways to show tone: one at a time.
  bool get isTone => this == gray || this == valueBands || this == colors;

  /// Gray has nothing to adjust.
  bool get hasPanel => this != gray;
}

/// Which tone aid is on, if any.
enum ToneAid { none, gray, valueBands, colors }

/// Which aids are on and which panel is open, for one visit to the photo
/// screen (not saved, not part of undo; m2-design §3.1, §6).
class ViewAids {
  const ViewAids({
    this.grid = false,
    this.tone = ToneAid.none,
    this.compare = false,
    this.panel,
  });

  /// All off, no panel: how every visit starts.
  static const off = ViewAids();

  final bool grid;
  final ToneAid tone;
  final bool compare;

  /// The aid whose panel is open; always one that is on.
  final Aid? panel;

  bool get anyOn => grid || tone != ToneAid.none || compare;

  bool isOn(Aid aid) => switch (aid) {
    Aid.grid => grid,
    Aid.gray => tone == ToneAid.gray,
    Aid.valueBands => tone == ToneAid.valueBands,
    Aid.colors => tone == ToneAid.colors,
    Aid.compare => compare,
  };

  /// A toolbar tap on [aid]:
  /// - off → on, with its panel open (any other panel closes; another tone
  ///   aid turns off);
  /// - on with its panel open → off;
  /// - on with its panel closed → its panel opens;
  /// - Gray (no panel) toggles.
  ViewAids tap(Aid aid) {
    if (!isOn(aid)) {
      return _set(aid, on: true)._withPanel(aid.hasPanel ? aid : null);
    }
    if (!aid.hasPanel || panel == aid) {
      return _set(aid, on: false)._withPanel(panel == aid ? null : panel);
    }
    return _withPanel(aid);
  }

  ViewAids closePanel() => _withPanel(null);

  ViewAids _set(Aid aid, {required bool on}) {
    var tone = this.tone;
    if (aid.isTone) {
      tone = !on
          ? ToneAid.none
          : switch (aid) {
              Aid.gray => ToneAid.gray,
              Aid.valueBands => ToneAid.valueBands,
              _ => ToneAid.colors,
            };
    }
    // A panel belongs to an aid that is on; turning a tone aid on turns the
    // other tone aids, and their panels, off.
    final keepPanel =
        panel != null && !(aid.isTone && on && panel!.isTone && panel != aid);
    return ViewAids(
      grid: aid == Aid.grid ? on : grid,
      tone: tone,
      compare: aid == Aid.compare ? on : compare,
      panel: keepPanel ? panel : null,
    );
  }

  ViewAids _withPanel(Aid? panel) =>
      ViewAids(grid: grid, tone: tone, compare: compare, panel: panel);

  @override
  bool operator ==(Object other) =>
      other is ViewAids &&
      other.grid == grid &&
      other.tone == tone &&
      other.compare == compare &&
      other.panel == panel;

  @override
  int get hashCode => Object.hash(grid, tone, compare, panel);

  @override
  String toString() =>
      'ViewAids(grid: $grid, tone: ${tone.name}, compare: $compare, '
      'panel: ${panel?.name})';
}
