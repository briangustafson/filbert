import 'dart:math' as math;

import 'package:filbert/core/imaging/crop_geometry.dart';
import 'package:filbert/core/imaging/edits.dart';
import 'package:filbert/features/crop/crop_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A 4000×3000 photo; centred coordinates run −2000…2000, −1500…1500.
  CropEditor open({Edits edits = Edits.none, CropAspect? project}) =>
      CropEditor.forEdits(
        edits,
        sourceWidth: 4000,
        sourceHeight: 3000,
        defaultAspect: project,
      )!;

  const min = 100.0;

  Matcher near(CropRect r) =>
      predicate<CropRect>((a) => a.closeTo(r, 0.01), 'close to $r');

  void drag(CropEditor e, CropHandle h, double dx, double dy) {
    e.startDrag(h);
    e.updateDrag(dx, dy, minSize: min);
    e.endDrag();
  }

  group('opening', () {
    test('uncropped, no project ratio: the whole photo, freeform', () {
      final e = open();
      expect(e.rect, near(const CropRect(-2000, -1500, 2000, 1500)));
      expect(e.aspect, isNull);
      expect(e.edits, Edits.none);
    });

    test('uncropped with a project ratio: proposes it', () {
      final e = open(project: const CropAspect(4, 5));
      expect(e.aspect, const CropAspect(4, 5));
      expect(e.rect, near(CropRect.centered(0, 0, 2400, 3000)));
    });

    test('an existing crop reopens as it was', () {
      final first = open(project: const CropAspect(4, 5));
      drag(first, CropHandle.move, 300, 0);
      final e = open(edits: first.edits, project: const CropAspect(4, 5));
      expect(e.rect, near(first.rect));
      expect(e.aspect, const CropAspect(4, 5));
    });

    test('a perspective crop cannot be opened', () {
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
        CropEditor.forEdits(
          perspective,
          sourceWidth: 4000,
          sourceHeight: 3000,
          defaultAspect: null,
        ),
        isNull,
      );
    });
  });

  group('freeform handles', () {
    test('a corner moves both of its edges', () {
      final e = open();
      drag(e, CropHandle.bottomRight, -500, -300);
      expect(e.rect, near(const CropRect(-2000, -1500, 1500, 1200)));
    });

    test('an edge moves only itself', () {
      final e = open();
      drag(e, CropHandle.top, 0, 400);
      expect(e.rect, near(const CropRect(-2000, -1100, 2000, 1500)));
    });

    test('never smaller than the minimum, never inside out', () {
      final e = open();
      drag(e, CropHandle.left, 9000, 0);
      expect(e.rect.width, closeTo(min, 1e-9));
      expect(e.rect.right, closeTo(2000, 1e-9));
    });

    test('never outside the photo', () {
      final e = open();
      drag(e, CropHandle.bottomRight, -1000, -1000);
      drag(e, CropHandle.bottomRight, 5000, 5000);
      expect(e.rect, near(const CropRect(-2000, -1500, 2000, 1500)));
    });

    test('moving stops at the edge without changing size', () {
      final e = open();
      drag(e, CropHandle.bottomRight, -2000, -1500); // 2000×1500
      drag(e, CropHandle.move, 9000, 9000);
      expect(e.rect, near(const CropRect(0, 0, 2000, 1500)));
    });
  });

  group('locked handles keep the ratio', () {
    test('corner: the opposite corner stays put', () {
      final e = open(project: const CropAspect(1, 1)); // 3000×3000
      drag(e, CropHandle.topLeft, 1000, 200);
      expect(e.rect.width / e.rect.height, closeTo(1, 1e-9));
      expect(e.rect.right, closeTo(1500, 1e-3));
      expect(e.rect.bottom, closeTo(1500, 1e-3));
    });

    test('edge: grows around the middle of the dragged edge', () {
      final e = open(project: const CropAspect(1, 1));
      drag(e, CropHandle.right, -1000, 0);
      expect(e.rect, near(const CropRect(-1500, -1000, 500, 1000)));
    });

    test('stops at the photo edge, still at the ratio', () {
      final e = open(project: const CropAspect(4, 5));
      drag(e, CropHandle.bottomRight, 5000, 5000);
      expect(e.rect.width / e.rect.height, closeTo(0.8, 1e-9));
      expect(e.frame.contains(e.rect), isTrue);
    });
  });

  group('aspect lock', () {
    test('locking keeps the centre and fills as much as fits', () {
      final e = open();
      drag(e, CropHandle.move, 0, 0);
      e.setAspect(const CropAspect(1, 1));
      expect(e.rect, near(CropRect.centered(0, 0, 3000, 3000)));
    });

    test('portrait ↔ landscape', () {
      final e = open(project: const CropAspect(4, 5));
      e.flipAspect();
      expect(e.aspect, const CropAspect(5, 4));
      expect(e.rect.width / e.rect.height, closeTo(1.25, 1e-9));
    });

    test('freeform keeps the current crop', () {
      final e = open(project: const CropAspect(4, 5));
      final before = e.rect;
      e.setAspect(null);
      expect(e.rect, before);
      expect(e.edits.crop!.output, isNull);
    });

    test('a locked crop stores its ratio', () {
      final e = open(project: const CropAspect(4, 5));
      expect(e.edits.crop!.output, const OutputAspect(4, 5));
    });
  });

  group('straighten and turn', () {
    test(
      'straightening shrinks the crop; it grows back in the same gesture',
      () {
        final e = open();
        final full = e.rect;
        e.startStraighten();
        e.setAngle(10 * math.pi / 180);
        expect(e.rect.width, lessThan(full.width));
        expect(e.frame.contains(e.rect), isTrue);
        e.setAngle(0);
        expect(e.rect, near(full));
        e.endStraighten();
      },
    );

    test('the angle is limited to ±45°', () {
      final e = open();
      e.setAngle(math.pi);
      expect(e.frame.angle, CropFrame.maxAngle);
    });

    test('Rotate 90° turns the crop and the lock with the photo', () {
      final e = open(project: const CropAspect(4, 5));
      e.rotate90();
      expect(e.frame.quarterTurns, 1);
      expect(e.aspect, const CropAspect(5, 4));
      expect(e.rect, near(CropRect.centered(0, 0, 3000, 2400)));
      expect(e.edits.quarterTurns, 1);
    });

    test('Reset: unstraightened, unturned, project ratio proposed', () {
      final e = open(project: const CropAspect(4, 5));
      e.rotate90();
      e.setAngle(0.2);
      e.setAspect(null);
      e.reset();
      expect(e.frame.angle, 0);
      expect(e.frame.quarterTurns, 0);
      expect(e.aspect, const CropAspect(4, 5));
      expect(e.rect, near(CropRect.centered(0, 0, 2400, 3000)));
    });
  });
}
