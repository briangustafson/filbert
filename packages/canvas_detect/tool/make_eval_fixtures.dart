// Makes the canvas-detection evaluation fixtures (m1-design §6.4) from the
// full-size photos in the repository's eval-originals/ (git-ignored). Run
// from packages/canvas_detect:
//
//   dart run tool/make_eval_fixtures.dart
//
// Each photo is decoded (EXIF orientation applied), downscaled to 1600 px on
// the long edge and re-encoded as JPEG. Re-encoding writes no metadata at
// all, so GPS and camera data are dropped, as is a motion photo's embedded
// video; orientation needs no tag because the pixels are upright.
//
// Fixtures are numbered in file-name (date) order: photo-01.jpg, … Existing
// fixtures are kept, so adding photos later only adds new numbers. The
// mapping back to original names is written next to the originals.

import 'dart:io';
import 'dart:math' as math;

import 'package:dartcv4/dartcv.dart' as cv;

const _originals = '../../eval-originals';
const _fixtures = 'test/fixtures';
const _mappingFile = '$_originals/fixture-mapping.txt';
const _longEdge = 1600;
const _quality = 90;

void main() {
  final mapping = _readMapping();
  final originals =
      Directory(_originals)
          .listSync()
          .whereType<File>()
          .where(
            (f) => RegExp(r'\.(jpe?g)$', caseSensitive: false).hasMatch(f.path),
          )
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
  var next = mapping.isEmpty
      ? 1
      : mapping.values.map(_number).reduce(math.max) + 1;

  Directory(_fixtures).createSync(recursive: true);
  for (final name in originals) {
    final fixture = mapping[name] ??=
        'photo-${(next++).toString().padLeft(2, '0')}.jpg';
    final target = File('$_fixtures/$fixture');
    if (target.existsSync()) continue;

    final image = cv.imread('$_originals/$name', flags: cv.IMREAD_COLOR);
    if (image.isEmpty) throw StateError('Could not read $name');
    final scale = math.min(1.0, _longEdge / math.max(image.cols, image.rows));
    final small = cv.resize(image, (
      (image.cols * scale).round(),
      (image.rows * scale).round(),
    ), interpolation: cv.INTER_AREA);
    final (ok, jpeg) = cv.imencode(
      '.jpg',
      small,
      params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, _quality]),
    );
    if (!ok) throw StateError('Could not encode $name');
    target.writeAsBytesSync(jpeg);
    stdout.writeln('$name → $fixture (${small.cols}×${small.rows})');
  }

  File(_mappingFile).writeAsStringSync(
    [for (final e in mapping.entries) '${e.value}\t${e.key}'].join('\n'),
  );
}

Map<String, String> _readMapping() {
  final file = File(_mappingFile);
  if (!file.existsSync()) return {};
  return {
    for (final line in file.readAsLinesSync().where((l) => l.contains('\t')))
      line.split('\t')[1]: line.split('\t')[0],
  };
}

int _number(String fixture) =>
    int.parse(RegExp(r'(\d+)').firstMatch(fixture)!.group(1)!);
