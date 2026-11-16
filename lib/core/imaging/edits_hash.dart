import 'edits.dart';

/// A short, stable hash of [edits] for render-cache keys (m1-design §4.4).
///
/// 64-bit FNV-1a over the canonical JSON, as 16 hex digits. Unlike
/// `String.hashCode` it is the same on every run, so cached files stay valid
/// across launches. Equal edits always give the same hash, whatever formatting
/// the stored `edits_json` had.
///
/// Relies on 64-bit wrap-around integers (native platforms); the web port
/// needs a different implementation.
String editsHash(Edits edits) {
  var hash = _offsetBasis;
  for (final unit in edits.toJsonString().codeUnits) {
    hash ^= unit;
    hash *= _prime;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

// 0xcbf29ce484222325 as a signed 64-bit int (Dart ints are signed).
const _offsetBasis = -0x340d631b7bdddcdb;
const _prime = 0x100000001b3;
