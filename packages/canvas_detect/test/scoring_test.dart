import 'dart:typed_data';

import 'package:canvas_detect/src/edge_map.dart';
import 'package:canvas_detect/src/geometry.dart';
import 'package:canvas_detect/src/scoring.dart';
import 'package:test/test.dart';

ScoredCandidate scored(List<V> corners, double score) =>
    ScoredCandidate(Candidate(corners), score, const [1, 1, 1, 1]);

void main() {
  const outer = [V(0, 0), V(100, 0), V(100, 110), V(0, 110)];
  const ledgeFree = [V(0, 0), V(100, 0), V(100, 100), V(0, 100)];
  const painted = [V(10, 10), V(60, 10), V(60, 60), V(10, 60)];

  test('a quad just inside the best one wins if it scores nearly as well', () {
    final best = pickBest([scored(outer, 0.80), scored(ledgeFree, 0.78)]);
    expect(best.candidate.corners, ledgeFree);
  });

  test('...but not if it scores clearly worse', () {
    final best = pickBest([scored(outer, 0.80), scored(ledgeFree, 0.70)]);
    expect(best.candidate.corners, outer);
  });

  test('...nor if it is much smaller (a shape in the painting)', () {
    final best = pickBest([scored(outer, 0.80), scored(painted, 0.79)]);
    expect(best.candidate.corners, outer);
  });

  test('a quad that is not inside the best one is ignored', () {
    const shifted = [V(5, 0), V(105, 0), V(105, 100), V(5, 100)];
    final best = pickBest([scored(outer, 0.80), scored(shifted, 0.79)]);
    expect(best.candidate.corners, outer);
  });

  test('edge support grows gradually with edge strength', () {
    // A vertical step at x = 50 of the given height, on a 100 × 100 map
    // with strong edges elsewhere setting the threshold. Support ramps from
    // 0 at half the threshold to 1 at 1.5×.
    double supportFor(double step) {
      const n = 100;
      final gx = Float32List(n * n), gy = Float32List(n * n);
      for (var y = 0; y < n; y++) {
        gx[y * n + 50] = step;
        for (var x = 0; x < 25; x++) {
          gx[y * n + x] = 100; // a quarter of the map: threshold 100
        }
      }
      final scorer = Scorer(EdgeMap(width: n, height: n, gx: gx, gy: gy));
      return scorer.sideSupport(const V(50, 5), const V(50, 95));
    }

    final weak = supportFor(40),
        middle = supportFor(100),
        strong = supportFor(200);
    expect(weak, lessThan(middle));
    expect(middle, lessThan(strong));
    expect(middle, inExclusiveRange(0, 1));
    expect(supportFor(0), 0);
  });
}
