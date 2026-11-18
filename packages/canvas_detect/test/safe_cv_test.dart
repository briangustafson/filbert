// The safe_cv.dart wrappers give the same results as the dartcv4 functions
// they replace (m1-design §7). The one file allowed to call those directly
// (see safe_cv_guard_test.dart).

import 'package:canvas_detect/safe_cv.dart' as safe_cv;
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:test/test.dart';

void main() {
  late cv.Mat image;

  setUp(() {
    image = cv.Mat.zeros(48, 64, cv.MatType.CV_8UC3);
    cv.randu(image, cv.Scalar.all(0), cv.Scalar.all(255));
  });

  tearDown(() => image.dispose());

  void expectSame(cv.Mat actual, cv.Mat expected) {
    expect(
      (actual.rows, actual.cols, actual.type),
      (expected.rows, expected.cols, expected.type),
    );
    expect(actual.data, expected.data);
    actual.dispose();
    expected.dispose();
  }

  test('resize', () {
    for (final interpolation in [cv.INTER_AREA, cv.INTER_CUBIC]) {
      expectSame(
        safe_cv.resize(image, (37, 21), interpolation: interpolation),
        cv.resize(image, (37, 21), interpolation: interpolation),
      );
    }
    // Scale factors with an empty size.
    expectSame(
      safe_cv.resize(image, (0, 0), fx: 0.5, fy: 0.25),
      cv.resize(image, (0, 0), fx: 0.5, fy: 0.25),
    );
  });

  test('resize writes into dst when given', () {
    final dst = cv.Mat.empty();
    final out = safe_cv.resize(image, (10, 8), dst: dst);
    expect(identical(out, dst), isTrue);
    expect((dst.cols, dst.rows), (10, 8));
    dst.dispose();
  });

  test('gaussianBlur', () {
    expectSame(
      safe_cv.gaussianBlur(image, (5, 5), 0),
      cv.gaussianBlur(image, (5, 5), 0),
    );
    expectSame(
      safe_cv.gaussianBlur(
        image,
        (7, 3),
        1.5,
        sigmaY: 0.5,
        borderType: cv.BORDER_REPLICATE,
      ),
      cv.gaussianBlur(
        image,
        (7, 3),
        1.5,
        sigmaY: 0.5,
        borderType: cv.BORDER_REPLICATE,
      ),
    );
  });

  test('getStructuringElement', () {
    for (final shape in [cv.MORPH_RECT, cv.MORPH_ELLIPSE, cv.MORPH_CROSS]) {
      expectSame(
        safe_cv.getStructuringElement(shape, (5, 3)),
        cv.getStructuringElement(shape, (5, 3)),
      );
    }
  });

  test('warpPerspective', () {
    final h = cv.getPerspectiveTransform2f(
      cv.VecPoint2f.fromList([
        cv.Point2f(3, 2),
        cv.Point2f(60, 5),
        cv.Point2f(58, 44),
        cv.Point2f(1, 40),
      ]),
      cv.VecPoint2f.fromList([
        cv.Point2f(0, 0),
        cv.Point2f(40, 0),
        cv.Point2f(40, 30),
        cv.Point2f(0, 30),
      ]),
    );
    expectSame(
      safe_cv.warpPerspective(image, h, (40, 30)),
      cv.warpPerspective(image, h, (40, 30)),
    );
    expectSame(
      safe_cv.warpPerspective(
        image,
        h,
        (50, 40),
        flags: cv.INTER_CUBIC,
        borderMode: cv.BORDER_CONSTANT,
        borderValue: cv.Scalar(10, 20, 30),
      ),
      cv.warpPerspective(
        image,
        h,
        (50, 40),
        flags: cv.INTER_CUBIC,
        borderMode: cv.BORDER_CONSTANT,
        borderValue: cv.Scalar(10, 20, 30),
      ),
    );
    h.dispose();
  });

  test('kmeans', () {
    final samples = image
        .reshape(1, image.rows * image.cols)
        .convertTo(cv.MatType.CV_32FC1);
    // Start from fixed labels, so both runs are deterministic.
    cv.Mat initialLabels() => cv.Mat.fromList(
      samples.rows,
      1,
      cv.MatType.CV_32SC1,
      [for (var i = 0; i < samples.rows; i++) i % 4],
    );
    const criteria = (cv.TERM_COUNT + cv.TERM_EPS, 20, 0.5);
    final (safeRval, safeLabels, safeCenters) = safe_cv.kmeans(
      samples,
      4,
      initialLabels(),
      criteria,
      1,
      cv.KMEANS_USE_INITIAL_LABELS,
    );
    final (rval, labels, centers) = cv.kmeans(
      samples,
      4,
      initialLabels(),
      criteria,
      1,
      cv.KMEANS_USE_INITIAL_LABELS,
    );
    expect(safeRval, rval);
    expect(safeRval, greaterThan(0));
    expectSame(safeLabels, labels);
    expectSame(safeCenters, centers);
    samples.dispose();
  });
}
