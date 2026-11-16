import 'dart:math' as math;

import 'package:filbert/core/imaging/crop_geometry.dart';
import 'package:filbert/core/imaging/edits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A 4000×3000 photo.
  CropFrame frame({double degrees = 0, int turns = 0}) => CropFrame(
    sourceWidth: 4000,
    sourceHeight: 3000,
    angle: degrees * math.pi / 180,
    quarterTurns: turns,
  );

  Matcher closeToRect(CropRect r) =>
      predicate<CropRect>((a) => a.closeTo(r, 0.01), 'close to $r');

  Matcher closeToQuad(List<(double, double)> expected) =>
      predicate<List<NormPoint>>((quad) {
        for (var i = 0; i < 4; i++) {
          if ((quad[i].x - expected[i].$1).abs() > 1e-6 ||
              (quad[i].y - expected[i].$2).abs() > 1e-6) {
            return false;
          }
        }
        return true;
      }, 'quad close to $expected');

  group('contains and fitting', () {
    test('the whole frame fits when not straightened', () {
      final f = frame();
      expect(f.contains(f.full), isTrue);
      expect(f.contains(f.full.scale(1.01)), isFalse);
    });

    test('straightening: the whole frame no longer fits; fit shrinks it', () {
      final f = frame(degrees: 10);
      expect(f.contains(f.full), isFalse);
      final fitted = f.fit(f.full);
      expect(f.contains(fitted), isTrue);
      expect(fitted.width / fitted.height, closeTo(4 / 3, 1e-9));
      expect(fitted.center.x, closeTo(0, 1e-9));
      // Not shrunk more than needed: 0.1% larger no longer fits.
      expect(f.contains(fitted.scale(1.001)), isFalse);
    });

    test('a crop outside the photo is brought back in', () {
      final f = frame();
      final fitted = f.fit(CropRect.centered(3000, 0, 500, 500));
      expect(f.contains(fitted), isTrue);
    });

    test('toward stops at the edge', () {
      final f = frame();
      final from = CropRect.centered(0, 0, 1000, 1000);
      final to = from.translate(5000, 0); // far off to the right
      final moved = f.toward(from, to);
      expect(moved.right, closeTo(2000, 0.01));
      expect(moved.width, closeTo(1000, 1e-9));
    });

    test('largest crop of an aspect, centred where possible', () {
      final f = frame();
      expect(
        f.largest(const CropAspect(1, 1)),
        closeToRect(CropRect.centered(0, 0, 3000, 3000)),
      );
      expect(
        f.largest(const CropAspect(4, 5)),
        closeToRect(CropRect.centered(0, 0, 2400, 3000)),
      );
      expect(f.largest(null), closeToRect(f.full));
      // Off-centre request: as near as fits.
      final square = f.largest(const CropAspect(1, 1), center: (x: 1500, y: 0));
      expect(square.right, closeTo(2000, 0.01));
    });
  });

  group('toEdits', () {
    test('the whole photo is no crop', () {
      final f = frame();
      expect(f.toEdits(f.full), Edits.none);
      expect(
        frame(turns: 1).toEdits(frame(turns: 1).full),
        const Edits(quarterTurns: 1),
      );
    });

    test('axis-aligned crop: the matching quad', () {
      final f = frame();
      // Left half: x −2000…0 of centred coordinates.
      final edits = f.toEdits(const CropRect(-2000, -1500, 0, 1500));
      expect(
        edits.crop!.quad,
        closeToQuad([(0, 0), (0.5, 0), (0.5, 1), (0, 1)]),
      );
      expect(edits.crop!.output, isNull);
      expect(edits.quarterTurns, 0);
    });

    test('straightened crop: a rotated rectangle in the original', () {
      final f = frame(degrees: 90 / 9); // 10°
      final rect = f.largest(const CropAspect(4, 3));
      final quad = f.toEdits(rect).crop!.quad;
      // Top edge points 10° counter-clockwise in the original (the photo was
      // turned clockwise to straighten it).
      final dx = (quad[1].x - quad[0].x) * 4000;
      final dy = (quad[1].y - quad[0].y) * 3000;
      expect(math.atan2(-dy, dx) * 180 / math.pi, closeTo(10, 1e-6));
      // All corners inside the photo; valid edits.
      expect(() => f.toEdits(rect).validate(), returnsNormally);
    });

    test('quarter turns: the quad is in unturned order; output flips', () {
      final f = frame(turns: 1); // displayed 3000×4000
      // Top half of the display = the left half of the original.
      const topHalf = CropRect(-1500, -2000, 1500, 0);
      final edits = f.toEdits(topHalf, aspect: const CropAspect(3, 2));
      expect(edits.quarterTurns, 1);
      expect(
        edits.crop!.quad,
        closeToQuad([(0, 0), (0.5, 0), (0.5, 1), (0, 1)]),
      );
      expect(edits.crop!.output, const OutputAspect(2, 3));
    });
  });

  group('fromEdits round-trips', () {
    void roundTrip(CropFrame f, CropRect rect, {CropAspect? aspect}) {
      final edits = f.toEdits(rect, aspect: aspect);
      final state = CropFrame.fromEdits(
        edits,
        sourceWidth: 4000,
        sourceHeight: 3000,
      )!;
      expect(state.frame.angle, closeTo(f.angle, 1e-8));
      expect(state.frame.quarterTurns, f.quarterTurns);
      expect(state.rect, closeToRect(rect));
      expect(state.aspect, aspect);
    }

    test('plain, straightened, turned, and both', () {
      roundTrip(frame(), const CropRect(-1000, -500, 1500, 1200));
      final s = frame(degrees: -7.5);
      roundTrip(
        s,
        s.largest(const CropAspect(4, 5)),
        aspect: const CropAspect(4, 5),
      );
      roundTrip(frame(turns: 3), const CropRect(-1000, -1500, 1200, 1800));
      final both = frame(degrees: 30, turns: 2);
      roundTrip(
        both,
        both.largest(const CropAspect(16, 9)),
        aspect: const CropAspect(16, 9),
      );
    });

    test('no crop: the whole frame, keeping quarter turns', () {
      final state = CropFrame.fromEdits(
        const Edits(quarterTurns: 1),
        sourceWidth: 4000,
        sourceHeight: 3000,
      )!;
      expect(state.frame.quarterTurns, 1);
      expect(state.rect, closeToRect(state.frame.full));
      expect(state.aspect, isNull);
    });

    test('a perspective quad is not a manual crop', () {
      final perspective = Edits(
        crop: CropEdit(
          quad: const [
            NormPoint(0.1, 0.1),
            NormPoint(0.9, 0.05),
            NormPoint(0.85, 0.95),
            NormPoint(0.15, 0.9),
          ],
        ),
      );
      expect(
        CropFrame.fromEdits(perspective, sourceWidth: 4000, sourceHeight: 3000),
        isNull,
      );
    });
  });

  test('turning a rect clockwise', () {
    // Right half of a centred 4000×3000 frame → bottom half of 3000×4000.
    expect(
      const CropRect(0, -1500, 2000, 1500).turnClockwise(),
      closeToRect(const CropRect(-1500, 0, 1500, 2000)),
    );
  });
}
