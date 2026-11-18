// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'view_aids_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which aids are on for the photo screen of [projectId]. Lives while the
/// screen watches it, so leaving the screen turns every aid off
/// (m2-design §3.1).

@ProviderFor(ViewAidsState)
final viewAidsStateProvider = ViewAidsStateFamily._();

/// Which aids are on for the photo screen of [projectId]. Lives while the
/// screen watches it, so leaving the screen turns every aid off
/// (m2-design §3.1).
final class ViewAidsStateProvider
    extends $NotifierProvider<ViewAidsState, ViewAids> {
  /// Which aids are on for the photo screen of [projectId]. Lives while the
  /// screen watches it, so leaving the screen turns every aid off
  /// (m2-design §3.1).
  ViewAidsStateProvider._({
    required ViewAidsStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'viewAidsStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewAidsStateHash();

  @override
  String toString() {
    return r'viewAidsStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ViewAidsState create() => ViewAidsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewAids value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewAids>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ViewAidsStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewAidsStateHash() => r'8c08a663efcbd7db28e38c73569d37b2f3e7cfdf';

/// Which aids are on for the photo screen of [projectId]. Lives while the
/// screen watches it, so leaving the screen turns every aid off
/// (m2-design §3.1).

final class ViewAidsStateFamily extends $Family
    with
        $ClassFamilyOverride<
          ViewAidsState,
          ViewAids,
          ViewAids,
          ViewAids,
          String
        > {
  ViewAidsStateFamily._()
    : super(
        retry: null,
        name: r'viewAidsStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Which aids are on for the photo screen of [projectId]. Lives while the
  /// screen watches it, so leaving the screen turns every aid off
  /// (m2-design §3.1).

  ViewAidsStateProvider call(String projectId) =>
      ViewAidsStateProvider._(argument: projectId, from: this);

  @override
  String toString() => r'viewAidsStateProvider';
}

/// Which aids are on for the photo screen of [projectId]. Lives while the
/// screen watches it, so leaving the screen turns every aid off
/// (m2-design §3.1).

abstract class _$ViewAidsState extends $Notifier<ViewAids> {
  late final _$args = ref.$arg as String;
  String get projectId => _$args;

  ViewAids build(String projectId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ViewAids, ViewAids>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ViewAids, ViewAids>,
              ViewAids,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The project's aid settings, live (m2-design §4.1).

@ProviderFor(viewPrefs)
final viewPrefsProvider = ViewPrefsFamily._();

/// The project's aid settings, live (m2-design §4.1).

final class ViewPrefsProvider
    extends
        $FunctionalProvider<AsyncValue<ViewPrefs>, ViewPrefs, Stream<ViewPrefs>>
    with $FutureModifier<ViewPrefs>, $StreamProvider<ViewPrefs> {
  /// The project's aid settings, live (m2-design §4.1).
  ViewPrefsProvider._({
    required ViewPrefsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'viewPrefsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewPrefsHash();

  @override
  String toString() {
    return r'viewPrefsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ViewPrefs> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<ViewPrefs> create(Ref ref) {
    final argument = this.argument as String;
    return viewPrefs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ViewPrefsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewPrefsHash() => r'b52833be18661e7d5af0e0260bc639e740fe0946';

/// The project's aid settings, live (m2-design §4.1).

final class ViewPrefsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ViewPrefs>, String> {
  ViewPrefsFamily._()
    : super(
        retry: null,
        name: r'viewPrefsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The project's aid settings, live (m2-design §4.1).

  ViewPrefsProvider call(String projectId) =>
      ViewPrefsProvider._(argument: projectId, from: this);

  @override
  String toString() => r'viewPrefsProvider';
}

/// The photo's palette of [count] colors (m2-design §5.2).

@ProviderFor(photoPalette)
final photoPaletteProvider = PhotoPaletteFamily._();

/// The photo's palette of [count] colors (m2-design §5.2).

final class PhotoPaletteProvider
    extends $FunctionalProvider<AsyncValue<Palette>, Palette, FutureOr<Palette>>
    with $FutureModifier<Palette>, $FutureProvider<Palette> {
  /// The photo's palette of [count] colors (m2-design §5.2).
  PhotoPaletteProvider._({
    required PhotoPaletteFamily super.from,
    required (ProjectImage, int) super.argument,
  }) : super(
         retry: null,
         name: r'photoPaletteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$photoPaletteHash();

  @override
  String toString() {
    return r'photoPaletteProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Palette> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Palette> create(Ref ref) {
    final argument = this.argument as (ProjectImage, int);
    return photoPalette(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is PhotoPaletteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$photoPaletteHash() => r'0185d8e0aefbbe839838dc98e46cc919d71f10f5';

/// The photo's palette of [count] colors (m2-design §5.2).

final class PhotoPaletteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Palette>, (ProjectImage, int)> {
  PhotoPaletteFamily._()
    : super(
        retry: null,
        name: r'photoPaletteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The photo's palette of [count] colors (m2-design §5.2).

  PhotoPaletteProvider call(ProjectImage image, int count) =>
      PhotoPaletteProvider._(argument: (image, count), from: this);

  @override
  String toString() => r'photoPaletteProvider';
}
