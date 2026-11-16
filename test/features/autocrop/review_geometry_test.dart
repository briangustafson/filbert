import 'package:filbert/core/imaging/edits.dart';
import 'package:filbert/features/autocrop/review_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const quad = [
    NormPoint(0.1, 0.2),
    NormPoint(0.8, 0.1),
    NormPoint(0.9, 0.85),
    NormPoint(0.15, 0.9),
  ];

  Matcher nearCorners(List<ReviewCorner> expected) =>
      predicate<List<ReviewCorner>>((actual) {
        for (var i = 0; i < 4; i++) {
          if ((actual[i].x - expected[i].x).abs() > 1e-12 ||
              (actual[i].y - expected[i].y).abs() > 1e-12) {
            return false;
          }
        }
        return true;
      }, 'corners near $expected');

  test('unturned: displayed corners are the quad', () {
    expect(
      quadToDisplayed(quad, 0),
      nearCorners([for (final p in quad) (x: p.x, y: p.y)]),
    );
  });

  test('a clockwise turn moves points and reorders corners', () {
    // Turned clockwise, the original's top-left (0, 0) shows at the top
    // right (1, 0), and the warp's top-left corner is shown top-right.
    expect(originalToDisplayed(const NormPoint(0, 0), 1), (x: 1.0, y: 0.0));
    final displayed = quadToDisplayed(quad, 1);
    expect(displayed[1], originalToDisplayed(quad[0], 1));
    expect(displayed[2], originalToDisplayed(quad[1], 1));
    expect(displayed[0], originalToDisplayed(quad[3], 1));
  });

  test('round-trips for every turn; displayed quads stay valid', () {
    for (var turns = 0; turns < 4; turns++) {
      final displayed = quadToDisplayed(quad, turns);
      expect(isValidReviewQuad(displayed), isTrue, reason: 'turns $turns');
      final back = displayedToQuad(displayed, turns);
      for (var i = 0; i < 4; i++) {
        expect(back[i].x, closeTo(quad[i].x, 1e-12));
        expect(back[i].y, closeTo(quad[i].y, 1e-12));
      }
    }
  });

  group('reviewEdits', () {
    test('the full image is no crop, keeping the turn', () {
      expect(
        reviewEdits(fullImageCorners, quarterTurns: 3),
        const Edits(quarterTurns: 3),
      );
    });

    test('a quad, with the project ratio as output (pre-turn)', () {
      final displayed = quadToDisplayed(quad, 1);
      final edits = reviewEdits(
        displayed,
        quarterTurns: 1,
        aspect: (w: 4, h: 5),
      );
      expect(edits.quarterTurns, 1);
      expect(edits.crop!.output, const OutputAspect(5, 4));
      for (var i = 0; i < 4; i++) {
        expect(edits.crop!.quad[i].x, closeTo(quad[i].x, 1e-12));
      }
      expect(() => edits.validate(), returnsNormally);
    });
  });

  test('invalid quads are recognised', () {
    expect(isValidReviewQuad(insetCorners(0.05)), isTrue);
    // Crossed (bow-tie): top-right and bottom-right swapped.
    expect(
      isValidReviewQuad(const [
        (x: 0.1, y: 0.1),
        (x: 0.9, y: 0.9),
        (x: 0.9, y: 0.1),
        (x: 0.1, y: 0.9),
      ]),
      isFalse,
    );
    // Outside the photo.
    expect(
      isValidReviewQuad(const [
        (x: -0.1, y: 0.1),
        (x: 0.9, y: 0.1),
        (x: 0.9, y: 0.9),
        (x: 0.1, y: 0.9),
      ]),
      isFalse,
    );
  });
}
