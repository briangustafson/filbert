import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sync_engine/sync_engine.dart';

import '../../../core/clock/clock.dart';
import 'sync_providers.dart';
import 'sync_settings.dart';

part 'sync_controller.g.dart';

/// Where sync stands, for Settings → Sync (m3-design §7.1).
@immutable
class SyncStatus {
  const SyncStatus({this.syncing = false, this.failure});

  static const idle = SyncStatus();

  /// A pass is running.
  final bool syncing;

  /// Why the last pass failed; null if it worked (or none ran yet).
  final UnavailableReason? failure;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.syncing == syncing &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(syncing, failure);

  @override
  String toString() => 'SyncStatus(syncing: $syncing, failure: $failure)';
}

/// Runs sync passes (m3-design §6.6): at launch and when sync is turned on,
/// when the app comes back to the front, 5 s after the last local change,
/// every 15 minutes, and on Sync now. One pass at a time; a trigger during
/// a pass queues one more. After a failure, the automatic triggers back off
/// from 30 s up to 15 minutes; Sync now and coming back always try at once.
/// A finished pass starts the downloads and, daily, the Drive purge.
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  static const debounce = Duration(seconds: 5);
  static const period = Duration(minutes: 15);
  static const firstBackoff = Duration(seconds: 30);
  static const maxBackoff = Duration(minutes: 15);

  /// Local changes this soon after a pass are its own writes arriving late.
  static const _echo = Duration(seconds: 1);

  var _enabled = false;
  Future<void>? _pass;
  var _queued = false;
  var _failures = 0;
  DateTime? _notBefore;
  DateTime? _passEndedAt;
  Timer? _periodic;
  Timer? _debounce;
  Timer? _retry;
  StreamSubscription<void>? _changes;

  @override
  SyncStatus build() {
    ref.onDispose(_stop);
    ref.listen(syncSettingsProvider, (_, next) {
      final settings = next.value;
      if (settings != null) _setEnabled(settings.enabled);
    }, fireImmediately: true);
    return SyncStatus.idle;
  }

  Clock get _clock => ref.read(clockProvider);

  /// Sync now: runs at once, even while backing off.
  Future<void> syncNow() => _trigger(force: true);

  /// The app came back to the front.
  void onResume() => unawaited(_trigger(force: true));

  void _setEnabled(bool enabled) {
    if (enabled == _enabled) return;
    _enabled = enabled;
    if (!enabled) {
      _stop();
      state = SyncStatus.idle;
      return;
    }
    _periodic = Timer.periodic(period, (_) => unawaited(_trigger()));
    _changes = ref.read(localChangesProvider).listen((_) => _onLocalChange());
    // At launch, or just turned on.
    unawaited(_trigger(force: true));
  }

  void _stop() {
    _periodic?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
    unawaited(_changes?.cancel());
    _periodic = _debounce = _retry = null;
    _changes = null;
    _queued = false;
    _failures = 0;
    _notBefore = null;
  }

  void _onLocalChange() {
    if (_pass != null) return;
    final ended = _passEndedAt;
    if (ended != null && _clock.now().difference(ended) < _echo) return;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(_trigger()));
  }

  Future<void> _trigger({bool force = false}) async {
    if (!_enabled) return;
    final notBefore = _notBefore;
    if (!force && notBefore != null && _clock.now().isBefore(notBefore)) {
      return;
    }
    final running = _pass;
    if (running != null) {
      _queued = true;
      return running;
    }
    final pass = _run();
    _pass = pass;
    try {
      await pass;
    } finally {
      _pass = null;
      if (ref.mounted) _passEndedAt = _clock.now();
    }
    if (_queued && _enabled && ref.mounted) {
      _queued = false;
      await _trigger(force: true);
    }
  }

  Future<void> _run() async {
    state = SyncStatus(syncing: true, failure: state.failure);
    try {
      final report = await ref.read(syncEngineProvider).syncOnce();
      debugPrint('Sync: $report');
      if (!ref.mounted) return;
      _failures = 0;
      _notBefore = null;
      _retry?.cancel();
      await ref
          .read(syncSettingsStoreProvider)
          .setLastSyncAt(_clock.now().millisecondsSinceEpoch);
      state = SyncStatus.idle;
      unawaited(ref.read(blobDownloaderProvider).run());
      unawaited(_purge());
    } on RemoteUnavailable catch (e) {
      debugPrint('Sync failed: $e');
      if (ref.mounted) _failed(e.reason);
    } on Exception catch (e) {
      debugPrint('Sync failed: $e');
      if (ref.mounted) _failed(UnavailableReason.other);
    }
  }

  void _failed(UnavailableReason reason) {
    _failures++;
    final delay = Duration(
      milliseconds: math.min(
        firstBackoff.inMilliseconds * math.pow(2, _failures - 1).toInt(),
        maxBackoff.inMilliseconds,
      ),
    );
    _notBefore = _clock.now().add(delay);
    _retry?.cancel();
    _retry = Timer(delay, () => unawaited(_trigger()));
    state = SyncStatus(failure: reason);
  }

  Future<void> _purge() async {
    try {
      final purged = await ref.read(drivePurgeProvider).runIfDue();
      if (purged > 0) debugPrint('Purged $purged photos from Drive');
    } on Exception catch (e) {
      debugPrint('Drive purge failed: $e');
    }
  }
}
