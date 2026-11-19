// The multi-device tests (m3-design §12) on in-memory devices. T6 runs the
// same scenarios against the Drift store.

import 'package:sync_engine/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final MapEntry(:key, :value) in engineScenarios.entries) {
    test(key, () => value(Sim()));
  }
}
