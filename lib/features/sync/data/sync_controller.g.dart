// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs sync passes (m3-design §6.6): at launch and when sync is turned on,
/// when the app comes back to the front, 5 s after the last local change,
/// every 15 minutes, and on Sync now. One pass at a time; a trigger during
/// a pass queues one more. After a failure, the automatic triggers back off
/// from 30 s up to 15 minutes; Sync now and coming back always try at once.
/// A finished pass starts the downloads and, daily, the Drive purge.

@ProviderFor(SyncController)
final syncControllerProvider = SyncControllerProvider._();

/// Runs sync passes (m3-design §6.6): at launch and when sync is turned on,
/// when the app comes back to the front, 5 s after the last local change,
/// every 15 minutes, and on Sync now. One pass at a time; a trigger during
/// a pass queues one more. After a failure, the automatic triggers back off
/// from 30 s up to 15 minutes; Sync now and coming back always try at once.
/// A finished pass starts the downloads and, daily, the Drive purge.
final class SyncControllerProvider
    extends $NotifierProvider<SyncController, SyncStatus> {
  /// Runs sync passes (m3-design §6.6): at launch and when sync is turned on,
  /// when the app comes back to the front, 5 s after the last local change,
  /// every 15 minutes, and on Sync now. One pass at a time; a trigger during
  /// a pass queues one more. After a failure, the automatic triggers back off
  /// from 30 s up to 15 minutes; Sync now and coming back always try at once.
  /// A finished pass starts the downloads and, daily, the Drive purge.
  SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  SyncController create() => SyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncStatus>(value),
    );
  }
}

String _$syncControllerHash() => r'cb5b6cf117ab94f725b2bb3cb7ac704bba809ea0';

/// Runs sync passes (m3-design §6.6): at launch and when sync is turned on,
/// when the app comes back to the front, 5 s after the last local change,
/// every 15 minutes, and on Sync now. One pass at a time; a trigger during
/// a pass queues one more. After a failure, the automatic triggers back off
/// from 30 s up to 15 minutes; Sync now and coming back always try at once.
/// A finished pass starts the downloads and, daily, the Drive purge.

abstract class _$SyncController extends $Notifier<SyncStatus> {
  SyncStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncStatus, SyncStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncStatus, SyncStatus>,
              SyncStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
