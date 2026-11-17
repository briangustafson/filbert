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
}
