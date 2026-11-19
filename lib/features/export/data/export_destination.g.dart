// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_destination.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The gallery where there is one, else a file.

@ProviderFor(exportDestination)
final exportDestinationProvider = ExportDestinationProvider._();

/// The gallery where there is one, else a file.

final class ExportDestinationProvider
    extends
        $FunctionalProvider<
          ExportDestination,
          ExportDestination,
          ExportDestination
        >
    with $Provider<ExportDestination> {
  /// The gallery where there is one, else a file.
  ExportDestinationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exportDestinationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exportDestinationHash();

  @$internal
  @override
  $ProviderElement<ExportDestination> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExportDestination create(Ref ref) {
    return exportDestination(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExportDestination value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExportDestination>(value),
    );
  }
}

String _$exportDestinationHash() => r'166834bb31326176c99dbd3ebc62e05aa2020b48';
