import 'package:filbert/core/imaging/edits.dart';
import 'package:filbert/core/imaging/edits_hash.dart';
import 'package:filbert/core/imaging/render_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

Edits crop(
  List<(double, double)> corners, {
  OutputAspect? output,
  int turns = 0,
}) => Edits(
  crop: CropEdit(
    quad: [for (final (x, y) in corners) NormPoint(x, y)],
    output: output,
  ),
  quarterTurns: turns,
);

void main() {
  group('RenderPlan', () {
    RenderPlan plan(
      Edits edits, {
      int w = 4000,
      int h = 3000,
      int max = 2048,
      int maxDecode = RenderPlan.defaultMaxDecodeLongEdge,
    }) => RenderPlan.forEdits(
      sourceWidth: w,
      sourceHeight: h,
      edits: edits,
      maxLongEdge: max,
      maxDecodeLongEdge: maxDecode,
    );

    test('full image: scaled to the long edge, decoded at that size', () {
      final p = plan(Edits.none);
      expect((p.warpWidth, p.warpHeight), (2048, 1536));
      expect((p.decodeWidth, p.decodeHeight), (2048, 1536));
      expect(p.outputSize, (2048, 1536));
    });

    test('never upscales a small original', () {
      final p = plan(Edits.none, w: 640, h: 480);
      expect((p.warpWidth, p.warpHeight), (640, 480));
      expect((p.decodeWidth, p.decodeHeight), (640, 480));
    });

    test('axis-aligned crop: size from the crop, decode at the same scale', () {
      // Left half of a 4000×3000 photo: 2000×3000 at full resolution.
      final p = plan(crop([(0, 0), (0.5, 0), (0.5, 1), (0, 1)]));
      expect((p.warpWidth, p.warpHeight), (1365, 2048));
      expect((p.decodeWidth, p.decodeHeight), (2731, 2048));
    });

    test('a small crop of a large photo caps the decode size', () {
      final p = plan(
        crop([(0.4, 0.4), (0.5, 0.4), (0.5, 0.5), (0.4, 0.5)]),
        w: 8000,
        h: 6000,
      );
      // The crop is only 800×600, so the output stays at that size…
      expect((p.warpWidth, p.warpHeight), (800, 600));
      // …but the full-resolution decode would be 8000×6000; capped at 4096.
      expect((p.decodeWidth, p.decodeHeight), (4096, 3072));
    });

    test('quad size is the average of opposite edges', () {
      // Trapezoid: top 1000 px wide, bottom 2000 px; sides ~2000 px tall.
      final p = plan(
        crop([(0.375, 0), (0.625, 0), (0.75, 2 / 3), (0.25, 2 / 3)]),
        max: 100000,
      );
      expect(p.warpWidth, 1500);
      expect(p.warpHeight, closeTo(2062, 1));
    });

    test('a fixed output aspect keeps the area', () {
      final p = plan(
        crop([
          (0, 0),
          (0.5, 0),
          (0.5, 1),
          (0, 1),
        ], output: const OutputAspect(1, 1)),
        max: 100000,
      );
      // 2000×3000 has the area of a 2449×2449 square.
      expect((p.warpWidth, p.warpHeight), (2449, 2449));
    });

    test('odd quarter turns swap the output size', () {
      expect(plan(Edits(quarterTurns: 1)).outputSize, (1536, 2048));
      expect(plan(Edits(quarterTurns: 2)).outputSize, (2048, 1536));
      expect(plan(Edits(quarterTurns: 3)).outputSize, (1536, 2048));
    });

    test('a thumbnail decodes small', () {
      final p = plan(Edits.none, max: 256);
      expect((p.decodeWidth, p.decodeHeight), (256, 192));
    });

    test('corners use pixel-edge coordinates', () {
      final p = plan(Edits.none, w: 40, h: 30, max: 40);
      expect(p.sourceCorners, [
        (-0.5, -0.5),
        (39.5, -0.5),
        (39.5, 29.5),
        (-0.5, 29.5),
      ]);
      expect(p.destinationCorners, p.sourceCorners);
    });

    test('rejects non-positive sizes', () {
      expect(() => plan(Edits.none, w: 0), throwsArgumentError);
      expect(() => plan(Edits.none, max: 0), throwsArgumentError);
    });
  });

  group('editsHash', () {
    test('16 hex digits, stable across runs', () {
      // Pinned: changing it invalidates every cached render on users' devices.
      expect(editsHash(Edits.none), '51177dd7339526f0');
    });

    test('equal edits hash equally; different edits differ', () {
      final a = crop([(0, 0), (0.5, 0), (0.5, 1), (0, 1)]);
      final b = crop([(0, 0), (0.5, 0), (0.5, 1), (0, 1)]);
      expect(editsHash(a), editsHash(b));
      expect(editsHash(a), isNot(editsHash(Edits.none)));
      expect(
        editsHash(const Edits(quarterTurns: 1)),
        isNot(editsHash(Edits.none)),
      );
    });
  });
}
