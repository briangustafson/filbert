// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'canvas_detection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The detector in use (runs in a background isolate).

@ProviderFor(canvasDetector)
final canvasDetectorProvider = CanvasDetectorProvider._();

/// The detector in use (runs in a background isolate).

final class CanvasDetectorProvider
    extends $FunctionalProvider<CanvasDetector, CanvasDetector, CanvasDetector>
    with $Provider<CanvasDetector> {
  /// The detector in use (runs in a background isolate).
  CanvasDetectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canvasDetectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canvasDetectorHash();

  @$internal
  @override
  $ProviderElement<CanvasDetector> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CanvasDetector create(Ref ref) {
    return canvasDetector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CanvasDetector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CanvasDetector>(value),
    );
  }
}

String _$canvasDetectorHash() => r'9f52ab9213928ac12b3ccb6992e420754c540daa';

@ProviderFor(canvasDetection)
final canvasDetectionProvider = CanvasDetectionProvider._();

final class CanvasDetectionProvider
    extends
        $FunctionalProvider<CanvasDetection, CanvasDetection, CanvasDetection>
    with $Provider<CanvasDetection> {
  CanvasDetectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canvasDetectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canvasDetectionHash();

  @$internal
  @override
  $ProviderElement<CanvasDetection> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CanvasDetection create(Ref ref) {
    return canvasDetection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CanvasDetection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CanvasDetection>(value),
    );
  }
}

String _$canvasDetectionHash() => r'55aab0a784f7806f5624f88b342ea9fd62727b7c';
