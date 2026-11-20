// Switching the crop screen's modes (m1-design §3.7).

import 'package:filbert/core/imaging/crop_geometry.dart';
import 'package:filbert/core/imaging/edits.dart';
import 'package:filbert/features/autocrop/review_geometry.dart';
import 'package:filbert/features/crop/crop_modes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trapezoid = [
    (x: 0.2, y: 0.1),
    (x: 0.8, y: 0.15),
    (x: 0.75, y: 0.9),
    (x: 0.25, y: 0.85),
  ];

  group('rectangleAround', () {
    test('the smallest upright rectangle containing the corners', () {
      final s = rectangleAround(
        trapezoid,
        quarterTurns: 0,
        sourceWidth: 400,
        sourceHeight: 300,
        aspect: null,
      );
      // Centred pixels: x from -200 to 200, y from -150 to 150.
      expect(
        s.rect.closeTo(const CropRect(-120, -120, 120, 120), 1e-9),
        isTrue,
      );
      expect(s.frame.angle, 0);
      expect(s.aspect, isNull);
    });

    test('grown to the locked ratio, then kept inside the photo', () {
      final s = rectangleAround(
        trapezoid,
        quarterTurns: 0,
        sourceWidth: 400,
        sourceHeight: 300,
        aspect: const CropAspect(2, 1),
      );
      expect(s.rect.width / s.rect.height, closeTo(2, 1e-9));
      expect(s.frame.contains(s.rect), isTrue);
      expect(s.aspect, const CropAspect(2, 1));
    });

    test('turned photos measure in the displayed size', () {
      final s = rectangleAround(
        fullImageCorners,
        quarterTurns: 1,
        sourceWidth: 400,
        sourceHeight: 300,
        aspect: null,
      );
      expect(
        s.rect.closeTo(const CropRect(-150, -200, 150, 200), 1e-9),
        isTrue,
      );
      expect(s.frame.quarterTurns, 1);
    });
  });

  test('cornersFromEdits: a stored quad as displayed, or the whole photo', () {
    expect(cornersFromEdits(Edits.none), fullImageCorners);
    final edits = Edits(
      crop: CropEdit(quad: [for (final c in trapezoid) NormPoint(c.x, c.y)]),
      quarterTurns: 1,
    );
    final back = displayedToQuad(cornersFromEdits(edits), 1);
    for (var i = 0; i < 4; i++) {
      expect(back[i].x, closeTo(edits.crop!.quad[i].x, 1e-12));
      expect(back[i].y, closeTo(edits.crop!.quad[i].y, 1e-12));
    }
  });

  test('turnCornersClockwise turns the points and the order with them', () {
    final turned = turnCornersClockwise(trapezoid);
    // The old bottom-left (0.25, 0.85) is the new top-left.
    expect(turned[0].x, closeTo(0.15, 1e-12));
    expect(turned[0].y, closeTo(0.25, 1e-12));
    // Same quad as the stored one, one turn on.
    final quad = displayedToQuad(trapezoid, 0);
    final back = displayedToQuad(turned, 1);
    for (var i = 0; i < 4; i++) {
      expect(back[i].x, closeTo(quad[i].x, 1e-12));
      expect(back[i].y, closeTo(quad[i].y, 1e-12));
    }
    expect(isValidReviewQuad(turned), isTrue);
  });
}
