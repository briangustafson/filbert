/// Safe versions of the dartcv4 functions that take a size or termination
/// criteria as a record (m1-design §7, "dartcv4 temporary-size hazard").
///
/// dartcv4 2.3.1 converts such a record to a native struct and reads it in
/// one expression, e.g. `cv_resize(…, dsize.cvd.ref, …)`. Nothing holds the
/// temporary struct, so a garbage collection between `.ref` and the native
/// call can free its memory, and OpenCV then reads garbage (in CI: a kernel
/// size that failed `ksize.width > 0 && ksize.width % 2 == 1`).
///
/// These wrappers take the same arguments but keep the struct in a local
/// variable. dartcv4's objects are `Finalizable`, so Dart keeps a local alive
/// until the end of its scope, including while the closure below runs. They
/// call dartcv4's generated bindings, which are internal: dartcv4 is pinned
/// to an exact version, and an upgrade must recheck these.
///
/// Call these instead of `cv.<name>`; `test/safe_cv_guard_test.dart` fails
/// if any dartcv4 function with this pattern is called directly.
library;

import 'dart:ffi' as ffi;

import 'package:dartcv4/dartcv.dart' as cv;
// The generated bindings, as dartcv4 itself calls them.
// ignore: implementation_imports
import 'package:dartcv4/src/g/core.g.dart' as ccore;
// ignore: implementation_imports
import 'package:dartcv4/src/g/imgproc.g.dart' as cimgproc;
import 'package:ffi/ffi.dart';

/// `cv.resize`, with [dsize] kept alive through the call.
cv.Mat resize(
  cv.Mat src,
  (int, int) dsize, {
  cv.Mat? dst,
  double fx = 0,
  double fy = 0,
  int interpolation = cv.INTER_LINEAR,
}) {
  final size = cv.Size(dsize.$1, dsize.$2);
  final out = dst ?? cv.Mat.empty();
  cv.cvRun(
    () => cimgproc.cv_resize(
      src.ref,
      out.ref,
      size.ref,
      fx,
      fy,
      interpolation,
      ffi.nullptr,
    ),
  );
  return out;
}

/// `cv.gaussianBlur`, with [ksize] kept alive through the call.
cv.Mat gaussianBlur(
  cv.Mat src,
  (int, int) ksize,
  double sigmaX, {
  cv.Mat? dst,
  double sigmaY = 0,
  int borderType = cv.BORDER_DEFAULT,
}) {
  final size = cv.Size(ksize.$1, ksize.$2);
  final out = dst ?? cv.Mat.empty();
  cv.cvRun(
    () => cimgproc.cv_GaussianBlur(
      src.ref,
      out.ref,
      size.ref,
      sigmaX,
      sigmaY,
      borderType,
      ffi.nullptr,
    ),
  );
  return out;
}

/// `cv.getStructuringElement`, with [ksize] kept alive through the call.
/// (dartcv4's version ignores its `anchor` argument, so it's left out.)
cv.Mat getStructuringElement(int shape, (int, int) ksize) {
  final size = cv.Size(ksize.$1, ksize.$2);
  final out = cv.Mat.empty();
  cv.cvRun(
    () => cimgproc.cv_getStructuringElement(
      shape,
      size.ref,
      out.ptr,
      ffi.nullptr,
    ),
  );
  return out;
}

/// `cv.warpPerspective`, with [dsize] kept alive through the call.
cv.Mat warpPerspective(
  cv.Mat src,
  cv.Mat m,
  (int, int) dsize, {
  cv.Mat? dst,
  int flags = cv.INTER_LINEAR,
  int borderMode = cv.BORDER_CONSTANT,
  cv.Scalar? borderValue,
}) {
  final size = cv.Size(dsize.$1, dsize.$2);
  final border = borderValue ?? cv.Scalar();
  final out = dst ?? cv.Mat.empty();
  cv.cvRun(
    () => cimgproc.cv_warpPerspective_1(
      src.ref,
      out.ref,
      m.ref,
      size.ref,
      flags,
      borderMode,
      border.ref,
      ffi.nullptr,
    ),
  );
  return out;
}

/// `cv.kmeans`, with [criteria] (type, max count, epsilon) kept alive
/// through the call. Returns the compactness, labels and centers.
(double rval, cv.Mat bestLabels, cv.Mat centers) kmeans(
  cv.Mat data,
  int k,
  cv.Mat bestLabels,
  (int, int, double) criteria,
  int attempts,
  int flags, {
  cv.Mat? centers,
}) {
  final term = cv.TermCriteria(criteria.$1, criteria.$2, criteria.$3);
  final out = centers ?? cv.Mat.empty();
  final compactness = calloc<ffi.Double>();
  try {
    cv.cvRun(
      () => ccore.cv_kmeans(
        data.ref,
        k,
        bestLabels.ref,
        term.ref,
        attempts,
        flags,
        out.ref,
        compactness,
        ffi.nullptr,
      ),
    );
    return (compactness.value, bestLabels, out);
  } finally {
    calloc.free(compactness);
  }
}
