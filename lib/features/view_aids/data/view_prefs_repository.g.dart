// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'view_prefs_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(viewPrefsRepository)
final viewPrefsRepositoryProvider = ViewPrefsRepositoryProvider._();

final class ViewPrefsRepositoryProvider
    extends
        $FunctionalProvider<
          ViewPrefsRepository,
          ViewPrefsRepository,
          ViewPrefsRepository
        >
    with $Provider<ViewPrefsRepository> {
  ViewPrefsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewPrefsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewPrefsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ViewPrefsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ViewPrefsRepository create(Ref ref) {
    return viewPrefsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewPrefsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewPrefsRepository>(value),
    );
  }
}

String _$viewPrefsRepositoryHash() =>
    r'2b1ef0da072c52a4ff3bad4a569110a0f48a9c19';
