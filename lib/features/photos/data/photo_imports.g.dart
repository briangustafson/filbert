// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_imports.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Adding photos to projects (m1-design §3.2, §3.3, §3.6): camera and picker,
/// import with progress, and rendering each new photo's thumbnail and preview
/// in the background so they're ready when shown.
///
/// State: imports in progress, by project id.

@ProviderFor(PhotoImports)
final photoImportsProvider = PhotoImportsProvider._();

/// Adding photos to projects (m1-design §3.2, §3.3, §3.6): camera and picker,
/// import with progress, and rendering each new photo's thumbnail and preview
/// in the background so they're ready when shown.
///
/// State: imports in progress, by project id.
final class PhotoImportsProvider
    extends $NotifierProvider<PhotoImports, Map<String, ImportProgress>> {
  /// Adding photos to projects (m1-design §3.2, §3.3, §3.6): camera and picker,
  /// import with progress, and rendering each new photo's thumbnail and preview
  /// in the background so they're ready when shown.
  ///
  /// State: imports in progress, by project id.
  PhotoImportsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoImportsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoImportsHash();

  @$internal
  @override
  PhotoImports create() => PhotoImports();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, ImportProgress> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, ImportProgress>>(value),
    );
  }
}

String _$photoImportsHash() => r'39938a6ca3cda6ffaeb5f41671a94c737a8a7418';

/// Adding photos to projects (m1-design §3.2, §3.3, §3.6): camera and picker,
/// import with progress, and rendering each new photo's thumbnail and preview
/// in the background so they're ready when shown.
///
/// State: imports in progress, by project id.

abstract class _$PhotoImports extends $Notifier<Map<String, ImportProgress>> {
  Map<String, ImportProgress> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<Map<String, ImportProgress>, Map<String, ImportProgress>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, ImportProgress>,
                Map<String, ImportProgress>
              >,
              Map<String, ImportProgress>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
