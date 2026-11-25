import 'dart:async';

import 'package:filbert/core/clock/clock.dart';
import 'package:filbert/features/sync/data/sync_controller.dart';
import 'package:filbert/features/sync/data/sync_providers.dart';
import 'package:filbert/features/sync/data/sync_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_engine/sync_engine.dart';

import '../../support/fake_sync.dart';

/// A pass that takes [duration] and fails while [failWith] is set.
class _FakeEngine implements SyncEngine {
  var passes = 0;
  var running = 0;
  Duration duration = const Duration(seconds: 2);
  UnavailableReason? failWith;

  @override
  Future<SyncReport> syncOnce() async {
    passes++;
    running++;
    await Future<void>.delayed(duration);
    running--;
    final reason = failWith;
    if (reason != null) throw RemoteUnavailable('test', reason);
    return SyncReport();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Time that moves with [_Time.elapse].
class _Time implements Clock {
  _Time(this.tester);

  final WidgetTester tester;
  var _elapsed = Duration.zero;

  @override
  DateTime now() => DateTime.utc(2026, 11, 25).add(_elapsed);

  /// Moves time and the test's timers forward together, a second at a time.
  Future<void> elapse(Duration duration) async {
    final end = _elapsed + duration;
    while (_elapsed < end) {
      final step = end - _elapsed < const Duration(seconds: 1)
          ? end - _elapsed
          : const Duration(seconds: 1);
      _elapsed += step;
      await tester.pump(step);
    }
  }

  Future<void> flushMicrotasks() => tester.pump();
}

void main() {
  late FakeSyncSettingsStore store;
  late FakeBlobDownloader downloader;
  late FakeDrivePurge purge;
  late StreamController<void> changes;
  late _FakeEngine engine;
  late ProviderContainer container;

  /// Runs [body] with a container whose sync is [enabled].
  void run(
    String description,
    bool enabled,
    Future<void> Function(_Time async) body,
  ) {
    testWidgets(description, (tester) async {
      final time = _Time(tester);
      store = FakeSyncSettingsStore(
        SyncSettings(enabled: enabled, account: 'painter@example.com'),
      );
      downloader = FakeBlobDownloader();
      purge = FakeDrivePurge();
      changes = StreamController<void>.broadcast();
      engine = _FakeEngine();
      container = ProviderContainer(
        overrides: [
          syncSettingsStoreProvider.overrideWithValue(store),
          syncEngineProvider.overrideWithValue(engine),
          blobDownloaderProvider.overrideWithValue(downloader),
          drivePurgeProvider.overrideWithValue(purge),
          localChangesProvider.overrideWithValue(changes.stream),
          clockProvider.overrideWithValue(time),
        ],
      );
      container.listen(syncControllerProvider, (_, _) {});
      await time.flushMicrotasks();
      await body(time);
      container.dispose();
      await tester.pump(const Duration(hours: 1));
    });
  }

  SyncStatus status() => container.read(syncControllerProvider);
  SyncController controller() =>
      container.read(syncControllerProvider.notifier);

  run('off: nothing runs', false, (async) async {
    changes.add(null);
    await async.elapse(const Duration(hours: 1));
    expect(engine.passes, 0);
  });

  run('on: a pass at launch, then downloads, the purge and the time', true, (
    async,
  ) async {
    expect(engine.passes, 1);
    expect(status().syncing, isTrue);
    await async.elapse(const Duration(seconds: 2));
    expect(status(), SyncStatus.idle);
    expect(downloader.runs, 1);
    expect(purge.runs, 1);
    expect(store.settings.lastSyncAt, isNotNull);
  });

  run('turning on starts a pass; turning off stops the timers', false, (
    async,
  ) async {
    unawaited(store.turnOn('painter@example.com'));
    await async.flushMicrotasks();
    expect(engine.passes, 1);
    await async.elapse(const Duration(seconds: 2));

    unawaited(store.turnOff());
    await async.flushMicrotasks();
    await async.elapse(const Duration(hours: 1));
    expect(engine.passes, 1);
  });

  run('a local change syncs 5 s after the last one', true, (async) async {
    await async.elapse(const Duration(seconds: 10));
    changes.add(null);
    await async.elapse(const Duration(seconds: 4));
    changes.add(null);
    await async.elapse(const Duration(seconds: 4));
    expect(engine.passes, 1, reason: 'debounced');
    await async.elapse(const Duration(seconds: 1));
    expect(engine.passes, 2);
  });

  run('a pass\'s own writes don\'t start another', true, (async) async {
    changes.add(null); // during the pass
    await async.elapse(const Duration(seconds: 2));
    changes.add(null); // just after, arriving late
    await async.flushMicrotasks();
    await async.elapse(const Duration(minutes: 1));
    expect(engine.passes, 1);
  });

  run('every 15 minutes', true, (async) async {
    await async.elapse(const Duration(minutes: 31));
    expect(engine.passes, 3);
  });

  run('one pass at a time; a trigger during one queues one more', true, (
    async,
  ) async {
    unawaited(controller().syncNow());
    unawaited(controller().syncNow());
    await async.flushMicrotasks();
    expect(engine.running, 1);
    await async.elapse(const Duration(seconds: 2));
    expect(engine.passes, 2, reason: 'the queued one');
    expect(engine.running, 1);
    await async.elapse(const Duration(seconds: 2));
    expect(engine.passes, 2);
  });

  run('failures back off from 30 s, doubling; Sync now tries at once', false, (
    async,
  ) async {
    engine.failWith = UnavailableReason.offline;
    unawaited(store.turnOn('painter@example.com'));
    await async.flushMicrotasks();
    await async.elapse(const Duration(seconds: 2));
    expect(status().failure, UnavailableReason.offline);

    // An automatic trigger inside the backoff is skipped.
    changes.add(null);
    await async.elapse(const Duration(seconds: 6));
    expect(engine.passes, 1);

    // The retry at 30 s fails too; the next waits 60 s.
    await async.elapse(const Duration(seconds: 24));
    expect(engine.passes, 2);
    await async.elapse(const Duration(seconds: 50));
    expect(engine.passes, 2);
    await async.elapse(const Duration(seconds: 14));
    expect(engine.passes, 3);
    expect(engine.running, 0);

    // Sync now doesn't wait, and success clears the failure.
    engine.failWith = null;
    unawaited(controller().syncNow());
    await async.elapse(const Duration(seconds: 2));
    expect(engine.passes, 4);
    expect(status(), SyncStatus.idle);
  });

  run('coming back to the app syncs at once', true, (async) async {
    await async.elapse(const Duration(minutes: 1));
    controller().onResume();
    await async.flushMicrotasks();
    expect(engine.passes, 2);
  });
}
