import 'package:canvas_detect/safe_cv.dart' as safe_cv;
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:test/test.dart';

/// OpenCV's native library builds and loads under plain `dart test`
/// (m1-design §6.1), so detection can stay in this pure-Dart package.
void main() {
  test('OpenCV loads and warps', () {
    final src = cv.Mat.zeros(100, 100, cv.MatType.CV_8UC3);
    final corners = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point(99, 0),
      cv.Point(99, 99),
      cv.Point(0, 99),
    ]);
    final half = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point(49, 0),
      cv.Point(49, 49),
      cv.Point(0, 49),
    ]);
    final h = cv.getPerspectiveTransform(corners, half);
    final out = safe_cv.warpPerspective(src, h, (50, 50));
    expect((out.cols, out.rows), (50, 50));
    expect(cv.openCvVersion(), startsWith('4.'));
  });
}
