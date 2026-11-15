// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opened before `runApp` and supplied as an override (see `main.dart`).

@ProviderFor(fileStore)
final fileStoreProvider = FileStoreProvider._();

/// Opened before `runApp` and supplied as an override (see `main.dart`).

final class FileStoreProvider
    extends $FunctionalProvider<FileStore, FileStore, FileStore>
    with $Provider<FileStore> {
  /// Opened before `runApp` and supplied as an override (see `main.dart`).
  FileStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileStoreHash();

  @$internal
  @override
  $ProviderElement<FileStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileStore create(Ref ref) {
    return fileStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileStore>(value),
    );
  }
}

String _$fileStoreHash() => r'5f28ccae753a8f9e0e63651145647e404921b1dd';
