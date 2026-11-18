// Fails if Filbert's code calls a dartcv4 function that has the
// temporary-size hazard directly instead of through safe_cv.dart (m1-design
// §7). The hazardous functions are found by scanning the dartcv4 source that
// pub resolved, so a new call to any of them is caught too, not only the
// ones safe_cv.dart wraps today.

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

/// A native object built and read in one expression: `size.cvd.ref`,
/// `TermCriteria.fromRecord(criteria).ref`, `size.toSize().ref`,
/// `(color ?? Scalar(…)).ref`. A cast, `(other as VecPoint).ptr`, reads an
/// object a variable holds, so it's safe.
final _hazard = RegExp(r'\.cvd\.(ref|ptr)\b|(?<!\bas \w+)\)\.(ref|ptr)\b');

/// The start of a top-level declaration: anything at column 0 except
/// comments, directives, annotations and the closing lines of a declaration.
final _topLevel = RegExp(r'^(?![\s/}\)\]@]|import |export |library |part )');
final _classDecl = RegExp(
  r'^(?:(?:abstract|final|base|sealed|interface)\s+)*(?:class|mixin|extension(?:\s+type)?|enum)\s+(\w+)',
);
final _functionName = RegExp(r'(\w+)\s*(?:<[^>]*>)?\(');

/// Files allowed to call the dartcv4 functions directly: the test that
/// compares the wrappers with them.
const _allowed = {'packages/canvas_detect/test/safe_cv_test.dart'};

void main() {
  late Directory repo;
  late ({Set<String> functions, Set<String> classes}) hazardous;

  setUpAll(() async {
    // `dart test` runs in packages/canvas_detect.
    repo = Directory.current.parent.parent;
    final dartcv = await Isolate.resolvePackageUri(
      Uri.parse('package:dartcv4/dartcv.dart'),
    );
    hazardous = _scanDartcv(Directory.fromUri(dartcv!.resolve('src/')));
  });

  test('the scan finds the known hazardous functions', () {
    expect(
      hazardous.functions,
      containsAll([
        'resize',
        'gaussianBlur',
        'getStructuringElement',
        'warpPerspective',
        'kmeans',
        'resizeAsync',
        // The other forms of the pattern: toTermCriteria().ref, toSize().ref,
        // (color ?? Scalar(…)).ref.
        'findTransformECC',
        'findChessboardCornersSB',
        'drawDetectedCornersCharuco',
      ]),
    );
    // 28 in dartcv4 2.3.1, plus their Async variants.
    expect(
      hazardous.functions.where((f) => !f.endsWith('Async')),
      hasLength(28),
    );
    expect(hazardous.functions, isNot(contains('cvtColor')));
    expect(hazardous.functions, isNot(contains('groupRectangles')));
  });

  test('our code calls them only through safe_cv.dart', () {
    final calls = RegExp(
      r'\bcv\.(' + hazardous.functions.join('|') + r')\s*\(',
    );
    final classes = RegExp(r'\bcv\.(' + hazardous.classes.join('|') + r')\b');
    final offences = <String>[];
    for (final file in _ourDartFiles(repo)) {
      final path = file.path.substring(repo.path.length + 1);
      if (_allowed.contains(path)) continue;
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        for (final m in [
          ...calls.allMatches(line),
          ...classes.allMatches(line),
        ]) {
          offences.add('$path:${i + 1}: ${m[0]}');
        }
        // The prefix check above relies on dartcv4 always being imported
        // as `cv`, and only through its main library.
        if (line.startsWith("import 'package:dartcv4/") &&
            line != "import 'package:dartcv4/dartcv.dart' as cv;" &&
            path != 'packages/canvas_detect/lib/safe_cv.dart') {
          offences.add('$path:${i + 1}: $line');
        }
      }
    }
    expect(
      offences,
      isEmpty,
      reason:
          'Call these through package:canvas_detect/safe_cv.dart (add a '
          'wrapper if it lacks one; classes with hazardous methods need '
          'wrappers before use). See m1-design §7.',
    );
  });
}

/// Names of dartcv4's top-level functions whose body contains [_hazard], and
/// of the classes with such a method.
({Set<String> functions, Set<String> classes}) _scanDartcv(Directory src) {
  final functions = <String>{};
  final classes = <String>{};
  for (final file in src.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('/g/')) continue;
    String? function;
    String? klass;
    for (final line in file.readAsLinesSync()) {
      if (_topLevel.hasMatch(line) && line.trim().isNotEmpty) {
        final c = _classDecl.firstMatch(line);
        klass = c?[1];
        function = c == null ? _functionName.firstMatch(line)?.group(1) : null;
      }
      if (!_hazard.hasMatch(line)) continue;
      if (klass != null) {
        classes.add(klass);
      } else if (function != null) {
        functions.add(function);
      }
    }
  }
  return (functions: functions, classes: classes);
}

Iterable<File> _ourDartFiles(Directory repo) sync* {
  for (final dir in [
    'lib',
    'test',
    'tool',
    'integration_test',
    'packages/canvas_detect/lib',
    'packages/canvas_detect/bin',
    'packages/canvas_detect/tool',
    'packages/canvas_detect/test',
  ]) {
    final d = Directory('${repo.path}/$dir');
    if (!d.existsSync()) continue;
    yield* d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
  }
}
