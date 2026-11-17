import 'dart:typed_data';

import 'package:canvas_detect/src/edge_map.dart';
import 'package:canvas_detect/src/geometry.dart';
import 'package:canvas_detect/src/refine.dart';
import 'package:test/test.dart';

/// Gradients of an image given by [value] (central differences).
EdgeMap edgeMapOf(int w, int h, double Function(int x, int y) value) {
  final gx = Float32List(w * h), gy = Float32List(w * h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      gx[y * w + x] = (value(x + 1, y) - value(x - 1, y)) / 2;
      gy[y * w + x] = (value(x, y + 1) - value(x, y - 1)) / 2;
    }
  }
  return EdgeMap(width: w, height: h, gx: gx, gy: gy);
}

bool inRect(int x, int y, int l, int t, int r, int b) =>
    x >= l && x < r && y >= t && y < b;

void main() {
  test('sides snap to the edges a few pixels away', () {
    // Canvas face covers x 60–240, y 50–150.
    final edges = edgeMapOf(
      300,
      200,
      (x, y) => inRect(x, y, 60, 50, 240, 150) ? 200 : 40,
    );
    final refined = refineQuad(edges, const [
      V(64, 46),
      V(236, 47),
      V(243, 153),
      V(57, 146),
    ], search: 8);
    const truth = [
      V(59.5, 49.5),
      V(239.5, 49.5),
      V(239.5, 149.5),
      V(59.5, 149.5),
    ];
    for (var i = 0; i < 4; i++) {
      expect((refined[i] - truth[i]).length, lessThan(1), reason: 'corner $i');
    }
  });

  test('of two nearby edges, the inner one wins', () {
    // Face (x 60–240) with a dark side strip 4 px wide on its left, against a
    // mid-grey wall: the outer edge is stronger, but the face edge is inside.
    final edges = edgeMapOf(300, 200, (x, y) {
      if (y < 50 || y >= 150) return 120;
      if (x >= 60 && x < 240) return 200;
      if (x >= 56 && x < 60) return 0;
      return 120;
    });
    final refined = refineQuad(edges, const [
      V(58, 50),
      V(240, 50),
      V(240, 150),
      V(58, 150),
    ], search: 8);
    expect(refined[0].x, closeTo(59.5, 1));
    expect(refined[3].x, closeTo(59.5, 1));
  });

  test('insetQuad moves every side inward', () {
    final q = insetQuad(const [V(0, 0), V(100, 0), V(100, 50), V(0, 50)], 2);
    expect(
      [for (final p in q) (p.x, p.y)],
      [(2, 2), (98, 2), (98, 48), (2, 48)],
    );
  });
}
