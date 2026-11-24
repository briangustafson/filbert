// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blob_availability.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(blobAvailabilityService)
final blobAvailabilityServiceProvider = BlobAvailabilityServiceProvider._();

final class BlobAvailabilityServiceProvider
    extends
        $FunctionalProvider<
          BlobAvailabilityService,
          BlobAvailabilityService,
          BlobAvailabilityService
        >
    with $Provider<BlobAvailabilityService> {
  BlobAvailabilityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blobAvailabilityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blobAvailabilityServiceHash();

  @$internal
  @override
  $ProviderElement<BlobAvailabilityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BlobAvailabilityService create(Ref ref) {
    return blobAvailabilityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlobAvailabilityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlobAvailabilityService>(value),
    );
  }
}

String _$blobAvailabilityServiceHash() =>
    r'd31e21b8e1ef66ce6965a88b15c7fb4afff7ab0d';

@ProviderFor(blobAvailability)
final blobAvailabilityProvider = BlobAvailabilityFamily._();

final class BlobAvailabilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<BlobAvailability>,
          BlobAvailability,
          Stream<BlobAvailability>
        >
    with $FutureModifier<BlobAvailability>, $StreamProvider<BlobAvailability> {
  BlobAvailabilityProvider._({
    required BlobAvailabilityFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'blobAvailabilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blobAvailabilityHash();

  @override
  String toString() {
    return r'blobAvailabilityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<BlobAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BlobAvailability> create(Ref ref) {
    final argument = this.argument as (String, String);
    return blobAvailability(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BlobAvailabilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blobAvailabilityHash() => r'3cb82baf681c7bc11bfb4c573c1d7b356d13f8b3';

final class BlobAvailabilityFamily extends $Family
    with $FunctionalFamilyOverride<Stream<BlobAvailability>, (String, String)> {
  BlobAvailabilityFamily._()
    : super(
        retry: null,
        name: r'blobAvailabilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BlobAvailabilityProvider call(String blobId, String mimeType) =>
      BlobAvailabilityProvider._(argument: (blobId, mimeType), from: this);

  @override
  String toString() => r'blobAvailabilityProvider';
}
